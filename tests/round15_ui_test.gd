extends "res://tests/ui_test.gd"

func road()->int:
	for node in app.game.nodes:
		if node.kind=="minigame":return node.id
	return -1
func run()->void:
	out_dir="res://docs/testing/round15"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.map_id="knight_manor";app.controllers.assign(["human","human","human","human"])
	app.talents_enabled=false;app.gods_enabled=false
	app.save_directory="res://.godot/r15-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏");await click("选择角色");await click("开始对局");await click("我已就位")
	app.gm_used=true;app.game.gm_teleport(0,road());app.refresh()
	await click("GM · F1");await click("准备 · 投娃娃")
	check(app.game.Minigame.id(app.game)=="toss_dolls","GM picker opens real doll preparation")
	await capture("01-dolls-ready")
	var before_cash:Array=[]
	for p in app.game.players:before_cash.append(p.cash)
	await click("开始投娃娃")
	var target:int=app.game.Minigame.ai_bin(app.game)
	await click_point(app.minigame_view.global_position+app.minigame_view.bins[target].get_center())
	check(app.game.pending_service.game.choice==target,"viewport bin click locks current object")
	await click_point(app.minigame_view.global_position+app.minigame_view.bins[(target+1)%3].get_center())
	check(app.game.pending_service.game.choice==target,"rapid second click cannot throw same object twice")
	await click("暂停小游戏")
	var frozen:Dictionary=app.Saves.snapshot(app.game)
	await create_timer(0.7).timeout
	check(app.Saves.snapshot(app.game)==frozen,"doll timer, locked throw and RNG freeze in pause")
	await capture("02-dolls-paused")
	await click("继续小游戏")
	var save:Dictionary=app.save_snapshot("投娃娃待投掷")
	check(save.ok and app.load_snapshot(save.path).ok,"pending throw saves and loads through UI")
	frozen=app.Saves.snapshot(app.game)
	await create_timer(0.6).timeout
	check(app.Saves.snapshot(app.game)==frozen,"restored pending throw waits for hotseat handoff")
	await click("我已就位")
	var budget:=0
	while app.game.pending_service.game.status!="result" and budget<1000:
		if app.game.pending_service.game.status=="playing" and app.game.pending_service.game.choice==-1:
			target=app.game.Minigame.ai_bin(app.game)
			await click_point(app.minigame_view.global_position+app.minigame_view.bins[target].get_center())
		if budget==25:await capture("03-dolls-playing")
		await create_timer(0.05).timeout
		budget+=1
	check(app.game.pending_service.game.status=="result","manual throws reach all-seat results")
	check(app.game.pending_service.game.history.size()==4 and app.game.pending_service.game.history[0].reason=="queue_empty","finite queue ends early and other human seats settle automatically")
	var awards:Array=app.game.pending_service.game.history.duplicate(true)
	await capture("04-dolls-results")
	await click("领取奖励")
	check(app.game.phase=="land","dolls return to board")
	for award in awards:check(app.game.players[award.player].cash==before_cash[award.player]+award.reward,"all four seats paid recorded award exactly once")
	check(not app.game.Minigame.close(app.game),"repeat doll claim rejected")
	# Old v5 model remains usable in the new UI, with AI resume preserving control.
	var old:Dictionary=app.load_snapshot("res://tests/fixtures/round14-v5-minigame.rms")
	check(old.ok and app.game.Minigame.id(app.game)=="catch_coins","genuine v5 mid-coin save enters updated UI")
	await capture("05-legacy-coins")
	print("ROUND15_UI failures=",failures," manual_frames=",budget)
	quit(1 if failures else 0)
