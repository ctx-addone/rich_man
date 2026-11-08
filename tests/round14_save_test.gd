extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:=0
var rejected:=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;push_error(label)
func fresh():
	var g=Game.new();g.setup(["A","B","C","D"],1414,20,{"map_id":"knight_manor","specials_enabled":true})
	return g
func road(g,kind:String)->int:
	for node in g.nodes:
		if node.kind==kind:return node.id
	return -1
func reject(payload:Dictionary)->void:
	var before:Dictionary=payload.duplicate(true)
	check(not Save.restore(payload).ok,"invalid new service payload rejected")
	check(payload==before,"rejection preserves caller payload")
	rejected+=1
func _init()->void:
	var fixture:String="res://tests/fixtures/round13-v4.rms"
	check(FileAccess.get_sha256(fixture).to_upper()=="3F1D9982A07F8FF47F7F2057B3190DFC1C668BDB66E11AA3A2C7380968C11C4C","authentic baseline v4 fixture hash")
	var legacy:Dictionary=Save.load_from_file(fixture)
	check(legacy.ok,"authentic v4 knight snapshot migrates")
	if legacy.ok:
		var bytes=FileAccess.open(fixture,FileAccess.READ);bytes.seek(44)
		var original:Dictionary=bytes_to_var(bytes.get_buffer(bytes.get_length()-44))
		check(original.version==4 and Save.snapshot(legacy.game).state==original.state,"v4 all game state preserved")
		check(Save.snapshot(legacy.game).rng_state==original.rng_state,"v4 random state preserved")
	var g=fresh();g.gm_teleport(0,road(g,"news"))
	var news:Dictionary=Save.snapshot(g)
	check(news.version==Save.VERSION and news.state.phase=="news","news serialized in current version")
	var loaded:Dictionary=Save.restore(news)
	check(loaded.ok,"pending news restores")
	if loaded.ok:
		g.News.resolve(g);loaded.game.News.resolve(loaded.game)
		check(Save.snapshot(g)==Save.snapshot(loaded.game),"news resolves identically after load")
	for key in ["kind","road","event_id"]:
		var bad:Dictionary=news.duplicate(true);bad.state.pending_service.erase(key);reject(bad)
	var bad:Dictionary=news.duplicate(true);bad.state.pending_service.event_id="invented";reject(bad)
	bad=news.duplicate(true);bad.state.pending_service.reward=99999;reject(bad)
	bad=news.duplicate(true);bad.version=4;reject(bad)
	g=fresh();g.gm_teleport(0,road(g,"minigame"))
	check(g.Minigame.gm_choose_ready(g,"catch_coins"),"isolate catch_coins save schema")
	for stage in ["ready","playing","result"]:
		if stage=="playing":g.Minigame.start(g);g.Minigame.ai_step(g)
		if stage=="result":
			while g.pending_service.game.status!="result":g.Minigame.ai_step(g)
		var payload:Dictionary=Save.snapshot(g)
		loaded=Save.restore(payload)
		check(loaded.ok,"minigame restores "+stage)
		if loaded.ok:
			check(Save.snapshot(loaded.game)==payload,"all minigame state and RNG restored "+stage)
			var a:Dictionary=Save.restore(payload);var b:Dictionary=Save.restore(payload)
			for ignored in range(120):
				if a.game.phase!="minigame":break
				check(AI.step(a.game) and AI.step(b.game),"restored minigame advances")
				check(Save.snapshot(a.game)==Save.snapshot(b.game),"identical visible commands restore exact progression")
		for field in ["id","version","player","tick","cell","score","items","results","status","reason","reward","participants","cursor","history"]:
			bad=payload.duplicate(true);bad.state.pending_service.game.erase(field);reject(bad)
		bad=payload.duplicate(true);bad.state.pending_service.game.score+=1;reject(bad)
		bad=payload.duplicate(true);bad.state.pending_service.game.reward+=1;reject(bad)
		bad=payload.duplicate(true);bad.state.pending_service.game.tick+=1;reject(bad)
		bad=payload.duplicate(true);bad.state.pending_service.game.player=1;reject(bad)
		bad=payload.duplicate(true);bad.state.service_visited.clear();reject(bad)
		bad=payload.duplicate(true);bad.state.landing_pending=true;reject(bad)
		bad=payload.duplicate(true);bad.version=4;reject(bad)
		if stage!="result":
			bad=payload.duplicate(true);bad.state.pending_service.game.items[0].cell=bad.state.pending_service.game.items[1].cell;reject(bad)
			bad=payload.duplicate(true);bad.state.pending_service.game.items[0].kind="gold_bar";reject(bad)
	print("ROUND14_SAVE_TEST failures=",failures," rejected=",rejected)
	quit(0 if failures==0 else 1)
