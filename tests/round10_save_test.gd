extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Save = preload("res://scripts/model/save_game.gd")
const FIXTURES = [
	{"path":"res://tests/fixtures/round8-v1.rms","version":1,"hash":"C09990DEE6711A615FAD37423964B26A65196BBE8037E240BE1414E23A5598CD"},
	{"path":"res://tests/fixtures/round9-v2.rms","version":2,"hash":"4BF053671BF73A0F0B962C72CEEBFEE0E716A6A25147F38332187CE7A7AACB9F"}
]
var failures := 0
var rejected := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func raw_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	file.seek(44)
	var data: Dictionary = bytes_to_var(file.get_buffer(file.get_length()-44))
	file.close()
	return data
func fresh():
	var g = Game.new()
	g.setup(["A","B","C","D"],103,8,{"specials_enabled":true,"gods_enabled":true,"teams":[0,0,1,1]})
	return g
func reject(data: Dictionary, live, message: String) -> void:
	var before: Dictionary = Save.snapshot(live)
	var original: Dictionary = data.duplicate(true)
	var result: Dictionary = Save.restore(data)
	rejected += 1
	check(not result.ok,message)
	check(Save.snapshot(live) == before,"rejected import preserves live game: " + message)
	check(data == original,"rejected import preserves input: " + message)
func step(g) -> void:
	match g.phase:
		"roll": g.roll_dice()
		"move": g.move_to(g.available_moves()[0])
		"bank": g.close_bank()
		"shop": g.close_shop()
		"lottery": g.close_lottery()
		"magic": g.choose_magic("gain_cards")
		"reaction": g.resolve_reaction()
		"land":
			if not g.buy_property(): g.upgrade_property()
			g.end_turn()
		"end","detained": g.end_turn()
func legacy_fixtures() -> void:
	for fixture in FIXTURES:
		check(FileAccess.get_sha256(fixture.path).to_upper() == fixture.hash,"immutable historical fixture v" + str(fixture.version))
		var raw: Dictionary = raw_file(fixture.path)
		var untouched: Dictionary = raw.duplicate(true)
		check(raw.version == fixture.version,"historical bytes have original version")
		var result: Dictionary = Save.load_from_file(fixture.path)
		check(result.ok,"load historical v" + str(fixture.version) + ": " + str(result.get("error","")))
		if not result.ok: continue
		var g = result.game
		for i in range(g.players.size()):
			check(g.players[i].team == i,"missing legacy team becomes independent")
			for field in raw.state.players[i]:
				check(raw.state.players[i][field] == g.players[i][field],"legacy player data retained: " + field)
		for field in raw.state:
			if field != "players": check(raw.state[field] == g.get(field),"legacy state retained: " + field)
		check(raw == untouched and raw.rng_state == g.rng.state and raw.rng_seed == g.rng.seed,"migration preserves source and main RNG")
		check(raw.market == Save.snapshot(g).market and raw.metadata == result.metadata,"migration preserves market RNG and metadata")
		check(g.specials_enabled == (fixture.version == 2),"historical map services preserved")
		if fixture.version == 2:
			check(g.phase == "lottery" and g.pending_service.purchases == 1 and g.steps_left == 2,"genuine v2 pending service restored")
			var twin_result: Dictionary = Save.restore(raw)
			check(twin_result.ok,"v2 twin migration")
			if twin_result.ok:
				var twin = twin_result.game
				g.close_lottery(); twin.close_lottery()
				for ignored in range(35):
					step(g); step(twin)
					check(Save.snapshot(g) == Save.snapshot(twin),"v2 service continuation and RNG identical")
		var invalid: Dictionary = untouched.duplicate(true)
		invalid.state.erase("bank_visited")
		reject(invalid,g,"old mandatory field remains required")
		if fixture.version == 2:
			invalid=untouched.duplicate(true); invalid.state.erase("pending_service")
			reject(invalid,g,"v2 must not fill missing v2 service fields")
func legacy_team_labels() -> void:
	var raw: Dictionary = raw_file(FIXTURES[1].path)
	var g = fresh()
	var old: Dictionary = raw.duplicate(true)
	old.state.players[0].team="red"; old.state.players[1].team="red"
	old.state.players[2].team=null; old.state.players[3].erase("team")
	var result: Dictionary = Save.restore(old)
	check(result.ok,"legacy optional string relationships normalize")
	if result.ok:
		check(result.game.same_team(0,1) and not result.game.same_team(2,3),"only explicit matching old labels merge")
		check(old.state.players[0].team == "red" and not old.state.players[3].has("team"),"successful migration does not mutate source")
	old=raw.duplicate(true)
	old.state.players[0].team=0; old.state.players[1].team="0"
	old.state.players[2].team=-1; old.state.players[3].team="-1"
	result=Save.restore(old)
	check(result.ok and result.game.team_scores().size()==4,"typed labels and missing sentinels do not merge")
	old=raw.duplicate(true)
	old.state.players[0].team=""; old.state.players[1].team=""
	old.state.players[2].team=null; old.state.players[3].team=null
	result=Save.restore(old)
	check(result.ok and result.game.team_scores().size()==4,"empty and null labels stay independent")
	old=raw.duplicate(true)
	for p in old.state.players: p.team="one"
	reject(old,g,"legacy all-one-team data cannot silently change to free for all")
	old=raw.duplicate(true); old.state.players[1].team=[]
	reject(old,g,"legacy malformed team type rejected")
	# Completed legacy games are explicitly rescored after relationship migration.
	old=raw.duplicate(true)
	old.state.phase="finished"; old.state.pending_service={}; old.state.winners=[0]
	old.state.players[0].cash=100000
	old.state.players[0].team="red"; old.state.players[1].team="red"
	old.state.players[2].team="blue"; old.state.players[3].team="blue"
	result=Save.restore(old)
	check(result.ok and result.game.winners==[0,1],"legacy finished result expands to normalized winning team")
	check(old.state.winners==[0],"legacy result migration preserves original input")
	old.state.winners=[99]
	reject(old,g,"legacy rescoring never repairs invalid winner references")
func team_replay() -> void:
	var g = fresh()
	g.road_gods.clear()
	var lot: Dictionary = g.lots.small_1_6
	lot.owner=1; lot.level=1; lot.building_type="house"
	check(g.gm_teleport(0,int(lot.frontage_nodes[0])) and g.phase=="land","arrive allied property without rent")
	var before_owner_cash: int = g.players[1].cash
	var before_actor_cash: int = g.players[0].cash
	var cost: int = g.upgrade_cost(lot.id)
	check(g.upgrade_property(lot.id) and lot.owner==1 and g.players[0].cash==before_actor_cash-cost and g.players[1].cash==before_owner_cash,"allied upgrade payer and ownership established")
	var path := "res://.godot/round10-team-save.rms"
	check(Save.save_to_file(g,path,{"controllers":["human","ai","ai","ai"]}).ok,"v3 writes team save")
	var result: Dictionary = Save.load_from_file(path)
	check(result.ok,"v3 reads team save")
	if not result.ok: return
	var twin = result.game
	check(twin.same_team(0,1) and twin.same_team(2,3) and twin.is_opponent(0,2),"v3 restores relations")
	check(Save.snapshot(g)==Save.snapshot(twin),"v3 exact state preserved")
	for ignored in range(60):
		step(g); step(twin)
		check(Save.snapshot(g)==Save.snapshot(twin),"team economy and movement replay exact")
		if g.phase=="finished": break
	g.stock_market.advance(20); twin.stock_market.advance(20)
	check(g.stock_market.quotes==twin.stock_market.quotes and g.stock_market.rng.state==twin.stock_market.rng.state,"independent market RNG preserved")
	var data: Dictionary = Save.snapshot(g)
	var first: Dictionary = Save.restore(data)
	var second: Dictionary = Save.restore(data)
	check(first.ok and second.ok,"team clone isolation fixtures")
	if first.ok and second.ok:
		first.game.players[0].team=3
		check(second.game.players[0].team==0 and data.state.players[0].team==0 and g.players[0].team==0,"restored team mutation stays isolated")
func results_and_rejection() -> void:
	var g = fresh()
	var good: Dictionary = Save.snapshot(g)
	for value in [null,true,"0",-1,4,0.5,[],{}]:
		var bad: Dictionary = good.duplicate(true)
		bad.state.players[0].team=value
		reject(bad,g,"v3 rejects malformed team " + str(value))
	var invalid: Dictionary = good.duplicate(true)
	invalid.state.players[0].erase("team"); reject(invalid,g,"v3 requires explicit team on every seat")
	invalid=good.duplicate(true)
	for p in invalid.state.players: p.team=0
	reject(invalid,g,"v3 requires at least two original teams")
	invalid=good.duplicate(true); invalid.state.winners=[0]
	reject(invalid,g,"unfinished match cannot have winners")
	g.players[1].bankrupt=true; g.players[2].bankrupt=true; g.players[3].bankrupt=true
	g._check_winner()
	check(g.phase=="finished" and g.winners==[0,1],"winning team includes eliminated teammate under explicit policy")
	good=Save.snapshot(g)
	var result: Dictionary = Save.restore(good)
	check(result.ok and result.game.winners==[0,1],"finished team result restores")
	for wrong in [[0],[2,3],[0,0],[99],[]]:
		invalid=good.duplicate(true); invalid.state.winners=wrong
		reject(invalid,g,"v3 rejects inconsistent finished winners " + str(wrong))
	g=fresh(); g.finish_game()
	check(g.winners==[0,1,2,3] and Save.restore(Save.snapshot(g)).ok,"tied team winners preserve all members")
	for p in g.players: p.bankrupt=true
	g.finish_game()
	check(g.winners.is_empty() and Save.restore(Save.snapshot(g)).ok,"no surviving team has no winner")
func _init() -> void:
	legacy_fixtures()
	legacy_team_labels()
	team_replay()
	results_and_rejection()
	print("ROUND10_SAVE rejected=",rejected," failures=",failures)
	quit(1 if failures else 0)
