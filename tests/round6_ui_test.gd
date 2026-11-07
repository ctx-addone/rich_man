extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round6"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.controllers.assign(["human", "human", "human", "human"])
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	var choice: OptionButton = app.find_child("CharacterChoice0", true, false)
	check(choice != null and choice.item_count == 17, "all sixteen characters and neutral placeholder selectable")
	var character_index: int = app.Traits.ids().find("nintaro")
	choice.select(character_index)
	choice.item_selected.emit(character_index)
	await capture("01-characters")
	await click("开始对局")
	await click("我已就位")
	check(app.game.players[0].character_id == "nintaro", "selected character survives setup")
	check(app.game.road_gods.size() == 10, "normal match spawns ten gods")
	app.show_gm()
	var gods: OptionButton = app.popup.find_child("GMGod", true, false)
	gods.select(app.Gods.CATALOG.keys().find("angel"))
	await click("神仙附身")
	check(app.game.players[0].god.id == "angel" and app.game.players[0].god.remaining == 10, "GM attach uses selected character duration")
	check(app.game.players[0].cards.has("robot"), "character receives robot on possession")
	await capture("02-possession")
	app.game.players[0].cards = ["god_bless"]
	app.refresh()
	await click("神眷卡")
	var target: OptionButton = app.popup.find_child("CardTarget", true, false)
	check(target != null and target.item_count == 10, "god card lists named road gods")
	await capture("03-god-choice")
	await click("确认使用")
	check(app.game.road_gods.size() == 9, "chosen god removed from road")
	app.game.players[0].cards.clear()
	for ignored in range(5): app.game.gm_give_card(0, "missile")
	check(app.game.players[0].cards == ["rapid_missile"], "fifth card automatically synthesizes")
	app.game.players[0].cards = ["green"]
	app.refresh()
	await click("绿化卡")
	await click("确认使用")
	check(app.game.road_gods.is_empty() and app.game.players[0].god.is_empty(), "green clears road and attached gods")
	app.game.players[0].pos = int(app.game.lots.small_1_6.frontage_nodes[0])
	app.game.lots.small_1_6.owner = 1
	app.game.lots.small_1_6.building_type = "house"
	app.game.lots.small_1_6.level = 1
	var own_lot: String = ""
	for lot in app.game.lots.values():
		if lot.kind == "small" and lot.id != "small_1_6" and app.game._distance(app.game.players[0].pos, int(lot.frontage_nodes[0])) <= 6:
			own_lot = lot.id
			lot.owner = 0
			lot.building_type = "house"
			lot.level = 3
			break
	app.game.players[0].cards = ["swap_house"]
	app.refresh()
	await click("换屋卡")
	await capture("05-swap-choice")
	await click("确认交换")
	check(app.game.lots.small_1_6.level == 3 and app.game.lots[own_lot].level == 1, "two selectors exchange eligible buildings")
	app.show_world_catalog()
	await capture("04-catalog")
	await click("关闭")
	app.show_gm()
	await click("立即结算整局")
	check(app.screen == "results", "new systems still reach results")
	print("ROUND6_UI_TEST failures=", failures)
	quit(1 if failures else 0)
