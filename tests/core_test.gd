extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	var g = Game.new()
	g.setup(["甲", "乙", "丙", "丁"], 42)
	check(g.nodes.size() == 57, "57 nodes")
	var visited: Array[int] = [0]
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var id: int = pending.pop_front()
		for target in g.nodes[id].neighbors:
			check(g.nodes[target].neighbors.has(id), "symmetric graph")
			if not visited.has(target):
				visited.append(target)
				pending.append(target)
	check(visited.size() == 57, "all nodes reachable")
	check(not g.end_turn(), "cannot skip before rolling")
	check(g.use_card("dice"), "use card")
	check(not g.use_card("traffic"), "one card per turn")
	g.roll_dice()
	check(g.last_roll == 6, "controlled die")
	check(not g.move_to(20), "reject illegal route")
	g.gm_teleport(0, 1)
	check(g.buy_property(), "buy unowned")
	check(g.players[0].cash == 8800, "purchase cash")
	check(g.net_worth(0) == 10000, "purchase preserves net assets")
	check(not g.upgrade_property(), "cannot buy and upgrade on same landing")
	g.gm_teleport(0, 1)
	check(g.upgrade_property(), "upgrade owned")
	check(g.net_worth(0) == 10000, "upgrade preserves net assets")
	g.end_turn()
	g.gm_teleport(1, 1)
	check(g.players[1].cash == 9120, "level2 rent 880")
	check(g.players[0].cash == 9080, "rent transferred")
	g.end_turn()
	check(g.use_card("rent_free"), "rent protection")
	g.gm_teleport(2, 1)
	check(g.players[2].cash == 10000 and not g.players[2].rent_shield, "shield consumed")
	g.end_turn()
	g.gm_teleport(3, 3)
	check(g.phase == "metro", "station landing")
	check(g.take_metro(18), "metro travel")
	check(g.players[3].cash == 9800 and g.players[3].pos == 18, "metro charge and position")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.players[0].pos = 6
	g.players[0].previous = 5
	g.traffic_phase = 0
	g.roll_dice(2)
	check(g.available_moves() == [7], "EW light filter")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.players[0].pos = 6
	g.players[0].previous = 51
	g.traffic_phase = 1
	g.roll_dice(2)
	check(g.phase == "land" and g.steps_left == 0, "red light safely stops")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.nodes[1].owner = 1
	g.nodes[1].level = 3
	g.players[0].cash = 10
	g.gm_teleport(0, 1)
	check(g.players[0].bankrupt and g.players[1].cash == 10010, "bankrupt partial debt")
	g.end_turn()
	check(g.current == 1, "bankruptcy advances")
	# Liquidation uses half original investment, transfers debt, and releases ownership.
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.nodes[2].owner = 0
	g.nodes[2].level = 3
	g.nodes[1].owner = 1
	g.nodes[1].level = 2
	g.players[0].cash = 100
	g.gm_teleport(0, 1)
	check(g.players[0].cash == 520, "1400+1200 investment liquidates at 1300, pays 880")
	check(g.nodes[2].owner == -1 and g.nodes[2].level == 0, "liquidation frees whole asset")
	check(not g.players[0].bankrupt and g.players[1].cash == 10880, "liquidation avoids bankruptcy")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.nodes[1].owner = 1
	g.nodes[1].level = 1
	g.players[0].cash = 220
	g.gm_teleport(0, 1)
	check(g.players[0].cash == 0 and not g.players[0].bankrupt, "exact payment leaves solvent zero cash")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.nodes[1].owner = 0
	g.nodes[1].level = 3
	g.gm_teleport(0, 1)
	check(not g.upgrade_property(), "level three cap")
	check(g.phase == "land" and g.end_turn(), "capped upgrade still permits end")
	check(not g.buy_property() and not g.take_metro(3), "wrong phases reject actions")
	g.finish_game()
	check(g.winners == [0], "property contributes to winner")
	check(not g.roll_dice() and not g.end_turn() and not g.gm_cash(0, 100), "finished game immutable through commands")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.finish_game()
	check(g.winners == [0, 1, 2, 3], "equal assets tie")
	g.setup(["甲", "乙", "丙", "丁"], 42, 1)
	g.players[0].bankrupt = true
	g.current = 3
	g.phase = "land"
	g.end_turn()
	check(g.phase == "finished" and g.round_number == 2, "round count wraps across bankrupt seat zero")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	for i in [0, 1, 2]: g.players[i].bankrupt = true
	g.current = 3
	g.phase = "land"
	g.end_turn()
	check(g.phase == "finished" and g.winners == [3], "last survivor ends early")
	g.setup(["甲", "乙", "丙", "丁"], 42)
	g.players[0].pos = 1
	g.players[0].previous = 2
	g.roll_dice(1)
	g.move_to(0)
	check(g.players[0].cash == 11000, "normal start entry rewards")
	g.gm_teleport(0, 0)
	check(g.players[0].cash == 11000, "GM start entry does not reward")
	# Full games exercise real rolls and route selection without any GM commands.
	for seed_value in range(1, 51):
		g.setup(["甲", "乙", "丙", "丁"], seed_value)
		var actions: int = 0
		while g.phase != "finished" and actions < 3000:
			actions += 1
			match g.phase:
				"roll": g.roll_dice()
				"move":
					var options: Array[int] = g.available_moves()
					check(not options.is_empty(), "no stuck move")
					if options.is_empty(): break
					g.move_to(options[g.rng.randi_range(0, options.size()-1)])
				"land":
					if not g.buy_property(): g.upgrade_property()
					g.end_turn()
				"metro", "end": g.end_turn()
			for p in g.players: check(p.cash >= 0, "nonnegative cash")
		check(g.phase == "finished", "seed %d completes" % seed_value)
		check(not g.winners.is_empty(), "winner exists")
		check(g.round_number <= 21, "round limit honored")
	print("Core tests: %s" % ("PASS (50 complete games)" if failures == 0 else "FAIL %d" % failures))
	quit(0 if failures == 0 else 1)
