extends RefCounted
const Game = preload("res://scripts/game_state.gd")
const VERSION = 1
const MAGIC = "RMSAVE01"
const MAX_BYTES = 16777216
const EXCLUDED = ["board_model", "stock_market", "rng"]

static func failure(message: String) -> Dictionary:
	return {"ok":false,"error":message}
static func fields(object) -> Array[String]:
	var result: Array[String] = []
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result.append(property.name)
	return result
static func snapshot(game, metadata: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {}
	for key in fields(game):
		if not EXCLUDED.has(key): state[key] = game.get(key)
	return {"version":VERSION,"state":state.duplicate(true),"rng_seed":game.rng.seed,"rng_state":game.rng.state,
		"market":{"quotes":game.stock_market.quotes.duplicate(true),"ledger":game.stock_market.ledger.duplicate(true),"market_round":game.stock_market.market_round,"rng_seed":game.stock_market.rng.seed,"rng_state":game.stock_market.rng.state},"metadata":metadata.duplicate(true)}
static func plain(value: Variant, depth: int = 0) -> bool:
	if depth > 32: return false
	if value is Dictionary:
		for key in value:
			if not plain(key,depth+1) or not plain(value[key],depth+1): return false
	elif value is Array:
		for child in value:
			if not plain(child,depth+1): return false
	elif typeof(value) not in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME,TYPE_VECTOR2,TYPE_VECTOR2I,TYPE_RECT2I]: return false
	return true
static func shape(value: Variant, template: Variant) -> bool:
	if typeof(value) != typeof(template): return false
	if template is Array and template.is_typed():
		for element in value:
			if typeof(element) != template.get_typed_builtin(): return false
	if template is Dictionary:
		for key in template:
			if not value.has(key) or not shape(value[key],template[key]): return false
	return true
static func player_index(value: Variant, count: int, minimum: int = 0) -> bool:
	return value is int and value >= minimum and value < count
static func event_valid(event: Dictionary, count: int) -> bool:
	for key in ["source","attacker","queue","kind","days","target","visited"]:
		if not event.has(key): return false
	if not event.source is String or event.kind not in ["money","hospital","prison","hibernate","sleepwalk"]: return false
	if not player_index(event.attacker,count,-1) or not player_index(event.target,count,-1) or not event.days is int: return false
	for key in ["queue","visited"]:
		if not event[key] is Array: return false
		for who in event[key]:
			if not player_index(who,count): return false
	if event.kind == "money":
		if not event.get("amount") is int or event.amount < 0 or not player_index(event.get("receiver"),count,-1): return false
	return true
static func restore(data: Variant) -> Dictionary:
	if not data is Dictionary or not plain(data): return failure("存档格式无效")
	data = data.duplicate(true)
	if data.get("version") != VERSION: return failure("存档版本不兼容")
	if not data.get("state") is Dictionary or not data.get("market") is Dictionary or not data.get("metadata") is Dictionary: return failure("存档缺少数据")
	var state: Dictionary = data.state
	if not state.get("players") is Array or state.players.size() < 2 or state.players.size() > 4: return failure("玩家数量无效")
	var names: Array = []
	for player in state.players:
		if not player is Dictionary or not player.get("name") is String: return failure("玩家格式无效")
		names.append(player.name)
	var game = Game.new()
	game.setup(names,1)
	for key in fields(game):
		if EXCLUDED.has(key): continue
		if not state.has(key) or not shape(state[key],game.get(key)): return failure("存档字段无效："+key)
	if state.nodes != game.nodes or state.lots.keys() != game.lots.keys(): return failure("地图版本不兼容")
	var count: int = state.players.size()
	if not player_index(state.current,count) or state.phase not in ["roll","move","land","bank","shop","end","detained","reaction","finished"]: return failure("行动状态无效")
	if state.round_number < 1 or state.round_limit < 1 or state.steps_left < 0 or state.dice_count < 1 or state.dice_count > 3: return failure("行动参数无效")
	if state.reaction_reward_active: return failure("不能恢复未完成的内部奖励步骤")
	for road in [state.forced_next,state.cached_next]:
		if road < -1 or road >= game.nodes.size(): return failure("路线无效")
	for road in state.controlled_path:
		if not road is int or road < 0 or road >= game.nodes.size(): return failure("指定路线无效")
	for i in range(count):
		var p: Dictionary = state.players[i]
		if not shape(p,game.players[i]) or p.id != i or p.pos < 0 or p.pos >= game.nodes.size() or p.previous < -1 or p.previous >= game.nodes.size() or p.cash < 0 or p.deposit < 0 or p.vehicle not in ["foot","motorbike","car"]: return failure("玩家状态无效")
		for card in p.cards:
			if not game.CARD_NAMES.has(card): return failure("未知卡牌")
		if p.cards.size() > game.HAND_LIMIT: return failure("手牌数量无效")
		if p.has("choose_junction") and not p.choose_junction is bool: return failure("岔路选择状态无效")
		if p.has("glory_until") and (not p.glory_until is int or p.glory_until < 0): return failure("辉煌到期状态无效")
		if p.has("next_direction") and (not p.next_direction is int or p.next_direction < -1 or p.next_direction >= game.nodes.size()): return failure("预选方向无效")
		if p.has("team") and typeof(p.team) not in [TYPE_NIL,TYPE_INT,TYPE_STRING]: return failure("队伍标识无效")
		if not p.god.is_empty() and (not game.Gods.CATALOG.has(p.god.get("id")) or not p.god.get("remaining") is int): return failure("神仙状态无效")
		if not p.god.is_empty() and p.god.remaining <= 0: return failure("附身时长无效")
		if not p.get("bomb",{}) is Dictionary: return failure("炸弹格式无效")
		if not p.get("bomb",{}).is_empty() and (not p.bomb.get("remaining") is int or not player_index(p.bomb.get("owner"),count,-1)): return failure("炸弹状态无效")
		if not p.status.is_empty():
			if p.status.get("kind") not in ["hospital","prison","vacation","hibernate","sleepwalk"] or not p.status.get("remaining") is int or not p.status.get("return_pos") is int or not p.status.get("return_previous") is int: return failure("停留状态无效")
			if p.status.kind == "vacation" and not state.lots.has(p.status.get("lot_id")): return failure("住宿地产无效")
			if p.status.remaining < 0: return failure("停留时长无效")
			if p.status.return_pos < 0 or p.status.return_pos >= game.nodes.size() or p.status.return_previous < -1 or p.status.return_previous >= game.nodes.size(): return failure("返回道路无效")
		for stock in p.stocks:
			if not game.stock_market.quotes.has(stock) or not p.stocks[stock] is int or p.stocks[stock] < 0: return failure("持仓无效")
	if state.phase == "detained":
		var detention: Dictionary = state.players[state.current].status
		if detention.get("kind") not in ["hospital","prison","vacation","hibernate"] or detention.get("remaining",0) <= 0: return failure("停留阶段缺少有效状态")
	for id in state.lots:
		var lot: Dictionary = state.lots[id]
		if not player_index(lot.owner,count,-1) or lot.level < 0 or lot.level > game.max_level(id): return failure("地产状态无效")
		if lot.footprint != game.lots[id].footprint or lot.frontage_nodes != game.lots[id].frontage_nodes or lot.kind != game.lots[id].kind or lot.trigger_events != game.lots[id].trigger_events: return failure("地产布局不兼容")
		if lot.kind != "facility" and lot.building_type != "vacant" and not game.building_options(id).has(lot.building_type): return failure("建筑类型无效")
		if not lot.research.is_empty() and (not game.CARD_NAMES.has(lot.research.get("card_id")) or not lot.research.get("remaining") is int): return failure("研究状态无效")
	for key in ["road_gods","road_objects"]:
		for road in state[key]:
			if not road is int or road < 0 or road >= game.nodes.size(): return failure("路面位置无效")
	for god in state.road_gods.values():
		if not game.Gods.CATALOG.has(god): return failure("道路神仙无效")
	for object in state.road_objects.values():
		if not object is Dictionary or object.get("kind") not in ["mine","roadblock","portal","banana","trap","jelly","timebomb","explosive"] or not player_index(object.get("owner"),count,-1): return failure("道路物件无效")
	for id in state.landing_queue:
		if not state.lots.has(id): return failure("落地队列无效")
	for id in state.bank_visited:
		if not state.lots.has(id): return failure("银行记录无效")
	for id in [state.active_lot_id,state.landing_hotel]:
		if not id.is_empty() and not state.lots.has(id): return failure("活动地产无效")
	for who in state.winners:
		if not player_index(who,count): return failure("获胜者无效")
	if state.phase == "reaction":
		var a: Dictionary = state.pending_attack
		if not event_valid(a,count) or not a.get("events") is Array or not a.get("return_phase") is String or not a.get("arrival") is bool: return failure("待处理事件无效")
		if not player_index(a.target,count) or a.return_phase not in ["roll","move","land","bank","shop","end","detained"]: return failure("反应恢复阶段无效")
		for event in a.events:
			if not event is Dictionary or not event_valid(event,count): return failure("后续事件无效")
	elif not state.pending_attack.is_empty(): return failure("事件与阶段不一致")
	var market: Dictionary = data.market
	if not shape(market,{"quotes":game.stock_market.quotes,"ledger":[],"market_round":1,"rng_seed":1,"rng_state":1}) or not data.get("rng_seed") is int or not data.get("rng_state") is int: return failure("市场或随机数状态无效")
	if market.quotes.keys() != game.stock_market.quotes.keys() or market.market_round < 1: return failure("市场目录无效")
	for quote in market.quotes.values():
		if quote.price < 1 or quote.price > 1000: return failure("股价无效")
		for price in quote.history:
			if not price is int or price < 1 or price > 1000: return failure("股价历史无效")
	for trade in market.ledger:
		if not trade is Dictionary or not shape(trade,{"round":1,"player":"","player_id":0,"side":"","stock_id":"","quantity":1,"price":1,"amount":1}): return failure("交易记录无效")
		if not market.quotes.has(trade.stock_id) or not player_index(trade.player_id,count): return failure("交易引用无效")
	# All checks precede reconstruction; caller's live game is never mutated.
	for key in fields(game):
		if not EXCLUDED.has(key): game.set(key,state[key])
	game.board_model.lots = game.lots
	game.rng.seed = data.rng_seed
	game.rng.state = data.rng_state
	game.stock_market.quotes = market.quotes
	game.stock_market.ledger.assign(market.ledger)
	game.stock_market.market_round = market.market_round
	game.stock_market.rng.seed = market.rng_seed
	game.stock_market.rng.state = market.rng_state
	return {"ok":true,"error":"","game":game,"metadata":data.metadata}
static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()
static func save_to_file(game, path: String, metadata: Dictionary = {}) -> Dictionary:
	var data: Dictionary = snapshot(game,metadata)
	var checked: Dictionary = restore(data)
	if not checked.ok: return checked
	var payload: PackedByteArray = var_to_bytes(data)
	if payload.size() > MAX_BYTES: return failure("存档过大")
	var directory: String = ProjectSettings.globalize_path(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return failure("无法创建存档目录")
	var temporary: String = path + ".writing"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return failure("无法写入存档")
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(payload.size())
	file.store_buffer(digest(payload))
	file.store_buffer(payload)
	file.flush()
	var error: int = file.get_error()
	file.close()
	if error != OK: return failure("写入失败，原存档保留")
	if not load_from_file(temporary).ok: return failure("写入校验失败，原存档保留")
	var backup: String = path + ".backup-" + str(Time.get_ticks_usec())
	var existed: bool = FileAccess.file_exists(path)
	if existed and DirAccess.rename_absolute(path,backup) != OK: return failure("无法替换原存档")
	if DirAccess.rename_absolute(temporary,path) != OK:
		if existed: DirAccess.rename_absolute(backup,path)
		return failure("替换失败，已保留原存档")
	if existed: DirAccess.remove_absolute(backup)
	return {"ok":true,"error":""}
static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return failure("存档不存在或不可读取")
	if file.get_length() < 44 or file.get_length() > MAX_BYTES + 44: return failure("存档长度无效")
	if file.get_buffer(8).get_string_from_ascii() != MAGIC: return failure("不是兼容存档")
	var length: int = file.get_32()
	if length != file.get_length()-44: return failure("存档不完整")
	var checksum: PackedByteArray = file.get_buffer(32)
	var payload: PackedByteArray = file.get_buffer(length)
	file.close()
	if digest(payload) != checksum: return failure("存档损坏，校验失败")
	return restore(bytes_to_var(payload))

static func peek_file(path: String) -> Dictionary:
	var result: Dictionary = load_from_file(path)
	if not result.ok: return result
	var game = result.game
	return {"ok":true,"error":"","metadata":result.metadata,"round_number":game.round_number,"phase":game.phase,"current":game.current,"player_name":game.players[game.current].name}
