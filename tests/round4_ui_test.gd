extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round4"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human", "human", "human", "human"])
	app.talents_enabled = false
	app.gods_enabled = false
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("开始对局")
	await click("我已就位")
	# Fixture positions only; banking and trades use actual rendered controls.
	app.gm_used = true
	app.game.gm_teleport(0, 7)
	app.refresh()
	await click("存入现金")
	check(app.game.players[0].deposit == 1000, "bank supplies stock funds")
	var worth: int = app.game.net_worth(0)
	await click("股票")
	var amount: SpinBox = app.popup.find_child("StockQuantity_test_grain", true, false)
	check(amount != null, "stock quantity control exists")
	if amount != null: amount.value = 3
	await click("买入 · 测试谷物公司")
	check(app.game.players[0].stocks.get("test_grain", 0) == 3 and app.game.players[0].deposit == 880, "buy spends deposit and creates shares")
	check(app.game.net_worth(0) == worth, "stock purchase preserves net worth")
	await capture("01-stock-purchase")
	await click("卖出 · 测试谷物公司")
	check(app.game.players[0].stocks.get("test_grain", 0) == 2 and app.game.players[0].deposit == 920, "partial sale returns deposit")
	await click("返回对局")
	check(app.game.phase == "bank", "stock window resumes bank service")
	await click("离开银行")
	# Fresh match: player 2 chooses an actual passive defense.
	app.start_game()
	await click("我已就位")
	app.gm_used = true
	app.game.players[0].cards = ["scheme"]
	app.game.players[1].cards = ["immune"]
	app.refresh()
	await click("谋划卡")
	await click("确认使用")
	check(app.game.phase == "reaction" and app.game.current == 0 and app.game.reaction_player() == 1, "attack gives defender control without changing active seat")
	await capture("02-defense-handoff")
	await click("我来应对")
	await capture("03-defense-choice")
	await click("使用 " + app.game.CARD_NAMES.immune)
	check(app.game.players[1].status.is_empty() and app.game.players[1].cards.is_empty(), "defense consumes its own card and prevents imprisonment")
	check(app.game.phase == "roll" and app.handoff, "defense restores attacker turn with handoff")
	await click("我已就位")
	check(find_button(app, "掷骰子") != null, "attacker can continue after defense")
	# Same-fate must end a now-disabled attacker's action, not leave a stuck roll phase.
	app.game.players[0].cards = ["hibernate"]
	app.game.players[1].cards = ["same_fate"]
	app.refresh()
	await click(app.game.CARD_NAMES.hibernate)
	await click("确认使用")
	await click("我来应对")
	await click("使用 " + app.game.CARD_NAMES.same_fate)
	check(app.game.players[0].status.get("kind", "") == "hibernate" and app.game.players[1].status.get("kind", "") == "hibernate", "same fate applies winter status to both parties")
	check(app.game.phase == "end", "disabled attacker reaches end phase")
	await click("我已就位")
	await capture("04-hibernation")
	await click("结束回合")
	check(app.game.current == 1 and app.game.phase == "detained", "winter status advances to next seat")
	await click("我已就位")
	await click("结束回合")
	check(app.game.players[1].status.remaining == 1, "skipped turn advances winter duration")
	app.start_game()
	await click("我已就位")
	app.gm_used = true
	app.game.players[0].cards = ["scheme", "immune"]
	app.game.players[1].cards = ["transfer"]
	app.refresh()
	await click("谋划卡")
	await click("确认使用")
	await click("我来应对")
	check(app.find_child("ReactionTarget", true, false) != null, "transfer presents eligible target selector")
	await capture("05-transfer-target")
	await click("使用 " + app.game.CARD_NAMES.transfer)
	check(app.game.phase == "reaction" and app.game.reaction_player() == 0, "transfer switches control to original attacker")
	await click("我来应对")
	await click("使用 " + app.game.CARD_NAMES.immune)
	check(app.game.players[0].status.is_empty() and app.game.players[1].status.is_empty(), "new target may defend transferred imprisonment")
	check(app.game.players[0].cards.is_empty() and app.game.players[1].cards.is_empty(), "attack and both defense cards each consumed once")
	print("R4_UI failures=", failures)
	quit(1 if failures else 0)
