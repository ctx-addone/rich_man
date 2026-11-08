extends "res://tests/ui_test.gd"

func run() -> void:
	out_dir = "res://docs/testing/round10"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	var initial_seed:String=OS.get_environment("RICHMAN_TEST_SEED")
	if not initial_seed.is_empty(): app.match_seed=int(initial_seed)
	var test_map:String = OS.get_environment("RICHMAN_TEST_MAP")
	if not test_map.is_empty(): app.map_id = test_map
	var test_turns:String=OS.get_environment("RICHMAN_TEST_TURNS")
	if not test_turns.is_empty():app.turns=int(test_turns)
	app.controllers.assign(["human", "human", "human", "human"])
	var team_match:bool=OS.get_environment("RICHMAN_TEST_TEAMS")=="2v2"
	if team_match: app.teams.assign([0,1,0,1])
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("开始对局")
	var seed_text:String=OS.get_environment("RICHMAN_TEST_SEED")
	app.game.rng.seed = 19 if seed_text.is_empty() else int(seed_text)
	var actions := 0
	var bank_used := false
	var card_played := false
	var minigames:Dictionary={}
	var merchants:int=0
	var shop_purchases:int=0
	var shop_transactions:Array[Dictionary]=[]
	while app.screen == "game" and actions < 5000:
		actions += 1
		if app.handoff:
			await click("我已就位")
			continue
		match app.game.phase:
			"merchant":
				merchants+=1
				var offers:Array=app.game.NPC.offers(app.game)
				if app.game.NPC.remaining(app.game)>0 and app.game.players[app.game.current].cards.size()<app.game.HAND_LIMIT and not offers.is_empty() and app.game.players[app.game.current].cash>=offers[0].price:
					await click("购买 · "+offers[0].name)
				else: await click("离开流动商人")
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
			"shop":
				# One genuine purchase is enough to cover pricing; full hands can
				# leave normally and wait for a later participant's shop visit.
				if shop_purchases == 0 and app.game.shop_remaining() > 0 and app.game.players[app.game.current].cards.size() < app.game.HAND_LIMIT:
					await click("浏览商店")
					var buyer:int = app.game.current
					for offer in app.game.shop_offers():
						var prefix:String = "购买卡牌 · %s · " % offer.name
						var purchase:Button = find_button(app, prefix)
						if purchase == null or purchase.disabled: continue
						var displayed_price:int = purchase.text.get_slice(" · ", 2).to_int()
						check(displayed_price == int(offer.price), "ordinary shop button displays current offer price")
						var cash_before:int = app.game.players[buyer].cash
						var cards_before:int = app.game.players[buyer].cards.count(offer.id)
						var quota_before:int = app.game.shop_remaining()
						var stock_before:int = app.game.shop_stock.count(offer.id)
						await capture("06-natural-shop-quote")
						await click(purchase.text)
						var paid:int = cash_before - app.game.players[buyer].cash
						check(paid == displayed_price, "ordinary shop deducts exactly the displayed cash price")
						check(app.game.players[buyer].cards.count(offer.id) == cards_before + 1 and app.game.shop_remaining() == quota_before - 1, "natural shop purchase grants one card and consumes one quota")
						check(app.game.shop_stock.count(offer.id) == stock_before - 1, "natural shop purchase removes exactly one matching stock slot")
						if paid == displayed_price and app.game.players[buyer].cards.count(offer.id) == cards_before + 1:
							shop_purchases += 1
							shop_transactions.append({"player":buyer,"day":app.game.round_number,"card":offer.id,"displayed_price":displayed_price,"paid":paid,"policy":app.game.shop_policy})
						break
					await click("返回对局")
				await click("离开商店")
			"lottery": await click("离开乐透站")
			"magic": await click("施放 · 获得3张卡片")
			"news": await click("确认新闻")
			"minigame":
				minigames[app.game.Minigame.id(app.game)]=true
				match app.game.pending_service.game.status:
					"ready": await click("开始"+app.game.Minigame.title(app.game))
					"participant_result": await process_frame
					"result": await click("领取奖励")
					"playing":
						if app.game.Minigame.id(app.game)=="toss_dolls":
							var bin_id:int=app.game.Minigame.ai_bin(app.game)
							if bin_id>=0: await click_point(app.minigame_view.global_position+app.minigame_view.bins[bin_id].get_center())
						elif app.game.Minigame.id(app.game)=="disarm_bomb":
							var switch_id:int=app.game.Minigame.ai_switch(app.game)
							if switch_id>=0: await click_point(app.minigame_view.global_position+app.minigame_view.switches[switch_id].get_center())
						elif app.game.Minigame.id(app.game)=="shoot_balloons":
							var lane:int=app.game.Minigame.ai_lane(app.game)
							if lane>=0:await click_point(app.minigame_view.global_position+app.minigame_view.lane_buttons[lane].get_center())
						else:
							var next:int=app.game.Minigame.ai_cell(app.game)
							await click_point(app.minigame_view.global_position + app.minigame_view.cells[next].get_center())
						await create_timer(0.1).timeout
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
	if OS.get_environment("RICHMAN_TEST_REQUIRE_MINIGAME")=="1":check(not minigames.is_empty(),"natural UI match actually played a minigame")
	if OS.get_environment("RICHMAN_TEST_REQUIRE_MERCHANT")=="1":check(merchants>0,"natural UI match actually encountered a merchant")
	if OS.get_environment("RICHMAN_TEST_REQUIRE_SHOP")=="1":check(shop_purchases>0,"natural UI match actually purchased from an ordinary shop")
	if OS.get_environment("RICHMAN_TEST_REQUIRE_INFLATION")=="1":
		check(app.game.economy_config.policy=="r16_samples" and app.game.price_index()>1,"natural UI match crossed an inflation boundary")
	if team_match:
		check(app.game.winners.size()>=2 and app.game.same_team(0,2), "team configuration persists through natural result")
	await capture("07-natural-results")
	print("FULL_UI_MATCH actions=%d rounds=%d failures=%d" % [actions,app.game.round_number,failures])
	print("FULL_UI_MINIGAMES ",minigames.keys())
	print("FULL_UI_MERCHANT_ACTIONS ",merchants)
	print("FULL_UI_SHOP_PURCHASES ",shop_purchases," transactions=",shop_transactions)
	print("FULL_UI_ECONOMY ",app.game.economy_config," final_price=",app.game.price_index())
	quit(1 if failures > 0 else 0)
