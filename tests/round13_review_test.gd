extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Maps=preload("res://scripts/model/map_catalog.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func fresh(seed_value:int=1313,teams:Array=[0,1,2,3],world:bool=false):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],seed_value,35,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":world,"talents_enabled":world,"teams":teams,"characters":["wumi","ludwig","nintaro","tangtang"]}),"knight map setup")
	return g
func approach(g,road:int,steps:int=1)->void:
	g.players[g.current].pos=g.nodes[road].neighbors[0]
	g.players[g.current].previous=-1;g.phase="roll"
	check(g.roll_dice(steps) and g.available_moves().has(road) and g.move_to(road),"actual movement reaches road "+str(road))
func restore_twin(g,label:String):
	var snapshot:Dictionary=Save.snapshot(g)
	var result:Dictionary=Save.restore(snapshot)
	check(result.ok,label+" save restores: "+str(result.get("error","")))
	if not result.ok:return null
	check(Save.snapshot(result.game)==snapshot,label+" exact snapshot roundtrip")
	return result.game
func settle_reactions(g)->void:
	var count:int=0
	while g.phase=="reaction" and count<20:
		check(g.resolve_reaction(),"reaction accepts hit");count+=1
	check(count<20,"reaction chain terminates")
func _init()->void:
	var loaded:Dictionary=Maps.load_map("knight_manor")
	check(loaded.ok,"knight map is validated and playable")
	if not loaded.ok:print("ROUND13_REVIEW_TEST failures=",failures);quit(1);return
	test_structure()
	test_frontage()
	test_services()
	test_cash()
	test_matches()
	print("ROUND13_REVIEW_TEST failures=",failures)
	quit(1 if failures else 0)
func test_structure()->void:
	var g=fresh()
	check(g.nodes.size()==102,"102 nodes includes hospital/prison endpoints")
	var edge_count:int=0
	for n in g.nodes:
		for other in n.neighbors:
			check(g.nodes[other].neighbors.has(n.id),"undirected reciprocal edge")
			edge_count+=1
	check(edge_count==208,"104 undirected edges, not 104 nodes")
	var counts:Dictionary={"small":0,"large":0,"bank":0,"shop":0,"hospital":0,"prison":0}
	for lot in g.lots.values():counts[lot.building_type if lot.kind=="facility" else lot.kind]+=1
	check(counts=={"small":58,"large":4,"bank":3,"shop":2,"hospital":1,"prison":1},"62 properties and seven distinct facilities")
	check(g.lots.size()==69 and g.start_road==-1 and g.start_bonus==0,"map has no invented start salary")
	check(g.map_metadata.spawn_roads.size()==4,"four explicit provisional spawn positions")
	for i in range(4):check(g.players[i].pos==g.map_metadata.spawn_roads[i] and g.players[i].cash==10000,"spawn assigns legal position without arrival payout")
	restore_twin(g,"fresh knight match")
func test_frontage()->void:
	var g=fresh()
	g.current=1
	for p in g.players:p.cards.clear();p.cash=1000000
	for lot in g.lots.values():
		if lot.kind!="large":continue
		check(lot.frontage_nodes.size()==2,"large property has two explicit entry roads")
		lot.owner=0;lot.level=2;lot.building_type="mall"
		for road in lot.frontage_nodes:
			check(g.board_model.lots_for_event(str(road),"stop").count(lot.id)==1,"each frontage references one shared lot")
			var before:int=g.players[1].cash
			# Seed the test-only probe identically for each mall frontage.
			g.rng.seed=1314
			var probe=RandomNumberGenerator.new();probe.seed=1314
			var rent:int=g.rent_preview(lot.id,1)*probe.randi_range(1,3)
			check(rent>0,"large building has meaningful rent")
			approach(g,int(road));settle_reactions(g)
			check(g.players[1].cash==before-rent and g.lots[lot.id].owner==0,"both frontages charge same shared building once")
		restore_twin(g,"multiple frontage "+lot.id)
func test_services()->void:
	var g=fresh()
	for p in g.players:p.cards.clear()
	for lot in g.lots.values():
		if lot.kind!="facility":continue
		if lot.building_type=="bank":
			approach(g,int(lot.frontage_nodes[0]),2)
			check(g.phase=="bank" and g.steps_left==1,"each bank interrupts pass with one step left")
			var twin=restore_twin(g,"bank pause")
			check(g.bank_transfer(1000) and g.close_bank() and g.phase=="move" and g.steps_left==1,"bank resumes without repeating arrival")
			if twin!=null:
				twin.bank_transfer(1000);twin.close_bank();check(Save.snapshot(g)==Save.snapshot(twin),"bank restored command continuation exact")
		elif lot.building_type=="shop":
			approach(g,int(lot.frontage_nodes[0]),2)
			check(g.phase=="move","passing shop does not open stop-only service")
			approach(g,int(lot.frontage_nodes[0]))
			check(g.phase=="shop" and not g.shop_offers().is_empty(),"each shop opens actual randomized offers on stop")
			restore_twin(g,"shop pause");check(g.close_shop(),"shop exits normally")
		elif lot.building_type in ["hospital","prison"]:
			var injury:int=(int(lot.exit_road)+10)%g.nodes.size()
			g.phase="roll";g.players[0].pos=injury;g.players[0].previous=-1
			check(g.send_to_facility(0,lot.building_type,1),"detention starts")
			restore_twin(g,"facility detention")
			check(g.gm_release(0) and g.players[0].pos==lot.exit_road and g.players[0].previous==lot.exit_previous,"facility releases to independently configured fixed exit")
			check(g.players[0].pos!=injury,"release does not silently reuse injury position")
func test_cash()->void:
	var g=fresh()
	var positive:int=-1
	var negative:int=-1
	for n in g.nodes:
		if n.kind=="cash":
			if n.cash_amount>0:positive=n.id
			elif n.cash_amount<=-g.Money.TEST_PROFILE.reaction_threshold:negative=n.id
	check(positive>=0 and negative>=0,"map has readable positive and negative cash tiles")
	if positive<0 or negative<0:return
	for road in [positive,negative]:
		g=fresh();g.players[0].cards.clear()
		var before:int=g.players[0].cash
		approach(g,road,2)
		check(g.phase=="move" and g.players[0].cash==before,"cash tile has no pass payout under explicit stop policy")
		approach(g,road)
		settle_reactions(g)
		check(g.players[0].cash==before+g.nodes[road].cash_amount,"cash stop settles configured amount exactly once")
		g._continue_land();g.Combat.advance(g)
		check(g.players[0].cash==before+g.nodes[road].cash_amount,"landing continuation cannot replay cash")
	g=fresh();g.players[0].cards=["free"]
	approach(g,negative)
	check(g.phase=="reaction" and g.pending_attack.source=="cash_tile","negative cash opens provisional defense chain")
	var twin=restore_twin(g,"cash reaction")
	var tampered:Dictionary=Save.snapshot(g)
	tampered.state.nodes[negative].cash_amount-=1
	check(not Save.restore(tampered).ok,"save rejects tampered static cash amount")
	tampered=Save.snapshot(g)
	tampered.state.map_metadata.spawn_roads[0]=(int(tampered.state.map_metadata.spawn_roads[0])+1)%g.nodes.size()
	check(not Save.restore(tampered).ok,"save rejects tampered spawn metadata")
	check(g.resolve_reaction("free") and g.players[0].cash==10000 and not g.landing_pending,"free defense does not replay debit")
	if twin!=null:twin.resolve_reaction("free");check(Save.snapshot(g)==Save.snapshot(twin),"cash reaction resumes exactly after restore")
	for n in g.nodes:
		if n.kind not in ["news","minigame","unresolved"]:continue
		g=fresh();g.players[0].cards.clear()
		var before:int=g.rng.state
		approach(g,n.id)
		check(g.phase=="land" and g.players[0].cash==10000 and g.players[0].cards.is_empty() and g.rng.state==before,"unimplemented tile stays explicit no-op without fabricated reward")
func test_matches()->void:
	for teams in [[0,1,2,3],[0,0,1,1]]:
		for seed_value in [1301,1327]:
			var g=fresh(seed_value,teams,true)
			var twin=null
			var count:int=0
			while g.phase!="finished" and count<15000:
				if count==120:twin=restore_twin(g,"natural knight AI midpoint")
				if not AI.step(g):check(false,"AI stalled at "+g.phase);break
				if twin!=null:
					check(AI.step(twin),"restored AI advances")
					check(Save.snapshot(g)==Save.snapshot(twin),"natural knight saved trajectory remains exact")
				count+=1
			check(g.phase=="finished" and not g.winners.is_empty(),"knight natural AI completes FFA/team seed "+str(seed_value))
