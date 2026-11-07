extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round8"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_directory = "res://.godot/round8-ui-%d" % Time.get_ticks_usec()
	app.ai_delay = 0.01
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	check(app.controllers == ["human","ai","ai","ai"], "default is one human with three computer opponents")
	await capture("01-controllers")
	await click("开始对局")
	await click("我已就位")
	# Save a deterministic movement fixture before automatic animation advances.
	app.game.roll_dice(3)
	app.gm_used = true
	app.refresh()
	app.show_saves()
	var state_before: Dictionary = app.Saves.snapshot(app.game)
	var title: LineEdit = app.popup.find_child("SaveTitle", true, false)
	title.text = "移动中回放"
	await click("新建存档")
	check(DirAccess.get_files_at(app.save_directory).size() == 1, "saving creates a historical record")
	await capture("02-save-history")
	app.menu()
	await click("读取存档")
	await click("读取 · 移动中回放")
	await click("确认读取")
	check(app.screen == "game" and app.game.phase == "move" and app.game.steps_left == 3, "menu load restores unfinished movement")
	check(app.Saves.snapshot(app.game).state == state_before.state, "load restores exact model state before any next action")
	check(app.gm_used and app.ai_paused and app.controllers == ["human","ai","ai","ai"], "load retains control settings and test marker, pauses AI")
	await capture("03-loaded-movement")
	# Reopen save while moving; each save must create a new entry, not overwrite.
	app.show_saves()
	await click("新建存档")
	check(DirAccess.get_files_at(app.save_directory).size() == 2, "second save appends a separate record")
	await click("返回")
	app.show_control_settings()
	for i in range(4):
		var choice: OptionButton = app.popup.find_child("LiveController%d" % i, true, false)
		choice.select(1)
		choice.item_selected.emit(1)
	await click("返回对局")
	check(app.controllers == ["ai","ai","ai","ai"], "live controls can hand all seats to AI")
	await capture("04-paused-ai")
	await click("接管当前席位")
	check(app.controllers[app.game.current] == "human" and app.handoff, "takeover returns action to a human")
	# Fresh normal all-AI game, ten rounds, no GM and no forced termination.
	app.controllers.assign(["ai","ai","ai","ai"])
	app.turns = 10
	app.start_game()
	var frames := 0
	while app.screen == "game" and frames < 16000:
		await process_frame
		frames += 1
	check(app.screen == "results" and not app.gm_used and not app.game.winners.is_empty(), "all-AI UI match finishes naturally without GM")
	await capture("05-ai-natural-results")
	print("ROUND8_UI_TEST failures=", failures, " frames=", frames)
	quit(1 if failures else 0)
