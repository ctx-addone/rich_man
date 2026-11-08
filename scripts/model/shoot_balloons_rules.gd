class_name RichShootBalloonsRules
extends RefCounted

const GAME_ID = "shoot_balloons"
const TITLE = "打气球"
const INSTRUCTIONS = "点击四列底部的炮钮，获取该列所有气球携带的物品。打到炸弹会结束本场；炸弹飞得更快，可以等待它飞走。"
const PARAMETERS = "测试参数：20秒、每0.5秒一拍，金币100、元宝500。若同列有炸弹，优先结束且本列奖励不计，保留此前分数；这个结算优先级尚未核实。其他角色自动计分，各自领奖。"
# Only whole-lane shooting, faster bomb ascent and bomb termination are verified.
# Values, discrete movement/spawning, timing and collision priority are TEST-R15.
const TEST_PROFILE = {"tick_seconds":0.5,"ticks":40,"top_height":8,"coin_value":100,"ingot_value":500,"reward_speed":1,"bomb_speed":2}
const KINDS = ["coin","ingot","bomb"]

static func _participants(players:Array, trigger:int) -> Array:
	var result:Array = []
	for offset in range(players.size()):
		var who:int = (trigger+offset)%players.size()
		if not players[who].bankrupt: result.append(who)
	return result

static func enter(g) -> bool:
	if not g.specials_enabled or g.phase != "land" or not g.Specials.eligible(g,g.current) or not g.pending_attack.is_empty() or not g.pending_service.is_empty(): return false
	if g.steps_left != 0 or g.landing_pending or g.landing_shop or not g.landing_queue.is_empty() or not g.landing_hotel.is_empty(): return false
	var road:int = g.players[g.current].pos
	if road < 0 or road >= g.nodes.size() or g.nodes[road].kind != "minigame" or g.service_visited.has(road): return false
	g.service_visited.append(road)
	g.pending_service = {"kind":"minigame","road":road,"game":{"id":GAME_ID,"version":1,"player":g.current,"tick":0,"score":0,"status":"ready","reason":"","reward":0,"participants":_participants(g.players,g.current),"cursor":0,"history":[],"balloons":[],"choice":-1,"events":[]}}
	g.phase = "minigame"
	g.Economy.freeze_service(g)
	g._log("打气球：选择整列射击，避开炸弹；生成与结算数值为测试参数。")
	return true

static func _active(g, status:String) -> bool:
	return g.phase == "minigame" and g.pending_service.get("kind","") == "minigame" and g.pending_service.get("game",{}).get("id","") == GAME_ID and g.pending_service.game.get("status","") == status

static func start(g) -> bool:
	if not _active(g,"ready"): return false
	g.pending_service.game.status = "playing"
	return true

static func shoot(g, lane:int) -> bool:
	if not _active(g,"playing") or lane < 0 or lane > 3 or g.pending_service.game.choice != -1: return false
	g.pending_service.game.choice = lane
	return true

static func _speed(kind:String) -> int:
	return TEST_PROFILE.bomb_speed if kind == "bomb" else TEST_PROFILE.reward_speed

static func _value(kind:String) -> int:
	return TEST_PROFILE.ingot_value if kind == "ingot" else TEST_PROFILE.coin_value

static func _has_bomb(balloons:Array, lane:int) -> bool:
	for balloon in balloons:
		if balloon.lane == lane and balloon.kind == "bomb": return true
	return false

# Pure tick transition; used by gameplay and strict serialized-history replay.
# The input is the visible pre-tick board, so no unseen spawn can be shot.
static func _advance(balloons:Array, score:int, event:Dictionary, elapsed:int) -> Dictionary:
	if _has_bomb(balloons,event.lane): return {"balloons":[],"score":score,"reason":"bomb"}
	var retained:Array = []
	for balloon in balloons:
		if balloon.lane == event.lane: score += _value(balloon.kind)
		else:
			var moved:Dictionary = balloon.duplicate()
			moved.height += moved.speed
			if moved.height < TEST_PROFILE.top_height: retained.append(moved)
	if elapsed == TEST_PROFILE.ticks: return {"balloons":[],"score":score,"reason":"time_up"}
	var spawn:Dictionary = event.spawn
	retained.append({"lane":spawn.lane,"kind":spawn.kind,"height":0,"speed":_speed(spawn.kind)})
	return {"balloons":retained,"score":score,"reason":""}

static func _record(game:Dictionary) -> Dictionary:
	return {"player":game.player,"tick":game.tick,"events":game.events.duplicate(true),"score":game.score,"reward":game.reward,"reason":game.reason}

static func tick(g) -> bool:
	if not _active(g,"playing"): return false
	var game:Dictionary = g.pending_service.game
	var event:Dictionary = {"lane":game.choice,"spawn":{}}
	game.tick += 1
	if not _has_bomb(game.balloons,game.choice) and game.tick < TEST_PROFILE.ticks:
		event.spawn = {"lane":g.rng.randi_range(0,3),"kind":KINDS[g.rng.randi_range(0,KINDS.size()-1)]}
	var result:Dictionary = _advance(game.balloons,game.score,event,game.tick)
	game.events.append(event)
	game.balloons = result.balloons
	game.score = result.score
	game.reason = result.reason
	game.choice = -1
	if not game.reason.is_empty():
		game.reward = game.score
		game.status = "result" if game.cursor == game.participants.size()-1 else "participant_result"
		game.history.append(_record(game))
	return true

static func next_player(g) -> bool:
	if not _active(g,"participant_result"): return false
	var game:Dictionary = g.pending_service.game
	game.cursor += 1
	game.player = game.participants[game.cursor]
	game.tick = 0
	game.score = 0
	game.status = "ready"
	game.reason = ""
	game.reward = 0
	game.balloons = []
	game.choice = -1
	game.events = []
	return true

static func ai_lane(g) -> int:
	if not _active(g,"playing"): return -1
	var best:int = 0
	var selected:int = -1
	for lane in range(4):
		if _has_bomb(g.pending_service.game.balloons,lane): continue
		var score:int = 0
		for balloon in g.pending_service.game.balloons:
			if balloon.lane == lane: score += _value(balloon.kind)
		if score > best: best = score; selected = lane
	return selected

static func ai_step(g) -> bool:
	if _active(g,"ready"): return start(g)
	if _active(g,"participant_result"): return next_player(g)
	if _active(g,"result"): return close(g)
	if not _active(g,"playing"): return false
	if g.pending_service.game.choice == -1:
		var lane:int = ai_lane(g)
		if lane >= 0: shoot(g,lane)
	return tick(g)

static func settle_others(g) -> bool:
	if g.phase != "minigame" or g.pending_service.get("game",{}).get("id","") != GAME_ID: return false
	var game:Dictionary = g.pending_service.game
	if game.status == "result" or (game.cursor == 0 and game.status != "participant_result"): return false
	var budget:int = game.participants.size()*(TEST_PROFILE.ticks+2)
	while game.status != "result" and budget > 0:
		if game.status == "participant_result":
			if not next_player(g): return false
		elif not ai_step(g): return false
		budget -= 1
	return game.status == "result"

static func close(g) -> bool:
	if not _active(g,"result"): return false
	for record in g.pending_service.game.history:
		var paid:int = g.Economy.minigame_cash(g,record)
		g.players[record.player].cash += paid
		g._log("%s 完成打气球：%d 分，奖励现金 %d。" % [g.players[record.player].name,record.score,paid])
	g.pending_service.clear()
	g.phase = "land"
	return true

static func _keys(value:Dictionary, expected:Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

static func _replay(events:Array) -> Dictionary:
	if events.size() > TEST_PROFILE.ticks: return {}
	var result:Dictionary = {"balloons":[],"score":0,"reason":""}
	for index in range(events.size()):
		var event = events[index]
		if not result.reason.is_empty() or not event is Dictionary or not _keys(event,["lane","spawn"]): return {}
		if not event.lane is int or event.lane < -1 or event.lane > 3 or not event.spawn is Dictionary: return {}
		var terminating:bool = _has_bomb(result.balloons,event.lane) or index+1 == TEST_PROFILE.ticks
		if terminating:
			if not event.spawn.is_empty(): return {}
		else:
			if not _keys(event.spawn,["lane","kind"]) or not event.spawn.lane is int or event.spawn.lane < 0 or event.spawn.lane > 3 or not event.spawn.kind is String or event.spawn.kind not in KINDS: return {}
		result = _advance(result.balloons,result.score,event,index+1)
	return result

static func _record_error(record:Dictionary) -> String:
	if not _keys(record,["player","tick","events","score","reward","reason"]): return "打气球历史字段无效"
	if not record.player is int or not record.tick is int or record.tick < 1 or record.tick > TEST_PROFILE.ticks or not record.events is Array or record.events.size() != record.tick: return "打气球历史时钟无效"
	var expected:Dictionary = _replay(record.events)
	if expected.is_empty() or expected.reason.is_empty() or not record.score is int or record.score != expected.score or not record.reward is int or record.reward != record.score or not record.reason is String or record.reason != expected.reason: return "打气球历史计分无效"
	return ""

static func state_error(state:Dictionary, g) -> String:
	state=g.Economy.scoring_state(state)
	if state.get("phase") != "minigame" or not state.get("current") is int or not state.get("players") is Array or not state.get("specials_enabled") is bool or not state.specials_enabled: return "打气球所属对局无效"
	if state.current < 0 or state.current >= state.players.size(): return "打气球触发者无效"
	if not state.get("service_visited") is Array or not state.get("pending_attack") is Dictionary or not state.pending_attack.is_empty(): return "打气球访问或攻击状态无效"
	if not state.get("landing_pending") is bool or state.landing_pending or not state.get("landing_shop") is bool or state.landing_shop or not state.get("steps_left") is int or state.steps_left != 0: return "打气球行动未完成"
	if not state.get("landing_queue") is Array or not state.landing_queue.is_empty() or state.get("landing_hotel") != "": return "打气球落地队列未完成"
	var service = state.get("pending_service")
	if not service is Dictionary or not _keys(service,["kind","road","game"]) or service.kind != "minigame": return "打气球服务字段无效"
	if not service.road is int or service.road < 0 or service.road >= g.nodes.size() or g.nodes[service.road].kind != "minigame" or not state.service_visited.has(service.road): return "打气球道路或到访无效"
	for player in state.players:
		if not player is Dictionary or not player.get("bankrupt") is bool: return "打气球参与席位无效"
	var trigger:Dictionary = state.players[state.current]
	if not trigger.get("pos") is int or trigger.pos != service.road or trigger.bankrupt or not trigger.get("status") is Dictionary or not trigger.status.is_empty() or not trigger.get("god") is Dictionary or trigger.god.get("id","") == "fierce": return "打气球触发者资格无效"
	var game = service.game
	if not game is Dictionary or not _keys(game,["id","version","player","tick","score","status","reason","reward","participants","cursor","history","balloons","choice","events"]): return "打气球运行字段无效"
	if game.id != GAME_ID or not game.version is int or game.version != 1: return "打气球版本无效"
	if not game.participants is Array or game.participants != _participants(state.players,state.current): return "打气球参与名单无效"
	for who in game.participants:
		if not who is int: return "打气球参与名单类型无效"
	if not game.cursor is int or game.cursor < 0 or game.cursor >= game.participants.size() or not game.player is int or game.player != game.participants[game.cursor]: return "打气球当前席位无效"
	if not game.tick is int or game.tick < 0 or game.tick > TEST_PROFILE.ticks or not game.events is Array or game.events.size() != game.tick: return "打气球时钟无效"
	var expected:Dictionary = _replay(game.events)
	if expected.is_empty() or not game.score is int or game.score != expected.score or not game.reward is int: return "打气球计分无效"
	if not game.status is String or game.status not in ["ready","playing","participant_result","result"] or not game.reason is String or game.reason != expected.reason: return "打气球阶段或结束原因无效"
	if not game.choice is int or game.choice < -1 or game.choice > 3 or not game.balloons is Array or not game.history is Array: return "打气球选择或气球无效"
	# Exact reconstructed objects also reject float-equal fields before equality.
	for balloon in game.balloons:
		if not balloon is Dictionary or not _keys(balloon,["lane","kind","height","speed"]): return "打气球气球结构无效"
		if not balloon.lane is int or not balloon.height is int or not balloon.speed is int or not balloon.kind is String: return "打气球气球字段类型无效"
	if game.balloons != expected.balloons: return "打气球气球重演不一致"
	var completed:bool = game.status in ["participant_result","result"]
	if game.history.size() != game.cursor+(1 if completed else 0): return "打气球历史席位数量无效"
	for index in range(game.history.size()):
		var record = game.history[index]
		if not record is Dictionary: return "打气球历史结构无效"
		var error:String = _record_error(record)
		if not error.is_empty(): return error
		if record.player != game.participants[index]: return "打气球历史收款人无效"
	if completed:
		if game.reason.is_empty() or game.tick < 1 or game.choice != -1 or not game.balloons.is_empty() or game.reward != game.score: return "打气球结果无效"
		if (game.status == "result") != (game.cursor == game.participants.size()-1) or game.history.back() != _record(game): return "打气球最终结果不一致"
	else:
		if not game.reason.is_empty() or game.tick >= TEST_PROFILE.ticks or game.reward != 0: return "打气球进行中结果无效"
		if game.status == "ready" and (game.tick != 0 or game.choice != -1): return "打气球准备状态无效"
	return ""
