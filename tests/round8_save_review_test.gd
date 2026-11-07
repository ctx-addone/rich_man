extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Save = preload("res://scripts/model/save_game.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _init() -> void:
	var g = Game.new()
	g.setup(["A", "B", "C", "D"], 19)
	var good: Dictionary = Save.snapshot(g)
	var original: Dictionary = good.duplicate(true)
	for property in ["next_direction", "glory_until", "choose_junction"]:
		var invalid: Dictionary = good.duplicate(true)
		invalid.state.players[0][property] = {"invalid":true}
		check(not Save.restore(invalid).ok, "reject malformed optional player field: " + property)
	var invalid: Dictionary = good.duplicate(true)
	invalid.state.phase = "detained"
	check(not Save.restore(invalid).ok, "detained phase requires detention status")
	invalid = good.duplicate(true)
	invalid.state.players[0].god = {"id":"angel", "remaining":-9}
	check(not Save.restore(invalid).ok, "reject negative possession duration")
	invalid = good.duplicate(true)
	invalid.state.road_objects[1] = {"kind":"free", "owner":0}
	check(not Save.restore(invalid).ok, "only deployable road objects may occupy roads")
	check(Save.snapshot(g) == original, "invalid imports never mutate original game")
	var first: Dictionary = Save.restore(good)
	var second: Dictionary = Save.restore(good)
	first.game.players[0].cash = 7
	first.game.stock_market.quotes.test_grain.price = 3
	check(second.game.players[0].cash == 10000 and good.state.players[0].cash == 10000, "restores do not share player state or mutate source snapshot")
	check(second.game.stock_market.quotes.test_grain.price == 40 and good.market.quotes.test_grain.price == 40, "restores do not share market dictionaries")
	# Legal pending fee with hotel continuation restores independently.
	var hotel: Dictionary = g.lots.lot_1_1
	hotel.owner = 1; hotel.building_type = "hotel"; hotel.level = 5
	g.players[0].cards = ["free"]
	g.gm_teleport(0, int(hotel.frontage_nodes[0]))
	var restored: Dictionary = Save.restore(Save.snapshot(g))
	check(restored.ok, "legal pending hotel fee restores")
	if restored.ok:
		g.resolve_reaction("free")
		restored.game.resolve_reaction("free")
		check(Save.snapshot(g) == Save.snapshot(restored.game), "hotel fee defense and stay replay exactly")
	print("ROUND8_SAVE_REVIEW failures=", failures)
	quit(1 if failures else 0)
