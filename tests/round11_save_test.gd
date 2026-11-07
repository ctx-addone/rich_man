extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const FIXTURES=[
	{"path":"res://tests/fixtures/round8-v1.rms","version":1,"sha":"C09990DEE6711A615FAD37423964B26A65196BBE8037E240BE1414E23A5598CD"},
	{"path":"res://tests/fixtures/round9-v2.rms","version":2,"sha":"4BF053671BF73A0F0B962C72CEEBFEE0E716A6A25147F38332187CE7A7AACB9F"},
	{"path":"res://tests/fixtures/round10-v3.rms","version":3,"sha":"B037992F9F3F6B2B2AAE5997DC6138F7F745344AEEEE5724FE9C15CF0372EBFD"}
]
var failures:int=0
var rejected:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;printerr(label)
func raw_file(path:String)->Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	file.seek(44)
	return bytes_to_var(file.get_buffer(file.get_length()-44))
func reject(data:Dictionary,live,label:String)->void:
	var before:Dictionary=Save.snapshot(live)
	var original:Dictionary=data.duplicate(true)
	check(not Save.restore(data).ok,label)
	check(Save.snapshot(live)==before and data==original,"failed import preserves live match and payload: "+label)
	rejected+=1
func assert_trajectory(a,b,steps:int,label:String)->void:
	for ignored in range(steps):
		check(Save.snapshot(a)==Save.snapshot(b),label+" state and both RNGs agree")
		if a.phase=="finished": break
		var moved:bool=AI.step(a)
		var twin_moved:bool=AI.step(b)
		check(moved and twin_moved,label+" both continuations advance")
		if not moved or not twin_moved: break
	check(Save.snapshot(a)==Save.snapshot(b),label+" final state agrees")
func legacy()->void:
	for fixture in FIXTURES:
		check(FileAccess.get_sha256(fixture.path).to_upper()==fixture.sha,"historical fixture hash v"+str(fixture.version))
		var raw:Dictionary=raw_file(fixture.path)
		var untouched:Dictionary=raw.duplicate(true)
		check(raw.version==fixture.version,"fixture has actual old version")
		var loaded:Dictionary=Save.load_from_file(fixture.path)
		check(loaded.ok,"historical version loads: "+str(loaded.get("error","")))
		if not loaded.ok: continue
		var g=loaded.game
		check(g.map_id==Game.Maps.DEFAULT_MAP_ID and g.map_metadata==Game.Maps.load_map(g.map_id).metadata and g.start_road==0 and g.start_bonus==1000,"old layout acquires exact default identity")
		for key in raw.state:
			if key=="players":
				for i in range(raw.state.players.size()):
					for field in raw.state.players[i]: check(raw.state.players[i][field]==g.players[i][field],"old player field preserved: "+field)
			else: check(raw.state[key]==g.get(key),"old field preserved: "+key)
		check(g.rng.seed==raw.rng_seed and g.rng.state==raw.rng_state,"historical gameplay RNG exact")
		check(Save.snapshot(g).market==raw.market and loaded.metadata==raw.metadata and raw==untouched,"historical market RNG metadata and source exact")
		var twin:Dictionary=Save.restore(raw)
		check(twin.ok,"historical second load succeeds")
		if twin.ok: assert_trajectory(g,twin.game,120,"legacy v"+str(fixture.version))
		var bad:Dictionary=untouched.duplicate(true)
		bad.state.erase("bank_visited");reject(bad,g,"legacy original required field stays required")
		bad=untouched.duplicate(true);bad.state.map_id="knight_manor";reject(bad,g,"legacy map identity cannot be reassigned")
		bad=untouched.duplicate(true);bad.state.map_metadata={"id":"forged"};reject(bad,g,"legacy forged metadata not silently repaired")
		if fixture.version>=2:
			bad=untouched.duplicate(true);bad.state.erase("pending_service");reject(bad,g,"legacy existing service fields still required")
		if fixture.version==3:
			bad=untouched.duplicate(true);bad.state.players[0].erase("team");reject(bad,g,"v3 team remains required")
func current()->void:
	var g=Game.new()
	g.setup(["A","B","C","D"],617,20,{"teams":[0,1,0,1],"specials_enabled":true,"gods_enabled":true})
	g.road_gods.clear()
	g.players[0].pos=16;g.players[0].previous=15;g.roll_dice(3);g.move_to(17);g.buy_ticket(4)
	check(g.phase=="lottery" and g.steps_left==2,"v4 fixture has real pending lottery continuation")
	var path:String="res://.godot/round11-v4-continuation.rms"
	var metadata:Dictionary={"title":"v4 map identity","controllers":["human","ai","human","ai"]}
	check(Save.save_to_file(g,path,metadata).ok,"v4 writes validated envelope")
	check(raw_file(path).version==Save.VERSION,"new disk envelope contains current version; historical versions remain in fixtures")
	var restored:Dictionary=Save.load_from_file(path)
	check(restored.ok,"v4 reads disk envelope")
	if not restored.ok: return
	check(restored.metadata==metadata and Save.snapshot(restored.game)==Save.snapshot(g),"v4 all state and map metadata roundtrip")
	assert_trajectory(g,restored.game,500,"v4 pending service continuation")
	check(Save.save_to_file(g,path,metadata).ok,"continued v4 state saves again")
	var good:Dictionary=Save.snapshot(g)
	for key in ["map_id","map_metadata","start_road","start_bonus"]:
		var bad:Dictionary=good.duplicate(true);bad.state.erase(key);reject(bad,g,"v4 requires map field "+key)
	for id in ["not_registered","knight_manor","../integration_city",7]:
		var bad:Dictionary=good.duplicate(true);bad.state.map_id=id;reject(bad,g,"reject unknown/unplayable/invalid map identity "+str(id))
	for key in ["id","name","description","source_status"]:
		var bad:Dictionary=good.duplicate(true);bad.state.map_metadata[key]="forged";reject(bad,g,"reject changed metadata "+key)
	for key in ["start_road","start_bonus"]:
		var bad:Dictionary=good.duplicate(true);bad.state[key]+=1;reject(bad,g,"reject changed runtime "+key)
		bad=good.duplicate(true);bad.state[key]+=1;bad.state.map_metadata[key]+=1;reject(bad,g,"matching forged metadata cannot authorize changed "+key)
	var bad:Dictionary=good.duplicate(true);bad.state.map_metadata.size=[50,50];reject(bad,g,"reject changed map dimensions")
	bad=good.duplicate(true);bad.state.map_metadata.playable=false;reject(bad,g,"reject changed playable state")
	bad=good.duplicate(true);bad.state.map_metadata.schema_version=2;reject(bad,g,"reject changed map schema")
	bad=good.duplicate(true);bad.state.nodes[1].name="forged";reject(bad,g,"reject road metadata drift")
	for field in ["id","name","street_id","rule_id"]:
		bad=good.duplicate(true);bad.state.lots.small_1_6[field]="forged";reject(bad,g,"reject static property metadata "+field)
	for field in ["price","rent"]:
		bad=good.duplicate(true);bad.state.lots.small_1_6[field]+=1;reject(bad,g,"reject static property economic metadata "+field)
	bad=good.duplicate(true);bad.state.lots.lot_13_1.building_type="bank";reject(bad,g,"reject changed hospital facility type")
	for field in ["exit_road","exit_previous"]:
		for value in [null,0]:
			bad=good.duplicate(true);bad.state.lots.lot_13_1[field]=value;reject(bad,g,"reject injected optional exit field "+field+"="+str(value))
	var first:Dictionary=Save.restore(good)
	var second:Dictionary=Save.restore(good)
	check(first.ok and second.ok,"v4 independent clones restore")
	if first.ok and second.ok:
		first.game.map_metadata.name="local mutation"
		check(second.game.map_metadata==g.map_metadata and good.state.map_metadata==g.map_metadata,"map metadata never aliases across restored games")
func _init()->void:
	legacy()
	current()
	print("ROUND11_SAVE failures=",failures," rejected=",rejected)
	quit(0 if failures==0 else 1)
