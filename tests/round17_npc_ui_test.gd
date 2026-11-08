extends "res://tests/round16_settings_ui_test.gd"

func neutral_road(excluded: Array = []) -> int:
	for node in app.game.nodes:
		if node.kind == "road" and not excluded.has(node.id) and app.game.lots_at_node(node.id).is_empty(): return node.id
	return -1

func run() -> void:
	out_dir = "res://docs/testing/round17"
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.map_id = "knight_manor"
	app.controllers.assign(["human", "human", "human", "human"])
	app.gods_enabled = false
	app.talents_enabled = false
	app.save_directory = "res://.godot/r17-npc-ui-%d" % Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	var toggle: CheckButton = app.page.find_child("NPCsToggle", true, false)
	check(toggle != null and toggle.button_pressed and app.npcs_enabled, "NPCs default on in new-game UI")
	await click("道路NPC")
	check(not app.npcs_enabled, "NPC toggle off updates setup setting")
	await click("道路NPC")
	await capture("01-npc-setup")
	await click("开始对局")
	check(app.game.npcs_enabled, "new match passes NPC setup option")
	await click("我已就位")
	var merchant_road: int = neutral_road()
	var dog_road: int = neutral_road([merchant_road])
	check(merchant_road >= 0 and dog_road >= 0, "neutral test roads exist")
	if merchant_road < 0 or dog_road < 0: quit(1); return
	# Public map selection preselects the GM destination; placement uses real buttons.
	app.on_tile(merchant_road)
	await click("GM · F1")
	await click("配置道路NPC")
	await click("放置 · " + app.game.NPC.title("merchant"))
	check(app.game.road_npcs.merchant.road == merchant_road and app.gm_used, "GM merchant placement is applied and marked")
	app.on_tile(dog_road)
	await click("GM · F1")
	await click("配置道路NPC")
	await click("放置 · " + app.game.NPC.title("dog"))
	check(app.game.road_npcs.dog.road == dog_road, "GM dog placement uses selected road")
	await process_frame
	check(app.board.npc_rects.has("merchant") and app.board.npc_rects.has("dog"), "NPC markers are drawn separately from property rectangles")
	await click_point(app.board.global_position + app.board.npc_rects.merchant.get_center())
	check(app.selected == merchant_road and app.selected_lot.is_empty(), "clicking NPC marker selects its road, not property")
	check(has_text(app.sidebar, "道路NPC · " + app.game.NPC.title("merchant")), "road inspector describes selected merchant")
	await capture("02-road-npc-markers")
	check(app.game.gm_teleport(0, merchant_road), "public GM landing enters merchant")
	app.refresh()
	check(app.game.phase == "merchant", "merchant landing is actionable")
	if app.game.phase != "merchant": quit(1); return
	while app.game.players[0].cards.size() < app.Game.HAND_LIMIT:
		check(app.game.gm_give_card(0, "dice"), "GM fills hand with legal cards")
	app.refresh()
	var purchase := find_button(app, "购买 · ")
	check(purchase != null and purchase.disabled, "full hand disables merchant purchases")
	await click("弃")
	var before_cash: int = app.game.players[0].cash
	var offers: Array = app.game.NPC.offers(app.game)
	check(offers.size() == 6, "merchant exposes six fixed card types")
	var selected_offer: Dictionary = offers[0]
	await click("购买 · " + selected_offer.name)
	check(app.game.players[0].cash == before_cash - selected_offer.price and app.game.NPC.remaining(app.game) == 1, "one purchase pays displayed quote and consumes one quota")
	check(find_button(app, "购买 · " + selected_offer.name) == null, "already purchased type is removed from this visit's shelf")
	await capture("03-merchant-purchase")
	await click("GM · F1")
	await click("配置道路NPC")
	var remove_active := find_button(app, "移除 · " + app.game.NPC.title("merchant"))
	check(remove_active != null and remove_active.disabled, "active merchant cannot be removed via GM")
	await click("返回GM")
	await click("关闭  /  Esc")
	var before: Dictionary = app.Saves.snapshot(app.game)
	await click("存读档")
	await click("新建存档")
	await click("读取 · ")
	await click("确认读取")
	check(app.Saves.snapshot(app.game) == before and app.npcs_enabled, "merchant save restores quote history, quota, state and NPC toggle")
	await click("我已就位")
	await click("离开流动商人")
	check(app.game.phase == "land" and app.game.pending_service.is_empty(), "zero-step merchant closes into original landing")
	await process_frame
	check(not app.game.road_npcs.has("merchant") and not app.board.npc_rects.has("merchant"), "merchant and marker disappear after closing")
	await click("GM · F1")
	await click("立即结算整局")
	await click("相同设置 · 再来一局")
	check(app.game.npcs_enabled and app.npcs_enabled, "same-settings restart retains NPC enablement")
	await click("我已就位")
	# Direct evidence establishes final-stop entry; passing does not open the NPC.
	var next_road: int = app.game.nodes[app.game.players[0].pos].neighbors[0]
	check(app.game.NPC.gm_remove(app.game, "dog"), "remove dog for isolated continuation test")
	check(app.game.NPC.gm_place(app.game, "merchant", next_road), "place merchant on first step")
	check(app.game.roll_dice(2) and app.game.move_to(next_road), "normal movement passes merchant with a remaining step")
	check(app.game.phase != "merchant" and app.game.steps_left == 1, "passing merchant does not open a final-stop service")
	if app.game.phase == "bank": app.game.close_bank()
	if app.game.phase == "lottery": app.game.close_lottery()
	if app.game.phase == "move": app.game.move_to(app.game.available_moves()[0])
	check(app.game.NPC.gm_remove(app.game, "merchant"), "remove passed merchant before unrelated setup")
	# Reset all four seats via public neutral landings so seat0 can walk normally into a shop.
	var shop_road: int = int(app.game.facility_lot("shop").frontage_nodes[0])
	var origin: int = app.game.nodes[shop_road].neighbors[0]
	for ignored in range(4):
		check(app.game.gm_teleport(app.game.current, merchant_road) and app.game.end_turn(), "public neutral turn setup")
	check(app.game.gm_teleport(0, origin), "place seat0 beside shop")
	for ignored in range(4):
		if app.game.current != 0: app.game.gm_teleport(app.game.current, merchant_road)
		check(app.game.end_turn(), "return seat0 to roll phase without state mutation")
	check(app.game.NPC.gm_place(app.game, "merchant", shop_road), "merchant shares a shop frontage for ordering test")
	check(app.game.roll_dice(1) and app.game.move_to(shop_road), "normal final step arrives at merchant and shop")
	check(app.game.phase == "merchant" and app.game.steps_left == 0, "merchant opens before same-road shop")
	app.handoff = false
	app.refresh()
	await capture("04-merchant-shop-order")
	await click("离开流动商人")
	check(app.game.phase == "shop" and not app.game.road_npcs.has("merchant"), "merchant close resumes independent shop service exactly once")
	await capture("05-shop-after-merchant")
	await click("离开商店")
	check(app.load_snapshot("res://tests/fixtures/round16-v7-priced-service.rms").ok, "genuine pre-NPC v7 fixture loads")
	check(not app.game.npcs_enabled and not app.npcs_enabled and app.game.road_npcs.is_empty(), "old save retains disabled NPCs and no random spawn")
	await click("GM · F1")
	await click("立即结算整局")
	await click("相同设置 · 再来一局")
	check(not app.game.npcs_enabled and app.game.road_npcs.is_empty(), "legacy restart preserves disabled NPCs")
	print("ROUND17_NPC_UI failures=", failures)
	quit(1 if failures else 0)
