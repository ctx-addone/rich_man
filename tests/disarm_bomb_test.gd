extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Bomb=preload("res://scripts/model/disarm_bomb_rules.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:int=0
var rejected:int=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr(label)
func fresh(seed_value:int=1533):
	var g=Game.new();g.setup(["A","B","C","D"],seed_value,15,{"map_id":"knight_manor","specials_enabled":true})
	for node in g.nodes:
		if node.kind=="minigame":g.players[0].pos=node.id;break
	g.phase="land";g.steps_left=0
	check(Bomb.enter(g),"bomb game enters actual minigame node")
	return g
func advance_to_choice(g)->void:
	check(Bomb.start(g),"bomb game starts")
	while g.pending_service.game.stage!="choose":check(Bomb.tick(g),"preview/shuffle tick")
func index_for(g,kind:String)->int:
	var activity:Dictionary=g.pending_service.game
	for index in range(6):
		if not activity.opened.has(index) and activity.initial[activity.order[index]]==kind:return index
	return -1
func check_state(g,label:String)->void:
	check(Bomb.state_error(Save.snapshot(g).state,g).is_empty(),label+" validates")
func reject(payload:Dictionary,g,label:String)->void:
	check(not Bomb.state_error(payload.state,g).is_empty(),label);rejected+=1
func _init()->void:
	var g=fresh()
	check_state(g,"ready")
	check(not Bomb.choose(g,0) and not Bomb.close(g) and not Bomb.next_player(g),"ready blocks selection/payout/next seat")
	check(Bomb.start(g) and not Bomb.start(g),"start is one-shot")
	for ignored in range(Bomb.TEST_PROFILE.preview_ticks):
		check(g.pending_service.game.stage=="preview" and not Bomb.choose(g,0),"preview reveals but blocks choices")
		Bomb.tick(g);check_state(g,"preview progression")
	var permutations:Array=[]
	for ignored in range(Bomb.TEST_PROFILE.shuffle_swaps):
		check(Bomb.tick(g),"shuffle advances")
		var a:Dictionary=g.pending_service.game
		check(a.stage=="shuffle" and a.last_swap.size()==2 and a.swaps.size()==ignored+1 and not Bomb.choose(g,0),"visible exchange records pair and locks choice")
		permutations.append(a.order.duplicate());check_state(g,"shuffle progression")
	check(permutations[0]!=[0,1,2,3,4,5],"first visible exchange changes actual token positions")
	check(Bomb.tick(g) and g.pending_service.game.stage=="choose" and g.pending_service.game.last_swap.is_empty(),"selection starts after full shuffle animation")
	var good:int=index_for(g,"coin")
	var before_rng:int=g.rng.state
	check(Bomb.choose(g,good) and g.pending_service.game.score==2500,"opening a remembered coin yields filmed sample score")
	check(not Bomb.choose(g,good) and g.rng.state==before_rng,"opened switch cannot be replayed; click does not draw random contents")
	var bad:int=index_for(g,"bomb")
	check(Bomb.choose(g,bad) and g.pending_service.game.status=="participant_result" and g.pending_service.game.reason=="bomb" and g.pending_service.game.score==2500,"bomb ends immediately while retaining previously earned points")
	check(not Bomb.choose(g,index_for(g,"coin")) and not Bomb.tick(g),"no further operations after bomb")
	check_state(g,"bomb result")
	var first:Dictionary=g.pending_service.game.history[0].duplicate(true)
	check(Bomb.next_player(g) and g.current==0 and g.pending_service.game.player==1 and g.pending_service.game.status=="ready","background participant keeps board owner unchanged")
	check(g.pending_service.game.history[0]==first and g.pending_service.game.score==0 and g.pending_service.game.opened.is_empty(),"new participant retains history and resets personal board")
	check(Bomb.settle_others(g) and g.pending_service.game.status=="result" and g.pending_service.game.history.size()==4,"background simulation reaches all-seat result")
	check_state(g,"all-seat result")
	for p in g.players:check(p.cash==10000,"no early payout")
	var records:Array=g.pending_service.game.history.duplicate(true)
	check(Bomb.close(g) and g.phase=="land" and g.pending_service.is_empty(),"all-seat reward closes service")
	for record in records:check(g.players[record.player].cash==10000+record.reward,"each participant receives own result exactly once")
	check(not Bomb.close(g),"cannot claim again")
	g=fresh();advance_to_choice(g)
	var remembered:int=Bomb.ai_switch(g)
	var actual_order:Array=g.pending_service.game.order.duplicate()
	g.pending_service.game.order.reverse()
	check(Bomb.ai_switch(g)==remembered,"AI derives memory from preview+visible swaps, not hidden current order")
	g.pending_service.game.order=actual_order
	while Bomb.ai_switch(g)>=0:check(Bomb.choose(g,Bomb.ai_switch(g)),"memory AI opens a safe remaining token")
	check(g.pending_service.game.score==10000 and Bomb.ai_switch(g)==-1,"AI stops choosing after four coins")
	while g.pending_service.game.status=="playing":check(Bomb.ai_step(g),"all coins opened still advances timer")
	check(g.pending_service.game.reason=="time_up" and g.pending_service.game.score==10000,"no invented full-clear termination")
	# Snapshots at each new boundary must resume exact visible permutation and RNG.
	for stage in ["ready","preview","shuffle","choose","participant_result","other_playing","result"]:
		g=fresh(888)
		if stage!="ready":Bomb.start(g)
		if stage in ["shuffle","choose","participant_result","other_playing","result"]:
			for i in range(6):Bomb.tick(g)
		if stage in ["choose","participant_result","other_playing","result"]:
			while g.pending_service.game.stage!="choose":Bomb.tick(g)
		if stage in ["participant_result","other_playing","result"]:Bomb.choose(g,index_for(g,"bomb"))
		if stage=="other_playing":Bomb.next_player(g);Bomb.start(g);Bomb.tick(g)
		if stage=="result":Bomb.settle_others(g)
		var payload:Dictionary=Save.snapshot(g)
		var restored:Dictionary=Save.restore(payload)
		check(restored.ok,"dispatcher/save accepts disarm "+stage+": "+str(restored.get("error","")))
		if restored.ok:
			var twin=restored.game
			check(Save.snapshot(twin)==payload,"restored exact state "+stage)
			var budget:int=200
			while g.phase=="minigame" and budget>0:
				check(Bomb.ai_step(g) and Bomb.ai_step(twin),"both restored bomb games progress")
				check(Save.snapshot(g)==Save.snapshot(twin),"same actions produce same restored states and RNG")
				budget-=1
			check(g.phase=="land","restored bomb game closes "+stage)
	g=fresh();advance_to_choice(g)
	var valid:Dictionary=Save.snapshot(g)
	for field in valid.state.pending_service.game.keys():
		var candidate:Dictionary=valid.duplicate(true);candidate.state.pending_service.game.erase(field);reject(candidate,g,"missing field rejected: "+field)
	for pair in [["id","invented"],["version",true],["player",3],["tick",5.5],["score",123],["reward",2500],["status","result"],["reason","bomb"],["cursor",true],["initial",["coin"]],["order",[0,1,2,3,4,true]],["swaps",[[0,0]]],["last_swap",[0,1]],["opened",[1,1]],["history",[{}]],["stage","preview"],["extra",1]]:
		var candidate:Dictionary=valid.duplicate(true);candidate.state.pending_service.game[pair[0]]=pair[1];reject(candidate,g,"invalid activity field: "+str(pair))
	var candidate:Dictionary=valid.duplicate(true);candidate.state.pending_service.game.swaps[0]=[false,1];reject(candidate,g,"boolean swap index rejected")
	candidate=valid.duplicate(true);candidate.state.players[0].god={"id":"fierce","remaining":1};reject(candidate,g,"fierce trigger rejected")
	# Preserve a validly-shaped but impossible reveal history rejection.
	Bomb.choose(g,index_for(g,"bomb"));valid=Save.snapshot(g)
	candidate=valid.duplicate(true);candidate.state.pending_service.game.history[0].score+=2500;reject(candidate,g,"history score must match revealed contents")
	candidate=valid.duplicate(true);candidate.state.pending_service.game.history[0].player=2;reject(candidate,g,"history payee cannot change")
	candidate=valid.duplicate(true);candidate.state.pending_service.game.opened.append(index_for(g,"coin"));reject(candidate,g,"opening after a bomb rejected")
	print("DISARM_BOMB_TEST failures=",failures," rejected=",rejected)
	quit(0 if failures==0 else 1)
