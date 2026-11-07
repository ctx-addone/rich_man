extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,msg:String)->void:
	if not ok: failures+=1; push_error(msg)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C"],71,30)
	for p in g.players: p.cards=[]; p.pos=40
	g.players[0].pos=0
	return g
func armed(kind:String):
	var g=fresh()
	g.players[0].cards=["immune"]
	g.players[0].bomb={"remaining":1,"owner":1}
	g.road_objects[1]={"kind":kind,"owner":1}
	check(g.roll_dice(2) and g.move_to(1) and g.phase=="reaction","expiry pauses before "+kind)
	check(g.resolve_reaction("immune"),"expiry immune before "+kind)
	return g
func _initialize()->void:
	var g=armed("banana")
	check(not g.road_objects.has(1) and g.steps_left==2 and g.phase=="move","expiry continues banana once")
	check(g.move_to(2) and g.steps_left==1,"banana resumes actual travel")
	g=armed("jelly")
	check(not g.road_objects.has(1) and g.steps_left==2 and g.available_moves()==[0],"expiry continues jelly reverse")
	g=armed("roadblock")
	check(not g.road_objects.has(1) and g.steps_left==0 and g.phase=="land","expiry continues roadblock")
	g=armed("trap")
	check(not g.road_objects.has(1) and g.players[0].stay_turns==1 and g.phase=="land","expiry continues trap")
	g=armed("mine")
	check(not g.road_objects.has(1) and g.players[0].status.get("kind","")=="hospital" and g.players[0].status.remaining==2,"expiry immune then mine still triggers independently")
	g=armed("portal")
	check(not g.road_objects.has(1) and g.players[0].pos!=1 and g.steps_left==0,"expiry continues portal")
	g=fresh()
	g.players[0].pos=6; g.players[0].previous=5
	g.players[0].cards=["immune"]
	g.players[0].bomb={"remaining":1,"owner":1}
	g.road_objects[7]={"kind":"banana","owner":1}
	check(g.roll_dice(2) and g.move_to(7) and g.resolve_reaction("immune"),"bank expiry immune")
	check(g.phase=="bank" and g.steps_left==2 and not g.road_objects.has(7),"banana then pass bank preserves movement")
	check(g.close_bank() and g.phase=="move" and g.steps_left==2,"bank resumes without replay banana")
	g=fresh()
	g.players[0].pos=5; g.players[0].previous=4
	g.players[0].cards=["dice","reverse"]
	check(g.use_card("dice",[6,7],2) and g.use_card("reverse",0),"controlled route then reverse accepted")
	check(g.roll_dice() and g.last_roll==2 and g.available_moves()==[4],"reverse invalidates old path but preserves count")
	g=fresh()
	g.players[0].cards=["dice"]
	g.road_objects[1]={"kind":"jelly","owner":1}
	check(g.use_card("dice",[1,2,3],3) and g.roll_dice() and g.move_to(1),"controlled path hits jelly")
	check(g.controlled_path.is_empty() and g.available_moves()==[0],"jelly overrides controlled route")
	g=fresh()
	g.players[0].cards=["dice","immune"]
	g.road_objects[1]={"kind":"mine","owner":1}
	check(g.use_card("dice",[1,2,3],3) and g.roll_dice() and g.move_to(1) and g.resolve_reaction("immune"),"controlled path survives immune blast")
	check(g.controlled_path==[2,3] and g.available_moves()==[2] and g.steps_left==2,"immune keeps remaining confirmed path")
	g=fresh()
	var id:String=g.lots_at_node(1)[0]
	g.lots[id].owner=1; g.lots[id].level=1; g.lots[id].building_type="house"
	var rent:int=g.rent_preview(id,0)
	g.players[0].status={"kind":"sleepwalk","remaining":2,"return_pos":0,"return_previous":-1}
	g.players[0].previous=79
	g.phase="move"; g.steps_left=1
	check(g.move_to(1) and g.players[0].cash==10000-rent and g.players[1].cash==10000+rent,"sleepwalking visitor still pays rent")
	check(not g.buy_property(id) and not g.can_trade_stocks(),"sleepwalk cannot use economic actions")
	g=fresh()
	id=g.lots_at_node(1)[0]
	g.lots[id].owner=1; g.lots[id].level=1; g.lots[id].building_type="house"
	g.players[1].status={"kind":"sleepwalk","remaining":2,"return_pos":40,"return_previous":-1}
	check(g.rent_preview(id,0)==0,"sleepwalking landlord cannot collect rent")
	check(g.roll_dice(1) and g.move_to(1) and g.players[0].cash==10000 and g.players[1].cash==10000,"sleepwalking landlord actual landing is free")
	g=fresh()
	g.players[0].bomb={"remaining":10,"owner":1}
	g.road_objects[1]={"kind":"timebomb","owner":2}
	check(g.roll_dice(1) and g.move_to(1),"carrier reaches another ground timebomb")
	check(g.players[0].bomb.remaining==9 and g.road_objects.has(1) and g.players[0].status.is_empty() and g.pending_attack.is_empty() and g.phase=="land","second timebomb stays on ground without becoming mine")
	g=fresh()
	id=g.lots_at_node(1)[0]
	g.lots[id].owner=0; g.lots[id].building_type="vacant"; g.lots[id].level=0
	g.players[0].pos=1; g.phase="land"
	g.players[0].cards=["worker"]
	check(not g.upgrade_property(id) and not g.card_targets("worker").has(id),"flattened lot requires chosen building before upgrade or worker")
	g.lots[id].level=1
	check(g.rent_preview(id,1)==0,"vacant lot never falls back to house rent")
	g.lots[id].level=0
	check(g.rebuild_property(id,"mall"),"flattened lot can choose a valid replacement building")
	g.phase="land"
	check(g.upgrade_property(id) and g.rent_preview(id,1)>0,"rebuilt type becomes rentable only after upgrade")
	print("round5_review_test: ",failures," failures")
	quit(1 if failures else 0)
