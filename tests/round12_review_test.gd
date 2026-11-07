extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Magic=preload("res://scripts/model/magic_house.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;push_error(label)
func fresh(seed_value:int=1214,teams:Array=[0,0,1,1]):
	var g=Game.new()
	g.setup(["A","B","C","D"],seed_value,30,{"specials_enabled":true,"talents_enabled":true,"teams":teams,"characters":["wumi","ludwig","nintaro","miyamoto"]})
	return g
func open(g,condition:String)->void:
	check(g.gm_teleport(g.current,51) and g.phase=="magic","actual magic visit opens")
	for value in range(1,1000):
		var probe=RandomNumberGenerator.new();probe.seed=value
		if Magic.CONDITIONS[probe.randi_range(0,7)]==condition:
			g.rng.seed=value;return
	check(false,"test condition seed exists")
func _init()->void:
	# Simultaneous losses must finish before Ludwig's team reward is issued.
	var g=fresh()
	for p in g.players: p.cards=["free","immune","dice","stay"];p.vehicle="car"
	open(g,"car");check(g.choose_magic("lose_cards"),"batch card loss executes")
	check(g.players[0].cards.size()==3 and g.players[1].cards.size()==3 and g.players[2].cards.size()==2 and g.players[3].cards.size()==2,"Ludwig rewards allies only after their losses")
	# Attachment must retain existing character hooks and entry effects.
	g=fresh();g.players[2].vehicle="car";g.players[2].cards.clear();g.road_gods={10:"fortune"}
	open(g,"car");g.choose_magic("gain_god")
	check(g.players[2].god.id=="fortune" and g.players[2].cards.size()==3 and g.players[2].cards.has("robot"),"fortune entry grants two cards then Nintaro robot")
	g=fresh();g.players[3].vehicle="car";g.players[3].cards.clear();g.road_gods={10:"martial"}
	open(g,"car");g.choose_magic("gain_god")
	check(g.players[3].god.remaining==g.Gods.PROFILE.duration+1 and g.players[3].cards==["send_god"],"Miyamoto duration and attachment card apply")
	g=fresh();g.players[1].vehicle="car";g.players[1].cards=["free","immune","dice","stay"];g.players[0].cards.clear();g.road_gods={10:"misfortune"}
	open(g,"car");g.choose_magic("gain_god")
	check(g.players[1].cards.size()==3 and g.players[0].cards.size()==1,"misfortune acquired through magic still triggers Ludwig card loss talent")
	# Transfer back to the visitor interrupts that action, without reopening service.
	g=fresh();g.players[1].vehicle="car";g.players[1].cards=["transfer"];g.players[0].cards.clear()
	open(g,"car");g.choose_magic("prison")
	check(g.phase=="reaction" and g.reaction_player()==1,"enemy detention waits for transfer")
	check(g.resolve_reaction("transfer",0) and g.phase=="end" and g.players[0].status.kind=="prison" and g.players[1].status.is_empty(),"transferred detention ends visitor action")
	check(g.pending_service.is_empty() and g.pending_attack.is_empty(),"transferred magic clears both pending workflows")
	var restored:Dictionary=Save.restore(Save.snapshot(g))
	check(restored.ok,"transferred prison state is saveable")
	check(g.gm_release(0) and g.players[0].cards==["teleport"],"release after magic triggers Wumi talent")
	# Unknown empty-ground definition is an explicit policy, but phases must agree.
	g=fresh();g.players[0].vehicle="car"
	for lot in g.lots.values():
		if lot.kind!="facility":lot.owner=1;lot.level=1;lot.building_type="house" if lot.kind=="small" else "mall"
	g.lots.small_1_6.owner=-1;g.lots.small_1_6.level=0;g.lots.small_1_6.building_type="vacant"
	open(g,"car");g.choose_magic("teleport_vacant")
	check(g.phase=="land" and g.lots_at_node(g.players[0].pos).has("small_1_6"),"teleport lands at sole allowed vacant frontage")
	check(g.buy_property("small_1_6"),"land phase intentionally permits active purchase after teleport")
	# AI evaluates public state without advancing hidden randomness.
	g=fresh();open(g,"female")
	var before:Dictionary=Save.snapshot(g)
	check(Magic.CATALOG.map(func(x):return x.id).has(Magic.ai_effect(g)),"AI chooses an existing effect")
	check(Save.snapshot(g)==before,"AI evaluation preserves complete public and RNG state")
	# Exercise full new-feature matches in both alliances and FFA.
	for teams in [[0,0,1,1],[0,1,2,3]]:
		for seed_value in [1218,1223]:
			g=fresh(seed_value,teams)
			var steps:int=0
			while g.phase!="finished" and steps<12000:
				if not AI.step(g):check(false,"AI stalls in "+g.phase);break
				steps+=1
			check(g.phase=="finished","new-feature natural AI match finishes seed "+str(seed_value))
	print("ROUND12_REVIEW_TEST failures=",failures)
	quit(1 if failures else 0)
