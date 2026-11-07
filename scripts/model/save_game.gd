extends RefCounted
const Game = preload("res://scripts/game_state.gd")
const VERSION = 4
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
static func v1_additions() -> Dictionary:
	# Only fields introduced by version 2 may be repaired. Missing v1 fields
	# remain errors; the original road layout must not silently gain services.
	return {"specials_enabled":false,"lottery_state":Game.Specials.initial_lottery(),
		"service_visited":[],"pending_service":{},"magic_last_result":{},
		"god_respawn_due":{},"shop_stock":[],"shop_visit_serial":0}
static func migrate_legacy_teams(players: Array) -> String:
	# Before v3, team was optional trait metadata. Preserve valid relationships,
	# but never merge missing/null identifiers into a single team.
	var groups: Dictionary = {}
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var team: Variant = p.get("team", null)
		if typeof(team) not in [TYPE_NIL,TYPE_INT,TYPE_STRING]: return "旧队伍标识无效"
		var key: String = "seat:%d" % i
		if team is int and team >= 0: key = "int:%d" % team
		elif team is String and not team.is_empty() and team != "-1": key = "string:" + team
		if not groups.has(key): groups[key] = groups.size()
		p.team = groups[key]
	return "" if groups.size() >= 2 else "旧队伍数据只包含一个阵营，无法恢复比赛"
static func exact_shape(value: Variant, template: Dictionary) -> bool:
	return value is Dictionary and value.size() == template.size() and shape(value,template)
static func unique_indices(value: Variant, count: int) -> bool:
	if not value is Array: return false
	var seen: Dictionary = {}
	for who in value:
		if not player_index(who,count) or seen.has(who): return false
		seen[who] = true
	return true
static func special_state_error(state: Dictionary, game) -> String:
	var count: int = state.players.size()
	var profile: Dictionary = game.Specials.TEST_PROFILE
	var lottery: Dictionary = state.lottery_state
	if not exact_shape(lottery,game.Specials.initial_lottery()): return "乐透数据格式无效"
	if lottery.pot < 0 or lottery.draw_round < 1 or lottery.draw_count < 0: return "乐透数值无效"
	if state.specials_enabled and lottery.draw_round <= state.round_number: return "乐透开奖时点无效"
	for ticket in lottery.tickets:
		if not exact_shape(ticket,{"player":0,"number":1}): return "乐透票据格式无效"
		if not player_index(ticket.player,count) or not game.Specials.numbers().has(ticket.number): return "乐透票据无效"
	if not unique_indices(lottery.last_winners,count): return "乐透获奖者无效"
	if lottery.draw_count == 0:
		if not lottery.last_draw.is_empty() or not lottery.last_winners.is_empty(): return "乐透开奖记录不一致"
	else:
		var draw: Dictionary = lottery.last_draw
		if not exact_shape(draw,{"round":1,"number":1,"pot":0,"payouts":{}}): return "乐透开奖记录格式无效"
		if draw.round < 1 or draw.round > state.round_number or draw.round >= lottery.draw_round or draw.pot < 0 or not game.Specials.numbers().has(draw.number): return "乐透开奖记录无效"
		var total: int = 0
		for who in draw.payouts:
			if not player_index(who,count) or not draw.payouts[who] is int or draw.payouts[who] < 0 or draw.payouts[who] > draw.pot-total: return "乐透派奖无效"
			total += draw.payouts[who]
		if not draw.payouts.is_empty() and total != draw.pot: return "乐透派奖总额无效"
		if draw.payouts.keys() != lottery.last_winners: return "乐透派奖名单不一致"
	var visited: Dictionary = {}
	for road in state.service_visited:
		if not road is int or road < 0 or road >= game.nodes.size() or game.nodes[road].kind not in ["lottery","magic"] or visited.has(road): return "服务经过记录无效"
		visited[road] = true
	var service: Dictionary = state.pending_service
	if state.phase in ["lottery","magic"]:
		if not state.specials_enabled or not exact_shape(service,{"kind":"","road":0,"purchases":0}): return "服务阶段缺少有效记录"
		var road: int = service.road
		if road < 0 or road >= game.nodes.size() or game.nodes[road].kind != state.phase: return "服务类型与地图不一致"
		var p: Dictionary = state.players[state.current]
		if service.kind != state.phase or service.road != road or p.pos != road or not visited.has(road): return "服务与道路或阶段不一致"
		if p.bankrupt or not p.status.is_empty() or p.god.get("id","") == "fierce" or not state.pending_attack.is_empty(): return "服务参与者无效"
		if service.purchases < 0 or service.purchases > int(profile.visit_limit): return "服务购买次数无效"
		if state.phase == "magic" and (service.purchases != 0 or state.steps_left != 0): return "魔法屋落地状态无效"
		if state.phase == "lottery":
			var owned: int = 0
			for ticket in lottery.tickets:
				if ticket.player == state.current: owned += 1
			if owned < service.purchases: return "乐透购买记录不一致"
	elif not service.is_empty(): return "待处理服务与阶段不一致"
	var magic: Dictionary = state.magic_last_result
	if not magic.is_empty():
		if not exact_shape(magic,{"effect":"","condition":"","targets":[]}): return "魔法结果格式无效"
		var effects: Array = []
		for option in game.Specials.MAGIC: effects.append(option.id)
		if not effects.has(magic.effect) or not game.Specials.CONDITIONS.has(magic.condition) or not unique_indices(magic.targets,count): return "魔法结果无效"
	if not state.specials_enabled and (not visited.is_empty() or not magic.is_empty() or lottery != game.Specials.initial_lottery()): return "未启用的服务存在活动状态"
	if state.shop_visit_serial < 0 or state.shop_purchases < 0 or state.shop_purchases > int(game.Buildings.PROFILE.shop_purchase_limit): return "商店访问计数无效"
	var stocked: Dictionary = {}
	var pool: Array = game.Shop.pool(game)
	for card in state.shop_stock:
		if not card is String or not pool.has(card) or stocked.has(card): return "商店库存无效"
		stocked[card] = true
	if state.shop_stock.size() > int(game.Shop.PROFILE.maximum_offers): return "商店库存过多"
	if not state.specials_enabled and not state.shop_stock.is_empty(): return "旧版商店不能包含随机库存"
	if not state.shop_stock.is_empty() and state.shop_visit_serial == 0: return "商店库存缺少访问记录"
	if state.phase == "shop" and state.specials_enabled:
		var original_stock: int = state.shop_stock.size()+state.shop_purchases
		if state.shop_visit_serial < 1 or original_stock < int(game.Shop.PROFILE.minimum_offers) or original_stock > int(game.Shop.PROFILE.maximum_offers): return "商店阶段库存不一致"
		var at_shop: bool = false
		for lot in game.lots.values():
			if lot.kind == "facility" and lot.building_type == "shop" and lot.frontage_nodes.has(str(state.players[state.current].pos)): at_shop = true
		if not at_shop: return "商店阶段位置无效"
	for god_id in state.god_respawn_due:
		if not god_id is String or not game.Gods.CATALOG.has(god_id) or not state.god_respawn_due[god_id] is int or state.god_respawn_due[god_id] < 1: return "神仙冷却状态无效"
	# Turning gods off pauses the clock; validated cooldowns may be retained.
	return ""
static func restore(data: Variant) -> Dictionary:
	if not data is Dictionary or not plain(data): return failure("存档格式无效")
	data = data.duplicate(true)
	if not data.get("version") is int or data.version not in [1,2,3,VERSION]: return failure("存档版本不兼容")
	if not data.get("state") is Dictionary or not data.get("market") is Dictionary or not data.get("metadata") is Dictionary: return failure("存档缺少数据")
	var state: Dictionary = data.state
	if data.version == 1:
		var additions: Dictionary = v1_additions()
		for key in additions:
			if not state.has(key): state[key] = additions[key]
		if state.specials_enabled != false: return failure("旧版本不能启用新增服务地图")
	if not state.get("specials_enabled") is bool: return failure("服务开关格式无效")
	if not state.get("players") is Array or state.players.size() < 2 or state.players.size() > 4: return failure("玩家数量无效")
	var names: Array = []
	for player in state.players:
		if not player is Dictionary or not player.get("name") is String: return failure("玩家格式无效")
		names.append(player.name)
	if data.version < 3:
		var migration_error: String = migrate_legacy_teams(state.players)
		if not migration_error.is_empty(): return failure(migration_error)
	var team_ids: Array = []
	for player in state.players: team_ids.append(player.get("team"))
	if not Game.Teams.valid_assignment(team_ids, state.players.size()): return failure("队伍配置无效")
	if data.version < 4:
		var legacy_map: Dictionary = Game.Maps.load_map(Game.Maps.DEFAULT_MAP_ID)
		if not legacy_map.ok: return failure("旧地图资源不可用")
		var additions: Dictionary = {"map_id":Game.Maps.DEFAULT_MAP_ID,"map_metadata":legacy_map.metadata,"start_road":legacy_map.metadata.start_road,"start_bonus":legacy_map.metadata.start_bonus}
		for key in additions:
			if not state.has(key): state[key] = additions[key].duplicate(true) if additions[key] is Dictionary else additions[key]
		if state.map_id != Game.Maps.DEFAULT_MAP_ID: return failure("旧存档地图标识无效")
	if not state.get("map_id") is String: return failure("地图标识格式无效")
	var game = Game.new()
	if not game.setup(names,1,20,{"specials_enabled":state.specials_enabled,"teams":team_ids,"map_id":state.map_id}): return failure("地图不存在或不可游玩")
	for key in fields(game):
		if EXCLUDED.has(key): continue
		if not state.has(key) or not shape(state[key],game.get(key)): return failure("存档字段无效："+key)
	if state.nodes != game.nodes or state.lots.keys() != game.lots.keys(): return failure("地图版本不兼容")
	if state.map_metadata != game.map_metadata or state.start_road != game.start_road or state.start_bonus != game.start_bonus: return failure("地图配置不一致")
	var count: int = state.players.size()
	if not player_index(state.current,count) or state.phase not in ["roll","move","land","bank","shop","lottery","magic","end","detained","reaction","finished"]: return failure("行动状态无效")
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
		for field in ["id","footprint","frontage_nodes","kind","trigger_events","name","price","rent","street_id","rule_id"]:
			if lot[field] != game.lots[id][field]: return failure("地产地图配置不一致："+field)
		for field in ["exit_road","exit_previous"]:
			if lot.has(field) != game.lots[id].has(field) or lot.get(field) != game.lots[id].get(field): return failure("设施出口配置不一致")
		if lot.kind == "facility" and lot.building_type != game.lots[id].building_type: return failure("固定设施类型与地图不一致")
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
	if not unique_indices(state.winners,count): return failure("获胜者无效")
	if state.phase != "finished" and not state.winners.is_empty(): return failure("未结束比赛不能包含获胜者")
	if state.phase == "reaction":
		var a: Dictionary = state.pending_attack
		if not event_valid(a,count) or not a.get("events") is Array or not a.get("return_phase") is String or not a.get("arrival") is bool: return failure("待处理事件无效")
		if not player_index(a.target,count) or a.return_phase not in ["roll","move","land","bank","shop","end","detained"]: return failure("反应恢复阶段无效")
		for event in a.events:
			if not event is Dictionary or not event_valid(event,count): return failure("后续事件无效")
	elif not state.pending_attack.is_empty(): return failure("事件与阶段不一致")
	var service_error: String = special_state_error(state,game)
	if not service_error.is_empty(): return failure(service_error)
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
	# Reconstruct only this private candidate. Final semantic checks also cannot
	# mutate the caller's live game or the deeply copied input snapshot.
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
	if state.phase == "finished":
		var expected_winners: Array[int] = game.Teams.winner_members(game)
		if data.version < 3:
			# Old team labels only affected traits. After explicit relationship
			# migration, completed legacy results use the new team scoring policy.
			game.winners = expected_winners
		elif state.winners != expected_winners: return failure("队伍胜负记录不一致")
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
