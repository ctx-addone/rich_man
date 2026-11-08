extends "res://tests/ui_test.gd"

func choose_team(seat:int,team_id:int)->void:
	var choice:OptionButton=app.find_child("TeamChoice%d"%seat,true,false)
	check(choice!=null,"team selector exists")
	choice.select(team_id)
	choice.item_selected.emit(team_id)
	await process_frame

func run()->void:
	out_dir="res://docs/testing/round10"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	# Historical-rule regression; round16 setup tests cover modern new games.
	app.economy_config = app.Game.Economy.legacy()
	app.controllers.assign(["human","human","human","human"])
	app.talents_enabled=false
	app.gods_enabled=false
	app.save_directory="res://.godot/r10-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	await click("选择角色")
	await click("2 对 2")
	check(app.teams==[0,1,0,1],"preset configures two alternating teams")
	await capture("01-team-setup")
	await choose_team(1,0)
	await choose_team(3,0)
	check(find_button(app,"开始对局").disabled,"one-team game is blocked in setup")
	await click("2 对 2")
	await click("开始对局")
	await click("我已就位")
	check(app.game.same_team(0,2) and app.game.is_opponent(0,1),"actual game uses selected relations")
	app.gm_used=true
	var lot:Dictionary=app.game.lots.lot_1_1
	lot.owner=2;lot.building_type="hotel";lot.level=1
	var friend_cash:int=app.game.players[2].cash
	app.game.gm_teleport(0,int(lot.frontage_nodes[0]))
	app.refresh()
	check(app.game.phase=="land" and app.game.players[0].status.is_empty() and app.game.players[0].cash==10000,"teammate hotel neither charges nor detains")
	await capture("02-allied-hotel")
	await click("升级建筑")
	check(lot.owner==2 and lot.level==2 and app.game.players[0].cash==9400 and app.game.players[2].cash==friend_cash,"UI upgrade uses actor cash and retains teammate property")
	var saved:Dictionary=app.save_snapshot("组队协作")
	check(saved.ok,"team game saves")
	if saved.ok:
		app.teams.assign([0,1,2,3])
		check(app.load_snapshot(saved.path).ok and app.teams==[0,1,0,1],"load restores team setup and runtime relations")
		await click("我已就位")
	await capture("03-team-loaded")
	# Construct a result where the richest individual is on the losing team.
	app.game.players[0].cash=5000;app.game.players[2].cash=5000
	app.game.players[1].cash=9000;app.game.players[3].cash=500
	app.game.finish_game();app.refresh()
	check(app.screen=="results" and app.game.winners==[0,2],"result uses combined team assets")
	await capture("04-team-results")
	await click("相同设置")
	check(app.teams==[0,1,0,1] and app.game.same_team(0,2),"rematch retains team assignment")
	# The final natural match exercises the real UI driver without GM actions.
	app.controllers.assign(["ai","ai","ai","ai"])
	app.talents_enabled=true;app.gods_enabled=true;app.turns=10;app.ai_delay=0.01
	app.start_game()
	var frames:int=0
	while app.screen=="game" and frames<16000:
		await process_frame
		frames+=1
	check(app.screen=="results" and not app.gm_used and app.game.winners.size()>=2,"natural team AI match reaches team result without GM")
	await capture("05-team-ai-results")
	print("ROUND10_UI failures=",failures," frames=",frames)
	quit(1 if failures else 0)
