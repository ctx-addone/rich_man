extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Balloons = preload("res://scripts/model/shoot_balloons_rules.gd")
const Save = preload("res://scripts/model/save_game.gd")
var failures:int = 0

func check(ok:bool, label:String) -> void:
	if not ok: failures += 1; push_error(label)

func fresh(seed_value:int=1517):
	var g = Game.new()
	check(g.setup(["A","B","C","D"],seed_value,20,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":false,"talents_enabled":false}),"map setup")
	var target:int = -1
	for node in g.nodes:
		if node.kind == "minigame": target = node.id; break
	check(g.gm_teleport(g.current,target) and g.Minigame.gm_choose_ready(g,"shoot_balloons"),"actual road opens explicit GM balloon fixture")
	return g

func restored(g,label:String):
	var raw:Dictionary = Save.snapshot(g)
	var result:Dictionary = Save.restore(raw)
	check(result.ok,label+" restores: "+str(result.get("error","")))
	if not result.ok: return null
	check(Save.snapshot(result.game) == raw,label+" preserves RNG and fields")
	return result.game

func reject(raw:Dictionary,label:String) -> void:
	var before:Dictionary = raw.duplicate(true)
	check(not Save.restore(raw).ok,label+" rejected")
	check(raw == before,label+" does not mutate input")

func fixture(g, events:Array) -> void:
	# Explicit white-box visible-board fixture; future draws retain seeded RNG.
	var state:Dictionary = Balloons._replay(events)
	check(not state.is_empty() and state.reason.is_empty(),"fixture is legal live history")
	var game:Dictionary = g.pending_service.game
	game.status = "playing"
	game.events = events.duplicate(true)
	game.tick = events.size()
	game.balloons = state.balloons
	game.score = state.score

func spawn(lane:int,kind:String,shot:int=-1) -> Dictionary:
	return {"lane":shot,"spawn":{"lane":lane,"kind":kind}}

func _init() -> void:
	test_commands_and_restore()
	test_whole_lane_and_bomb()
	test_ascent_and_ai()
	test_all_seats_and_timeout()
	test_strict_validation()
	print("SHOOT_BALLOONS_TEST failures=",failures)
	quit(1 if failures else 0)

func test_commands_and_restore() -> void:
	var g = fresh()
	var before:Dictionary = Save.snapshot(g)
	check(not Balloons.shoot(g,0) and not Balloons.tick(g) and not Balloons.close(g) and not Balloons.settle_others(g),"ready cannot shoot, advance or claim")
	check(before == Save.snapshot(g),"rejected ready commands preserve random state")
	restored(g,"ready")
	check(Balloons.start(g) and not Balloons.start(g),"starts once")
	before = Save.snapshot(g)
	check(Balloons.ai_lane(g) == -1 and before == Save.snapshot(g),"AI waits on empty board without random draws")
	check(not Balloons.shoot(g,-1) and not Balloons.shoot(g,4) and not g.Minigame.select_cell(g,0),"invalid and other-game input rejected")
	check(Balloons.tick(g),"first tick creates visible item")
	check(Balloons.shoot(g,2),"one lane queued")
	before = Save.snapshot(g)
	check(not Balloons.shoot(g,2) and not Balloons.shoot(g,3),"rapid clicks cannot duplicate or change queued shot")
	check(before == Save.snapshot(g),"duplicate clicks preserve state")
	var twin = restored(g,"queued shot")
	if twin != null:
		check(Balloons.tick(g) and Balloons.tick(twin),"queued shot resolves on both copies")
		check(Save.snapshot(g) == Save.snapshot(twin),"same shot and subsequent RNG after load")
		for ignored in range(6):
			Balloons.ai_step(g); Balloons.ai_step(twin)
		check(Save.snapshot(g) == Save.snapshot(twin),"continued random sequence stays identical")
	var other = fresh()
	other.Minigame.gm_choose_ready(other,"catch_coins")
	before = Save.snapshot(other)
	check(not Balloons.start(other) and not Balloons.shoot(other,0) and not Balloons.tick(other) and not Balloons.close(other),"cross-game entry guards")
	check(before == Save.snapshot(other),"cross-game rejection is pure")

func test_whole_lane_and_bomb() -> void:
	var g = fresh()
	fixture(g,[spawn(0,"coin"),spawn(0,"ingot"),spawn(1,"coin")])
	restored(g,"multiple visible rewards in one lane")
	check(Balloons.shoot(g,0) and Balloons.tick(g),"shoot populated column")
	check(g.pending_service.game.score == 600,"whole lane awards both coin and ingot, not nearest one")
	var kept:bool = false
	for balloon in g.pending_service.game.balloons:
		if balloon.lane == 1 and balloon.height == 1: kept = true
	check(kept,"other columns remain and ascend")
	g = fresh()
	fixture(g,[spawn(0,"coin"),spawn(0,"bomb",0),spawn(0,"ingot")])
	check(g.pending_service.game.score == 100,"fixture has earned score before hazardous column")
	var random_before:int = g.rng.state
	check(Balloons.shoot(g,0) and Balloons.tick(g),"bomb collision ends early")
	var game:Dictionary = g.pending_service.game
	check(game.reason == "bomb" and game.status == "participant_result" and game.score == 100,"TEST bomb priority forfeits same-column new loot, keeps prior score")
	check(game.events.back().spawn.is_empty() and game.balloons.is_empty() and g.rng.state == random_before,"early terminal tick generates no hidden balloon or RNG draw")
	restored(g,"early bomb result")
	check(not Balloons.close(g),"first seat cannot prematurely pay whole game")
	check(Balloons.settle_others(g) and game.status == "result","other local seats receive independent automatic results")
	restored(g,"full roster after early manual bomb")

func test_ascent_and_ai() -> void:
	var g = fresh()
	fixture(g,[spawn(0,"bomb"),spawn(1,"ingot"),spawn(0,"coin")])
	var before:Dictionary = Save.snapshot(g)
	check(Balloons.ai_lane(g) == 1 and before == Save.snapshot(g),"AI chooses visible safe high-value column only")
	fixture(g,[spawn(0,"bomb"),spawn(0,"coin")])
	check(Balloons.ai_lane(g) == -1,"AI waits rather than shoot coin sharing bomb lane")
	var replay:Dictionary = Balloons._replay([spawn(0,"bomb"),spawn(1,"ingot"),spawn(2,"coin"),spawn(2,"coin"),spawn(2,"coin")])
	var bomb_left:bool = false
	var ingot_left:bool = false
	for balloon in replay.balloons:
		if balloon.kind == "bomb": bomb_left = true
		if balloon.kind == "ingot" and balloon.height == 3: ingot_left = true
	check(not bomb_left and ingot_left,"fast bomb exits top while slower older reward remains")

func test_all_seats_and_timeout() -> void:
	var g = fresh()
	var starting:Array = []
	for player in g.players: starting.append(player.cash)
	Balloons.start(g)
	for ignored in range(Balloons.TEST_PROFILE.ticks): Balloons.ai_step(g)
	check(g.pending_service.game.status == "participant_result" and g.pending_service.game.reason == "time_up","manual first participant ends at deadline")
	check(g.pending_service.game.events.back().spawn.is_empty(),"deadline creates no unseen next-wave item")
	restored(g,"first result before automatic seats")
	check(Balloons.next_player(g),"handoff can persist")
	var twin = restored(g,"automatic seat ready")
	check(Balloons.settle_others(g),"remaining seats complete within bounded simulation")
	if twin != null:
		Balloons.settle_others(twin)
		check(Save.snapshot(g) == Save.snapshot(twin),"automatic roster simulation survives load identically")
	var history:Array = g.pending_service.game.history.duplicate(true)
	check(history.size() == 4,"all four local seats have separate result")
	for player in g.players: check(player.cash == starting[player.id],"no cash paid before unified confirmation")
	restored(g,"final result")
	check(Balloons.close(g) and not Balloons.close(g),"pay exactly once")
	for record in history: check(g.players[record.player].cash == starting[record.player]+record.reward,"each seat receives own score, not first player's reward")
	check(g.phase == "land" and g.pending_service.is_empty(),"result rejoins board loop")
	var before:Dictionary = Save.snapshot(g)
	check(not Balloons.enter(g) and before == Save.snapshot(g),"same action cannot replay service road")

func test_strict_validation() -> void:
	var g = fresh()
	fixture(g,[spawn(0,"coin"),spawn(1,"bomb"),spawn(2,"ingot")])
	var base:Dictionary = Save.snapshot(g)
	var mutations:Array = [
		["score",999], ["tick",2], ["tick",3.0], ["choice",4], ["choice",true], ["reward",100],
		["status","result"], ["status","ready"], ["reason","bomb"], ["version",2], ["version",1.0],
		["participants",[0,0,2,3]], ["participants",[0.0,1,2,3]], ["player",1], ["cursor",1], ["history",[{}]], ["balloons",[]]
	]
	for mutation in mutations:
		var raw:Dictionary = base.duplicate(true)
		raw.state.pending_service.game[mutation[0]] = mutation[1]
		reject(raw,"bad "+str(mutation[0])+" "+str(mutation[1]))
	for field in ["lane","height","speed"]:
		var raw:Dictionary = base.duplicate(true)
		raw.state.pending_service.game.balloons[0][field] = float(raw.state.pending_service.game.balloons[0][field])
		reject(raw,"float-equal balloon "+field)
	for field in ["lane","kind"]:
		var raw:Dictionary = base.duplicate(true)
		raw.state.pending_service.game.events[0].spawn[field] = 4 if field == "lane" else "unknown"
		reject(raw,"invalid spawn "+field)
	var raw:Dictionary = base.duplicate(true)
	raw.state.pending_service.game.events[0].spawn = {}
	reject(raw,"nonterminal tick cannot omit spawn")
	raw = base.duplicate(true)
	raw.state.pending_service.game.events[0].lane = 0.0
	reject(raw,"float shot cannot bypass replay")
	check(Save.snapshot(g) == base,"all malformed restores leave live game and RNG unchanged")
	fixture(g,[spawn(0,"coin"),spawn(0,"bomb",0),spawn(0,"ingot")])
	Balloons.shoot(g,0); Balloons.tick(g)
	raw = Save.snapshot(g)
	raw.state.pending_service.game.events.back().spawn = {"lane":0,"kind":"coin"}
	reject(raw,"bomb ending cannot invent post-ending spawn")
	raw = Save.snapshot(g)
	raw.state.pending_service.game.history[0].reward += 1
	reject(raw,"historical reward forgery")
