extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _init() -> void:
	var g = Game.new()
	g.setup(["A", "B"], 11, 20, {"talents_enabled":true,"characters":["original","ludwig"]})
	g.players[1].cards.clear()
	g.gm_god(1, "misfortune")
	check(g.players[1].cards.is_empty(), "empty hand is not an involuntary loss")
	# Ten missiles make five cards per person, then each hand synthesizes once.
	g.players[0].cards = ["magic", "missile", "missile", "missile", "missile", "missile"]
	g.players[1].cards = ["missile", "missile", "missile", "missile", "missile"]
	check(g.use_card("magic", 1), "magic succeeds")
	check(g.players[0].cards == ["rapid_missile"] and g.players[1].cards == ["rapid_missile"], "synthesis does not change allocation quotas")
	var nearby: Array = []
	for lot in g.lots.values():
		if lot.kind == "small":
			lot.owner = 0
			lot.building_type = "house"
			lot.level = 1
	g.players[0].pos = int(g.lots.small_1_6.frontage_nodes[0])
	nearby = g.card_targets("swap_house")
	var other: String = ""
	for id in nearby:
		if id != "small_1_6": other = id; break
	g.players[0].cards = ["swap_house"]
	g.lots.small_1_6.owner = 1
	g.lots[other].level = 3
	check(not g.use_card("swap_house", [other, "small_1_6"]), "swap cannot start remotely or target enemy second lot")
	check(g.players[0].cards.has("swap_house"), "invalid swap retains card")
	check(g.use_card("swap_house", ["small_1_6", other]), "valid current frontage swap")
	check(g.lots.small_1_6.owner == 1 and g.lots.small_1_6.level == 3 and g.lots[other].level == 1, "swap exchanges buildings but preserves land ownership")
	print("ROUND6_REVIEW_TEST failures=", failures)
	quit(1 if failures else 0)
