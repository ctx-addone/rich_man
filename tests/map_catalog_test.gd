extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Maps=preload("res://scripts/model/map_catalog.gd")
const BASELINE = ["f42c6a33b496eea85d47a1f463712d20856c0aa168e6bb124234b88d2067cd6b","b26387ad2736ab28ebd7dd723aca7e7e00c759b080c505ffaeb0bdf7d247445e"]
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;printerr(label)
func data()->Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/integration_city.json"))
func find_lot(layout:Dictionary,id:String)->Dictionary:
	for lot in layout.lots:
		if lot.id==id: return lot
	return {}
func enter_road(g,road:int)->void:
	g.players[g.current].pos=road;g.players[g.current].previous=-1;g.steps_left=0;g.phase="move"
	g.bank_visited.clear();g.service_visited.clear();g.pending_service.clear()
	g._continue_arrival()
func _init()->void:
	check(Maps.entries().size()==1 and Maps.entries(true).size()==2,"only complete prototype selectable; evidence remains listed separately")
	check(not Maps.load_map("knight_manor").ok and not Maps.load_map("../integration_city").ok,"unplayable evidence and unregistered path rejected")
	check(Maps.load_map("integration_city").ok,"registered layout validates")
	var no_facilities:Dictionary=data()
	for lot in no_facilities.lots:
		if lot.building_type in ["hospital","prison"]: lot.kind="large";lot.building_type="vacant"
	var generic:Dictionary=Maps.prepare(no_facilities)
	check(generic.ok,"generic import inspection accepts graphs without gameplay facilities")
	check(Maps._required_facility_errors(generic.layout).size()==2,"playable traditional loader requires both hospital and prison")
	for enabled in [false,true]:
		var g=Game.new()
		check(g.setup(["A","B"],91,20,{"specials_enabled":enabled}),"setup reports success")
		var snapshot={"nodes":g.nodes,"lots":g.lots,"roads":g.board_model.roads,"frontage":g.board_model.frontage}
		check(var_to_bytes(snapshot).hex_encode().sha256_text()==BASELINE[1 if enabled else 0],"all old nodes/lots/frontage exactly match pre-refactor binary snapshot")
		check(g.map_id==Maps.DEFAULT_MAP_ID and g.start_road==0 and g.start_bonus==1000 and g.players[0].pos==g.start_road,"default map state and spawn preserved")
		g.players[0].cash=7777;g.lots.small_1_6.owner=1
		var before:Dictionary={"players":g.players.duplicate(true),"lots":g.lots.duplicate(true),"nodes":g.nodes.duplicate(true),"rng":g.rng.state,"map":g.map_metadata.duplicate(true),"phase":g.phase}
		for invalid in ["not_registered","knight_manor",7]:
			check(not g.setup(["X","Y"],321,1,{"map_id":invalid}),"invalid map refuses setup")
			check(g.players==before.players and g.lots==before.lots and g.nodes==before.nodes and g.rng.state==before.rng and g.map_metadata==before.map and g.phase==before.phase,"rejected setup preserves current match atomically")
	var broken:Dictionary=data()
	broken.playable=false;check(not Maps.validate(broken).is_empty(),"evidence flagged nonplayable rejected")
	broken=data();broken.roads[0].id="11";check(not Maps.validate(broken).is_empty(),"noncontiguous ids rejected")
	broken=data();broken.roads[1].exits=[];check(not Maps.validate(broken).is_empty(),"dead-end without exits rejected")
	broken=data();broken.roads[0].exits=["0"];check(not Maps.validate(broken).is_empty(),"self-loop rejected")
	broken=data();broken.roads[0].exits=["999"];check(not Maps.validate(broken).is_empty(),"missing exit target rejected")
	broken=data();broken.roads[1].cell=broken.roads[0].cell;check(not Maps.validate(broken).is_empty(),"overlapping road cells rejected")
	broken=data();broken.roads[1].cell=[2.5,0];check(not Maps.validate(broken).is_empty(),"fractional cell rejected")
	broken=data();broken.size=[1,1];check(not Maps.validate(broken).is_empty(),"roads and lots outside declared bounds rejected")
	broken=data();broken.start_road=500;check(not Maps.validate(broken).is_empty(),"missing start rejected")
	broken=data();broken.start_bonus=true;check(not Maps.validate(broken).is_empty(),"boolean reward rejected")
	broken=data();broken.lots[0].price=-1;check(not Maps.validate(broken).is_empty(),"negative price rejected")
	broken=data();broken.lots[0].rent=1.5;check(not Maps.validate(broken).is_empty(),"fractional rent rejected")
	broken=data();broken.lots[0].footprint=[0,0,4,4];check(not Maps.validate(broken).is_empty(),"road-building overlap rejected")
	broken=data();broken.lots[0].frontage_nodes=["0"];check(not Maps.validate(broken).is_empty(),"diagonal frontage rejected")
	broken=data();broken.roads[17].special_override={"kind":"invented","name":"X"};check(not Maps.validate(broken).is_empty(),"unimplemented service rejected")
	broken=data();find_lot(broken,"lot_13_1").exit_previous=10;check(not Maps.validate(broken).is_empty(),"direction without exit rejected")
	broken=data();find_lot(broken,"lot_13_1").exit_road=999;check(not Maps.validate(broken).is_empty(),"exit outside graph rejected")
	broken=data();find_lot(broken,"lot_13_1").exit_road=10;find_lot(broken,"lot_13_1").exit_previous=40;check(not Maps.validate(broken).is_empty(),"nonadjacent exit direction rejected")
	broken=data();find_lot(broken,"lot_13_1").exit_road=10;find_lot(broken,"lot_13_1").exit_previous=9;broken.roads[10].exits="wrong";check(not Maps.validate(broken).is_empty(),"nested malformed exit returns errors without crash")
	broken=data()
	for road in broken.roads:
		if road.id in ["0","1"]: road.exits=["1" if road.id=="0" else "0"]
		else:
			road.exits.erase("0");road.exits.erase("1")
	check(not Maps.validate(broken).is_empty(),"disconnected playable graph rejected")
	# Contract variation only; never registered or presented as an original map.
	var variant:Dictionary=data()
	variant.id="contract_fixture";variant.name="Contract fixture";variant.size=[30,20]
	variant.start_road=25;variant.start_bonus=4321
	variant.roads[0].kind="road";variant.roads[25].kind="start"
	variant.roads[34].special_override={"kind":"lottery","name":"第二乐透站"}
	var bank:Dictionary=find_lot(variant,"lot_1_1")
	bank.kind="facility";bank.building_type="bank";bank.name="第二银行";bank.trigger_events=["pass","stop"]
	var shop:Dictionary=find_lot(variant,"lot_1_9")
	shop.kind="facility";shop.building_type="shop";shop.name="第二商店"
	find_lot(variant,"lot_13_1").exit_road=10;find_lot(variant,"lot_13_1").exit_previous=9
	find_lot(variant,"lot_19_9").exit_road=40;find_lot(variant,"lot_19_9").exit_previous=39
	var prepared:Dictionary=Maps.prepare(variant)
	check(prepared.ok,"variable bounds/start/multiple facilities and explicit exits validate")
	if prepared.ok:
		var g=Game.new();g.setup(["A","B"],17,30,{"specials_enabled":true})
		g._build_map(prepared)
		check(g.map_id=="contract_fixture" and g.start_road==25 and g.map_metadata.size==[30,20],"runtime adapter uses supplied metadata")
		g.players[0].pos=24;g.phase="roll";g.roll_dice(1);g.move_to(25)
		check(g.players[0].cash==14321,"configured nonzero start grants configured reward")
		for road in [17,34]:
			enter_road(g,road)
			check(g.phase=="lottery" and g.pending_service.road==road,"each lottery location enters independently")
			g.close_lottery()
		for lot_id in ["lot_1_1","lot_7_1"]:
			enter_road(g,int(g.lots[lot_id].frontage_nodes[0]))
			check(g.phase=="bank" and g.bank_visited.has(lot_id),"each bank accepts visitors")
			g.close_bank()
		for lot_id in ["lot_1_9","small_22_6"]:
			enter_road(g,int(g.lots[lot_id].frontage_nodes[0]))
			check(g.phase=="shop","each shop accepts visitors")
			g.close_shop()
		g.players[0].pos=50;g.players[0].previous=49
		g.send_to_facility(0,"hospital",1);g.gm_release(0)
		check(g.players[0].pos==10 and g.players[0].previous==9,"hospital releases at explicit configured road and direction")
		g.send_to_facility(0,"prison",1);g.gm_release(0)
		check(g.players[0].pos==40 and g.players[0].previous==39,"prison has independent release exit")
	var legacy=Game.new();legacy.setup(["A","B"],17)
	legacy.players[0].pos=50;legacy.players[0].previous=49
	legacy.send_to_facility(0,"hospital",1);legacy.gm_release(0)
	check(legacy.players[0].pos==50 and legacy.players[0].previous==49,"default layout preserves legacy return location")
	print("MAP_CATALOG_TEST failures=",failures)
	quit(0 if failures==0 else 1)
