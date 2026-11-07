class_name RichGame
extends RefCounted

const CARD_NAMES = {"dice": "遥控骰子", "rent_free": "免租卡", "traffic": "信号切换", "cash": "奖金卡"}
const CARD_DESCRIPTIONS = {"dice": "本回合下一次掷骰固定为6。", "rent_free": "免除下一次应付租金，持续到触发。", "traffic": "立即反转全城红绿灯方向。", "cash": "立即获得500现金。"}
var nodes: Array[Dictionary] = []
var players: Array[Dictionary] = []
var current: int = 0
var round_number: int = 1
var round_limit: int = 20
var phase: String = "roll"
var steps_left: int = 0
var last_roll: int = 0
var logs: Array[String] = []
var winners: Array[int] = []
var traffic_phase: int = 0
var rng := RandomNumberGenerator.new()
var card_used: bool = false
var controlled_dice: int = 0

func setup(names: Array, seed_value: int = 0, rounds: int = 20) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	players.clear()
	logs.clear()
	winners.clear()
	current = 0
	round_number = 1
	round_limit = maxi(1, rounds)
	phase = "roll"
	steps_left = 0
	last_roll = 0
	traffic_phase = 0
	card_used = false
	controlled_dice = 0
	_build_map()
	for i in range(names.size()):
		players.append({"name": str(names[i]), "cash": 10000, "pos": 0, "previous": -1, "bankrupt": false, "cards": ["dice", "rent_free", "traffic"], "rent_shield": false})
	_log("开局：每人10000现金，共%d轮；进入起点奖励1000。" % round_limit)

func _build_map() -> void:
	nodes.clear()
	for x in range(13): _add_node(Vector2(x, 0))
	for y in range(1, 9): _add_node(Vector2(12, y))
	for x in range(11, -1, -1): _add_node(Vector2(x, 8))
	for y in range(7, 0, -1): _add_node(Vector2(0, y))
	for x in range(1, 12): _add_node(Vector2(x, 4))
	for y in range(1, 8):
		if y != 4: _add_node(Vector2(6, y))
	for n in nodes:
		for other in nodes:
			var delta: Vector2 = n.pos - other.pos
			if absf(delta.x) + absf(delta.y) == 1.0:
				n.neighbors.append(other.id)
		var p: Vector2 = n.pos
		if n.id == 0:
			n.kind = "start"
			n.name = "市民广场"
		elif p in [Vector2(3, 0), Vector2(12, 6), Vector2(0, 6)]:
			n.kind = "metro"
			n.name = "地铁站 %s" % ["北", "东", "西"][[Vector2(3, 0), Vector2(12, 6), Vector2(0, 6)].find(p)]
		elif p in [Vector2(6, 0), Vector2(6, 4)]:
			n.kind = "signal"
			n.signal = true
			n.name = "信号路口"
		elif n.id % 9 == 0:
			n.kind = "event"
			n.name = "城市事件"
		elif n.neighbors.size() > 2:
			n.kind = "junction"
			n.name = "分岔路口"
		else:
			n.name = "街区 %02d" % n.id

func _add_node(pos: Vector2) -> void:
	var id: int = nodes.size()
	nodes.append({"id": id, "pos": pos, "kind": "property", "name": "", "price": 1000 + (id % 3) * 200, "rent": 180 + (id % 3) * 40, "neighbors": [], "owner": -1, "level": 0, "signal": false})

func signal_state(node_id: int) -> String:
	if node_id < 0 or node_id >= nodes.size() or not nodes[node_id].signal: return "无信号灯"
	return "东西通行 / 南北红灯" if traffic_phase == 0 else "南北通行 / 东西红灯"

func available_moves() -> Array[int]:
	var result: Array[int] = []
	if players.is_empty() or phase != "move": return result
	var p: Dictionary = players[current]
	var n: Dictionary = nodes[p.pos]
	for target in n.neighbors:
		if target == p.previous and n.neighbors.size() > 1: continue
		if n.signal:
			var horizontal: bool = nodes[target].pos.y == n.pos.y
			if horizontal != (traffic_phase == 0): continue
		result.append(target)
	return result

func roll_dice(forced: int = 0) -> bool:
	if phase != "roll" or players.is_empty(): return false
	last_roll = clampi(forced, 1, 6) if forced > 0 else (controlled_dice if controlled_dice > 0 else rng.randi_range(1, 6))
	controlled_dice = 0
	steps_left = last_roll
	phase = "move"
	_log("%s 掷出 %d。" % [players[current].name, last_roll])
	_check_movement()
	return true

func move_to(node_id: int) -> bool:
	if not available_moves().has(node_id): return false
	var p: Dictionary = players[current]
	p.previous = p.pos
	p.pos = node_id
	steps_left -= 1
	if node_id == 0:
		p.cash += 1000
		_log("%s 经过起点，获得1000。" % p.name)
	_check_movement()
	return true

func _check_movement() -> void:
	if steps_left <= 0:
		_land()
	elif available_moves().is_empty():
		_log("红灯阻挡，剩余%d步作废，停在路口。" % steps_left)
		steps_left = 0
		_land()

func _land() -> void:
	phase = "land"
	var p: Dictionary = players[current]
	var n: Dictionary = nodes[p.pos]
	_log("%s 停在 %s。" % [p.name, n.name])
	match n.kind:
		"property":
			if n.owner >= 0 and n.owner != current:
				if p.rent_shield:
					p.rent_shield = false
					_log("免租卡生效，本次租金免除。")
				else:
					var cost: int = n.rent * n.level * n.level
					_log("应向 %s 支付租金%d。" % [players[n.owner].name, cost])
					_pay(current, cost, n.owner)
		"metro": phase = "metro"
		"event":
			match rng.randi_range(0, 2):
				0:
					p.cash += 500
					_log("城市奖励：获得500。")
				1:
					_log("城市维护费：支付400。")
					_pay(current, 400)
				2:
					var card: String = CARD_NAMES.keys()[rng.randi_range(0, 3)]
					p.cards.append(card)
					_log("获得卡牌：%s。" % CARD_NAMES[card])

func buy_property() -> bool:
	if phase != "land": return false
	var n: Dictionary = nodes[players[current].pos]
	if n.kind != "property" or n.owner != -1 or players[current].cash < n.price or players[current].bankrupt: return false
	players[current].cash -= n.price
	n.owner = current
	n.level = 1
	phase = "end"
	_log("%s 购买%s，支付%d。" % [players[current].name, n.name, n.price])
	return true

func upgrade_property() -> bool:
	if phase != "land": return false
	var n: Dictionary = nodes[players[current].pos]
	if n.kind != "property" or n.owner != current or n.level >= 3 or players[current].cash < 600: return false
	players[current].cash -= 600
	n.level += 1
	phase = "end"
	_log("升级%s至%d级，支付600。" % [n.name, n.level])
	return true

func take_metro(destination: int) -> bool:
	if phase != "metro" or destination < 0 or destination >= nodes.size(): return false
	var p: Dictionary = players[current]
	if nodes[destination].kind != "metro" or destination == p.pos or p.cash < 200: return false
	p.cash -= 200
	p.pos = destination
	p.previous = -1
	phase = "end"
	_log("支付200车费，抵达%s，结束移动。" % nodes[destination].name)
	return true

func skip_metro() -> bool:
	if phase != "metro": return false
	phase = "end"
	return true

func use_card(card_id: String, _target: int = -1) -> bool:
	if phase != "roll" or card_used or not CARD_NAMES.has(card_id) or not players[current].cards.has(card_id): return false
	if card_id == "rent_free" and players[current].rent_shield: return false
	players[current].cards.erase(card_id)
	card_used = true
	match card_id:
		"dice": controlled_dice = 6
		"rent_free": players[current].rent_shield = true
		"traffic": traffic_phase = 1 - traffic_phase
		"cash": players[current].cash += 500
	_log("%s 使用%s。" % [players[current].name, CARD_NAMES[card_id]])
	return true

func end_turn() -> bool:
	if phase not in ["land", "metro", "end"]: return false
	_check_winner()
	if phase == "finished": return true
	var next: int = current
	for ignored in range(players.size()):
		next = (next + 1) % players.size()
		if next == 0:
			round_number += 1
			traffic_phase = 1 - traffic_phase
			if round_number > round_limit:
				finish_game()
				return true
		if not players[next].bankrupt: break
	current = next
	phase = "roll"
	steps_left = 0
	card_used = false
	controlled_dice = 0
	return true

func _pay(player_id: int, amount: int, receiver: int = -1) -> void:
	var p: Dictionary = players[player_id]
	for n in nodes:
		if p.cash >= amount: break
		if n.owner == player_id:
			var sale: int = (n.price + 600 * (n.level - 1)) / 2
			p.cash += sale
			n.owner = -1
			n.level = 0
			_log("资金不足，%s变现%d。" % [n.name, sale])
	var paid: int = mini(p.cash, amount)
	p.cash -= paid
	if receiver >= 0: players[receiver].cash += paid
	if paid < amount:
		p.bankrupt = true
		p.cards.clear()
		_log("%s 无力偿付，破产退出。" % p.name)
		_check_winner()

func net_worth(player_id: int) -> int:
	var total: int = players[player_id].cash
	for n in nodes:
		if n.owner == player_id: total += n.price + 600 * (n.level - 1)
	return total

func _check_winner() -> void:
	var alive: int = 0
	for p in players:
		if not p.bankrupt: alive += 1
	if alive <= 1: finish_game()

func finish_game() -> void:
	phase = "finished"
	winners.clear()
	var highest: int = -1
	for i in range(players.size()):
		if players[i].bankrupt: continue
		var worth: int = net_worth(i)
		if worth > highest:
			highest = worth
			winners.clear()
		if worth == highest: winners.append(i)
	_log("比赛结束，按未破产角色净资产结算。")

func gm_cash(player_id: int, delta: int) -> bool:
	if phase == "finished" or player_id < 0 or player_id >= players.size() or players[player_id].bankrupt: return false
	players[player_id].cash = maxi(0, players[player_id].cash + delta)
	_log("GM：%s现金调整%d。" % [players[player_id].name, delta])
	return true

func gm_teleport(player_id: int, node_id: int) -> bool:
	if phase == "finished" or player_id < 0 or player_id >= players.size() or node_id < 0 or node_id >= nodes.size() or players[player_id].bankrupt: return false
	players[player_id].pos = node_id
	players[player_id].previous = -1
	_log("GM：%s传送至%s。" % [players[player_id].name, nodes[node_id].name])
	if player_id == current:
		steps_left = 0
		_land()
	return true

func gm_give_card(player_id: int, card_id: String) -> bool:
	if phase == "finished" or player_id < 0 or player_id >= players.size() or not CARD_NAMES.has(card_id) or players[player_id].bankrupt: return false
	players[player_id].cards.append(card_id)
	_log("GM：向%s发放%s。" % [players[player_id].name, CARD_NAMES[card_id]])
	return true

func _log(message: String) -> void:
	logs.append(message)
	if logs.size() > 150: logs.pop_front()
