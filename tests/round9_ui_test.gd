extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round9"
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human", "human", "human", "human"])
	app.gods_enabled = false
	app.talents_enabled = false
	app.save_directory = "res://.godot/round9-ui-%d" % Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	check(app.specials_enabled, "new games enable special facilities")
	var toggle: CheckButton = app.find_child("SpecialsToggle", true, false)
	check(toggle != null and toggle.button_pressed, "facility toggle exposed")
	await capture("01-special-setup")
	await click("开始对局")
	await click("我已就位")
	# Fixture only positions the actor; entry uses the actual movement command.
	app.gm_used = true
	app.game.players[0].pos = 16
	app.game.players[0].previous = 15
	app.game.players[0].cash = 20000
	app.game.players[0].cards.clear()
	check(app.game.roll_dice(2) and app.game.move_to(17), "walk into lottery")
	app.refresh()
	check(app.game.phase == "lottery" and app.game.steps_left == 1, "lottery pauses with one step left")
	await click("购入一注")
	check(app.game.lottery_state.tickets.size() == 1 and app.game.players[0].cash == 15000, "UI purchases selected ticket once")
	await capture("02-lottery-ticket")
	var saved: Dictionary = app.save_snapshot("乐透中途")
	check(saved.ok, "save while buying lottery")
	if saved.ok:
		check(app.load_snapshot(saved.path).ok, "load lottery snapshot through app")
		await click("我已就位")
		check(app.game.lottery_state.tickets.size() == 1 and app.game.pending_service.purchases == 1, "load retains purchased ticket and quota")
	await click("离开乐透站")
	await create_timer(0.7).timeout
	check(app.game.players[0].pos == 18 and app.game.phase == "land", "leaving resumes remaining movement and lands")
	app.game.phase = "roll"
	check(app.game.gm_teleport(0, 51), "magic landing fixture")
	app.handoff = false
	app.refresh()
	check(app.game.phase == "magic", "stopping enters magic selection")
	await capture("03-magic-choice")
	await click("施放 · 获得3张卡片")
	check(app.game.phase == "land" and app.game.magic_last_result.effect == "gain_cards", "magic selection resolves then returns to land")
	await capture("04-magic-result")
	var shop_road: int = -1
	for lot in app.game.lots.values():
		if lot.building_type == "shop": shop_road = int(lot.frontage_nodes[0])
	app.game.phase = "roll"
	app.game.players[0].cards.clear()
	check(app.game.gm_teleport(0, shop_road), "shop landing fixture")
	app.handoff = false
	app.refresh()
	await click("浏览商店")
	var offers: Array = app.game.shop_offers()
	check(offers.size() >= 5 and offers.size() <= 8, "random visit has bounded offers")
	await capture("05-random-shop")
	var offered: Dictionary = offers[0]
	await click("购买卡牌 · " + offered.name)
	check(not app.game.shop_stock.has(offered.id) and app.game.shop_purchases == 1, "buy removes one stock without rerolling")
	check(app.game.shop_offers().size() == offers.size()-1, "remaining stock stays fixed")
	print("ROUND9_UI_TEST failures=", failures)
	quit(1 if failures else 0)
