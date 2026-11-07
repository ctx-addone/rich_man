extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/model/ai_controller.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func fresh():
	var g = Game.new()
	g.setup(["A", "B", "C", "D"], 13)
	return g
func _init() -> void:
	var completed := 0
	var used_cards := false
	var acquired := false
	var banked := false
	for enabled in [false, true]:
		for seed_value in [11, 19, 37, 53]:
			var g = Game.new()
			g.setup(["A", "B", "C", "D"], seed_value, 50, {"gods_enabled":enabled,"talents_enabled":enabled,"characters":["eleven","nintaro","shalong","sarah"]})
			var actions := 0
			while g.phase != "finished" and actions < 20000:
				actions += 1
				if not AI.step(g): check(false, "AI stalled: %s seed %d" % [g.phase, seed_value]); break
				used_cards = used_cards or g.card_used
				for p in g.players:
					banked = banked or p.deposit > 0
					check(p.cash >= 0 and p.deposit >= 0 and p.cards.size() <= 8, "legal AI balances and hand")
				for lot in g.lots.values(): acquired = acquired or lot.owner >= 0
			check(g.phase == "finished" and not g.winners.is_empty(), "50-round AI match completes")
			if g.phase == "finished": completed += 1
	check(used_cards and acquired and banked, "natural matches exercise cards, property purchases, bank")
	var g = fresh()
	g.players[0].cards = ["free"]
	g.Money.begin(g, 0, 1000, 1, "rent")
	g.Combat.advance(g)
	check(AI.step(g) and g.players[0].cash == 10000 and g.players[0].cards.is_empty(), "AI chooses free before money loss")
	g = fresh()
	g.players[0].cards = ["immune"]
	g.Combat.begin(g, "missile", 1, [0], "hospital", 1)
	g.Combat.advance(g)
	check(AI.step(g) and g.players[0].status.is_empty(), "AI chooses hospital immunity")
	g = fresh()
	g.phase = "shop"
	g.players[0].cards.clear()
	check(AI.step(g) and g.players[0].cards.has("free") and g.players[0].cash < 10000, "AI buys useful shop card")
	g = fresh()
	g.players[0].cards.clear()
	var lot: Dictionary = g.lots.lot_1_1
	lot.owner = 0; lot.building_type = "lab"; lot.level = 1
	check(AI.step(g) and not lot.research.is_empty(), "AI starts eligible research")
	lot.research.remaining = 0
	check(AI.step(g) and g.players[0].cards.has("portal"), "AI collects completed research")
	g = fresh()
	g.players[0].cards = ["free", "stay", "swap_house"]
	check(AI.step(g) and g.phase == "move", "unsupported or unavailable cards never block dice")
	var twin = fresh()
	g = fresh()
	for ignored in range(160):
		if g.phase == "finished": break
		check(AI.step(g) == AI.step(twin), "same visible state chooses the same command")
		check(g.players == twin.players and g.phase == twin.phase and g.rng.state == twin.rng.state, "deterministic policy preserves paired game trajectories")
	print("AI_TEST failures=", failures, " completed_matches=", completed)
	quit(1 if failures else 0)
