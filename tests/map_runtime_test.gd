extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Maps=preload("res://scripts/model/map_catalog.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;printerr(label)
func fixture()->Dictionary:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/integration_city.json"))
	data.start_road=-1;data.start_bonus=0;data.roads[0].kind="road"
	data.spawn_roads=[5,9]
	data.roads[2].kind="cash";data.roads[2].cash_amount=2000
	data.roads[3].kind="cash";data.roads[3].cash_amount=-5000
	data.roads[4].kind="unresolved";data.roads[4].trace_ref={"logical":[11,10],"source":"test"}
	data.roads[5].kind="news";data.roads[6].kind="minigame"
	return data
func fresh():
	var g=Game.new();g.setup(["A","B","C","D"],184,8)
	g._build_map(Maps.prepare(fixture()))
	for p in g.players: p.cards=[]
	return g
func land(g,id:int)->void:
	g.phase="move";g.steps_left=0;g.players[g.current].pos=id
	g._land()
func _init()->void:
	var prepared:Dictionary=Maps.prepare(fixture())
	check(prepared.ok and prepared.metadata.start_road==-1 and prepared.metadata.spawn_roads==[5,9],"no START with explicit spawns validates")
	var legacy:Dictionary=Maps.load_map("integration_city")
	check(not legacy.metadata.has("spawn_roads"),"legacy metadata shape unchanged")
	var invalid:Dictionary=fixture()
	invalid.start_bonus=1;check(not Maps.validate(invalid).is_empty(),"no-start reward rejected")
	invalid=fixture();invalid.roads[0].kind="start";check(not Maps.validate(invalid).is_empty(),"hidden start tile rejected")
	for bad in [[],[1024],[-1],[true],[1.2],"0"]:
		invalid=fixture();invalid.spawn_roads=bad;check(not Maps.validate(invalid).is_empty(),"invalid spawn rejected: "+str(bad))
	for bad in [true,1.2,"2000",null]:
		invalid=fixture();invalid.roads[2].cash_amount=bad;check(not Maps.validate(invalid).is_empty(),"invalid amount rejected: "+str(bad))
	invalid=fixture();invalid.roads[2].erase("cash_amount");check(not Maps.validate(invalid).is_empty(),"cash without amount rejected")
	invalid=fixture();invalid.roads[4].cash_amount=1000;check(not Maps.validate(invalid).is_empty(),"cash metadata on other kind rejected")
	var g=fresh()
	check(g.nodes[4].trace_ref=={"logical":[11,10],"source":"test"},"static road evidence carried into runtime")
	g.players[0].pos=1;g.phase="move";g.steps_left=2;g.move_to(2)
	check(g.players[0].cash==10000 and g.phase=="move","passing cash tile does not pay")
	land(g,2);check(g.players[0].cash==12000,"positive cash landing pays printed amount")
	g._continue_land();g._continue_land();check(g.players[0].cash==12000,"positive payout cannot repeat on continuation")
	g=fresh();g.players[0].cash=1000;g.players[0].deposit=6000
	land(g,3);check(g.players[0].cash==0 and g.players[0].deposit==2000,"negative tile uses existing cash then deposit debt policy")
	g._continue_land();check(g.players[0].deposit==2000,"negative payout cannot repeat on continuation")
	g=fresh();g.players[0].cards=["free"]
	land(g,3);check(g.phase=="reaction" and not g.landing_pending and g.pending_attack.source=="cash_tile","cash debt offers existing test-profile defense after clearing landing continuation")
	check(g.resolve_reaction("free") and g.phase=="land" and g.players[0].cash==10000,"defense resolves once and returns to landing")
	g._continue_land();check(g.players[0].cash==10000 and g.pending_attack.is_empty(),"defense continuation does not recreate cash debt")
	g=fresh();g.players[0].cash=1
	land(g,3);check(g.players[0].bankrupt and g.phase=="end" and g.pending_attack.is_empty(),"cash debt bankruptcy clears reaction and permits next player")
	check(g.end_turn() and g.current==1,"cash bankruptcy game can continue")
	for kind_road in [4,5,6]:
		g=fresh();var before_rng:int=g.rng.state
		land(g,kind_road)
		check(g.players[0].cash==10000 and g.players[0].cards.is_empty() and g.rng.state==before_rng,"unresolved/news/minigame do not fabricate effects")
	g=fresh();g.players[0].pos=1;g.phase="move";g.steps_left=1
	g.move_to(0);check(g.players[0].cash==10000,"coordinate origin gives no fake start reward")
	var live:Dictionary=Maps.load_map("knight_manor")
	check(live.ok,"knight runtime layout validates")
	if live.ok:
		g=Game.new();check(g.setup(["A","B","C","D"],541,10,{"map_id":"knight_manor","specials_enabled":true}),"knight setup works")
		check(g.nodes.size()==102 and g.lots.size()==69 and g.start_road==-1 and g.start_bonus==0,"knight graph count and no-start state")
		for i in range(4): check(g.players[i].pos==int(g.map_metadata.spawn_roads[i%g.map_metadata.spawn_roads.size()]),"seat uses configured spawn")
		for kind in ["hospital","prison"]:
			var facility:Dictionary=g.facility_lot(kind)
			var before_cash:int=g.players[0].cash
			check(g.send_to_facility(0,kind,1),"knight admits player to "+kind)
			check(g.gm_release(0),"knight releases player from "+kind)
			check(g.players[0].pos==int(facility.exit_road) and g.players[0].previous==int(facility.exit_previous),"knight facility uses its configured release direction")
			check(g.players[0].cash==before_cash,"release repositions onto cash road without a fabricated landing")
		for seed_value in [11,73]:
			g=Game.new();g.setup(["A","B","C","D"],seed_value,15,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":true,"teams":[0,1,0,1]})
			var actions:int=0
			while g.phase!="finished" and actions<20000:
				actions+=1
				if not AI.step(g): check(false,"knight full match stalled: "+g.phase);break
			check(g.phase=="finished" and not g.winners.is_empty(),"knight full game reaches valid team result")
	print("MAP_RUNTIME_TEST failures=",failures)
	quit(0 if failures==0 else 1)
