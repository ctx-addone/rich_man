extends "res://tests/ui_test.gd"

func fresh_match(cards: Array) -> void:
	app.start_game()
	await click("我已就位")
	app.gm_used = true
	app.game.players[0].cards = cards
	app.refresh()

func wait_for_movement() -> void:
	var frames := 0
	while app.game.phase in ["roll", "move"] and frames < 500:
		await create_timer(0.02).timeout
		frames += 1
	check(frames < 500, "automatic movement resolves within bounded time")

func run() -> void:
	out_dir = "res://docs/testing/round5"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.shop_policy = "legacy_v8" # Preserve historical scenarios; R18 covers the new shop.
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human", "human", "human", "human"])
	app.talents_enabled = false
	app.gods_enabled = false
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("开始对局")
	await click("我已就位")
	app.gm_used = true
	app.game.players[0].cards = ["car", "dice"]
	app.refresh()
	await click("汽车卡")
	await click("确认使用")
	check(app.game.players[0].vehicle == "car", "vehicle card equips car")
	await click("3颗骰子")
	check(app.game.dice_count == 3, "car permits selecting three dice")
	await click("遥控骰子")
	await capture("01-controlled-routes")
	await choose_route_steps(12)
	await click("掷骰子")
	check(app.game.last_dice.size() == 3 and app.game.last_roll == 12, "controlled route produces legal three-die sum")
	await capture("02-vehicle-dice")
	await fresh_match(["teleport"])
	await click("传送卡")
	var people: OptionButton = app.popup.find_child("TeleportPlayer", true, false)
	var roads: OptionButton = app.popup.find_child("TeleportRoad", true, false)
	check(people != null and roads != null, "teleport has separate player and road selectors")
	if people != null: people.select(0)
	if roads != null: roads.select(roads.get_item_index(7))
	await click("确认传送")
	check(app.game.players[0].pos == 7 and app.game.phase == "roll", "teleport changes road without spending the current dice action")
	await capture("03-teleport-road")
	await fresh_match(["sleepwalk"])
	app.game.players[1].pos = 6
	app.game.players[1].previous = 5
	app.game.players[1].cards = ["dice"]
	app.game.players[1].cash = 100
	app.refresh()
	await click("梦游卡")
	await click("确认使用")
	check(app.game.players[1].status.get("kind", "") == "sleepwalk", "sleepwalk card applies moving status")
	app.game.phase = "end"
	app.refresh()
	await click("结束回合")
	await click("我已就位")
	await wait_for_movement()
	check(app.game.players[1].pos != 6 and app.game.phase != "bank", "sleepwalk moves automatically and bypasses bank service")
	var sleeping_card := find_button(app, "遥控骰子")
	check(sleeping_card != null and sleeping_card.disabled, "sleepwalker cannot play active cards")
	await capture("04-sleepwalk")
	await fresh_match(["immune"])
	await click("GM · F1")
	await click("设置汽车")
	await click("GM · F1")
	await click("附身炸弹 · 剩1步")
	check(app.game.players[0].vehicle == "car" and app.game.players[0].bomb.remaining == 1, "GM constructs vehicle and timed bomb through UI")
	app.game.players[0].previous = 79
	for index in range(1, 4): app.game.players[index].pos = 50
	app.forced_dice = 1
	app.refresh()
	await capture("05-bomb-countdown")
	await click("掷骰子")
	await wait_for_movement()
	check(app.game.phase == "reaction" and app.game.players[0].vehicle == "foot", "bomb explosion destroys vehicle before personal defense")
	await click("我来应对")
	await click("使用 " + app.game.CARD_NAMES.immune)
	check(app.game.players[0].status.is_empty() and app.game.players[0].bomb.is_empty(), "immune prevents hospital without restoring bomb or vehicle")
	await click("我已就位")
	check(app.game.phase == "land", "defended last-step blast resumes landing")
	await capture("06-bomb-defense")
	print("R5_UI failures=", failures)
	quit(1 if failures else 0)
