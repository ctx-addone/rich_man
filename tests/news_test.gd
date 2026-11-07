extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const News=preload("res://scripts/model/news_rules.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
var rejected:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;printerr(label)
func fresh(seed_value:int=17):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],seed_value,12,{"map_id":"knight_manor","specials_enabled":true,"talents_enabled":true,"characters":["atu","wumi","nintaro","sarah"]}),"news test map loaded")
	for p in g.players: p.cards=[]
	return g
func news_road(g)->int:
	for node in g.nodes:
		if node.kind=="news": return node.id
	return -1
func prepare_enter(g)->void:
	g.players[g.current].pos=news_road(g);g.phase="land";g.steps_left=0
	g.landing_pending=false;g.landing_queue.clear();g.landing_hotel=""
	g.pending_service.clear();g.pending_attack.clear();g.service_visited.clear()
func enter_event(g,event_id:String)->void:
	prepare_enter(g)
	check(News.enter(g),"news enters")
	g.pending_service.event_id=event_id
func state(g)->Dictionary:
	var result:Dictionary={}
	for key in ["phase","specials_enabled","pending_service","players","current","steps_left","landing_pending","landing_queue","landing_hotel","pending_attack","service_visited"]: result[key]=g.get(key)
	return result.duplicate(true)
func reject(candidate:Dictionary,g,label:String)->void:
	check(not News.state_error(candidate,g).is_empty(),label);rejected+=1
func _init()->void:
	var g=fresh()
	g.send_to_facility(1,"prison",4);g.send_to_facility(2,"prison",2);g.send_to_facility(3,"hospital",3)
	var exit1:int=g.players[1].status.return_pos
	var previous1:int=g.players[1].status.return_previous
	enter_event(g,"release_prisoners")
	check(g.players[1].status.kind=="prison" and g.players[2].status.kind=="prison","drawing and displaying news does not settle early")
	check(News.current(g).targets==[1,2],"news preview identifies all prisoners")
	check(News.state_error(state(g),g).is_empty(),"legitimate news state validates")
	var rng_before:int=g.rng.state
	var preview:Dictionary=News.current(g);preview.name="changed";preview.targets.clear()
	check(News.current(g).name!="changed" and News.current(g).targets==[1,2] and g.rng.state==rng_before,"display returns copies without redraw/RNG use")
	check(not News.enter(g) and not g.end_turn(),"pending news blocks reentry and turn skip")
	check(News.resolve(g),"release news confirms")
	check(g.players[1].status.is_empty() and g.players[2].status.is_empty() and g.players[3].status.kind=="hospital","only prison status cleared")
	check(g.players[1].pos==exit1 and g.players[1].previous==previous1,"release uses existing configured return geometry")
	check(g.players[1].cards==["teleport"],"release calls existing Wumi prison-release hook exactly once")
	check(g.phase=="land" and g.pending_service.is_empty() and not News.resolve(g) and not News.enter(g),"news settled once and visited road cannot reopen")
	check(g.players[1].cards==["teleport"] and g.rng.state==rng_before,"repeated confirmation cannot grant cards or redraw")
	check(g.end_turn() and g.current==1 and g.phase=="roll","released player's next action proceeds normally")
	for other_kind in ["hibernate","sleepwalk","vacation","hospital"]:
		g=fresh();g.players[1].status={"kind":other_kind,"remaining":3,"return_pos":g.players[1].pos,"return_previous":-1}
		var original:Dictionary=g.players[1].status.duplicate(true)
		enter_event(g,"release_prisoners");check(News.resolve(g) and g.players[1].status==original,"prison release does not clear "+other_kind)
	g=fresh();g.send_to_facility(1,"prison",3);g.players[1].bankrupt=true
	enter_event(g,"release_prisoners");check(News.current(g).targets.is_empty(),"bankrupt prisoner excluded")
	News.resolve(g);check(g.players[1].status.kind=="prison","bankrupt prisoner not resurrected")
	g=fresh();enter_event(g,"house_subsidy")
	var balances:Array=[]
	for p in g.players: balances.append(p.cash)
	check(News.current(g).targets==[0] and News.resolve(g),"subsidy resolves for actor")
	check(g.players[0].cash==balances[0]+News.TEST_PROFILE.house_subsidy_amount and g.players[1].cash==balances[1],"subsidy changes only actor cash by explicit test amount")
	check(not News.resolve(g) and g.players[0].cash==balances[0]+News.TEST_PROFILE.house_subsidy_amount,"subsidy cannot be claimed twice")
	g=fresh();prepare_enter(g);g.steps_left=1
	check(not News.enter(g),"passing news does not enter")
	g.steps_left=0;g.specials_enabled=false;check(not News.enter(g),"disabled services block news")
	g.specials_enabled=true;g.landing_pending=true;check(not News.enter(g),"unfinished landing blocks news")
	g.landing_pending=false;g.pending_attack={"test":true};check(not News.enter(g),"unfinished attack blocks news")
	g.pending_attack.clear();g.landing_queue=["test"];check(not News.enter(g),"unfinished lot queue blocks news")
	for status_kind in ["sleepwalk","prison","hospital"]:
		prepare_enter(g);g.players[0].status={"kind":status_kind};check(not News.enter(g),"test-profile eligibility excludes "+status_kind)
	g.players[0].status={};prepare_enter(g);g.players[0].god={"id":"fierce","remaining":2};check(not News.enter(g),"test-profile eligibility excludes fierce")
	g=fresh();enter_event(g,"house_subsidy");g.gm_teleport(0,0)
	check(g.phase=="land" and g.players[0].cash==10000 and not News.resolve(g),"explicit GM teleport interruption closes without settling")
	g=fresh();enter_event(g,"release_prisoners")
	var valid:Dictionary=state(g)
	for pair in [["phase","land"],["specials_enabled",false],["specials_enabled",1],["current",true],["current",99],["steps_left",1],["steps_left",0.0],["landing_pending",true],["landing_pending",0],["landing_queue",["lot"]],["landing_hotel","lot"],["pending_attack",{"x":1}],["service_visited",[]],["service_visited",[news_road(g),news_road(g)]],["service_visited",[true]]]:
		var bad:Dictionary=valid.duplicate(true);bad[pair[0]]=pair[1];reject(bad,g,"invalid news state: "+str(pair))
	for pair in [["kind","magic"],["road",true],["road",-1],["road",g.nodes.size()],["event_id","invented"],["event_id",1],["unexpected",0]]:
		var bad:Dictionary=valid.duplicate(true);bad.pending_service[pair[0]]=pair[1];reject(bad,g,"invalid pending news: "+str(pair))
	for pair in [["pos",-1],["bankrupt",true],["bankrupt",0],["status",{"kind":"sleepwalk"}],["god",{"id":"fierce"}]]:
		var bad:Dictionary=valid.duplicate(true);bad.players[0][pair[0]]=pair[1];reject(bad,g,"invalid news participant: "+str(pair))
	var first=fresh(73);var second=fresh(73)
	prepare_enter(first);prepare_enter(second);News.enter(first);News.enter(second)
	check(first.pending_service==second.pending_service and first.rng.state==second.rng.state,"seeded draw is deterministic")
	var completed:int=0
	for seed_value in [7,39]:
		g=fresh(seed_value)
		var actions:int=0
		while g.phase!="finished" and actions<20000:
			actions+=1
			var ok:bool=News.resolve(g) if g.phase=="news" else AI.step(g)
			if not ok: check(false,"news integration match stalled at "+g.phase);break
		if g.phase=="finished": completed+=1
	check(completed==2,"news-enabled knight matches finish")
	print("NEWS_TEST failures=",failures," rejected=",rejected," completed_matches=",completed)
	quit(0 if failures==0 else 1)
