extends "res://tests/ui_test.gd"
const Magic=preload("res://scripts/model/magic_house.gd")
func seed_condition(condition:String)->void:
	for value in range(1,1000):
		var probe=RandomNumberGenerator.new();probe.seed=value
		if Magic.CONDITIONS[probe.randi_range(0,Magic.CONDITIONS.size()-1)]==condition:app.game.rng.seed=value;return
func run()->void:
	out_dir="res://docs/testing/round12"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human","human","human","human"])
	app.gods_enabled=false;app.talents_enabled=false
	root.add_child(app)
	await click("开始游戏");await click("选择角色");await click("开始对局");await click("我已就位")
	app.gm_used=true
	app.game.gm_teleport(0,17);app.refresh()
	var numbers:OptionButton=app.find_child("LotteryNumber",true,false)
	check(numbers!=null and numbers.item_count==30,"all thirty lottery numbers exposed")
	numbers.select(29)
	await click("购入一注")
	check(app.game.lottery_state.tickets[0].number==30,"UI can purchase number thirty")
	await capture("01-lottery-thirty")
	await click("离开乐透站")
	app.game.phase="roll";app.game.players[0].vehicle="car";app.game.gm_teleport(0,51);app.refresh()
	for option in Magic.CATALOG:check(find_button(app,"施放 · "+option.name)!=null,"effect button exists: "+option.id)
	await capture("02-nine-magic-top")
	seed_condition("car")
	await click("施放 · 原地停留1天")
	check(app.game.phase=="land" and app.game.players[0].stay_turns==1,"last effect accessible through scrolling and applies")
	app.game.phase="roll";app.game.gm_teleport(0,51);app.refresh();seed_condition("car")
	await click("施放 · 摧毁载具")
	check(app.game.players[0].vehicle=="foot","vehicle effect executes from UI")
	app.game.phase="roll";app.game.players[1].vehicle="car";app.game.players[1].cards=["immune"]
	app.game.gm_teleport(0,51);app.refresh();seed_condition("car")
	await click("施放 · 入狱1天")
	check(app.game.phase=="reaction" and app.game.reaction_player()==1,"magic prison hands control to victim")
	await capture("03-magic-defense")
	# Complete via public defense command; existing handoff UI tests cover the buttons.
	app.game.resolve_reaction("immune");app.refresh()
	check(app.game.phase=="land" and app.game.players[1].status.is_empty(),"magic defense returns to current actor")
	app.controllers.assign(["ai","ai","ai","ai"]);app.turns=20;app.ai_delay=0.01
	app.gods_enabled=true;app.talents_enabled=true;app.start_game()
	var frames:=0
	while app.screen=="game" and frames<16000:await process_frame;frames+=1
	check(app.screen=="results" and not app.gm_used,"natural AI match completes with expanded magic")
	await capture("04-natural-result")
	print("ROUND12_UI failures=",failures," frames=",frames)
	quit(1 if failures else 0)
