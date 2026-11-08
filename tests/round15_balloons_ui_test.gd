extends "res://tests/ui_test.gd"
func road()->int:
	for node in app.game.nodes:
		if node.kind=="minigame":return node.id
	return -1
func run()->void:
	out_dir="res://docs/testing/round15"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.map_id="knight_manor";app.controllers.assign(["human","human","human","human"])
	app.talents_enabled=false;app.gods_enabled=false
	app.save_directory="res://.godot/r15-balloons-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏");await click("选择角色");await click("开始对局");await click("我已就位")
	app.gm_used=true;app.game.gm_teleport(0,road());app.refresh()
	await click("GM · F1");await click("准备 · 打气球")
	check(app.game.Minigame.id(app.game)=="shoot_balloons","GM picker opens balloon preparation")
	await capture("10-balloons-ready")
	var before:Array=[]
	for p in app.game.players:before.append(p.cash)
	await click("开始打气球")
	var lane:int=app.game.Minigame.ai_lane(app.game)
	var guard:=0
	while lane<0 and guard<200:
		await create_timer(0.05).timeout
		lane=app.game.Minigame.ai_lane(app.game);guard+=1
	check(lane>=0,"visible safe target appears")
	if lane<0:quit(1);return
	await click_point(app.minigame_view.global_position+app.minigame_view.lane_buttons[lane].get_center())
	check(app.game.pending_service.game.choice==lane,"real cannon button queues column shot")
	await click("暂停小游戏")
	var frozen:Dictionary=app.Saves.snapshot(app.game)
	await create_timer(0.65).timeout
	check(app.Saves.snapshot(app.game)==frozen,"balloons, pending shot, score and RNG freeze")
	await capture("11-balloons-pause")
	await click("继续小游戏")
	var save:Dictionary=app.save_snapshot("打气球待发射")
	check(save.ok and app.load_snapshot(save.path).ok,"column shot and flying positions save and restore")
	frozen=app.Saves.snapshot(app.game)
	await create_timer(0.6).timeout
	check(app.Saves.snapshot(app.game)==frozen,"loaded balloon game waits for handoff")
	await click("我已就位")
	var budget:=0
	while app.game.pending_service.game.status!="result" and budget<1200:
		if app.game.pending_service.game.status=="playing" and app.game.pending_service.game.choice==-1:
			lane=app.game.Minigame.ai_lane(app.game)
			if lane>=0:await click_point(app.minigame_view.global_position+app.minigame_view.lane_buttons[lane].get_center())
		if budget==80:await capture("12-balloons-playing")
		await create_timer(0.05).timeout;budget+=1
	var activity:Dictionary=app.game.pending_service.game
	check(activity.status=="result" and activity.history.size()==4,"balloon manual game leads to automatic other-seat scores")
	check(activity.history[0].score>0,"visible target firing earns positive score")
	await capture("13-balloons-results")
	var awards:Array=activity.history.duplicate(true)
	await click("领取奖励")
	for award in awards:check(app.game.players[award.player].cash==before[award.player]+award.reward,"balloon result pays every seat once")
	check(app.game.phase=="land" and not app.game.Minigame.close(app.game),"balloon returns to board and prevents double award")
	print("ROUND15_BALLOONS_UI failures=",failures," manual_frames=",budget)
	quit(1 if failures else 0)
