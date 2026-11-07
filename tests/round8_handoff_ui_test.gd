extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round8/handoff"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440,900)
	app = load("res://scenes/main.tscn").instantiate()
	app.controllers.assign(["human","ai","human","ai"])
	app.gods_enabled = false
	app.talents_enabled = false
	app.ai_delay = 0.01
	app.save_directory = "res://.godot/round8-handoff-%d" % Time.get_ticks_usec()
	root.add_child(app)
	app.start_game()
	await click("我已就位")
	app.ai_paused = true
	app.game.players[0].cards = ["scheme"]
	app.game.players[1].cards = ["immune"]
	app.refresh()
	await click("谋划卡")
	await click("确认使用")
	check(app.game.reaction_player() == 1 and app.is_automated(), "AI defender controls reaction during human action")
	await capture("01-ai-defender")
	await click("继续电脑行动")
	for ignored in range(8): await process_frame
	check(app.game.phase == "roll" and app.game.current == 0 and app.handoff and app.game.players[1].cards.is_empty(), "AI defense returns to human caster without stealing turn")
	# Reverse roles: computer attacks a human and waits for the human decision.
	app.game.current = 1
	app.game.card_used = false
	app.game.players[1].cards = ["scheme"]
	app.game.players[0].cards = ["immune"]
	app.handoff = false
	app.refresh()
	for ignored in range(8): await process_frame
	check(app.game.phase == "reaction" and app.game.reaction_player() == 0 and not app.is_automated(), "AI attack waits for human defender")
	app.show_saves()
	var saved: Dictionary = app.save_snapshot("防御中")
	check(saved.ok, "pending human reaction saved")
	var before: Dictionary = app.Saves.snapshot(app.game)
	var corrupt_path: String = app.save_directory.path_join("broken.rms")
	var file := FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string("not a game")
	file.close()
	check(not app.load_snapshot(corrupt_path).ok and app.Saves.snapshot(app.game) == before, "bad file leaves live match intact")
	var bad_meta: String = app.save_directory.path_join("bad-meta.rms")
	check(app.Saves.save_to_file(app.game,bad_meta,{"portraits":"invalid"}).ok, "malformed UI metadata fixture stored without objects")
	check(not app.load_snapshot(bad_meta).ok and app.Saves.snapshot(app.game) == before, "bad UI metadata leaves live match intact")
	check(app.load_snapshot(saved.path).ok and app.game.phase == "reaction", "valid reload preserves unresolved reaction")
	await click("我来应对")
	await capture("02-human-defense-loaded")
	await click("使用 无懈卡")
	check(app.game.phase == "roll" and app.game.current == 1 and app.game.players[0].status.is_empty(), "human defense continues computer caster action")
	check(app.ai_paused and app.is_automated(), "loaded AI remains paused until requested")
	await click("接管当前席位")
	await click("我已就位")
	check(app.controllers[1] == "human" and find_button(app,"掷骰子") != null, "former computer actor is playable after takeover")
	print("ROUND8_HANDOFF_UI_TEST failures=",failures)
	quit(1 if failures else 0)
