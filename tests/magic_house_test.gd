extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Magic=preload("res://scripts/model/magic_house.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:=0
func check(ok:bool, message:String)->void:
	if not ok: failures+=1; push_error(message)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C","D"],1212,20,{"specials_enabled":true,"characters":["sun_xiaomei","atu","sarah","ludwig"]})
	return g
func force_condition(g, condition:String)->void:
	for value in range(1,1000):
		var probe=RandomNumberGenerator.new();probe.seed=value
		if Magic.CONDITIONS[probe.randi_range(0,Magic.CONDITIONS.size()-1)]==condition:
			g.rng.seed=value;return
	check(false,"condition seed exists")
func open(g, condition:String)->void:
	check(g.gm_teleport(g.current,51) and g.phase=="magic","enter actual magic stop")
	force_condition(g,condition)
func built(g,id:String,owner:int,level:int=4)->void:
	var lot:Dictionary=g.lots[id]
	lot.owner=owner;lot.level=level;lot.building_type="house" if lot.kind=="small" else "lab"
func same_snapshot(g,label:String)->void:
	var raw:Dictionary=Save.snapshot(g)
	var restored:Dictionary=Save.restore(raw)
	check(restored.ok,label+" restores: "+str(restored.get("error","")))
	if restored.ok: check(Save.snapshot(restored.game)==raw,label+" preserves all state and RNG")
func _init()->void:
	var g=fresh()
	check(g.lottery_numbers().size()==30 and g.lottery_numbers().front()==1 and g.lottery_numbers().back()==30,"UI-backed 01..30 lottery range")
	g.gm_teleport(0,17)
	check(g.buy_ticket(30),"upper boundary ticket can be bought")
	same_snapshot(g,"ticket30")
	check(not g.buy_ticket(31),"31 rejected")
	g=fresh();g.players[0].vehicle="motorbike";g.players[1].vehicle="car"
	check(Magic.targets(g,"car")==[0,1],"vehicle condition includes motorbikes")
	check(Magic.targets(g,"female")==[0,2] and Magic.targets(g,"male")==[1,3],"sex condition follows character rather than portrait or talents")
	g.players[0].character_id="original"
	check(Magic.targets(g,"female")==[2],"neutral original has no invented sex")
	g.players[2].status={"kind":"hospital","remaining":1}
	check(Magic.targets(g,"female").is_empty(),"disappeared female excluded")
	g=fresh();g.players[2].god={"id":"poor","remaining":3}
	check(Magic.targets(g,"possessed")==[2],"god condition includes unfavorable gods")
	g.players[1].cards.append("free");g.players[2].cards.append("free")
	check(Magic.targets(g,"most_cards")==[1,2],"card count leaders include ties")
	g.players[0].pos=int(g.lots.small_4_6.frontage_nodes[0]);g.players[1].pos=17
	check(Magic.targets(g,"on_property").has(0) and not Magic.targets(g,"on_property").has(1),"property condition uses nearby land and excludes service-only roads")
	g.players[0].pos=51
	check(not Magic.targets(g,"on_property").has(0),"caster on magic square is excluded even with demo frontage")
	check(Magic.targets(g,"invented").is_empty(),"unknown condition cannot select everyone")
	# Exactly one complete building per affected owner; no neighboring/ally damage.
	g=fresh();g.players[0].vehicle="car";g.players[1].vehicle="car"
	for id in ["small_1_6","small_4_6","small_7_6"]: built(g,id,0)
	built(g,"small_10_6",1,2);built(g,"small_13_6",2,3)
	open(g,"car");g.choose_magic("demolish")
	var destroyed:=0
	for id in ["small_1_6","small_4_6","small_7_6"]:
		var lot:Dictionary=g.lots[id]
		if lot.level==0: destroyed+=1;check(lot.owner==0 and lot.building_type=="vacant","demolition preserves land title")
	check(destroyed==1 and g.lots.small_10_6.level==0 and g.lots.small_13_6.level==3,"one complete building per selected owner, other owners intact")
	same_snapshot(g,"demolish")
	# Card loss is a batch, then the existing Ludwig team talent can respond once.
	g=fresh();g.talents_enabled=true;g.players[3].vehicle="car";g.players[3].cards=["free","immune","dice","mine","stay"]
	open(g,"car");g.choose_magic("lose_cards")
	check(g.players[3].cards.size()==4,"odd half rounds down, then out-of-turn Ludwig gains one")
	same_snapshot(g,"lost cards")
	g=fresh();g.players[0].vehicle="car";g.players[0].cards=["free"]
	open(g,"car");g.choose_magic("lose_cards")
	check(g.players[0].cards.size()==1,"one card uses explicit floor policy without accidental extra loss")
	# Consume actual road gods without duplicating one across multiple targets.
	g=fresh();g.players[0].vehicle="car";g.players[1].vehicle="car";g.road_gods={10:"angel"}
	open(g,"car");g.choose_magic("gain_god")
	check(g.players[0].god.id=="angel" and g.players[1].god.is_empty() and g.road_gods.is_empty(),"single ground god consumed only once")
	same_snapshot(g,"ground god")
	g=fresh();g.players[0].vehicle="car"
	open(g,"car");g.choose_magic("gain_god")
	check(g.players[0].god.is_empty() and g.phase=="land","no god does not fabricate a spawn or stall")
	# New effects respect actual state transition/continuation, not just labels.
	g=fresh();g.players[0].vehicle="car";g.players[0].cards.clear()
	open(g,"car");g.choose_magic("prison")
	check(g.phase=="end" and g.players[0].status.kind=="prison" and g.players[0].status.remaining==1,"self imprisonment ends action with one future detention")
	same_snapshot(g,"self prison")
	g.end_turn()
	for ignored in range(3):g.phase="end";g.end_turn()
	check(g.current==0 and g.phase=="detained","self prison not decremented in interrupted action")
	g.end_turn()
	for ignored in range(3):g.phase="end";g.end_turn()
	check(g.current==0 and g.players[0].status.is_empty(),"one detention releases on following visit")
	g=fresh();g.players[1].vehicle="car";g.players[1].cards=["immune"]
	open(g,"car");g.choose_magic("prison")
	check(g.phase=="reaction" and g.reaction_player()==1,"magic prison uses explicit provisional defense integration")
	same_snapshot(g,"magic defense")
	g.resolve_reaction("immune")
	check(g.phase=="land" and g.players[1].status.is_empty(),"defense resumes consumed magic visit")
	g=fresh();g.players[0].vehicle="car"
	open(g,"car");g.choose_magic("teleport_vacant")
	check(Magic.vacant_destinations(g).has(g.players[0].pos) and g.players[0].previous==-1 and g.phase=="land" and g.pending_service.is_empty(),"vacant teleport settles once at eligible frontage")
	same_snapshot(g,"vacant teleport")
	g=fresh();g.players[0].vehicle="car";g.dice_count=3
	open(g,"car");g.choose_magic("destroy_vehicle")
	check(g.players[0].vehicle=="foot" and g.dice_count==1,"destroy vehicle resets current dice capability")
	same_snapshot(g,"destroy vehicle")
	g=fresh();g.players[0].vehicle="car"
	open(g,"car");g.choose_magic("stay")
	check(g.players[0].stay_turns==1,"stay marks next action")
	g.phase="roll";g.roll_dice()
	check(g.phase=="end" and g.last_roll==0 and g.players[0].stay_turns==0,"stay expires after one skipped move")
	# Every new effect supports save continuation; model + restored twin stay identical.
	for option in Magic.CATALOG:
		g=fresh();g.players[0].vehicle="car";g.players[1].vehicle="motorbike"
		g.road_gods={10:"fortune",11:"poor"};built(g,"small_1_6",0)
		open(g,"car");check(g.choose_magic(option.id),"effect executes: "+option.id)
		var restored:Dictionary=Save.restore(Save.snapshot(g))
		check(restored.ok,"effect saves: "+option.id)
		if not restored.ok:continue
		for ignored in range(80):
			if g.phase=="finished":break
			check(AI.step(g) and AI.step(restored.game),"effect continuation advances: "+option.id)
			check(Save.snapshot(g)==Save.snapshot(restored.game),"effect replay RNG exact: "+option.id)
	print("MAGIC_HOUSE_TEST failures=",failures)
	quit(1 if failures else 0)
