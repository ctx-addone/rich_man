extends "res://tests/ui_test.gd"
func road()->int:
	for node in app.game.nodes:
		if node.kind=="minigame":return node.id
	return -1
func run()->void:
	out_dir="res://docs/testing/round15"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.shop_policy = "legacy_v8" # Preserve historical scenarios; R18 covers the new shop.
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.map_id="knight_manor";app.controllers.assign(["human","human","human","human"])
	app.talents_enabled=false;app.gods_enabled=false
	app.save_directory="res://.godot/r15-bomb-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏");await click("选择角色");await click("开始对局");await click("我已就位")
	app.gm_used=true;app.game.gm_teleport(0,road());app.refresh()
	await click("GM · F1");await click("准备 · 拆炸弹")
	check(app.game.Minigame.id(app.game)=="disarm_bomb","GM picker opens actual bomb preparation")
	await capture("06-bomb-preview")
	var before:Array=[]
	for p in app.game.players:before.append(p.cash)
	await click("开始拆炸弹")
	await click_point(app.minigame_view.global_position+app.minigame_view.switches[0].get_center())
	check(app.game.pending_service.game.opened.is_empty(),"preview cannot be clicked for an early reward")
	while app.game.pending_service.game.stage!="shuffle":await process_frame
	await click("暂停小游戏")
	var frozen:Dictionary=app.Saves.snapshot(app.game)
	await create_timer(0.65).timeout
	check(app.Saves.snapshot(app.game)==frozen,"shuffle pause freezes RNG, swaps and clock")
	await capture("07-bomb-shuffle-pause")
	await click("继续小游戏")
	var save:Dictionary=app.save_snapshot("拆炸弹洗牌中")
	check(save.ok and app.load_snapshot(save.path).ok,"shuffle saves and restores through UI")
	frozen=app.Saves.snapshot(app.game)
	await create_timer(0.6).timeout
	check(app.Saves.snapshot(app.game)==frozen,"loaded shuffle waits for human handoff")
	await click("我已就位")
	while app.game.pending_service.game.stage!="choose":await process_frame
	var activity:Dictionary=app.game.pending_service.game
	check(activity.swaps.size()==6,"visible swap sequence completes before choices")
	var safe:int=app.game.Minigame.ai_switch(app.game)
	await click_point(app.minigame_view.global_position+app.minigame_view.switches[safe].get_center())
	check(activity.score==2500 and activity.opened==[safe],"real switch click reveals coin and adds observed score")
	await click_point(app.minigame_view.global_position+app.minigame_view.switches[safe].get_center())
	check(activity.score==2500 and activity.opened==[safe],"same switch cannot reward twice")
	await capture("08-bomb-coin")
	# Follow the public preview and swap history to deliberately select a bomb.
	var remembered:Array=[0,1,2,3,4,5]
	for pair in activity.swaps:
		var old:int=remembered[pair[0]];remembered[pair[0]]=remembered[pair[1]];remembered[pair[1]]=old
	var bomb_index:int=-1
	for index in range(6):
		if activity.initial[remembered[index]]=="bomb":bomb_index=index;break
	await click_point(app.minigame_view.global_position+app.minigame_view.switches[bomb_index].get_center())
	check(activity.status=="result" and activity.history.size()==4,"bomb ends trigger and automatically settles other humans")
	check(activity.history[0].reason=="bomb" and activity.history[0].score==2500,"explosion preserves already earned score")
	await capture("09-bomb-results")
	var awards:Array=activity.history.duplicate(true)
	await click("领取奖励")
	for award in awards:check(app.game.players[award.player].cash==before[award.player]+award.reward,"bomb results pay every recorded seat once")
	check(app.game.phase=="land" and not app.game.Minigame.close(app.game),"bomb returns to board and repeat claim fails")
	print("ROUND15_BOMB_UI failures=",failures)
	quit(1 if failures else 0)
