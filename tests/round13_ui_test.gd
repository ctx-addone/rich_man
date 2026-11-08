extends "res://tests/ui_test.gd"

func run()->void:
	out_dir="res://docs/testing/round13"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human","human","human","human"])
	app.save_directory="res://.godot/r13-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	var maps:OptionButton=app.find_child("MapChoice",true,false)
	check(maps.item_count==2 and not maps.is_item_disabled(1),"knight selectable")
	maps.select(1);maps.item_selected.emit(1)
	await capture("01-knight-preview")
	await click("选择角色");await click("开始对局");await click("我已就位")
	check(app.game.map_id=="knight_manor" and app.game.nodes.size()==102 and app.game.lots.size()==69,"selected knight world created")
	await capture("02-knight-overview")
	var checkpoint:Dictionary=app.Saves.snapshot(app.game)
	for ignored in range(4): await click("＋")
	await click("定位当前角色")
	check(app.board.zoom_factor>2.0,"zoom controls magnify dense map")
	check(app.board.points[app.game.players[app.game.current].pos].distance_to(app.board.size/2)<1.0,"focus centers current player")
	check(app.Saves.snapshot(app.game)==checkpoint,"camera does not alter simulation or random state")
	await capture("03-knight-zoom")
	# Wheel and drag are routed through actual viewport input.
	var point:Vector2=app.board.global_position+app.board.size/2
	var wheel:=InputEventMouseButton.new();wheel.position=point;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	root.push_input(wheel,true)
	var wheel_up:=InputEventMouseButton.new();wheel_up.position=point;wheel_up.button_index=MOUSE_BUTTON_WHEEL_UP;wheel_up.pressed=false
	root.push_input(wheel_up,true);await process_frame
	var old_pan:Vector2=app.board.pan_offset
	var down:=InputEventMouseButton.new();down.position=point;down.button_index=MOUSE_BUTTON_RIGHT;down.pressed=true
	root.push_input(down,true)
	var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(30,20);motion.relative=Vector2(30,20);motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion,true)
	var up:=InputEventMouseButton.new();up.position=motion.position;up.button_index=MOUSE_BUTTON_RIGHT;up.pressed=false
	root.push_input(up,true);await process_frame
	check(app.board.pan_offset==old_pan+Vector2(30,20),"right drag pans board through viewport")
	await click("全图")
	print("VIEW_RESET zoom=",app.board.zoom_factor," pan=",app.board.pan_offset)
	check(app.board.zoom_factor==1.0 and app.board.pan_offset==Vector2.ZERO,"overview resets view")
	var pick:String=app.game.lots.keys()[0]
	await click_point(app.board.global_position+app.board.lot_rects[pick].get_center())
	check(app.selected_lot==pick,"property can be selected at overview scale")
	var saved:Dictionary=app.save_snapshot("骑士庄园验证")
	check(saved.ok,"knight world saves")
	if saved.ok:
		app.map_id="integration_city"
		check(app.load_snapshot(saved.path).ok and app.map_id=="knight_manor","load restores knight map and static metadata")
	app.controllers.assign(["ai","ai","ai","ai"]);app.turns=20;app.ai_delay=0.01;app.start_game()
	var frames:=0
	while app.screen=="game" and frames<18000: await process_frame;frames+=1
	check(app.screen=="results" and not app.gm_used,"natural knight match completes without GM")
	await capture("04-knight-results")
	await click("相同设置")
	check(app.game.map_id=="knight_manor","rematch retains knight map")
	print("ROUND13_UI failures=",failures," frames=",frames)
	quit(1 if failures else 0)
