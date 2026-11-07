extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Save = preload("res://scripts/model/save_game.gd")
const FIXTURE = "res://tests/fixtures/round8-v1.rms"
var failures := 0
var rejected := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func fresh():
	var g = Game.new()
	g.setup(["A","B","C","D"],91,40,{"specials_enabled":true,"gods_enabled":true})
	g.road_gods.clear()
	return g
func reject(data: Dictionary, message: String) -> void:
	rejected += 1
	check(not Save.restore(data).ok,message)
func clone_game(g):
	var result: Dictionary = Save.restore(bytes_to_var(var_to_bytes(Save.snapshot(g))))
	check(result.ok,"roundtrip " + g.phase + ": " + str(result.get("error","")))
	return result.get("game")
func legacy() -> void:
	check(FileAccess.get_sha256(FIXTURE).to_upper() == "C09990DEE6711A615FAD37423964B26A65196BBE8037E240BE1414E23A5598CD","immutable genuine v1 fixture")
	var result: Dictionary = Save.load_from_file(FIXTURE)
	check(result.ok,"real round8 fixture loads: " + str(result.get("error","")))
	if not result.ok: return
	var old = result.game
	check(not old.specials_enabled and old.nodes[17].kind == "event" and old.nodes[51].kind == "event","v1 keeps original road layout")
	check(old.lottery_state == old.Specials.initial_lottery() and old.shop_stock.is_empty() and old.god_respawn_due.is_empty(),"v1 adds only inactive service defaults")
	check(Save.snapshot(old).version == Save.VERSION,"migrated save writes current schema")
	var file := FileAccess.open(FIXTURE,FileAccess.READ)
	file.seek(44)
	var raw: Dictionary = bytes_to_var(file.get_buffer(file.get_length()-44))
	file.close()
	check(raw.version == 1,"fixture actually predates v2")
	var migrated: Dictionary = Save.snapshot(old)
	for key in raw.state:
		if key == "players":
			for i in range(raw.state.players.size()):
				for field in raw.state.players[i]:
					check(raw.state.players[i][field] == migrated.state.players[i][field],"v1 preserves original player field " + field)
		else: check(raw.state[key] == migrated.state[key],"v1 preserves field " + key)
	check(raw.rng_state == migrated.rng_state and raw.market == migrated.market and raw.metadata == result.metadata,"v1 preserves RNG market metadata")
	raw.state.erase("bank_visited")
	reject(raw,"migration must not repair missing original v1 fields")
func service_roundtrips() -> void:
	var g = fresh()
	g.players[0].pos=16; g.players[0].previous=15
	check(g.roll_dice(3) and g.move_to(17) and g.phase == "lottery" and g.steps_left == 2,"real movement suspends at lottery")
	check(g.buy_ticket(2),"lottery purchase before save")
	var restored = clone_game(g)
	if restored == null: return
	check(Save.snapshot(g) == Save.snapshot(restored),"lottery pending purchase and path preserved")
	check(Save.save_to_file(g,"res://.godot/round9-lottery.rms").ok and Save.load_from_file("res://.godot/round9-lottery.rms").ok,"lottery phase writes and reads v2 envelope")
	check(g.close_lottery() and restored.close_lottery(),"restored lottery resumes")
	for road in [18,19]:
		check(g.move_to(road) and restored.move_to(road),"restored remaining movement")
	check(Save.snapshot(g) == Save.snapshot(restored),"lottery movement replay exact")
	g = fresh()
	check(g.gm_teleport(0,51) and g.phase == "magic","real magic stop")
	restored = clone_game(g)
	if restored == null: return
	check(Save.save_to_file(g,"res://.godot/round9-magic.rms").ok and Save.load_from_file("res://.godot/round9-magic.rms").ok,"magic phase writes and reads v2 envelope")
	check(g.choose_magic("gain_cards") and restored.choose_magic("gain_cards"),"restored magic chooses effect")
	check(Save.snapshot(g) == Save.snapshot(restored),"magic condition and card RNG replay exact")
	check(clone_game(g) != null,"magic result remains restorable")
	g = fresh()
	var shop: Dictionary = g.facility_lot("shop")
	check(g.gm_teleport(0,int(shop.frontage_nodes[0])) and g.phase == "shop","real shop visit")
	var first: String = g.shop_offers()[0].id
	check(g.buy_card(first),"purchase reduces random shop inventory")
	restored = clone_game(g)
	if restored == null: return
	check(g.shop_offers() == restored.shop_offers() and not restored.shop_stock.has(first),"shop inventory does not reroll on load")
	g.close_shop(); restored.close_shop()
	check(Save.snapshot(g) == Save.snapshot(restored),"shop exit RNG matches")
	g = fresh()
	g.god_respawn_due={"wealth":2,"angel":3}
	g.lottery_state.tickets=[{"player":0,"number":1},{"player":1,"number":1}]
	g.lottery_state.draw_round=2
	restored = clone_game(g)
	if restored == null: return
	g.round_number=2; restored.round_number=2
	g.Specials.advance_round(g); restored.Specials.advance_round(restored)
	g.Gods.advance_round(g); restored.Gods.advance_round(restored)
	check(Save.snapshot(g) == Save.snapshot(restored),"lottery draw and cooldown respawn RNG preserved")
	check(clone_game(g) != null,"settled lottery and cooldown remain restorable")
	g.gods_enabled=false
	var paused = clone_game(g)
	check(paused != null and paused.god_respawn_due == g.god_respawn_due,"disabled gods retain paused valid cooldowns")
	var path := "res://.godot/round9-save-test.rms"
	check(Save.save_to_file(g,path,{"title":"round9"}).ok and Save.load_from_file(path).ok,"v2 disk envelope roundtrip")
func invalid_new_fields() -> void:
	var g = fresh()
	var valid: Dictionary = Save.snapshot(g)
	for key in Save.v1_additions():
		var missing: Dictionary = valid.duplicate(true)
		missing.state.erase(key)
		reject(missing,"v2 requires " + key)
	var bad: Dictionary = valid.duplicate(true)
	bad.state.specials_enabled="true"; reject(bad,"flag type must be bool")
	bad=valid.duplicate(true); bad.state.lottery_state.tickets=["bad"]; reject(bad,"ticket must be dictionary")
	bad=valid.duplicate(true); bad.state.lottery_state.tickets=[{"player":0,"number":99}]; reject(bad,"ticket number range")
	bad=valid.duplicate(true); bad.state.lottery_state.tickets=[{"player":9,"number":1}]; reject(bad,"ticket player reference")
	bad=valid.duplicate(true); bad.state.lottery_state.pot=-1; reject(bad,"negative jackpot")
	bad=valid.duplicate(true); bad.state.lottery_state.draw_round=0; reject(bad,"draw timer")
	bad=valid.duplicate(true); bad.state.lottery_state.last_winners=["A"]; reject(bad,"winner element type")
	bad=valid.duplicate(true); bad.state.service_visited=[17,17]; reject(bad,"duplicate service visits")
	bad=valid.duplicate(true); bad.state.service_visited=["17"]; reject(bad,"visit element type")
	bad=valid.duplicate(true); bad.state.service_visited=[18]; reject(bad,"non-service visit")
	bad=valid.duplicate(true); bad.state.pending_service={"kind":"lottery","road":17,"purchases":0}; reject(bad,"orphan pending service")
	bad=valid.duplicate(true); bad.state.phase="magic"; reject(bad,"magic phase needs matching pending record")
	bad=valid.duplicate(true); bad.state.magic_last_result={"effect":"gain_cards","condition":"car","targets":[7]}; reject(bad,"magic target reference")
	bad=valid.duplicate(true); bad.state.magic_last_result={"effect":"unknown","condition":"car","targets":[]}; reject(bad,"magic effect catalog")
	bad=valid.duplicate(true); bad.state.magic_last_result={"effect":"gain_cards","condition":"unknown","targets":[]}; reject(bad,"magic condition catalog")
	bad=valid.duplicate(true); bad.state.shop_stock=["portal"]; bad.state.shop_visit_serial=1; reject(bad,"research card cannot be shop inventory")
	bad=valid.duplicate(true); bad.state.shop_stock=["dice","dice"]; bad.state.shop_visit_serial=1; reject(bad,"duplicate shop stock")
	bad=valid.duplicate(true); bad.state.shop_stock=[7]; reject(bad,"shop card element type")
	bad=valid.duplicate(true); bad.state.shop_visit_serial=-1; reject(bad,"negative shop serial")
	bad=valid.duplicate(true); bad.state.shop_purchases=99; reject(bad,"shop quota bound")
	bad=valid.duplicate(true); bad.state.god_respawn_due={"wealth":"2"}; reject(bad,"cooldown value type")
	bad=valid.duplicate(true); bad.state.god_respawn_due={"fake":2}; reject(bad,"cooldown god catalog")
	bad=valid.duplicate(true); bad.state.god_respawn_due={"wealth":-1}; reject(bad,"cooldown bound")
	g.gm_teleport(0,17)
	valid=Save.snapshot(g)
	bad=valid.duplicate(true); bad.state.pending_service.purchases="1"; reject(bad,"purchase count type")
	bad=valid.duplicate(true); bad.state.pending_service.purchases=1; reject(bad,"purchase count requires owned ticket")
	bad=valid.duplicate(true); bad.state.pending_service.road=51; reject(bad,"service road mismatch")
	bad=valid.duplicate(true); bad.state.pending_service.kind="magic"; reject(bad,"service kind mismatch")
	bad=valid.duplicate(true); bad.state.players[0].pos=18; reject(bad,"service player position mismatch")
	g=fresh(); g.gm_teleport(0,51)
	bad=Save.snapshot(g); bad.state.steps_left=1; reject(bad,"magic requires completed movement")
	g=fresh(); g.gm_teleport(0,int(g.facility_lot("shop").frontage_nodes[0]))
	valid=Save.snapshot(g)
	bad=valid.duplicate(true); bad.state.players[0].pos=0; reject(bad,"shop phase must be at shop")
	bad=valid.duplicate(true); bad.state.shop_stock=[]; reject(bad,"shop stock must account for purchases")
	bad=valid.duplicate(true); bad.state.shop_visit_serial=0; reject(bad,"shop phase needs recorded visit")
	valid=Save.snapshot(fresh())
	valid.state.lottery_state.draw_count=1
	valid.state.lottery_state.last_draw={"round":1,"number":1,"pot":100,"payouts":{0:100}}
	valid.state.lottery_state.last_winners=[0]
	check(Save.restore(valid).ok,"well-formed settled payout accepted")
	bad=valid.duplicate(true); bad.state.lottery_state.last_draw.payouts={0:"100"}; reject(bad,"payout amount type")
	bad=valid.duplicate(true); bad.state.lottery_state.last_draw.payouts={0:99}; reject(bad,"payout conservation")
	bad=valid.duplicate(true); bad.state.lottery_state.last_winners=[1]; reject(bad,"payout winner linkage")
func isolation() -> void:
	var g = fresh()
	g.gm_teleport(0,17); g.buy_ticket(1)
	var payload: Dictionary = Save.snapshot(g,{"nested":{"title":"original"}})
	var restored: Dictionary = Save.restore(payload)
	check(restored.ok,"isolation fixture")
	if not restored.ok: return
	payload.state.lottery_state.tickets[0].number=2
	payload.metadata.nested.title="changed"
	check(g.lottery_state.tickets[0].number==1 and restored.game.lottery_state.tickets[0].number==1 and restored.metadata.nested.title=="original","snapshot and restore deep-copy payload")
	restored.game.lottery_state.tickets[0].number=3
	check(g.lottery_state.tickets[0].number==1,"restored clone cannot mutate live game")
func _init() -> void:
	legacy()
	service_roundtrips()
	invalid_new_fields()
	isolation()
	print("ROUND9_SAVE rejected=",rejected," failures=",failures)
	quit(1 if failures else 0)
