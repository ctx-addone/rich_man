extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Save = preload("res://scripts/model/save_game.gd")
var failures:int = 0
var interruption_cases:int = 0
var ui_cases:int = 0
var app:Control

func check(ok:bool,label:String) -> void:
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	call_deferred("run")

func road(g,kind:String) -> int:
	for node in g.nodes:
		if node.kind == kind: return node.id
	return -1

func phases(game_id:String) -> Array:
	var result:Array = ["ready","playing","participant_result","result"]
	if game_id == "disarm_bomb": result.append_array(["shuffle","choose"])
	return result

func fixture(game_id:String, stage:String):
	var g = Game.new()
	check(g.setup(["A","B","C","D"],1517,35,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":false,"talents_enabled":false}),"review setup")
	# Legitimate hotel supports a real vacation state, without bypassing save checks.
	for lot in g.lots.values():
		if lot.kind == "large":
			lot.owner = 1; lot.level = 1; lot.building_type = "hotel"
			break
	check(g.gm_teleport(0,road(g,"minigame")) and g.Minigame.gm_choose_ready(g,game_id),"review enters selected service")
	if stage != "ready": check(g.Minigame.start(g),"review starts service")
	if stage in ["shuffle","choose"]:
		var budget:int = 100
		while g.pending_service.game.stage != stage and budget > 0:
			g.Minigame.tick(g); budget -= 1
		check(budget > 0,"requested disarm substage reached")
	elif stage in ["participant_result","result"]:
		var budget:int = 500
		while g.pending_service.game.status == "playing" and budget > 0:
			g.Minigame.ai_step(g); budget -= 1
		check(budget > 0 and g.pending_service.game.status == "participant_result","first participant finishes without claiming")
		if stage == "result": check(g.Minigame.settle_others(g),"others produce unclaimed final result")
	return g

func balances(g) -> Array:
	var result:Array = []
	for player in g.players: result.append([player.cash,player.deposit])
	return result

func restored(g,label:String):
	var raw:Dictionary = Save.snapshot(g)
	var loaded:Dictionary = Save.restore(raw)
	check(loaded.ok,label+" restores: "+str(loaded.get("error","")))
	if not loaded.ok: return null
	check(Save.snapshot(loaded.game) == raw,label+" preserves exact state/RNG")
	return loaded.game

func interrupt(g,action:String) -> void:
	match action:
		"hospital","prison": check(g.send_to_facility(g.current,action,2),"facility accepts interruption")
		"teleport": check(g.gm_teleport(g.current,road(g,"unresolved")),"teleport accepts interruption")
		"fierce": check(g.gm_god(g.current,"fierce"),"fierce attaches and interrupts")
		"finish": g.finish_game()
		"vacation":
			for lot in g.lots.values():
				if lot.building_type == "hotel": g.send_on_vacation(g.current,lot.id); return

func test_interruptions() -> void:
	for game_id in Game.Minigame.TEST_POOL:
		for stage in phases(game_id):
			for action in ["hospital","prison","teleport","fierce","finish","vacation"]:
				var g = fixture(game_id,stage)
				var label:String = game_id+"/"+stage+"/"+action
				var twin = restored(g,label+" before interruption")
				if twin == null: continue
				var before:Array = balances(g)
				interrupt(g,action); interrupt(twin,action)
				check(g.pending_service.is_empty() and g.phase != "minigame",label+" clears service and leaves minigame")
				check(balances(g) == before,label+" never leaks unclaimed cash or deposit")
				check(not g.Minigame.close(g) and not g.Minigame.tick(g) and not g.Minigame.settle_others(g),label+" old service commands rejected")
				check(Save.snapshot(g) == Save.snapshot(twin),label+" behaves identically after pre-interruption load")
				var after = restored(g,label+" interrupted state")
				if after != null:
					check(not after.Minigame.close(after) and balances(after) == before,label+" restored interruption cannot claim old reward")
				interruption_cases += 1

func install_ui(g,controller:String) -> void:
	if app.popup != null: app.close_popup()
	app.game = g
	app.controllers.assign([controller,controller,controller,controller])
	app.handoff = false
	app.ai_paused = false
	app.ai_delay = 0.0
	app.build_game()
	app.set_process(false)

func assert_frozen(label:String) -> void:
	var before:Dictionary = Save.snapshot(app.game)
	var elapsed:float = app.minigame_elapsed
	app._process(1.25)
	check(Save.snapshot(app.game) == before and app.minigame_elapsed == elapsed,label+" freezes timer/state/RNG")

func test_ui_guards() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.save_directory = "res://.godot/r15-independent-review-%d" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_process(false)
	for game_id in Game.Minigame.TEST_POOL:
		for stage in phases(game_id):
			var label:String = game_id+"/"+stage
			install_ui(fixture(game_id,stage),"human")
			app.handoff = true
			assert_frozen(label+" human handoff")
			app.handoff = false
			app.show_minigame_pause()
			assert_frozen(label+" pause popup")
			app.dismiss()
			var human_save:Dictionary = app.save_snapshot("review human "+label)
			check(human_save.ok and app.load_snapshot(human_save.path).ok,label+" human UI save/load")
			check(app.handoff,label+" human load requires handoff")
			assert_frozen(label+" loaded human handoff")
			app.controllers.assign(["ai","ai","ai","ai"])
			app.handoff = false; app.ai_paused = true
			assert_frozen(label+" AI pause")
			var ai_save:Dictionary = app.save_snapshot("review AI "+label)
			check(ai_save.ok and app.load_snapshot(ai_save.path).ok,label+" AI UI save/load")
			check(app.ai_paused and app.controllers[0] == "ai",label+" AI load stays paused with controller preserved")
			assert_frozen(label+" loaded AI pause")
			var before:Dictionary = Save.snapshot(app.game)
			app.ai_paused = false; app.handoff = false
			app._process(app.game.Minigame.profile(app.game).tick_seconds+0.01)
			check(Save.snapshot(app.game) != before,label+" explicit resume advances one service action")
			ui_cases += 1
	app.queue_free()

func run() -> void:
	test_interruptions()
	test_ui_guards()
	await process_frame
	print("ROUND15_REVIEW_TEST failures=",failures," interruptions=",interruption_cases," ui_states=",ui_cases," pool=",Game.Minigame.TEST_POOL)
	quit(1 if failures else 0)
