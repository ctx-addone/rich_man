extends "res://tests/ui_test.gd"

func key(code: int, ctrl: bool = false, unicode_value: int = 0, target: Viewport = null) -> void:
	if target == null: target = root
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.unicode = unicode_value
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		if target == root: target.push_input(event, true)
		else: Input.parse_input_event(event)
	await process_frame

func type_amount(node_name: String, amount: int) -> void:
	var spin: SpinBox = app.popup.find_child(node_name, true, false)
	check(spin != null, "numeric setting exists: " + node_name)
	if spin == null: return
	await click_point(spin.get_line_edit().get_global_rect().get_center())
	await key(KEY_A, true)
	for character in str(amount): await key(0, false, character.unicode_at(0))
	await key(KEY_ENTER)
	check(int(spin.value) == amount, "keyboard entered " + node_name)

func has_text(node: Node, fragment: String) -> bool:
	if node is Label and fragment in node.text: return true
	for child in node.get_children():
		if has_text(child, fragment): return true
	return false

func choose_option(option: OptionButton, wanted_id: int) -> void:
	await click_point(option.get_global_rect().get_center())
	await create_timer(0.15).timeout
	var menu := option.get_popup()
	if not menu.visible:
		await key(KEY_SPACE, false, 0, menu)
		await create_timer(0.15).timeout
	check(menu.visible, "native menu opens for " + option.name)
	for ignored in range(menu.item_count + 1):
		if menu.get_focused_item() >= 0 and menu.get_item_id(menu.get_focused_item()) == wanted_id: break
		await key(KEY_DOWN, false, 0, menu)
	await key(KEY_ENTER, false, 0, menu)
	check(option.get_selected_id() == wanted_id, "real dropdown input chooses %d" % wanted_id)

func run() -> void:
	out_dir = "res://docs/testing/round16"
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.map_id = "knight_manor"
	app.controllers.assign(["human", "human", "human", "human"])
	app.talents_enabled = false
	app.gods_enabled = false
	app.save_directory = "res://.godot/r16-settings-%d" % Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	check(app.economy_config == {"initial_cash":100000,"initial_deposit":100000,"inflation_interval":15,"policy":"r16_samples"}, "new UI uses witnessed menu sample, not legacy test preset")
	await click("经济设置")
	await capture("01-economy-settings")
	await type_amount("InitialCash", 123456)
	await type_amount("InitialDeposit", 78901)
	var interval: OptionButton = app.popup.find_child("InflationInterval", true, false)
	check(interval.item_count == 6, "cycle choices include disabled, 1, 5, 10, 15, 20")
	await choose_option(interval, 1)
	await click("应用到新局")
	var chosen: Dictionary = {"initial_cash":123456,"initial_deposit":78901,"inflation_interval":1,"policy":"r16_samples"}
	check(app.economy_config == chosen, "apply commits exact typed settings")
	check(has_text(app.page, "123456") and has_text(app.page, "78901"), "character screen summarizes exact settings")
	await click("经济设置")
	await type_amount("InitialCash", 500000)
	await click("取消")
	check(app.economy_config == chosen, "cancel discards uncommitted draft")
	await choose_option(app.page.find_child("RoundLimitChoice", true, false), 0)
	check(app.turns == 0, "unlimited selection updates startup setting")
	await capture("00-characters-configured")
	await click("开始对局")
	check(app.game.round_limit == 0 and "无限期" in app.top_title.text and "/ 0" not in app.top_title.text, "unlimited game starts without zero denominator")
	for player in app.game.players:
		check(player.cash == 123456 and player.deposit == 78901, "all four seats receive configured starting balances")
	check(app.top_title.text.contains("第 1") and app.top_title.text.contains("物价×1"), "header shows initial day and price")
	await click("我已就位")
	# Use public GM commands only to finish the four seats without an economic event.
	var safe_road := -1
	for node in app.game.nodes:
		if node.kind == "road" and app.game.lots_at_node(node.id).is_empty(): safe_road = node.id; break
	check(safe_road >= 0, "map contains neutral testing road")
	if safe_road < 0: quit(1); return
	for ignored in range(4):
		check(app.game.gm_teleport(app.game.current, safe_road), "GM places current seat on neutral road")
		check(app.game.end_turn(), "public end turn advances seat")
	app.gm_used = true
	app.refresh()
	check(app.game.round_number == 2 and app.game.price_index() == 2, "four completed seats advance day and daily price")
	check(app.top_title.text.contains("第 2") and app.top_title.text.contains("物价×2"), "header refreshes inflated price")
	await capture("02-day-two-price")
	var snapshot: Dictionary = app.Saves.snapshot(app.game)
	await click("存读档")
	await click("新建存档")
	check(DirAccess.get_files_at(app.save_directory).size() == 1, "real save button creates a new save")
	await click("读取 · ")
	await click("确认读取")
	check(app.Saves.snapshot(app.game) == snapshot and app.economy_config == chosen, "load preserves entire state and restart configuration")
	check(app.turns == 0 and app.game.round_limit == 0, "load preserves unlimited setting")
	await click("我已就位")
	await click("GM · F1")
	await click("立即结算整局")
	await click("相同设置 · 再来一局")
	check(app.game.economy_config == chosen and app.game.price_index() == 1, "same-settings restart retains chosen policy and resets day")
	check(app.game.round_limit == 0 and "无限期" in app.top_title.text, "same-settings restart retains unlimited duration")
	for player in app.game.players: check(player.cash == 123456 and player.deposit == 78901, "restart resets each starting balance")
	check(app.load_snapshot("res://tests/fixtures/round15-v6-economy.rms").ok, "genuine v6 fixture loads in economic UI")
	check(app.economy_config.policy == "legacy_v6" and app.economy_config.inflation_interval == 0, "old save preserves old reward policy and disabled inflation")
	await click("我已就位")
	check(has_text(app.sidebar, "旧局规则"), "old minigame sidebar explains legacy rewards")
	await capture("03-legacy-reward-policy")
	await click("GM · F1")
	await click("立即结算整局")
	await click("相同设置 · 再来一局")
	check(app.game.economy_config.policy == "legacy_v6" and app.game.players[0].cash == 10000 and app.game.players[0].deposit == 0, "restarting migrated old save keeps legacy initial settings")
	print("ROUND16_SETTINGS_UI failures=", failures)
	quit(1 if failures else 0)
