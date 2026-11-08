extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const Coins=preload("res://scripts/model/catch_coins_rules.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func fresh(seed_value:int=1501):
	var g=Game.new();g.setup(["A","B","C","D"],seed_value,40,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":false,"talents_enabled":false})
	return g
func road(g)->int:
	for node in g.nodes:
		if node.kind=="minigame":return node.id
	return -1
func _init()->void:
	var fixture="res://tests/fixtures/round14-v5-minigame.rms"
	check(FileAccess.get_sha256(fixture).to_upper()=="248CB72A549F5F7A79324A8327DC1ED22D68EF1EE840ECBE30925B65E8F10FE5","authentic prior-commit v5 fixture")
	var file=FileAccess.open(fixture,FileAccess.READ);file.seek(44)
	var old:Dictionary=bytes_to_var(file.get_buffer(file.get_length()-44))
	check(old.version==5 and old.state.pending_service.game.cursor==1 and old.state.pending_service.game.tick==5,"fixture was captured midway through background second participant")
	var loaded:Dictionary=Save.load_from_file(fixture)
	check(loaded.ok,"real v5 minigame restores without new fields: "+str(loaded.get("error","")))
	if loaded.ok:
		var twin:Dictionary=Save.restore(old)
		var now:Dictionary=Save.snapshot(loaded.game,old.metadata)
		var expected:Dictionary=old.duplicate(true);expected.version=Save.VERSION
		expected.state.economy_config=Game.Economy.legacy()
		check(now==expected,"all historical fields and RNG preserved; envelope version and neutral legacy economy are the only migrations")
		while loaded.game.phase=="minigame":
			check(loaded.game.Minigame.ai_step(loaded.game) and Coins.ai_step(twin.game),"new dispatcher and preserved legacy rules both advance")
			check(Save.snapshot(loaded.game)==Save.snapshot(twin.game),"legacy continuation identical to preserved catch v1 after each command")
	var seen:Dictionary={}
	for seed_value in range(32):
		var g=fresh(seed_value+1);check(g.gm_teleport(0,road(g)),"map landing enters selected game")
		seen[g.Minigame.id(g)]=true
		var before:Dictionary=Save.snapshot(g)
		g.Minigame.title(g);g.Minigame.profile(g);g.Minigame.instructions(g);g.Minigame.parameters(g)
		check(Save.snapshot(g)==before,"display queries do not reroll or consume RNG")
		check(not g.Minigame.enter(g) and Save.snapshot(g)==before,"reentry rejected without RNG or service mutation")
		check(not g.Minigame.gm_choose_ready(g,"invalid") and Save.snapshot(g)==before,"unknown GM type rejected atomically")
		check(g.Minigame.gm_choose_ready(g,g.Minigame.id(g)) and Save.snapshot(g)==before,"same GM type does not reroll its queue")
		var restored:Dictionary=Save.restore(before)
		check(restored.ok and Save.snapshot(restored.game)==before,"selected type and preview survive save")
		if g.Minigame.id(g)!="catch_coins":
			check(not g.Minigame.select_cell(g,4) and g.Minigame.legal_cells(g).is_empty() and g.Minigame.ai_cell(g)==-1,"coin commands cannot touch doll state")
			var bad:Dictionary=before.duplicate(true);bad.version=5
			check(not Save.restore(bad).ok,"v5 cannot claim a new minigame schema")
		else:check(not g.Minigame.toss(g,1) and g.Minigame.ai_bin(g)==-1,"doll commands cannot touch coin state")
		if g.Minigame.id(g)!="disarm_bomb":check(not g.Minigame.choose(g,0) and g.Minigame.ai_switch(g)==-1,"switch command cannot touch another game")
		if g.Minigame.id(g)!="shoot_balloons":check(not g.Minigame.shoot(g,0) and g.Minigame.ai_lane(g)==-1,"cannon command cannot touch another game")
		g.Minigame.start(g)
		before=Save.snapshot(g)
		check(not g.Minigame.gm_choose_ready(g,"catch_coins") and Save.snapshot(g)==before,"GM cannot reroll after a game starts")
		for value in ["not_a_game",7,null]:
			var bad:Dictionary=before.duplicate(true);bad.state.pending_service.game.id=value
			check(not Save.restore(bad).ok,"invalid game identity rejected safely")
	for game_id in g_pool():check(seen.has(game_id),"every evidenced Knight Manor game can be selected")
	var natural_seen:Dictionary={}
	for seed_value in range(1510,1516):
		var g=fresh(seed_value)
		for command in range(20000):
			if g.phase=="finished":break
			if g.phase=="minigame":natural_seen[g.Minigame.id(g)]=true
			if not AI.step(g):check(false,"natural AI accepts every selected minigame state");break
		check(g.phase=="finished" and not g.winners.is_empty(),"natural mixed-game match reaches winner")
	for game_id in g_pool():check(natural_seen.has(game_id),"normal whole matches actually exercise "+game_id)
	print("ROUND15_POOL_TEST failures=",failures," games=",natural_seen.keys())
	quit(0 if failures==0 else 1)

func g_pool()->Array:
	return Game.Minigame.TEST_POOL
