class_name RichTossDollsRules
extends RefCounted

const GAME_ID = "toss_dolls"
const TITLE = "投娃娃"
const INSTRUCTIONS = "男娃娃投左侧蓝篮，女娃娃投右侧粉篮，炸弹投入中间垃圾桶。点击容器投掷当前物品，后续物品可预览。"
const PARAMETERS = "本版暂定40件、最多40秒，每0.5秒结算投掷；单娃350分为实机样本推断。错色或丢弃娃娃不得分；炸弹入篮清空该篮并结束，持弹未投也会结束。奖励按各自得分结算。"
# 350 points is inferred from filmed 2024 scoring; timing, probabilities,
# preview count, wrong-color handling and held-bomb outcome are TEST-R15.
const TEST_PROFILE = {"tick_seconds":0.5,"ticks":80,"doll_value":350,"preview_count":4,"items_total":40}
const KINDS = ["blue","pink","bomb"]

static func _participants(players:Array, trigger:int) -> Array:
	var result:Array = []
	for offset in range(players.size()):
		var who:int = (trigger+offset)%players.size()
		if not players[who].bankrupt: result.append(who)
	return result

static func _queue(g) -> Array:
	var result:Array = []
	for ignored in range(TEST_PROFILE.preview_count): result.append(_draw(g))
	return result

static func _draw(g) -> String:
	return KINDS[g.rng.randi_range(0,KINDS.size()-1)]

static func enter(g) -> bool:
	if not g.specials_enabled or g.phase != "land" or not g.Specials.eligible(g,g.current) or not g.pending_attack.is_empty() or not g.pending_service.is_empty(): return false
	if g.steps_left != 0 or g.landing_pending or g.landing_shop or not g.landing_queue.is_empty() or not g.landing_hotel.is_empty(): return false
	var road:int = g.players[g.current].pos
	if road < 0 or road >= g.nodes.size() or g.nodes[road].kind != "minigame" or g.service_visited.has(road): return false
	g.service_visited.append(road)
	g.pending_service = {"kind":"minigame","road":road,"game":{"id":GAME_ID,"version":1,"player":g.current,"tick":0,"score":0,"status":"ready","reason":"","reward":0,"participants":_participants(g.players,g.current),"cursor":0,"history":[],"queue":_queue(g),"choice":-1,"baskets":{"blue":0,"pink":0},"events":[],"spawned":TEST_PROFILE.preview_count}}
	g.phase = "minigame"
	g._log("投娃娃：按类别选择蓝篮、垃圾桶或粉篮；数值与自动得分策略见测试参数。")
	return true

static func _active(g, status:String) -> bool:
	return g.phase == "minigame" and g.pending_service.get("kind","") == "minigame" and g.pending_service.get("game",{}).get("id","") == GAME_ID and g.pending_service.game.get("status","") == status

static func start(g) -> bool:
	if not _active(g,"ready"): return false
	g.pending_service.game.status = "playing"
	return true

static func toss(g, bin_id:int) -> bool:
	if not _active(g,"playing") or bin_id < 0 or bin_id > 2 or g.pending_service.game.choice != -1: return false
	# Lock one command per visible object; clicking does not generate a new item.
	g.pending_service.game.choice = bin_id
	return true

static func _apply_event(baskets:Dictionary, kind:String, bin_id:int) -> String:
	if kind == "bomb":
		if bin_id == 0: baskets.blue = 0; return "bomb_blue"
		if bin_id == 2: baskets.pink = 0; return "bomb_pink"
		if bin_id == -1: return "held_bomb"
	elif (kind == "blue" and bin_id == 0) or (kind == "pink" and bin_id == 2): baskets[kind] += 1
	return ""

static func _score(baskets:Dictionary) -> int:
	return (baskets.blue+baskets.pink)*TEST_PROFILE.doll_value

static func _record(game:Dictionary) -> Dictionary:
	return {"player":game.player,"tick":game.tick,"events":game.events.duplicate(true),"baskets":game.baskets.duplicate(),"score":game.score,"reward":game.reward,"reason":game.reason}

static func tick(g) -> bool:
	if not _active(g,"playing"): return false
	var game:Dictionary = g.pending_service.game
	var kind:String = game.queue[0]
	var bin_id:int = game.choice
	game.tick += 1
	if bin_id != -1 or kind == "bomb":
		game.events.append({"tick":game.tick,"kind":kind,"bin":bin_id})
		game.reason = _apply_event(game.baskets,kind,bin_id)
		game.queue.pop_front()
	game.score = _score(game.baskets)
	game.choice = -1
	if game.reason.is_empty() and game.queue.is_empty() and game.spawned == TEST_PROFILE.items_total: game.reason = "queue_empty"
	if game.reason.is_empty() and game.tick == TEST_PROFILE.ticks: game.reason = "time_up"
	if not game.reason.is_empty():
		game.queue = []
		game.reward = game.score
		game.status = "result" if game.cursor == game.participants.size()-1 else "participant_result"
		game.history.append(_record(game))
	else:
		while game.queue.size() < TEST_PROFILE.preview_count and game.spawned < TEST_PROFILE.items_total:
			game.queue.append(_draw(g))
			game.spawned += 1
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
	game.queue = _queue(g)
	game.choice = -1
	game.baskets = {"blue":0,"pink":0}
	game.events = []
	game.spawned = TEST_PROFILE.preview_count
	return true

static func ai_bin(g) -> int:
	if not _active(g,"playing"): return -1
	return {"blue":0,"bomb":1,"pink":2}[g.pending_service.game.queue[0]]

static func ai_step(g) -> bool:
	if _active(g,"ready"): return start(g)
	if _active(g,"participant_result"): return next_player(g)
	if _active(g,"result"): return close(g)
	if not _active(g,"playing"): return false
	if g.pending_service.game.choice == -1: toss(g,ai_bin(g))
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
		g.players[record.player].cash += record.reward
		g._log("%s 完成投娃娃：%d 分，奖励现金 %d。" % [g.players[record.player].name,record.score,record.reward])
	g.pending_service.clear()
	g.phase = "land"
	return true

static func _keys(value:Dictionary, expected:Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

static func _replay(events:Array, elapsed:int) -> Dictionary:
	var baskets:Dictionary = {"blue":0,"pink":0}
	var reason:String = ""
	var previous_tick:int = 0
	if events.size() > TEST_PROFILE.items_total: return {}
	for event in events:
		if not reason.is_empty() or not event is Dictionary or not _keys(event,["tick","kind","bin"]): return {}
		if not event.tick is int or event.tick <= previous_tick or event.tick > elapsed: return {}
		if not event.kind is String or event.kind not in KINDS or not event.bin is int or event.bin < -1 or event.bin > 2: return {}
		if event.bin == -1 and event.kind != "bomb": return {}
		previous_tick = event.tick
		reason = _apply_event(baskets,event.kind,event.bin)
	if not reason.is_empty() and previous_tick != elapsed: return {}
	if reason.is_empty() and events.size() == TEST_PROFILE.items_total:
		if previous_tick != elapsed: return {}
		reason = "queue_empty"
	if reason.is_empty() and elapsed == TEST_PROFILE.ticks: reason = "time_up"
	return {"baskets":baskets,"score":_score(baskets),"reason":reason}

static func _record_error(record:Dictionary) -> String:
	if not _keys(record,["player","tick","events","baskets","score","reward","reason"]): return "投娃娃历史字段无效"
	if not record.player is int or not record.tick is int or record.tick < 1 or record.tick > TEST_PROFILE.ticks or not record.events is Array or record.events.size() > record.tick: return "投娃娃历史时钟无效"
	var expected:Dictionary = _replay(record.events,record.tick)
	if expected.is_empty() or expected.reason.is_empty(): return "投娃娃历史未完成或事件无效"
	if not record.baskets is Dictionary or not _keys(record.baskets,["blue","pink"]) or not record.baskets.blue is int or not record.baskets.pink is int: return "投娃娃历史篮子字段无效"
	if not record.baskets is Dictionary or record.baskets != expected.baskets or not record.score is int or record.score != expected.score or not record.reward is int or record.reward != record.score or not record.reason is String or record.reason != expected.reason: return "投娃娃历史计分无效"
	return ""

static func state_error(state:Dictionary, g) -> String:
	if state.get("phase") != "minigame" or not state.get("current") is int or not state.get("players") is Array or not state.get("specials_enabled") is bool or not state.specials_enabled: return "投娃娃所属对局无效"
	if state.current < 0 or state.current >= state.players.size(): return "投娃娃触发者无效"
	if not state.get("service_visited") is Array or not state.get("pending_attack") is Dictionary or not state.pending_attack.is_empty(): return "投娃娃访问或攻击状态无效"
	if not state.get("landing_pending") is bool or state.landing_pending or not state.get("landing_shop") is bool or state.landing_shop or not state.get("steps_left") is int or state.steps_left != 0: return "投娃娃行动未完成"
	if not state.get("landing_queue") is Array or not state.landing_queue.is_empty() or state.get("landing_hotel") != "": return "投娃娃落地队列未完成"
	var service = state.get("pending_service")
	if not service is Dictionary or not _keys(service,["kind","road","game"]) or service.kind != "minigame": return "投娃娃服务字段无效"
	if not service.road is int or service.road < 0 or service.road >= g.nodes.size() or g.nodes[service.road].kind != "minigame" or not state.service_visited.has(service.road): return "投娃娃道路或到访无效"
	for player in state.players:
		if not player is Dictionary or not player.get("bankrupt") is bool: return "投娃娃参与席位无效"
	var trigger:Dictionary = state.players[state.current]
	if not trigger.get("pos") is int or trigger.pos != service.road or trigger.bankrupt or not trigger.get("status") is Dictionary or not trigger.status.is_empty() or not trigger.get("god") is Dictionary or trigger.god.get("id","") == "fierce": return "投娃娃触发者资格无效"
	var game = service.game
	if not game is Dictionary or not _keys(game,["id","version","player","tick","score","status","reason","reward","participants","cursor","history","queue","choice","baskets","events","spawned"]): return "投娃娃运行字段无效"
	if game.id != GAME_ID or not game.version is int or game.version != 1: return "投娃娃版本无效"
	if not game.participants is Array or game.participants != _participants(state.players,state.current): return "投娃娃参与名单无效"
	for who in game.participants:
		if not who is int: return "投娃娃参与名单类型无效"
	if not game.cursor is int or game.cursor < 0 or game.cursor >= game.participants.size() or not game.player is int or game.player != game.participants[game.cursor]: return "投娃娃当前席位无效"
	if not game.tick is int or game.tick < 0 or game.tick > TEST_PROFILE.ticks or not game.events is Array or game.events.size() > game.tick: return "投娃娃时钟无效"
	if not game.baskets is Dictionary or not _keys(game.baskets,["blue","pink"]) or not game.baskets.blue is int or not game.baskets.pink is int: return "投娃娃篮子字段无效"
	var expected:Dictionary = _replay(game.events,game.tick)
	if expected.is_empty() or game.baskets != expected.baskets or not game.score is int or game.score != expected.score or not game.reward is int: return "投娃娃计分无效"
	if not game.status is String or game.status not in ["ready","playing","participant_result","result"] or not game.reason is String or game.reason != expected.reason: return "投娃娃阶段或结束原因无效"
	if not game.choice is int or game.choice < -1 or game.choice > 2 or not game.queue is Array or not game.history is Array: return "投娃娃选择或队列无效"
	var completed:bool = game.status in ["participant_result","result"]
	var handled_on_last_tick:bool = not game.events.is_empty() and game.events.back().tick == game.tick
	var expected_spawned:int = mini(TEST_PROFILE.items_total,TEST_PROFILE.preview_count+game.events.size()-(1 if completed and handled_on_last_tick else 0))
	if not game.spawned is int or game.spawned != expected_spawned: return "投娃娃有限供给无效"
	if game.history.size() != game.cursor+(1 if completed else 0): return "投娃娃历史席位数量无效"
	for index in range(game.history.size()):
		var record = game.history[index]
		if not record is Dictionary: return "投娃娃历史结构无效"
		var error:String = _record_error(record)
		if not error.is_empty(): return error
		if record.player != game.participants[index]: return "投娃娃历史收款人无效"
	if completed:
		if game.reason.is_empty() or game.tick < 1 or game.choice != -1 or not game.queue.is_empty() or game.reward != game.score: return "投娃娃结果无效"
		if (game.status == "result") != (game.cursor == game.participants.size()-1) or game.history.back() != _record(game): return "投娃娃最终结果不一致"
	else:
		if not game.reason.is_empty() or game.tick >= TEST_PROFILE.ticks or game.reward != 0 or game.queue.size() != game.spawned-game.events.size() or game.queue.is_empty(): return "投娃娃进行中结果无效"
		if game.status == "ready" and (game.tick != 0 or game.choice != -1): return "投娃娃准备状态无效"
		for item in game.queue:
			if not item is String or item not in KINDS: return "投娃娃物品无效"
	return ""
