extends "res://tests/ui_test.gd"

func fresh_match() -> void:
	app.start_game()
	await click("我已就位")
	app.game.road_gods.clear()
	app.gm_used = true

func rent_fixture(cards: Array) -> void:
	var lot: Dictionary = app.game.lots.small_1_6
	lot.owner = 1
	lot.building_type = "house"
	lot.level = 5
	lot.rent_until = 10
	app.game.players[1].glory_until = 10
	app.game.players[0].cards = cards
	app.game.gm_teleport(0, int(lot.frontage_nodes[0]))
	app.refresh()

func run() -> void:
	out_dir = "res://docs/testing/round7"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.shop_policy = "legacy_v8" # Preserve historical scenarios; R18 covers the new shop.
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.controllers.assign(["human", "human", "human", "human"])
	app.character_ids.assign(["eleven", "original", "original", "original"])
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("开始对局")
	await click("我已就位")
	app.game.road_gods.clear()
	app.gm_used = true
	app.show_gm()
	await click("配置地产与租金测试")
	var lot_choice: OptionButton = app.popup.find_child("GMLot", true, false)
	var lot_options: Array = []
	for lot in app.game.lots.values():
		if lot.kind != "facility": lot_options.append(lot.id)
	var lot_index: int = lot_options.find("small_1_6")
	lot_choice.select(lot_index)
	lot_choice.item_selected.emit(lot_index)
	var lot_owner: OptionButton = app.popup.find_child("GMLotOwner", true, false)
	lot_owner.select(2)
	var lot_level: SpinBox = app.popup.find_child("GMLotLevel", true, false)
	lot_level.value = 5
	await capture("00-gm-property")
	await click("应用地产配置")
	check(app.game.lots.small_1_6.owner == 1 and app.game.lots.small_1_6.level == 5, "GM configures a shared property for fee testing")
	rent_fixture(["free"])
	check(app.game.phase == "reaction", "rent opens money defense before debit")
	check(app.game.players[0].cash == 10000 and app.game.players[1].cash == 10000, "cash unchanged during decision")
	await click("我来应对")
	await capture("01-free-reaction")
	await click("使用 免费卡")
	check(app.game.players[0].cash == 10000 and app.game.players[1].cash == 10000, "free prevents payment without crediting receiver")
	check(app.game.players[0].cards == ["dice"], "eleven rewards a die after passive free consumption")
	check(app.game.phase == "land", "rent continuation restores land")
	await click("我已就位")
	await capture("02-free-resolved")
	await fresh_match()
	app.game.players[2].cards = ["free"]
	rent_fixture(["transfer"])
	await click("我来应对")
	var transfer: OptionButton = app.find_child("ReactionTarget", true, false)
	var targets: Array = app.game.reaction_targets("transfer")
	check(transfer != null and targets.has(2), "money transfer exposes another payer")
	transfer.select(targets.find(2))
	await click("使用 转移卡")
	check(app.game.reaction_player() == 2, "transfer hands decision to selected payer")
	await click("我来应对")
	await capture("03-transfer-reaction")
	await click("使用 免费卡")
	check(app.game.players[0].cash == 10000 and app.game.players[2].cash == 10000, "transferred free prevents both debits")
	await click("我已就位")
	await fresh_match()
	app.game.gm_god(1, "martial")
	app.game.players[0].cards = ["god_bless"]
	app.refresh()
	await click("神眷卡")
	var god_choice: OptionButton = app.popup.find_child("CardTarget", true, false)
	check(god_choice != null and god_choice.item_count == 1, "attached god is selectable without ground gods")
	await capture("04-attached-god")
	await click("确认使用")
	check(app.game.players[0].god.get("id", "") == "martial" and app.game.players[1].god.is_empty(), "possession moves to inviter")
	app.game.players[0].cards.clear()
	for ignored in range(5): app.game.gm_give_card(0, "send_god")
	check(app.game.players[0].cards == ["green"], "sixth recipe converts five send cards into green")
	print("ROUND7_UI_TEST failures=", failures)
	quit(1 if failures else 0)
