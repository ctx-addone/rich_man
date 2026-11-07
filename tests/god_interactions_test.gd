extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _init() -> void:
	var g = Game.new()
	g.setup(["A", "B", "C"], 17, 20, {"talents_enabled":true,"characters":["nintaro","original","sarah"]})
	g.players[0].cards = ["god_bless"]
	g.gm_god(1,"angel")
	g.players[1].god.remaining = 1
	g.gm_bomb(0,30)
	check(g.card_targets("god_bless").has("player:1"), "attached god offered without any road gods")
	check(g.Gods.bless_target_name(g,"player:1").contains("天使"), "target label names god and host")
	check(g.use_card("god_bless","player:1"), "attached god invited")
	check(g.players[1].god.is_empty(), "old host loses god")
	check(g.players[0].god.id == "angel" and g.players[0].god.remaining == 10, "receiving character recalculates duration")
	check(g.players[0].bomb.is_empty() and g.players[0].cards == ["robot"], "new slot replaces bomb and yields talent card")
	check(not g.card_targets("god_bless").has("player:0"), "cannot reinvite own god to farm rewards")
	g.players[0].cards = ["god_bless"]
	check(not g.use_card("god_bless","player:1") and g.players[0].cards.has("god_bless"), "stale target retains card")
	g.gm_spawn_god(5,"martial")
	check(g.use_card("god_bless","road:5") and not g.road_gods.has(5), "road selection uses stable key")
	check(g.players[0].god.id == "martial", "road invitation replaces old god")
	g.gm_god(1,"poor")
	g.current = 2
	g.players[2].cards = ["god_bless"]
	g.gm_bomb(2,30)
	var cash: int = g.players[2].cash
	check(g.use_card("god_bless","player:1"), "immune receiver accepts command")
	check(g.players[1].god.is_empty() and g.players[2].god.is_empty() and g.players[2].bomb.is_empty(), "immune invitation still clears source and prior slot")
	check(g.players[2].cash == cash, "immune god has no entry cash effect")
	g.players[2].cards = ["send_god","send_god","send_god","send_god"]
	check(g.give_card(2,"send_god") and g.players[2].cards == ["green"], "sixth synthesis recipe")
	g.players[2].cards = ["send_god","send_god","send_god","send_god","dice","dice","dice","dice"]
	var before: Array = g.players[2].cards.duplicate()
	check(not g.give_card(2,"send_god") and g.players[2].cards == before, "current capacity-first profile rejects without losing existing cards")
	g.players[2].cards = ["free"]
	check(not g.use_card("free") and g.players[2].cards == ["free"], "free is reaction only")
	g.players[2].cards = ["robot"]
	var route: Dictionary = g.controlled_routes("robot")[0]
	var road: int = route.path[0]
	g.gm_spawn_god(road,"earth")
	g.road_objects[road] = {"kind":"mine","owner":1}
	g.gm_god(1,"angel")
	check(g.use_card("robot",route.path,route.steps), "robot executes selected route")
	check(not g.road_gods.has(road) and not g.road_objects.has(road), "robot clears both road object and god")
	check(g.players[1].god.id == "angel", "robot preserves attached gods")
	g.players[2].cards = ["steal","dice","dice","dice","dice","dice","dice","dice"]
	g.players[1].cards = ["free"]
	check(g.use_card("steal",1), "full hand can consume steal before receiving card")
	check(g.players[2].cards.size()==8 and g.players[2].cards.has("free") and g.players[1].cards.is_empty(), "full-hand steal neither loses nor duplicates cards")
	print("GOD_INTERACTIONS_TEST failures=", failures)
	quit(1 if failures else 0)
