extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const DebugTools = preload("res://scripts/model/debug_tools.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func fresh():
	var g = Game.new()
	g.setup(["A", "B", "C"], 17, 20)
	for p in g.players: p.cards.clear()
	return g
func _init() -> void:
	var g = fresh()
	g.players[0].cards = ["steal", "dice", "dice", "dice", "dice", "dice", "dice", "dice"]
	g.players[1].cards = ["free"]
	check(g.use_card("steal", 1), "full hand can spend steal before receiving replacement")
	check(g.players[0].cards.size() == 8 and g.players[0].cards.has("free") and g.players[1].cards.is_empty(), "full-hand steal preserves capacity and transfers once")
	g = fresh()
	g.players[0].cards = ["free", "free"]
	# Explicitly exercise one road with two stop events, independent of the fixture map layout.
	var ids: Array = []
	for lot in g.lots.values():
		if lot.kind == "small" and ids.size() < 2:
			lot.owner = 1
			lot.building_type = "house"
			lot.level = 5
			ids.append(lot.id)
	g.phase = "land"
	g.landing_pending = true
	g.landing_queue = ids
	g._continue_land()
	check(g.phase == "reaction", "first frontage debt waits")
	check(g.resolve_reaction("free"), "first frontage waived")
	check(g.phase == "reaction" and g.landing_pending, "second frontage has separate defense window")
	check(g.resolve_reaction("free"), "second frontage waived")
	check(g.phase == "land" and not g.landing_pending and g.players[0].cash == 10000 and g.players[1].cash == 10000, "two frontage fees resume without duplicate payment")
	g = fresh()
	g.players[0].cards = ["free", "immune"]
	g.Money.begin(g, 0, 1000, 1, "rent")
	g.Combat.begin(g, "missile", 1, [0], "hospital", 2)
	g.Combat.advance(g)
	check(g.reaction_options() == ["free"], "mixed queue money event only offers financial defense")
	var before_lot: Dictionary = g.lots.small_1_6.duplicate(true)
	check(not DebugTools.configure_lot(g, "small_1_6", 1, "house", 5), "debug lot configuration rejected during reaction")
	check(g.lots.small_1_6 == before_lot, "rejected debug action does not partially mutate lot")
	check(g.resolve_reaction("free"), "mixed queue money defense resolves")
	check(g.phase == "reaction" and g.pending_attack.kind == "hospital" and g.reaction_options() == ["immune"], "next hospital event retains independent defense")
	check(g.resolve_reaction("immune"), "mixed queue hospital defense resolves")
	check(g.phase == "roll" and g.pending_attack.is_empty() and g.players[0].status.is_empty() and g.players[0].cash == 10000, "mixed defenses finish without payment hospitalization or stale queue")
	g = fresh()
	g.players[0].cards = ["transfer"]
	var hotel: Dictionary = {}
	for lot in g.lots.values():
		if lot.kind == "large": hotel = lot; break
	hotel.owner = 1
	hotel.building_type = "hotel"
	hotel.level = 5
	g.gm_teleport(0, int(hotel.frontage_nodes[0]))
	check(g.phase == "reaction", "hotel transfer starts before payment and lodging")
	var hotel_amount: int = g.pending_attack.amount
	check(g.resolve_reaction("transfer", 2), "hotel debt transferred")
	check(g.players[0].cash == 10000 and g.players[2].cash == 10000 - hotel_amount and g.players[1].cash == 10000 + hotel_amount, "hotel receiver preserved while transferee pays once")
	check(g.players[0].status.get("kind", "") == "vacation" and g.players[2].status.is_empty(), "only original hotel visitor is lodged after transfer")
	check(g.phase == "end" and not g.landing_pending and g.pending_attack.is_empty(), "hotel transfer completes all pending continuations")
	print("ROUND7_REVIEW_TEST failures=", failures)
	quit(1 if failures else 0)
