extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func advance_once(g)->void:
	match g.phase:
		"roll":g.roll_dice()
		"move":g.move_to(g.available_moves()[0])
		"bank":g.close_bank()
		"shop":g.close_shop()
		"reaction":g.resolve_reaction()
		"land","end","detained":g.end_turn()
func complex_restores()->void:
	var g=Game.new()
	g.setup(["A","B","C","D"],17)
	g.players[0].pos=5;g.players[0].previous=4
	g.gm_vehicle(0,"car");g.set_dice_count(2)
	g.players[0].cards=["dice"]
	check(g.use_card("dice",[6,7,8,9,10,11,12,13],8),"controlled bank route accepted")
	g.roll_dice();g.move_to(6);g.move_to(7)
	check(g.phase=="bank" and g.steps_left==6,"controlled route pauses at bank")
	var path="res://.godot/save-complex.rms"
	check(Save.save_to_file(g,path).ok,"save bank continuation")
	var clone=Save.load_from_file(path).game
	check(clone.controlled_path==g.controlled_path and clone.steps_left==6,"bank save retains route and remaining steps")
	g.close_bank();clone.close_bank()
	for ignored in range(20):
		if g.phase not in ["move","bank"]:break
		advance_once(g);advance_once(clone)
	check(Save.snapshot(g)==Save.snapshot(clone) and g.players[0].pos==13,"bank route continuation replays exactly")
	g.setup(["A","B","C","D"],17)
	for p in g.players:p.cards=[];p.pos=40
	g.players[0].pos=60;g.players[1].pos=3;g.players[2].pos=3
	g.players[1].cards=["immune","immune"];g.players[2].cards=["immune","immune"]
	g.road_objects[2]={"kind":"mine","owner":0}
	g.road_objects[3]={"kind":"explosive","owner":0}
	g.Explosives.blast(g,1,"missile",0);g.Combat.advance(g)
	check(g.phase=="reaction" and not g.pending_attack.events.is_empty(),"actual chained blasts suspend with queued events")
	check(Save.save_to_file(g,path).ok,"save chained blast queue")
	clone=Save.load_from_file(path).game
	var reactions:=0
	while g.phase=="reaction" and reactions<12:
		reactions+=1
		var defense:String="immune" if g.reaction_options().has("immune") else ""
		g.resolve_reaction(defense);clone.resolve_reaction(defense)
		check(Save.snapshot(g)==Save.snapshot(clone),"each restored blast defense preserves remaining events")
	check(reactions>=4 and g.pending_attack.is_empty(),"all victims and successive blast windows drain")
	g.setup(["A","B","C","D"],17)
	g.players[0].pos=6;g.players[0].previous=5
	g.send_to_facility(0,"hospital",2);g.end_turn()
	for ignored in range(200):
		if g.current==0 and g.phase=="detained":break
		advance_once(g)
	check(g.phase=="detained" and g.players[0].status.remaining==2,"hospital fixture reaches first skipped action")
	check(Save.save_to_file(g,path).ok,"save hospital detention")
	clone=Save.load_from_file(path).game
	for ignored in range(200):
		advance_once(g);advance_once(clone)
		if g.current==0 and g.phase=="roll":break
	check(g.players[0].status.is_empty() and g.players[0].pos==6 and Save.snapshot(g)==Save.snapshot(clone),"restored detention counts skips and returns to original road")
	g.setup(["A","B","C","D"],17)
	g.players[0].pos=6;g.players[0].previous=5
	g.Combat.begin(g,"sleepwalk",1,[0],"sleepwalk",2);g.Combat.advance(g)
	g.roll_dice()
	check(Save.save_to_file(g,path).ok,"save moving sleepwalker")
	clone=Save.load_from_file(path).game
	for ignored in range(40):
		advance_once(g);advance_once(clone)
		if g.current!=0:break
	check(g.current==1 and g.players[0].status.remaining==1 and Save.snapshot(g)==Save.snapshot(clone),"sleepwalker resumes movement and counts one action without relocation")
func _init()->void:
	var g=Game.new()
	g.setup(["A","B","C","D"],77,20,{"gods_enabled":true,"talents_enabled":true,"characters":["eleven","nintaro","sarah","atu"]})
	var path="res://.godot/save-test.rms"
	var result=Save.save_to_file(g,path,{"title":"test","controllers":["human","ai","ai","human"]})
	check(result.ok,"save initial: "+str(result))
	if not result.ok: quit(1);return
	var loaded=Save.load_from_file(path)
	check(loaded.ok,"load initial")
	var clone=loaded.game
	check(Save.snapshot(g)==Save.snapshot(clone),"all initial state preserved")
	g.roll_dice();clone.roll_dice()
	check(g.last_dice==clone.last_dice and g.rng.state==clone.rng.state,"dice RNG continuation identical")
	for ignored in range(3):
		if g.phase=="move":
			var next=g.available_moves()[0]
			g.move_to(next);clone.move_to(next)
	check(Save.snapshot(g)==Save.snapshot(clone),"movement replay identical")
	result=Save.save_to_file(g,path)
	check(result.ok,"overwrite existing save atomically")
	clone=Save.load_from_file(path).game
	g.stock_market.advance(2);clone.stock_market.advance(2)
	check(g.stock_market.quotes==clone.stock_market.quotes and g.stock_market.rng.state==clone.stock_market.rng.state,"market RNG continuation identical")
	g.setup(["A","B","C","D"],17)
	g.players[0].cards=["free"]
	g.lots.small_1_6.owner=1;g.lots.small_1_6.level=5;g.lots.small_1_6.building_type="house"
	g.gm_teleport(0,int(g.lots.small_1_6.frontage_nodes[0]))
	check(g.phase=="reaction","pending real rent")
	result=Save.save_to_file(g,path)
	check(result.ok,"save reaction")
	clone=Save.load_from_file(path).game
	g.resolve_reaction("free");clone.resolve_reaction("free")
	check(Save.snapshot(g)==Save.snapshot(clone) and clone.phase=="land","restored reaction continues landing once")
	var invalid=Save.snapshot(g)
	invalid.state.players[0].pos=9999
	check(not Save.restore(invalid).ok,"invalid player position rejected")
	invalid=Save.snapshot(g);invalid.version=999
	check(not Save.restore(invalid).ok,"unknown schema rejected")
	var bytes=FileAccess.get_file_as_bytes(path)
	bytes[bytes.size()-1]=bytes[bytes.size()-1]^1
	var file=FileAccess.open(path+".corrupt",FileAccess.WRITE);file.store_buffer(bytes);file.close()
	check(not Save.load_from_file(path+".corrupt").ok,"corrupt payload rejected")
	var before=FileAccess.get_file_as_bytes(path)
	check(not Save.save_to_file(g,path,{"bad":g}).ok,"object metadata rejected before overwrite")
	check(FileAccess.get_file_as_bytes(path)==before,"failed save retains original bytes")
	g.setup(["A","B","C","D"],32,10,{"gods_enabled":true,"talents_enabled":true,"characters":["eleven","nintaro","sarah","atu"]})
	var phases: Dictionary = {}
	var actions:=0
	while g.phase != "finished" and actions < 2000:
		actions+=1
		phases[g.phase]=true
		var restored=Save.restore(bytes_to_var(var_to_bytes(Save.snapshot(g))))
		check(restored.ok,"roundtrip during "+g.phase)
		if not restored.ok: break
		g=restored.game
		match g.phase:
			"roll": g.roll_dice()
			"move": g.move_to(g.available_moves()[0])
			"bank": g.bank_transfer(100);g.close_bank()
			"shop": g.close_shop()
			"reaction": g.resolve_reaction()
			"land":
				if not g.buy_property(): g.upgrade_property()
				g.end_turn()
			"end","detained":g.end_turn()
	check(g.phase=="finished","full match survives restoration at every command boundary")
	check(Save.restore(Save.snapshot(g)).ok,"finished state restorable")
	print("SAVE_REPLAY actions=",actions," phases=",phases.keys())
	complex_restores()
	print("SAVE_TEST failures=",failures)
	quit(1 if failures else 0)
