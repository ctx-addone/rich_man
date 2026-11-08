extends "res://tests/ui_test.gd"

func run()->void:
	out_dir="res://docs/testing/round11"
	root.size=Vector2i(1440,900)
	app=load("res://scenes/main.tscn").instantiate()
	app.shop_policy = "legacy_v8" # Preserve historical scenarios; R18 covers the new shop.
	app.npcs_enabled = false # Preserve the pre-NPC scenario; R17 tests cover NPCs.
	app.controllers.assign(["human","human","human","human"])
	app.save_directory="res://.godot/r11-ui-%d"%Time.get_ticks_usec()
	root.add_child(app)
	await click("开始游戏")
	var maps:OptionButton=app.find_child("MapChoice",true,false)
	check(maps!=null and maps.item_count==2,"map registry shown in selection")
	check(maps.get_item_metadata(0)=="integration_city" and not maps.is_item_disabled(0),"validated map selectable")
	check(maps.get_item_metadata(1)=="knight_manor" and not maps.is_item_disabled(1),"validated knight layout selectable")
	await capture("01-map-selection")
	await click("选择角色")
	await click("开始对局")
	await click("我已就位")
	check(app.game.map_id=="integration_city" and app.top_title.text.begins_with(app.game.map_metadata.name),"selected map title comes from metadata")
	var old_game=app.game
	app.map_id="not_registered"
	app.start_game()
	check(app.game==old_game and app.screen=="game","invalid start preserves current live game")
	app.map_id="integration_city"
	var saved:Dictionary=app.save_snapshot("地图配置测试")
	check(saved.ok,"v4 map saves")
	if saved.ok:
		app.map_id="knight_manor"
		check(app.load_snapshot(saved.path).ok and app.map_id=="integration_city","load restores selected map")
		await click("我已就位")
	await capture("02-loaded-map")
	app.controllers.assign(["ai","ai","ai","ai"])
	app.turns=10;app.ai_delay=0.01
	app.start_game()
	var frames:=0
	while app.screen=="game" and frames<16000:
		await process_frame
		frames+=1
	check(app.screen=="results" and not app.gm_used,"natural AI match reaches results after map refactor")
	await capture("03-natural-results")
	await click("相同设置")
	check(app.game.map_id=="integration_city","rematch retains map")
	print("ROUND11_UI failures=",failures," frames=",frames)
	quit(1 if failures else 0)
