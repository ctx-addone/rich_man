extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const Main=preload("res://scripts/main.gd")
const MiniView=preload("res://scripts/minigame_view.gd")
var failures:int=0
var interruption_cases:int=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr(label)
func fresh():
	var g=Game.new();g.setup(["A","B","C","D"],1444,20,{"map_id":"knight_manor","specials_enabled":true})
	return g
func road(g,kind:String)->int:
	for node in g.nodes:
		if node.kind==kind:return node.id
	return -1
func enter_stage(g,stage:String)->void:
	check(g.gm_teleport(g.current,road(g,"news" if stage=="news" else "minigame")),"GM service entry")
	if stage=="news":g.pending_service.event_id="house_subsidy"
	elif stage in ["playing","participant_result","other_ready","other_playing","result"]:
		g.Minigame.start(g);g.Minigame.ai_step(g)
		if stage!="playing":
			while g.pending_service.game.status=="playing":g.Minigame.ai_step(g)
			check(g.pending_service.game.status=="participant_result","trigger finishes before other participants")
			if stage=="result":check(g.Minigame.settle_others(g),"other participants settle to final result")
			elif stage in ["other_ready","other_playing"]:
				check(g.Minigame.next_player(g),"internal next participant begins")
				if stage=="other_playing":g.Minigame.start(g);g.Minigame.ai_step(g)
				check(g.pending_service.game.player!=g.current,"internal participant is not board-turn owner")
func serializable(g,label:String)->void:
	var snapshot:Dictionary=Save.snapshot(g)
	var result:Dictionary=Save.restore(snapshot)
	check(result.ok,label+" restores: "+str(result.get("error","")))
	if result.ok:check(Save.snapshot(result.game)==snapshot,label+" exact restored state")
func _init()->void:
	for stage in ["news","ready","playing","participant_result","other_ready","other_playing","result"]:
		for action in ["hospital","prison","vacation","teleport","fierce","finish"]:
			var g=fresh();enter_stage(g,stage)
			var before:Array=[]
			for p in g.players:before.append(p.cash)
			match action:
				"hospital","prison":check(g.send_to_facility(0,action,2),"GM detention succeeds")
				"vacation":g.send_on_vacation(0,g.lots.keys()[0])
				"teleport":check(g.gm_teleport(0,road(g,"road")),"GM teleport away succeeds")
				"fierce":check(g.gm_god(0,"fierce"),"GM fierce attachment succeeds")
				"finish":g.finish_game()
			check(g.phase not in ["news","minigame"] and g.pending_service.is_empty(),stage+" interrupted by "+action+" clears service")
			for who in range(g.players.size()):check(g.players[who].cash==before[who],stage+" interrupted by "+action+" never pays any participant's outstanding reward")
			check(not g.News.resolve(g) and not g.Minigame.close(g) and not g.Minigame.tick(g),"stale commands rejected after "+action)
			serializable(g,stage+" / "+action)
			interruption_cases+=1
		# Unrelated GM actions must preserve a live service and pending outcome.
		var g=fresh();enter_stage(g,stage)
		var pending:Dictionary=g.pending_service.duplicate(true)
		check(g.gm_cash(1,1000) and g.gm_vehicle(0,"car") and g.gm_give_card(1,"immune") and g.send_to_facility(2,"prison",2),"non-interrupting GM actions execute")
		check(g.pending_service==pending and g.phase in ["news","minigame"],"unrelated GM action does not erase pending "+stage)
		serializable(g,stage+" / unrelated GM")
	# Chaining a GM relocation between services must not settle the old service.
	var g=fresh();enter_stage(g,"result")
	var cash:int=g.players[0].cash
	g.gm_teleport(0,road(g,"news"));g.pending_service.event_id="house_subsidy"
	check(g.phase=="news" and g.players[0].cash==cash,"result-to-news relocation discards prior payout")
	check(g.News.resolve(g) and g.players[0].cash==cash+g.News.TEST_PROFILE.house_subsidy_amount,"only replacement news effect settles")
	serializable(g,"service-to-service relocation")
	# Internal background simulation may be persisted, but never changes board-turn
	# ownership or pays early; restoring it must produce the same complete table.
	for stage in ["participant_result","other_ready","other_playing"]:
		g=fresh();enter_stage(g,stage)
		var loaded:Dictionary=Save.restore(Save.snapshot(g))
		check(loaded.ok,"internal participant stage restores: "+stage)
		if not loaded.ok:continue
		var twin=loaded.game
		check(g.Minigame.settle_others(g) and twin.Minigame.settle_others(twin),"background participants finish after restore")
		check(Save.snapshot(g)==Save.snapshot(twin) and g.current==0,"background results and RNG reproduce with board current unchanged")
		for p in g.players:check(p.cash==10000,"all-seat cash remains unchanged until final confirmation")
		var history:Array=g.pending_service.game.history.duplicate(true)
		check(history.size()==4 and g.Minigame.close(g),"final confirmation pays full participant table")
		for record in history:check(g.players[record.player].cash==10000+record.reward,"each participant receives its own score once")
		check(not g.Minigame.close(g),"all-seat reward cannot be replayed")
	# A real v4 map snapshot must keep static identity while adopting new runtime hooks.
	var legacy:Dictionary=Save.load_from_file("res://tests/fixtures/round13-v4.rms")
	check(legacy.ok,"authentic v4 file accepted after service upgrade")
	if legacy.ok:
		g=legacy.game
		var file=FileAccess.open("res://tests/fixtures/round13-v4.rms",FileAccess.READ);file.seek(44)
		var original:Dictionary=bytes_to_var(file.get_buffer(file.get_length()-44))
		check(g.nodes==original.state.nodes and g.map_metadata==original.state.map_metadata,"v4 nodes and map metadata retained exactly")
		check(g.start_road==-1 and g.map_metadata.spawn_roads==original.state.map_metadata.spawn_roads,"v4 no-start and spawn meanings retained")
		var changed:Dictionary=original.duplicate(true);changed.state.nodes[road(g,"news")].kind="event"
		check(not Save.restore(changed).ok,"v4 cannot substitute random-event semantics for news map identity")
		changed=original.duplicate(true);changed.state.map_metadata.spawn_roads.reverse()
		check(not Save.restore(changed).ok,"v4 cannot alter map spawn metadata")
		g.gm_teleport(g.current,road(g,"news"))
		check(g.phase=="news","migrated v4 match enters newly implemented news")
		serializable(g,"v4 resumed in news")
	# UI-specific regression: resumed AI game has handoff=true until its next action.
	# Human acknowledgement must not block an AI seat after the user resumes AI.
	g=fresh();enter_stage(g,"playing")
	var app=Main.new()
	app.game=g;app.screen="game";app.controllers.assign(["ai","ai","ai","ai"])
	app.handoff=true;app.ai_paused=false;app.popup=null
	app.minigame_view=MiniView.new();app.add_child(app.minigame_view)
	var tick_before:int=g.pending_service.game.tick
	app._process(g.Minigame.TEST_PROFILE.tick_seconds)
	check(g.pending_service.game.tick==tick_before+1,"loaded AI minigame resumes without inaccessible human handoff")
	app.ai_paused=true;tick_before=g.pending_service.game.tick
	app._process(g.Minigame.TEST_PROFILE.tick_seconds)
	check(g.pending_service.game.tick==tick_before,"AI pause still blocks timer")
	app.controllers.assign(["human","human","human","human"]);app.ai_paused=false;app.handoff=true
	app._process(g.Minigame.TEST_PROFILE.tick_seconds)
	check(g.pending_service.game.tick==tick_before,"human hotseat handoff still blocks timer")
	g=fresh();enter_stage(g,"other_playing");app.game=g
	app.controllers.assign(["human","ai","ai","ai"])
	check(app.automated_seat()==g.current and not app.is_automated(),"automatic opponent scoring does not switch UI ownership away from trigger")
	app.free()
	print("ROUND14_REVIEW_TEST failures=",failures," interrupted=",interruption_cases)
	quit(0 if failures==0 else 1)
