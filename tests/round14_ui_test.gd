extends "res://tests/ui_test.gd"

func road(kind:String)->int:
	for node in app.game.nodes:
		if node.kind==kind:return node.id
	return -1
func run()->void:
	out_dir="res://docs/testing/round14"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.map_id="knight_manor"
	app.controllers.assign(["human","human","human","human"])
	app.talents_enabled=false;app.gods_enabled=false
	app.save_directory="res://.godot/r14-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏");await click("选择角色");await click("开始对局");await click("我已就位")
	app.gm_used=true
	app.game.send_to_facility(1,"prison",2);app.game.send_to_facility(2,"hospital",2)
	for seed_value in range(1,100):
		var rng=RandomNumberGenerator.new();rng.seed=seed_value
		if app.game.News.TEST_PROFILE.event_ids[rng.randi_range(0,app.game.News.TEST_PROFILE.event_ids.size()-1)]=="release_prisoners":
			app.game.rng.seed=seed_value;break
	app.game.gm_teleport(0,road("news"));app.refresh()
	check(app.game.phase=="news","news opens from actual map landing")
	await capture("01-news-release")
	var news:Dictionary=app.save_snapshot("待结算新闻")
	check(news.ok and app.load_snapshot(news.path).ok,"pending news saves and restores from UI")
	await click("我已就位");await click("确认新闻")
	check(app.game.players[1].status.is_empty() and app.game.players[2].status.kind=="hospital","news releases prison but preserves hospital")
	app.game.gm_teleport(0,road("minigame"));app.game.Minigame.gm_choose_ready(app.game,"catch_coins");app.refresh()
	var balances:Array=[]
	for player in app.game.players: balances.append(player.cash)
	check(app.game.pending_service.game.status=="ready","minigame waits for explicit start")
	await capture("02-minigame-ready")
	await click("开始接金币")
	var target:int=app.game.Minigame.ai_cell(app.game)
	await click_point(app.minigame_view.global_position+app.minigame_view.cells[target].get_center())
	check(app.game.pending_service.game.cell==target,"actual grid click moves basket")
	await create_timer(0.55).timeout
	check(app.game.pending_service.game.tick>=1,"real timer advances falling objects")
	await click("暂停小游戏")
	var frozen:Dictionary=app.Saves.snapshot(app.game)
	await create_timer(0.65).timeout
	check(app.Saves.snapshot(app.game)==frozen,"pause freezes score, tick and RNG")
	await capture("03-minigame-pause")
	await click("继续小游戏")
	var save:Dictionary=app.save_snapshot("接金币进行中")
	check(save.ok and app.load_snapshot(save.path).ok,"running minigame restores")
	frozen=app.Saves.snapshot(app.game)
	await create_timer(0.6).timeout
	check(app.Saves.snapshot(app.game)==frozen,"loaded minigame waits for hotseat handoff")
	await click("我已就位")
	var budget:=0
	var manual_starts:=1
	while app.game.pending_service.game.status!="result" and budget<700:
		if app.handoff: await click("我已就位")
		elif app.game.pending_service.game.status=="ready":
			manual_starts+=1
			await click("开始接金币")
		elif app.game.pending_service.game.status=="participant_result": await process_frame
		else:
			var next:int=app.game.Minigame.ai_cell(app.game)
			await click_point(app.minigame_view.global_position+app.minigame_view.cells[next].get_center())
		await create_timer(0.1).timeout
		budget+=1
	check(app.game.pending_service.game.status=="result","human minigame reaches results")
	check(manual_starts==1 and app.game.pending_service.game.history.size()==4,"only trigger seat plays manually; other local human seats receive automatic scores")
	var awards:Array=app.game.pending_service.game.history.duplicate(true)
	await capture("04-minigame-result")
	var before:int=app.game.players[0].cash
	var reward:int=app.game.pending_service.game.history[0].reward
	await click("领取奖励")
	check(app.game.phase=="land" and app.game.players[0].cash==before+reward,"reward paid once and board restored")
	for award in awards: check(app.game.players[award.player].cash==balances[award.player]+award.reward,"each seat receives its own recorded reward exactly once")
	check(not app.game.Minigame.close(app.game),"repeated award rejected")
	# Prepare a turn on the same road; card confirmation and GO use actual UI input.
	app.game.phase="roll";app.game.players[0].cards=["stay"];app.handoff=false;app.refresh()
	var stay_pos:int=app.game.players[0].pos
	await click("停留卡");await click("确认使用");await click("掷骰子")
	check(app.game.phase=="minigame" and app.game.players[0].pos==stay_pos,"stay card UI re-enters current minigame without movement")
	await capture("06-stay-reentry")
	app.controllers.assign(["ai","ai","ai","ai"]);app.ai_paused=false;app.ai_delay=0.01;app.turns=20;app.start_game()
	var frames:=0
	while app.screen=="game" and frames<22000:await process_frame;frames+=1
	check(app.screen=="results" and not app.gm_used,"natural AI match completes with news and minigame")
	await capture("05-natural-match")
	print("ROUND14_UI failures=",failures," frames=",frames)
	quit(1 if failures else 0)
