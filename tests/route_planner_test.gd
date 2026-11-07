extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Planner = preload("res://scripts/model/route_planner.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var g = Game.new()
	g.setup(["A", "B"], 11, 30)
	check(g.nodes.size() == 117, "uses the integrated 117 road graph")
	var p: Dictionary = g.players[0]
	p.pos = 0
	p.previous = -1
	var before: int = g.rng.state
	var initial: Array[Dictionary] = Planner.routes(g, "dice")
	var exits: Array = []
	for route in initial:
		check(Planner.valid_path(g, "dice", route.path, route.steps), "enumerated route validates")
		if route.steps == 1: exits.append(route.destination)
	check(exits.size() == g.nodes[0].neighbors.size(), "unknown initial heading preserves all exits")
	check(g.rng.state == before and initial == Planner.routes(g, "dice"), "queries are deterministic and do not consume RNG")
	p.previous = g.nodes[0].neighbors[0]
	for route in Planner.routes(g, "dice"):
		check(route.path[0] != p.previous, "forward routes exclude arrival edge")
	for route in Planner.routes(g, "super_dice"):
		check(Planner.valid_path(g, "super_dice", route.path, route.steps), "signed super route validates")
		if route.steps < 0: check(route.path[0] == p.previous, "negative super starts by reversing")
	check(not Planner.valid_path(g, "dice", [p.previous], 1), "reject unauthorized initial reversal")
	check(not Planner.valid_path(g, "dice", [9999], 1), "reject nonexistent destination")
	check(not Planner.valid_path(g, "dice", [1.0], 1), "reject noninteger path")
	check(not Planner.valid_path(g, "super_dice", [], 0), "reject zero distance")
	g.dice_count = 3
	var long_routes: Array[Dictionary] = Planner.routes(g, "dice")
	var found_max := false
	for route in long_routes:
		check(route.steps >= 3 and route.steps <= 18, "car sum bounds")
		if route.steps == 18: found_max = true
	check(found_max, "enumeration includes maximum car sum")
	for route in Planner.routes(g, "robot"):
		check(route.path.size() == 10 and Planner.valid_path(g, "robot", route.path, 10), "robot supplies ten valid edges")
	# Diamond keeps two distinct routes to the same endpoint; deadends permit return.
	var fixture: Dictionary = {"players": [{"pos": 0, "previous": -1}], "current": 0, "dice_count": 1,
		"nodes": [{"neighbors": [1, 2]}, {"neighbors": [0, 3]}, {"neighbors": [0, 3]}, {"neighbors": [1, 2, 4]}, {"neighbors": [3]}]}
	var same_destination := 0
	for route in Planner.routes(fixture, "dice"):
		if route.destination == 3 and route.steps == 2: same_destination += 1
	check(same_destination == 2, "retain both paths to the same endpoint")
	check(Planner.valid_path(fixture, "dice", [1, 3, 4, 3], 4), "deadend reversal is legal")
	check(not Planner.valid_path(fixture, "dice", [1, 0], 2), "reject immediate return at nondeadend")
	fixture.players[0].next_direction = 2
	for route in Planner.routes(fixture, "dice"):
		check(route.path[0] == 2, "explicit next direction is respected")
	check(not Planner.valid_path(fixture, "dice", [1], 1), "validation also respects next direction")
	check(Planner.routes(fixture, "unknown").is_empty(), "unknown card has no routes")
	print("route_planner_test: %d failures" % failures)
	quit(1 if failures else 0)
