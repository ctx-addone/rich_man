extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round5"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("开始对局")
	app.game.rng.seed = 19
	var actions := 0
	var bank_used := false
	var card_played := false
	while app.screen == "game" and actions < 5000:
		actions += 1
		if app.handoff:
			await click("我已就位")
			continue
		match app.game.phase:
			"roll":
				if app.game.is_sleepwalking():
					await create_timer(0.05).timeout
					continue
				if not card_played:
					await click("遥控骰子")
					await choose_route_steps(6)
					card_played = true
				await click("掷骰子")
			"move":
				var moves: Array = app.game.available_moves()
				if moves.size() > 1: await click("→ %02d" % moves[app.game.rng.randi_range(0,moves.size()-1)])
				else: await create_timer(0.05).timeout
			"land":
				var b := find_button(app, "购买地产")
				var u := find_button(app, "升级建筑")
				if b != null and not b.disabled:
					await click("购买地产")
					var choice := find_button(app, "选择 ")
					if choice != null and not choice.disabled: await click("选择 ")
					else:
						await click("取消")
						await click("结束回合")
				elif u != null and not u.disabled: await click("升级建筑")
				else: await click("结束回合")
			"bank":
				await click("离开银行")
				bank_used = true
			"shop": await click("离开商店")
			"reaction":
				if find_button(app, "我来应对") != null: await click("我来应对")
				else: await click("承受效果")
			"end", "detained", "metro": await click("结束回合")
			_:
				check(false, "unsupported phase: " + app.game.phase)
				break
	check(app.screen == "results", "complete match reaches results without GM")
	check(not app.gm_used, "match never used GM")
	check(card_played and bank_used, "card and bank exercised")
	check(not app.game.winners.is_empty(), "natural winner exists")
	await capture("07-natural-results")
	print("FULL_UI_MATCH actions=%d rounds=%d failures=%d" % [actions,app.game.round_number,failures])
	quit(1 if failures > 0 else 0)
