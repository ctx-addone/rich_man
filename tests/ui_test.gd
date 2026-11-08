extends SceneTree

var app: Control
var failures: int = 0
var out_dir := "res://docs/testing/round5/base"

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

func find_amount(node: Node) -> SpinBox:
	if node is SpinBox: return node
	for child in node.get_children():
		var found := find_amount(child)
		if found != null: return found
	return null

func click(prefix: String) -> void:
	await process_frame
	await process_frame
	var control := find_button(app, prefix)
	check(control != null, "button exists: " + prefix)
	if control == null: return
	check(not control.disabled, "button enabled: " + prefix)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await process_frame
	await process_frame
	var point := control.get_global_rect().get_center()
	await click_point(point)

func click_point(point: Vector2) -> void:
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
	var destination: String = OS.get_environment("RICHMAN_TEST_OUTPUT")
	if destination.is_empty(): destination = out_dir
	DirAccess.make_dir_recursive_absolute(destination)
	check(root.get_texture().get_image().save_png(destination.path_join(file_name + ".png")) == OK, "screenshot " + file_name)

func choose_route_steps(steps: int) -> void:
	var choice: OptionButton = app.popup.find_child("RouteChoice", true, false)
	check(choice != null, "route selector exists")
	if choice == null: return
	var found := false
	for index in range(choice.item_count):
		if choice.get_item_metadata(index) == steps:
			choice.select(index)
			choice.item_selected.emit(index)
			found = true
			break
	check(found, "requested route length exists")
	if found: await click("确认路线")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.shop_policy = "legacy_v8" # Preserve historical scenarios; R18 covers the new shop.
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.controllers.assign(["human", "human", "human", "human"])
	app.talents_enabled = false
	app.gods_enabled = false
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
	await click("遥控骰子")
	await choose_route_steps(1)
	await click("掷骰子")
	check(app.game.phase == "move", "roll requests initial direction")
	var move: int = app.game.available_moves()[0]
	await click("→ %02d" % move)
	check(app.game.players[0].pos == move, "chosen one-step die reaches selected road")
	var lot_id := ""
	for id in app.game.lots:
		if app.game.lots[id].kind == "small" and app.game.lots[id].frontage_nodes.size() > 1:
			lot_id = id
			break
	check(not lot_id.is_empty(), "map contains multi-frontage building")
	if lot_id.is_empty(): quit(1); return
	var lot: Dictionary = app.game.lots[lot_id]
	var first_entrance := int(lot.frontage_nodes[0])
	var second_entrance := int(lot.frontage_nodes[1])
	app.game.gm_teleport(0, first_entrance)
	app.refresh()
	await click("购买地产")
	await click("选择 住宅")
	check(lot.owner == 0, "purchase via UI assigns building ownership")
	check(not app.game.nodes[first_entrance].has("owner"), "road has no duplicate ownership")
	await process_frame
	await click_point(app.board.global_position + app.board.lot_rects[lot_id].get_center())
	check(app.selected_lot == lot_id, "building click selects lot rather than road")
	await capture("04-game")
	await click("结束回合")
	check(app.game.current == 1 and app.handoff, "turn advances and requires new human")
	await click("我已就位")
	app.game.gm_teleport(1, second_entrance)
	app.refresh()
	check(app.game.players[1].cash == 10000 - lot.rent, "second entrance charges same building rent")
	await click("GM · F1")
	await click("入狱2回合")
	check(app.game.phase == "end" and app.game.players[1].status.kind == "prison", "GM imprisonment stops current journey")
	await click("结束回合")
	for ignored in range(3):
		app.game.gm_teleport(app.game.current, 0)
		app.game.end_turn()
	app.handoff = false
	app.refresh()
	check(app.game.current == 1 and app.game.phase == "detained", "next personal turn starts in detention")
	await capture("08-prison")
	await click("GM · F1")
	await click("解除停留")
	check(app.game.players[1].status.is_empty(), "GM release clears detention")
	await click("GM · F1")
	await click("住院2回合")
	check(app.game.players[1].status.kind == "hospital", "GM hospitalization enters facility")
	await capture("09-hospital")
	await click("GM · F1")
	await click("解除停留")
	var bank: Dictionary = app.game.facility_lot("bank")
	app.game.gm_teleport(1, int(bank.frontage_nodes[0]))
	app.refresh()
	check(app.game.phase == "bank", "bank landing opens service")
	var before_cash: int = app.game.players[1].cash
	await click("存入现金")
	check(app.game.players[1].deposit == 1000 and app.game.players[1].cash == before_cash - 1000, "deposit UI transfers funds")
	await capture("10-bank")
	await click("提取存款")
	check(app.game.players[1].deposit == 0 and app.game.players[1].cash == before_cash, "withdraw UI restores cash")
	find_amount(app).value = 780
	await click("存入现金")
	check(app.game.players[1].deposit == 780, "bank accepts exact non-hundred amount")
	find_amount(app).value = 780
	await click("提取存款")
	check(app.game.players[1].deposit == 0 and app.game.players[1].cash == before_cash, "withdraw exact 780 clears remainder")
	await click("离开银行")
	check(app.game.phase != "bank", "bank service can close")
	await click("GM · F1")
	await click("立即结算整局")
	check(app.screen == "results", "GM finishes game and opens results")
	await capture("06-results")
	await click("相同设置")
	check(app.screen == "game" and app.game.lots[lot_id].owner == -1 and not app.gm_used, "restart creates clean state")
	await click("主菜单")
	await click("确认离开")
	check(app.screen == "menu", "exit confirmation returns menu")
	print("UI_TEST failures=", failures)
	quit(1 if failures > 0 else 0)
