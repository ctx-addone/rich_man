extends SceneTree

var app: Control
var failures: int = 0
var out_dir := "res://docs/testing"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.is_visible_in_tree() and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found := find_button(child, prefix)
		if found != null: return found
	return null

func click(prefix: String) -> void:
	await process_frame
	await process_frame
	var control := find_button(app, prefix)
	check(control != null, "button exists: " + prefix)
	if control == null: return
	check(not control.disabled, "button enabled: " + prefix)
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	await process_frame

func capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out_dir.path_join(file_name + ".png")) == OK, "screenshot " + file_name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await capture("01-menu")
	await click("开始游戏")
	check(app.screen == "map", "main menu to map selection")
	await capture("02-map")
	await click("选择角色")
	check(app.screen == "characters", "map to character selection")
	await capture("03-characters")
	await click("开始对局")
	check(app.screen == "game" and app.handoff, "game starts with handoff")
	await click("我已就位")
	check(not app.handoff, "handoff confirmation")
	await click("GM · F1")
	check(app.popup != null, "GM opens")
	await capture("05-gm")
	await click("+1000 现金")
	check(app.game.players[0].cash == 11000 and app.gm_used, "GM adds cash")
	app.forced_dice = 1
	await click("掷骰子")
	check(app.game.phase == "move", "roll requests initial direction")
	await click("→ 01")
	check(app.game.phase == "land" and app.game.players[0].pos == 1, "move reaches property")
	await click("购买地产")
	check(app.game.nodes[1].owner == 0, "purchase via UI")
	await capture("04-game")
	await click("结束回合")
	check(app.game.current == 1 and app.handoff, "turn advances and requires new human")
	await click("我已就位")
	app.forced_dice = 1
	await click("掷骰子")
	await click("→ 01")
	check(app.game.players[1].cash == 10000 - app.game.nodes[1].rent, "rent automatically settled")
	await click("GM · F1")
	await click("立即结算整局")
	check(app.screen == "results", "GM finishes game and opens results")
	await capture("06-results")
	await click("相同设置")
	check(app.screen == "game" and app.game.nodes[1].owner == -1 and not app.gm_used, "restart creates clean state")
	await click("主菜单")
	await click("确认离开")
	check(app.screen == "menu", "exit confirmation returns menu")
	print("UI_TEST failures=", failures)
	quit(1 if failures > 0 else 0)
