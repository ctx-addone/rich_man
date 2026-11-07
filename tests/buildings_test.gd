extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,msg:String)->void:
	if not ok: failures+=1; push_error(msg)
func fresh():
	var game=Game.new()
	game.setup(["甲","乙","丙","丁"],33,50)
	return game
func own(g,id:String,kind:String,owner:int=0,level:int=1)->Dictionary:
	var lot:Dictionary=g.lots[id]
	lot.owner=owner
	lot.level=level
	lot.building_type=kind
	return lot
func _initialize()->void:
	var g=fresh()
	var lot=own(g,"small_1_6","house")
	check(g.rent_preview(lot.id)==220,"Base house rent")
	own(g,"small_4_6","house")
	check(g.rent_preview(lot.id)==275,"Same street bonus")
	lot.building_type="chain"
	g.lots.small_4_6.building_type="chain"
	check(g.rent_preview(lot.id)==270,"Chain count bonus")
	own(g,"lot_1_1","estate",1,2)
	check(g.rent_preview(lot.id,1)==216,"Estate discounts payer rent")
	lot.closed_until=3
	check(g.rent_preview(lot.id)==0,"Closed building produces no rent")
	g=fresh()
	lot=own(g,"lot_1_1","hotel",0)
	g.current=1
	g.gm_teleport(1,int(lot.frontage_nodes[0]))
	check(g.players[1].status.kind=="vacation" and g.players[1].status.lot_id==lot.id,"Hotel creates separate vacation status")
	check(g.players[1].cash==9840,"Hotel rent charged")
	check(g.gm_release(1) and g.players[1].status.is_empty(),"Vacation released")
	g=fresh()
	lot=own(g,"lot_1_1","energy",0,2)
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	check(g.players[0].cash==10600,"Energy owner landing payout")
	g.current=1
	check(g.shop_offers()[0].price==390,"Energy raises opponents card purchase costs")
	g=fresh()
	g.gm_teleport(0,int(g.facility_lot("shop").frontage_nodes[0]))
	check(g.phase=="shop" and g.shop_remaining()==3,"Shop landing opens limited trade")
	while g.players[0].cards.size()<8: g.give_card(0,"dice")
	var cash:int=g.players[0].cash
	check(not g.buy_card("dice") and g.players[0].cash==cash and g.shop_remaining()==3,"Full hand rejects purchase without payment or quota cost")
	check(g.discard_card(0) and g.buy_card("dice") and g.players[0].cards.size()==8,"Discard creates purchase room")
	g.players[0].cards.clear()
	check(g.shop_remaining()==2 and g.buy_card("dice") and g.buy_card("dice"),"Successful purchases consume visit allowance")
	cash=g.players[0].cash
	var count:int=g.players[0].cards.size()
	check(g.shop_remaining()==0 and not g.buy_card("dice") and g.players[0].cash==cash and g.players[0].cards.size()==count,"Exhausted allowance causes no payment or delivery")
	g._land()
	check(g.shop_remaining()==0,"Replaying same shop landing cannot refresh quota")
	own(g,"lot_1_1","bookstore",0,5)
	check(g.close_shop() and g.players[0].cards.size()>=1,"Bookstore grants cards on leaving shop")
	var hand:int=g.players[0].cards.size()
	check(not g.close_shop() and hand==g.players[0].cards.size(),"Leaving shop cannot replay reward")
	check(not g.buy_card("dice") and g.shop_remaining()==0,"Closed visit rejects buying and reports no allowance")
	g.gm_teleport(0,0)
	g.gm_teleport(0,int(g.facility_lot("shop").frontage_nodes[0]))
	check(g.shop_remaining()==3,"New arrival resets shop allowance")
	g=fresh()
	lot=own(g,"lot_1_1","lab",0,1)
	check(g.start_research(lot.id,"portal"),"Lab can research real first-tier card")
	check(not g.start_research(lot.id,"portal"),"Cannot replace active research")
	g.round_number=2; g._tick_economy()
	check(lot.research.remaining==1,"Research advances")
	g.round_number=3; g._tick_economy()
	check(lot.research.is_empty() and g.players[0].cards.has("portal"),"Research completes and delivers")

	g.phase="roll"
	check(g.start_research(lot.id,"portal"),"New research starts after prior completion")
	while g.players[0].cards.size()<8: g.give_card(0,"dice")
	g.round_number=4;g._tick_economy()
	g.round_number=5;g._tick_economy()
	check(lot.research.remaining==0 and not g.collect_research(lot.id),"Full hand preserves completed research")
	g.discard_card(0)
	check(g.collect_research(lot.id) and lot.research.is_empty(),"Discard and collect research immediately")
	for offer in g.shop_offers(): check(offer.id not in ["portal","glory","misery","disaster"],"Special acquisition cards not sold in basic shop")
	g.players[0].deposit=1000
	g.round_number=21;g._tick_economy()
	check(g.players[0].deposit==1020,"Provisional monthly interest")
	g=fresh()
	g.gm_teleport(0,1)
	check(not g.buy_property("lot_1_1","house"),"Large lot rejects house type")
	check(g.buy_property("lot_1_1","park") and g.rent_preview("lot_1_1")==0,"Park produces no rent")
	g.gm_teleport(0,2)
	check(g.rebuild_property("lot_1_1","lab"),"Owner can rebuild large lot")
	g.gm_teleport(0,2)
	check(g.upgrade_property("lot_1_1"),"Upgrade independent building")
	g=fresh()
	g.players[0].pos=6
	g.players[0].previous=5
	g.road_objects[7]={"kind":"roadblock","owner":1}
	g.roll_dice(3)
	check(g.move_to(7) and g.phase=="bank" and g.steps_left==0,"Roadblock at bank still opens arrival service")
	check(not g.road_objects.has(7) and g.close_bank() and g.phase=="land","Bank closes to final roadblock landing")
	check(not g.close_bank(),"Bank cannot reopen from repeated close")
	g=fresh()
	lot=own(g,"lot_1_1","lab",0,1)
	check(g.start_research(lot.id,"portal"),"Start research before demolition")
	g.current=1
	g.give_card(1,"bulldozer")
	check(g.use_card("bulldozer",lot.id) and lot.level==0,"Bulldozer removes last lab level")
	g.current=0
	g.round_number=2;g._tick_economy()
	g.round_number=3;g._tick_economy()
	check(lot.research.remaining==2 and not g.players[0].cards.has("portal"),"Destroyed lab pauses both research progress and delivery")
	lot.research.remaining=0
	check(not g.collect_research(lot.id),"Destroyed lab cannot manually collect completed work")
	lot.research.remaining=2
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	check(g.upgrade_property(lot.id),"Restore demolished lab by upgrade")
	g.round_number=4;g._tick_economy()
	check(lot.research.remaining==1,"Restored lab resumes prior progress")
	g.round_number=5;g._tick_economy()
	check(lot.research.is_empty() and g.players[0].cards.has("portal"),"Restored lab completes preserved research")
	g=fresh()
	while g.players[0].cards.size()<8: g.give_card(0,"dice")
	g.nodes[0].kind="event"
	for seed_value in range(1,100):
		var probe:=RandomNumberGenerator.new()
		probe.seed=seed_value
		if probe.randi_range(0,1)==1:
			g.rng.seed=seed_value
			break
	g.logs.clear()
	g.gm_teleport(0,0)
	var log_text:String="\n".join(g.logs)
	check(log_text.contains("手牌已满") and not log_text.contains("机会获得"),"Rejected event card logs refusal without false success")
	print("BUILDINGS_TEST failures=",failures)
	quit(1 if failures else 0)
