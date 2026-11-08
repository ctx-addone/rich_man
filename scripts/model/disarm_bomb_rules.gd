class_name RichDisarmBombRules
extends RefCounted

const GAME_ID = "disarm_bomb"
const TITLE = "拆炸弹"
const INSTRUCTIONS = "先记住金币与炸弹的位置，再观察开关换位。点击尚未打开的开关获得金币；揭开炸弹立即结束，已得分保留。"
const PARAMETERS = "六开关、四金币两炸弹来自实机样本。本版暂定16秒、六次换位，单币2500分为样本值；全币开完可等待计时结束。奖励按各自得分结算，非原版完整公式。"
const TEST_PROFILE = {"tick_seconds":0.5,"ticks":32,"preview_ticks":4,"shuffle_swaps":6,"coin_value":2500}
const INITIAL = ["coin","coin","coin","coin","bomb","bomb"]

static func _participants(players:Array,trigger:int)->Array:
	var result:Array=[]
	for offset in range(players.size()):
		var who:int=(trigger+offset)%players.size()
		if not players[who].bankrupt:result.append(who)
	return result

static func _reset(game:Dictionary)->void:
	game.tick=0;game.score=0;game.reward=0;game.reason="";game.status="ready"
	game.stage="preview";game.initial=INITIAL.duplicate();game.order=[0,1,2,3,4,5]
	game.swaps=[];game.last_swap=[];game.opened=[]

static func enter(g)->bool:
	if not g.specials_enabled or g.phase!="land" or not g.Specials.eligible(g,g.current) or not g.pending_attack.is_empty() or not g.pending_service.is_empty():return false
	if g.steps_left!=0 or g.landing_pending or g.landing_shop or not g.landing_queue.is_empty() or not g.landing_hotel.is_empty():return false
	var road:int=g.players[g.current].pos
	if road<0 or road>=g.nodes.size() or g.nodes[road].kind!="minigame" or g.service_visited.has(road):return false
	var game:Dictionary={"id":GAME_ID,"version":1,"player":g.current,"participants":_participants(g.players,g.current),"cursor":0,"history":[]}
	_reset(game)
	g.service_visited.append(road);g.pending_service={"kind":"minigame","road":road,"game":game};g.phase="minigame"
	g.Economy.freeze_service(g)
	g._log("拆炸弹：记住物品、追踪换位，再选择开关；数值和时长见测试配置。")
	return true

static func _active(g,status:String)->bool:
	return g.phase=="minigame" and g.pending_service.get("kind","")=="minigame" and g.pending_service.get("game",{}).get("id","")==GAME_ID and g.pending_service.game.get("status","")==status

static func start(g)->bool:
	if not _active(g,"ready"):return false
	g.pending_service.game.status="playing"
	return true

static func _swap(order:Array,pair:Array)->void:
	var saved:int=order[pair[0]];order[pair[0]]=order[pair[1]];order[pair[1]]=saved

static func _stage(elapsed:int)->String:
	if elapsed<=TEST_PROFILE.preview_ticks:return "preview"
	if elapsed<=TEST_PROFILE.preview_ticks+TEST_PROFILE.shuffle_swaps:return "shuffle"
	return "choose"

static func _record(game:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key in ["player","tick","score","reward","reason","initial","order","swaps","opened"]:result[key]=game[key]
	return result.duplicate(true)

static func _finish(game:Dictionary,reason:String)->void:
	game.reason=reason;game.reward=game.score
	game.status="result" if game.cursor==game.participants.size()-1 else "participant_result"
	game.history.append(_record(game))

static func tick(g)->bool:
	if not _active(g,"playing"):return false
	var game:Dictionary=g.pending_service.game
	game.tick+=1;game.stage=_stage(game.tick);game.last_swap=[]
	if game.stage=="shuffle":
		var first:int=g.rng.randi_range(0,5)
		var second:int=g.rng.randi_range(0,4)
		if second>=first:second+=1
		game.last_swap=[first,second]
		_swap(game.order,game.last_swap)
		game.swaps.append(game.last_swap.duplicate())
	if game.tick==TEST_PROFILE.ticks:_finish(game,"time_up")
	return true

static func choose(g,index:int)->bool:
	if not _active(g,"playing") or g.pending_service.game.stage!="choose" or index<0 or index>=6:return false
	var game:Dictionary=g.pending_service.game
	if game.opened.has(index):return false
	game.opened.append(index)
	if game.initial[game.order[index]]=="bomb":_finish(game,"bomb")
	else:game.score+=int(TEST_PROFILE.coin_value)
	return true

static func ai_switch(g)->int:
	if not _active(g,"playing") or g.pending_service.game.stage!="choose":return -1
	var game:Dictionary=g.pending_service.game
	# Perfect memory TEST policy: reconstruct only the displayed preview and
	# visible swaps. Do not inspect the hidden current order or RNG state.
	var remembered:Array=[0,1,2,3,4,5]
	for pair in game.swaps:_swap(remembered,pair)
	for index in range(6):
		if not game.opened.has(index) and game.initial[remembered[index]]=="coin":return index
	return -1

static func next_player(g)->bool:
	if not _active(g,"participant_result"):return false
	var game:Dictionary=g.pending_service.game
	game.cursor+=1;game.player=game.participants[game.cursor]
	_reset(game)
	return true

static func ai_step(g)->bool:
	if _active(g,"ready"):return start(g)
	if _active(g,"participant_result"):return next_player(g)
	if _active(g,"result"):return close(g)
	if not _active(g,"playing"):return false
	var index:int=ai_switch(g)
	if index>=0 and not choose(g,index):return false
	return tick(g) if _active(g,"playing") else true

static func settle_others(g)->bool:
	if g.phase!="minigame" or g.pending_service.get("game",{}).get("id","")!=GAME_ID:return false
	var game:Dictionary=g.pending_service.game
	if game.status=="result" or (game.cursor==0 and game.status!="participant_result"):return false
	var budget:int=game.participants.size()*(TEST_PROFILE.ticks+2)
	while game.status!="result" and budget>0:
		if game.status=="participant_result":
			if not next_player(g):return false
		elif not ai_step(g):return false
		budget-=1
	return game.status=="result"

static func close(g)->bool:
	if not _active(g,"result"):return false
	var history:Array=g.pending_service.game.history.duplicate(true)
	var payouts:Dictionary={}
	for record in history: payouts[record.player]=g.Economy.minigame_cash(g,record)
	g.pending_service.clear();g.phase="land"
	for record in history:
		var paid:int=payouts[record.player]
		g.players[record.player].cash+=paid
		g._log("%s 完成拆炸弹：%d分，奖励现金%d。"%[g.players[record.player].name,record.score,paid])
	return true

static func _keys(value:Dictionary,keys:Array)->bool:
	if value.size()!=keys.size():return false
	for key in keys:
		if not value.has(key):return false
	return true

static func _replay(value:Dictionary)->Dictionary:
	if not value.get("tick") is int or value.tick<0 or value.tick>TEST_PROFILE.ticks:return {}
	if not value.get("initial") is Array or value.initial!=INITIAL or not value.get("order") is Array or not value.get("swaps") is Array or not value.get("opened") is Array:return {}
	var expected_count:int=clampi(value.tick-TEST_PROFILE.preview_ticks,0,TEST_PROFILE.shuffle_swaps)
	if value.swaps.size()!=expected_count:return {}
	var order:Array=[0,1,2,3,4,5]
	for pair in value.swaps:
		if not pair is Array or pair.size()!=2:return {}
		for index in pair:
			if not index is int or index<0 or index>=6:return {}
		if pair[0]==pair[1]:return {}
		_swap(order,pair)
	for index in value.order:
		if not index is int:return {}
	if value.order!=order:return {}
	if not value.opened.is_empty() and _stage(value.tick)!="choose":return {}
	var seen:Dictionary={};var score:int=0;var reason:String=""
	for index in value.opened:
		if not reason.is_empty() or not index is int or index<0 or index>=6 or seen.has(index):return {}
		seen[index]=true
		if value.initial[order[index]]=="bomb":reason="bomb"
		else:score+=int(TEST_PROFILE.coin_value)
	if reason=="bomb" and value.tick==TEST_PROFILE.ticks:return {}
	if reason.is_empty() and value.tick==TEST_PROFILE.ticks:reason="time_up"
	return {"score":score,"reason":reason}

static func _record_error(record:Dictionary)->String:
	if not _keys(record,["player","tick","score","reward","reason","initial","order","swaps","opened"]) or not record.player is int:return "拆炸弹历史字段无效"
	var expected:Dictionary=_replay(record)
	if expected.is_empty() or expected.reason.is_empty():return "拆炸弹历史未完成或轨迹无效"
	if not record.score is int or record.score!=expected.score or not record.reward is int or record.reward!=record.score or not record.reason is String or record.reason!=expected.reason:return "拆炸弹历史分数无效"
	return ""

static func state_error(state:Dictionary,g)->String:
	state=g.Economy.scoring_state(state)
	if state.get("phase")!="minigame" or not state.get("specials_enabled") is bool or not state.specials_enabled or not state.get("current") is int or not state.get("players") is Array:return "拆炸弹对局无效"
	if state.current<0 or state.current>=state.players.size():return "拆炸弹触发者无效"
	if not state.get("service_visited") is Array or not state.get("pending_attack") is Dictionary or not state.pending_attack.is_empty():return "拆炸弹访问或攻击状态无效"
	if not state.get("landing_pending") is bool or state.landing_pending or not state.get("landing_shop") is bool or state.landing_shop or not state.get("steps_left") is int or state.steps_left!=0:return "拆炸弹行动未完成"
	if not state.get("landing_queue") is Array or not state.landing_queue.is_empty() or state.get("landing_hotel")!="":return "拆炸弹落地未完成"
	var service=state.get("pending_service")
	if not service is Dictionary or not _keys(service,["kind","road","game"]) or service.kind!="minigame":return "拆炸弹服务字段无效"
	if not service.road is int or service.road<0 or service.road>=g.nodes.size() or g.nodes[service.road].kind!="minigame" or not state.service_visited.has(service.road):return "拆炸弹道路无效"
	for player in state.players:
		if not player is Dictionary or not player.get("bankrupt") is bool:return "拆炸弹席位结构无效"
	var trigger:Dictionary=state.players[state.current]
	if not trigger.get("pos") is int or trigger.pos!=service.road or trigger.bankrupt or not trigger.get("status") is Dictionary or not trigger.status.is_empty() or not trigger.get("god") is Dictionary or trigger.god.get("id","")=="fierce":return "拆炸弹触发者资格无效"
	var game=service.game
	if not game is Dictionary or not _keys(game,["id","version","player","tick","score","status","reason","reward","participants","cursor","history","stage","initial","order","swaps","last_swap","opened"]):return "拆炸弹运行字段无效"
	if game.id!=GAME_ID or not game.version is int or game.version!=1:return "拆炸弹版本无效"
	if not game.participants is Array or game.participants!=_participants(state.players,state.current):return "拆炸弹参与名单无效"
	for who in game.participants:
		if not who is int:return "拆炸弹参与名单类型无效"
	if not game.cursor is int or game.cursor<0 or game.cursor>=game.participants.size() or not game.player is int or game.player!=game.participants[game.cursor]:return "拆炸弹当前席位无效"
	var expected:Dictionary=_replay(game)
	if expected.is_empty() or not game.score is int or game.score!=expected.score or not game.reward is int or not game.reason is String or game.reason!=expected.reason:return "拆炸弹轨迹或计分无效"
	if not game.stage is String or game.stage!=_stage(game.tick) or not game.last_swap is Array:return "拆炸弹展示阶段无效"
	var last:Array=game.swaps.back() if game.stage=="shuffle" else []
	for index in game.last_swap:
		if not index is int:return "拆炸弹交换动画类型无效"
	if game.last_swap!=last:return "拆炸弹交换动画无效"
	if not game.status is String or game.status not in ["ready","playing","participant_result","result"] or not game.history is Array:return "拆炸弹阶段无效"
	var completed:bool=game.status in ["participant_result","result"]
	if game.history.size()!=game.cursor+(1 if completed else 0):return "拆炸弹历史数量无效"
	for index in range(game.history.size()):
		if not game.history[index] is Dictionary:return "拆炸弹历史结构无效"
		var error:String=_record_error(game.history[index])
		if not error.is_empty():return error
		if game.history[index].player!=game.participants[index]:return "拆炸弹历史收款人无效"
	if completed:
		if game.reason.is_empty() or game.reward!=game.score or (game.status=="result")!=(game.cursor==game.participants.size()-1) or game.history.back()!=_record(game):return "拆炸弹结算状态无效"
	else:
		if not game.reason.is_empty() or game.reward!=0 or game.tick>=TEST_PROFILE.ticks:return "拆炸弹进行中结果无效"
		if game.status=="ready" and game.tick!=0:return "拆炸弹准备状态无效"
	return ""
