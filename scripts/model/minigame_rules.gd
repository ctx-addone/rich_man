class_name RichMinigameRules
extends RefCounted

const Coins = preload("res://scripts/model/catch_coins_rules.gd")
const Dolls = preload("res://scripts/model/toss_dolls_rules.gd")
const Bomb = preload("res://scripts/model/disarm_bomb_rules.gd")
const Balloons = preload("res://scripts/model/shoot_balloons_rules.gd")
# Compatibility aliases for the unchanged catch_coins v1 rules and callers.
const GAME_ID = "catch_coins"
const TEST_PROFILE = Coins.TEST_PROFILE
# These games are observed on Knight Manor. Equal weighting is TEST-R15.
const TEST_POOL = ["catch_coins", "toss_dolls", "disarm_bomb", "shoot_balloons"]
const TITLES = {"catch_coins":"接金币", "toss_dolls":"投娃娃", "disarm_bomb":"拆炸弹", "shoot_balloons":"打气球"}

static func id(g) -> String:
	return str(g.pending_service.get("game",{}).get("id","")) if g.phase == "minigame" else ""

static func _model(game_id:String):
	if game_id == "catch_coins": return Coins
	if game_id == "toss_dolls": return Dolls
	if game_id == "disarm_bomb": return Bomb
	if game_id == "shoot_balloons": return Balloons
	return null

static func profile(g) -> Dictionary:
	var model = _model(id(g))
	return model.TEST_PROFILE if model != null else TEST_PROFILE

static func title(g) -> String:
	return TITLES.get(id(g),"小游戏")

static func instructions(g) -> String:
	if id(g) == "toss_dolls": return Dolls.INSTRUCTIONS
	if id(g) == "disarm_bomb": return Bomb.INSTRUCTIONS
	if id(g) == "shoot_balloons": return Balloons.INSTRUCTIONS
	return "点击上下左右相邻的发光格移动。金币落地后会短暂停留，移动过去拾取；避开空中和地面的红色炸弹。"

static func parameters(g) -> String:
	if id(g) == "toss_dolls": return Dolls.PARAMETERS
	if id(g) == "disarm_bomb": return Bomb.PARAMETERS
	if id(g) == "shoot_balloons": return Balloons.PARAMETERS
	return "金币+100，金元宝+500；本版暂定12秒，炸弹扣300分，得分最低为0。"

static func outcome(g) -> String:
	if id(g) == "" or g.pending_service.game.history.is_empty(): return ""
	var reason:String = g.pending_service.game.history[0].get("reason","time_up")
	if id(g) == "shoot_balloons" and reason == "bomb": return "击中了炸弹气球，本轮结束；此前分数保留（测试规则）"
	return {"time_up":"时间结束", "queue_empty":"本轮物品已全部投完", "bomb_blue":"炸弹误入蓝篮：蓝篮清空，保留粉篮得分", "bomb_pink":"炸弹误入粉篮：粉篮清空，保留蓝篮得分", "held_bomb":"手中炸弹未及时丢弃，本轮结束", "bomb":"打开了炸弹，本轮结束，保留已获得分数"}.get(reason,reason)

static func can_enter(g) -> bool:
	if not g.specials_enabled or g.phase != "land" or not g.Specials.eligible(g,g.current) or not g.pending_attack.is_empty() or not g.pending_service.is_empty(): return false
	if g.steps_left != 0 or g.landing_pending or g.landing_shop or not g.landing_queue.is_empty() or not g.landing_hotel.is_empty(): return false
	var road:int = g.players[g.current].pos
	return road >= 0 and road < g.nodes.size() and g.nodes[road].kind == "minigame" and not g.service_visited.has(road)

static func enter(g, requested_id:String="") -> bool:
	if not can_enter(g) or (requested_id != "" and not TEST_POOL.has(requested_id)): return false
	var selected:String = requested_id
	if selected == "": selected = TEST_POOL[g.rng.randi_range(0,TEST_POOL.size()-1)]
	return _model(selected).enter(g)

# Explicit GM setup only, before the first participant starts. Ordinary UI has
# no reroll. Changing type is recorded by the GM UI as a test intervention.
static func gm_choose_ready(g, selected:String) -> bool:
	if not TEST_POOL.has(selected) or id(g) == "" or g.pending_service.game.status != "ready" or g.pending_service.game.cursor != 0: return false
	if id(g) == selected: return true
	var road:int = g.pending_service.road
	g.pending_service.clear()
	g.service_visited.erase(road)
	g.phase = "land"
	return enter(g,selected)

static func start(g) -> bool:
	var model = _model(id(g))
	return model.start(g) if model != null else false
static func tick(g) -> bool:
	var model = _model(id(g))
	return model.tick(g) if model != null else false
static func ai_step(g) -> bool:
	var model = _model(id(g))
	return model.ai_step(g) if model != null else false
static func next_player(g) -> bool:
	var model = _model(id(g))
	return model.next_player(g) if model != null else false
static func settle_others(g) -> bool:
	var model = _model(id(g))
	return model.settle_others(g) if model != null else false
static func close(g) -> bool:
	var model = _model(id(g))
	return model.close(g) if model != null else false

static func select_cell(g, cell:int) -> bool:
	return Coins.select_cell(g,cell) if id(g) == "catch_coins" else false
static func legal_cells(g) -> Array[int]:
	if id(g) == "catch_coins": return Coins.legal_cells(g)
	var empty:Array[int]=[]
	return empty
static func ai_cell(g) -> int:
	return Coins.ai_cell(g) if id(g) == "catch_coins" else -1
static func toss(g, bin_id:int) -> bool:
	return Dolls.toss(g,bin_id) if id(g) == "toss_dolls" else false
static func ai_bin(g) -> int:
	return Dolls.ai_bin(g) if id(g) == "toss_dolls" else -1
static func choose(g, switch_id:int) -> bool:
	return Bomb.choose(g,switch_id) if id(g) == "disarm_bomb" else false
static func ai_switch(g) -> int:
	return Bomb.ai_switch(g) if id(g) == "disarm_bomb" else -1
static func shoot(g, lane:int) -> bool:
	return Balloons.shoot(g,lane) if id(g) == "shoot_balloons" else false
static func ai_lane(g) -> int:
	return Balloons.ai_lane(g) if id(g) == "shoot_balloons" else -1

static func state_error(state:Dictionary, g) -> String:
	var service = state.get("pending_service")
	if not service is Dictionary or not service.get("game") is Dictionary: return "小游戏服务结构无效"
	var game_id = service.game.get("id")
	if not game_id is String: return "小游戏类型无效"
	var model = _model(game_id)
	if model == null: return "未知小游戏类型"
	return model.state_error(state,g)
