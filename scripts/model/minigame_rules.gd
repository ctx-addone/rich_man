class_name RichMinigameRules
extends RefCounted

# R11 footage confirms a clickable 3x3 grid, falling coins/bombs, score and timer.
# R14 in-game instructions confirm orthogonal movement and persistent ground loot.
# Coin 100/ingot 500 are inferred from the filmed 2024 Knight Manor sample.
# Timing, spawn composition, bomb penalty and payout formula remain TEST-R14.
const TEST_PROFILE = {"tick_seconds":0.5,"ticks":24,"coin_value":100,"ingot_value":500,"bomb_penalty":300,"item_life":3}
const GAME_ID = "catch_coins"

static func enter(g) -> bool:
	if not g.specials_enabled or g.phase != "land" or not g.Specials.eligible(g,g.current) or not g.pending_attack.is_empty() or not g.pending_service.is_empty(): return false
	if g.steps_left != 0 or g.landing_pending or g.landing_shop or not g.landing_queue.is_empty() or not g.landing_hotel.is_empty(): return false
	var road:int = g.players[g.current].pos
	if road < 0 or road >= g.nodes.size() or g.nodes[road].kind != "minigame" or g.service_visited.has(road): return false
	g.service_visited.append(road)
	g.pending_service = {"kind":"minigame","road":road,"game":{"id":GAME_ID,"version":1,"player":g.current,"tick":0,"cell":4,"score":0,"items":_wave(g),"results":[],"status":"ready","reason":"","reward":0,"participants":_participants(g.players,g.current),"cursor":0,"history":[]}}
	g.phase = "minigame"
	g._log("接金币：点击九宫格移动，接金币并避开炸弹；计时与分值为测试参数。")
	return true

static func _participants(players:Array, trigger:int) -> Array:
	# TEST-R14: every non-bankrupt seat participates, including absent/possessed
	# seats. Only the board-turn player is manual; other seats use public AI input.
	var result:Array = []
	for offset in range(players.size()):
		var who:int = (trigger+offset)%players.size()
		if not players[who].bankrupt: result.append(who)
	return result

static func _wave(g) -> Array:
	var items:Array = []
	_refill(g,items)
	return items

static func _refill(g, items:Array) -> void:
	var cells:Array[int] = [0,1,2,3,4,5,6,7,8]
	var kinds:Array = []
	for item in items:
		cells.erase(item.cell)
		kinds.append(item.kind)
	for kind in ["coin","ingot","bomb"]:
		if kinds.has(kind): continue
		var index:int = g.rng.randi_range(0,cells.size()-1)
		items.append({"cell":cells[index],"kind":kind,"remaining":TEST_PROFILE.item_life,"life":TEST_PROFILE.item_life})
		cells.remove_at(index)

static func _active(g, status:String) -> bool:
	return g.phase == "minigame" and g.pending_service.get("kind","") == "minigame" and g.pending_service.get("game",{}).get("status","") == status

static func start(g) -> bool:
	if not _active(g,"ready"): return false
	g.pending_service.game.status = "playing"
	return true

static func select_cell(g, cell:int) -> bool:
	if not _active(g,"playing") or cell < 0 or cell >= 9: return false
	if not legal_cells(g).has(cell): return false
	g.pending_service.game.cell = cell
	return true

static func legal_cells(g) -> Array[int]:
	var result:Array[int] = []
	if g.phase != "minigame": return result
	var origin:int = g.pending_service.game.cell
	for cell in range(9):
		if _distance(origin,cell) <= 1: result.append(cell)
	return result

static func _distance(a:int, b:int) -> int:
	return absi(a%3-b%3)+absi(a/3-b/3)

static func _value(kind:String) -> int:
	if kind == "coin": return TEST_PROFILE.coin_value
	if kind == "ingot": return TEST_PROFILE.ingot_value
	return -TEST_PROFILE.bomb_penalty

static func tick(g) -> bool:
	if not _active(g,"playing"): return false
	var game:Dictionary = g.pending_service.game
	var result:int = 0
	var retained:Array = []
	for item in game.items:
		item.remaining -= 1
		if item.cell == game.cell:
			result = _value(item.kind)
		elif item.remaining > 0: retained.append(item)
	game.results.append(result)
	game.score = maxi(0,game.score+result)
	game.tick += 1
	if game.tick == TEST_PROFILE.ticks:
		game.items = []
		game.status = "result" if game.cursor == game.participants.size()-1 else "participant_result"
		game.reason = "time_up"
		game.reward = game.score
		game.history.append({"player":game.player,"results":game.results.duplicate(),"score":game.score,"reward":game.reward})
	else:
		_refill(g,retained)
		game.items = retained
	return true

static func next_player(g) -> bool:
	if not _active(g,"participant_result"): return false
	var game:Dictionary = g.pending_service.game
	game.cursor += 1
	game.player = game.participants[game.cursor]
	game.tick = 0
	game.cell = 4
	game.score = 0
	game.items = _wave(g)
	game.results = []
	game.status = "ready"
	game.reason = ""
	game.reward = 0
	return true

static func settle_others(g) -> bool:
	if g.phase != "minigame" or g.pending_service.get("kind","") != "minigame": return false
	var game:Dictionary = g.pending_service.game
	if game.status == "result" or (game.cursor == 0 and game.status != "participant_result"): return false
	# Other local human seats also get automatic scores in the filmed original.
	# Simulate their actual public inputs; do not fabricate random scores/cash.
	var budget:int = game.participants.size()*(TEST_PROFILE.ticks+2)
	while game.status != "result" and budget > 0:
		if game.status == "participant_result":
			if not next_player(g): return false
		elif not ai_step(g): return false
		budget -= 1
	return game.status == "result"

static func close(g) -> bool:
	if not _active(g,"result"): return false
	var game:Dictionary = g.pending_service.game
	for record in game.history:
		g.players[record.player].cash += record.reward
		g._log("%s 完成接金币：%d 分，奖励现金 %d。" % [g.players[record.player].name,record.score,record.reward])
	g.pending_service.clear()
	g.phase = "land"
	return true

static func ai_step(g) -> bool:
	if _active(g,"ready"): return start(g)
	if _active(g,"participant_result"): return next_player(g)
	if _active(g,"result"): return close(g)
	if not _active(g,"playing"): return false
	select_cell(g,ai_cell(g))
	return tick(g)

static func ai_cell(g) -> int:
	if not _active(g,"playing"): return -1
	# Only inspect the same visible wave as the human; never inspect RNG state.
	var selected:int = g.pending_service.game.cell
	var best:float = -INF
	for cell in legal_cells(g):
		var score:float = 0
		for item in g.pending_service.game.items:
			if item.cell == cell: score += _value(item.kind)
			elif item.kind != "bomb": score += 1.0/(1+_distance(cell,item.cell))
		if score > best: best = score; selected = cell
	return selected

static func _keys(value:Dictionary, expected:Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true

static func _score(results:Array) -> int:
	var result:int = 0
	for value in results:
		if not value is int or value not in [0,TEST_PROFILE.coin_value,TEST_PROFILE.ingot_value,-TEST_PROFILE.bomb_penalty]: return -1
		result = maxi(0,result+value)
	return result

# Save receives the whole serialized game state, not an unchecked runtime object.
static func state_error(state:Dictionary, g) -> String:
	if state.get("phase","") != "minigame": return "小游戏阶段无效"
	if not state.get("current") is int or not state.get("players") is Array or not state.get("specials_enabled") is bool or not state.get("service_visited") is Array: return "小游戏所属对局结构无效"
	if not state.get("pending_attack") is Dictionary or not state.get("landing_queue") is Array or not state.get("landing_hotel") is String or not state.get("landing_pending") is bool or not state.get("landing_shop") is bool or not state.get("steps_left") is int: return "小游戏行动结构无效"
	var service = state.get("pending_service")
	if not service is Dictionary or not _keys(service,["kind","road","game"]): return "小游戏服务结构无效"
	if service.kind != "minigame" or not service.road is int or service.road < 0 or service.road >= g.nodes.size() or g.nodes[service.road].kind != "minigame": return "小游戏道路无效"
	if not state.get("specials_enabled",false) or not state.get("service_visited",[]).has(service.road): return "小游戏开关或到访记录无效"
	var game = service.game
	if not game is Dictionary or not _keys(game,["id","version","player","tick","cell","score","items","results","status","reason","reward","participants","cursor","history"]): return "小游戏运行结构无效"
	if game.id != GAME_ID or not game.version is int or game.version != 1: return "小游戏版本无效"
	if state.current < 0 or state.current >= state.players.size(): return "小游戏触发者无效"
	for participant in state.players:
		if not participant is Dictionary or not participant.get("bankrupt") is bool: return "小游戏席位结构无效"
	if not game.participants is Array or game.participants != _participants(state.players,state.current): return "小游戏参与名单无效"
	for who in game.participants:
		if not who is int: return "小游戏参与名单类型无效"
	if not game.cursor is int or game.cursor < 0 or game.cursor >= game.participants.size(): return "小游戏席位进度无效"
	if not game.player is int or game.player != game.participants[game.cursor]: return "小游戏参与者无效"
	var player:Dictionary = state.players[state.current]
	if not player.get("pos") is int or not player.get("bankrupt") is bool or not player.get("status") is Dictionary or not player.get("god") is Dictionary: return "小游戏参与者结构无效"
	if player.pos != service.road or player.bankrupt or not player.status.is_empty() or player.god.get("id","") == "fierce": return "小游戏参与者状态无效"
	if not state.pending_attack.is_empty() or state.landing_pending or state.landing_shop or state.steps_left != 0 or not state.landing_queue.is_empty() or state.landing_hotel != "": return "小游戏行动状态无效"
	if not game.tick is int or game.tick < 0 or game.tick > TEST_PROFILE.ticks or not game.cell is int or game.cell < 0 or game.cell >= 9: return "小游戏时间或位置无效"
	if not game.score is int or not game.reward is int or not game.results is Array or game.results.size() != game.tick: return "小游戏计分结构无效"
	var expected_score:int = _score(game.results)
	if expected_score < 0 or game.score != expected_score or game.score > game.tick*TEST_PROFILE.ingot_value: return "小游戏累计分数无效"
	if game.status not in ["ready","playing","participant_result","result"] or not game.reason is String or not game.items is Array: return "小游戏运行阶段无效"
	var completed:bool = game.status in ["participant_result","result"]
	if not game.history is Array or game.history.size() != game.cursor+(1 if completed else 0): return "小游戏完成席位数量无效"
	for index in range(game.history.size()):
		var record = game.history[index]
		if not record is Dictionary or not _keys(record,["player","results","score","reward"]): return "小游戏席位成绩结构无效"
		if not record.player is int or record.player != game.participants[index] or not record.results is Array or record.results.size() != TEST_PROFILE.ticks: return "小游戏席位成绩名单无效"
		var score:int = _score(record.results)
		if score < 0 or not record.score is int or not record.reward is int or record.score != score or record.reward != score or score > TEST_PROFILE.ticks*TEST_PROFILE.ingot_value: return "小游戏席位成绩无效"
	if completed:
		if game.tick != TEST_PROFILE.ticks or game.reason != "time_up" or game.reward != game.score or not game.items.is_empty(): return "小游戏结算无效"
		if (game.status == "result") != (game.cursor == game.participants.size()-1): return "小游戏最终结算席位无效"
		if game.history.back() != {"player":game.player,"results":game.results,"score":game.score,"reward":game.reward}: return "小游戏当前席位成绩不一致"
	else:
		if game.tick >= TEST_PROFILE.ticks or game.reason != "" or game.reward != 0 or (game.status == "ready" and game.tick != 0): return "小游戏进行中结算无效"
		if game.status == "ready" and game.cell != 4: return "小游戏准备位置无效"
		if game.items.size() != 3: return "小游戏坠物数量无效"
		var occupied:Dictionary = {}
		var coins:int = 0
		var ingots:int = 0
		var bombs:int = 0
		for item in game.items:
			if not item is Dictionary or not _keys(item,["cell","kind","remaining","life"]): return "小游戏坠物结构无效"
			if not item.cell is int or item.cell < 0 or item.cell >= 9 or occupied.has(item.cell): return "小游戏坠物格无效"
			occupied[item.cell] = true
			if not item.remaining is int or not item.life is int or item.remaining < 1 or item.remaining > TEST_PROFILE.item_life or item.life != TEST_PROFILE.item_life: return "小游戏坠物时间无效"
			if item.remaining < maxi(1,TEST_PROFILE.item_life-game.tick): return "小游戏坠物先于场次开始无效"
			if item.kind == "coin": coins += 1
			elif item.kind == "ingot": ingots += 1
			elif item.kind == "bomb": bombs += 1
			else: return "小游戏坠物种类无效"
		if coins != 1 or ingots != 1 or bombs != 1: return "小游戏坠物配比无效"
	return ""
