extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Mini = preload("res://scripts/model/minigame_rules.gd")
const Save = preload("res://scripts/model/save_game.gd")
const AI = preload("res://scripts/model/ai_controller.gd")
var failures:int = 0

func check(ok:bool, label:String) -> void:
	if not ok: failures += 1; push_error(label)

func fresh(seed_value:int=1407, enabled:bool=true, teams:Array=[0,1,2,3]):
	var g = Game.new()
	check(g.setup(["A","B","C","D"],seed_value,20,{"map_id":"knight_manor","specials_enabled":enabled,"gods_enabled":false,"talents_enabled":false,"teams":teams}),"knight setup")
	return g

func road(g) -> int:
	for node in g.nodes:
		if node.kind == "minigame": return node.id
	return -1

func open(g) -> void:
	check(g.gm_teleport(g.current,road(g)) and g.phase == "minigame","actual minigame landing opens ready state")
	check(Mini.gm_choose_ready(g,"catch_coins"),"isolate catch_coins rules within the random pool")

func restored(g, label:String):
	var before:Dictionary = Save.snapshot(g)
	var result:Dictionary = Save.restore(before)
	check(result.ok,label+" restore: "+str(result.get("error","")))
	if not result.ok: return null
	check(Save.snapshot(result.game) == before,label+" exact state and RNG")
	return result.game

func select_kind(g,kind:String) -> void:
	for item in g.pending_service.game.items:
		if item.kind == kind:
			walk_to(g,item.cell)
			return
	check(false,"visible item exists")

func walk_to(g, target:int) -> void:
	while g.pending_service.game.cell != target:
		var current:int = g.pending_service.game.cell
		var step:int = current
		if current%3 != target%3: step += 1 if target%3 > current%3 else -1
		else: step += 3 if target/3 > current/3 else -3
		check(Mini.select_cell(g,step),"human uses orthogonal movement command")

func finish_remaining(g) -> void:
	var count:int = 0
	while g.pending_service.game.status != "result" and count < 120:
		check(Mini.ai_step(g),"remaining participant executes normal commands")
		count += 1
	check(count < 120,"all participants reach final result")

func reject(raw:Dictionary,label:String) -> void:
	check(not Save.restore(raw).ok,"tampered "+label+" rejected")

func _init() -> void:
	test_lifecycle()
	test_scoring()
	test_persistent_items()
	test_ai_and_replay()
	test_automatic_others()
	test_validation()
	test_guards()
	test_matches()
	print("MINIGAME_TEST failures=",failures)
	quit(1 if failures else 0)

func test_lifecycle() -> void:
	var g = fresh(); open(g)
	if g.phase != "minigame": return
	var initial_cash:int = g.players[0].cash
	var before:Dictionary = Save.snapshot(g)
	check(not Mini.tick(g) and not Mini.select_cell(g,0) and not Mini.close(g),"ready waits for explicit start; no premature reward")
	check(Save.snapshot(g) == before,"rejected ready operations are pure")
	restored(g,"ready")
	check(Mini.start(g) and not Mini.start(g),"start exactly once")
	before = Save.snapshot(g)
	check(not Mini.select_cell(g,-1) and not Mini.select_cell(g,9) and not Mini.select_cell(g,0) and not Mini.close(g),"invalid or diagonal positions and early close rejected")
	check(Mini.legal_cells(g) == [1,3,4,5,7],"center only exposes orthogonal neighbors and stay")
	check(Save.snapshot(g) == before,"invalid playing operations do not reroll")
	for i in range(Mini.TEST_PROFILE.ticks):
		var scene:Dictionary = g.pending_service.game
		check(scene.items.size() == 3 and scene.items[0].cell != scene.items[1].cell and scene.items[1].cell != scene.items[2].cell and scene.items[0].cell != scene.items[2].cell,"visible wave has no overlaps")
		var rng_before:int = g.rng.state
		select_kind(g,"coin")
		check(g.rng.state == rng_before,"position command never draws randomness")
		check(Mini.tick(g),"one discrete tick settles wave")
		check(g.players[0].cash == initial_cash,"score has no cash side effect before result claim")
	check(g.pending_service.game.status == "participant_result" and g.pending_service.game.score == 2400 and g.pending_service.game.reward == 2400,"24 successful ticks produce current participant result")
	check(not Mini.tick(g) and not Mini.select_cell(g,0),"finished result cannot continue")
	check(not Mini.close(g),"first participant cannot claim for the whole group")
	restored(g,"participant result")
	check(Mini.next_player(g) and g.pending_service.game.player == 1 and g.current == 0 and g.pending_service.game.status == "ready","next independent seat preserves board turn")
	restored(g,"second participant ready")
	finish_remaining(g)
	var twin = restored(g,"unclaimed result")
	var history:Array = g.pending_service.game.history.duplicate(true)
	check(Mini.close(g) and g.phase == "land" and g.pending_service.is_empty(),"result claim returns to board")
	check(g.players[0].cash == initial_cash+2400 and not Mini.close(g),"reward can only be claimed once")
	for record in history: check(g.players[record.player].cash == initial_cash+record.reward,"each participant receives their own earned reward")
	check(not Mini.enter(g),"same arrival cannot reopen or reroll after claim")
	if twin != null:
		check(Mini.close(twin) and Save.snapshot(twin) == Save.snapshot(g),"unclaimed saved result pays exactly the same amount once")
	restored(g,"claimed result")

func test_scoring() -> void:
	var sample = fresh(); open(sample); Mini.start(sample)
	select_kind(sample,"ingot"); Mini.tick(sample)
	check(sample.pending_service.game.score == 500,"filmed sample supports 500-point ingot")
	var g = fresh(); open(g); Mini.start(g)
	var initial_cash:int = g.players[0].cash
	for ignored in range(5): select_kind(g,"coin"); Mini.tick(g)
	select_kind(g,"bomb"); Mini.tick(g)
	check(g.pending_service.game.score == 200,"bomb subtracts 300 earned points")
	select_kind(g,"bomb"); Mini.tick(g)
	check(g.pending_service.game.score == 0,"bomb penalty floors at zero without touching match cash")
	while g.pending_service.game.status == "playing":
		var occupied:Array = []
		for item in g.pending_service.game.items: occupied.append(item.cell)
		for cell in range(9):
			if not occupied.has(cell): walk_to(g,cell); break
		Mini.tick(g)
	check(g.pending_service.game.score == 0 and g.players[0].cash == initial_cash,"missing coins produces no reward")
	finish_remaining(g); Mini.close(g)
	check(g.players[0].cash == initial_cash,"zero score never grants random cash")
	check(g.players[1].cash > initial_cash,"other seats independently earn rewards despite first player zero")

func test_persistent_items() -> void:
	var g = fresh(); open(g); Mini.start(g)
	var observed:Dictionary = g.pending_service.game.items[0].duplicate()
	var occupied:Array = []
	for item in g.pending_service.game.items: occupied.append(item.cell)
	for cell in range(9):
		if not occupied.has(cell): walk_to(g,cell); break
	Mini.tick(g)
	var found:Dictionary = {}
	for item in g.pending_service.game.items:
		if item.cell == observed.cell: found = item
	check(not found.is_empty() and found.kind == observed.kind and found.remaining == 2,"uncollected falling item persists on ground after landing")
	restored(g,"persistent grounded item")
	walk_to(g,observed.cell); Mini.tick(g)
	check(g.pending_service.game.score == Mini.TEST_PROFILE.coin_value,"player can collect retained coin on a later tick")

func test_ai_and_replay() -> void:
	var human = fresh(1417); var bot = fresh(1417)
	open(human); open(bot)
	check(Save.snapshot(human) == Save.snapshot(bot),"same seed creates identical initial visible wave")
	var steps:int = 0
	while human.phase == "minigame" and steps < 120:
		match human.pending_service.game.status:
			"ready": Mini.start(human)
			"playing":
				var before:Dictionary = Save.snapshot(human)
				var cell:int = Mini.ai_cell(human)
				check(Save.snapshot(human) == before,"AI suggestion is read-only")
				Mini.select_cell(human,cell); Mini.tick(human)
			"participant_result": Mini.next_player(human)
			"result": Mini.close(human)
		check(Mini.ai_step(bot),"AI executes a public step")
		check(Save.snapshot(human) == Save.snapshot(bot),"AI is exactly equivalent to human commands")
		if bot.phase == "minigame" and (bot.pending_service.game.tick == 8 or bot.pending_service.game.status in ["ready","participant_result","result"]):
			var twin = restored(bot,"active wave")
			if twin != null: bot = twin
		steps += 1
	check(human.phase == "land" and steps < 120,"all four seats independently complete and claim")
	check(Save.snapshot(human) == Save.snapshot(bot),"AI and human earn identical reward")

func test_validation() -> void:
	var g = fresh(); open(g); Mini.start(g); select_kind(g,"coin"); Mini.tick(g)
	check(not Mini.state_error({"phase":"minigame"},g).is_empty(),"direct incomplete state validation is safe")
	var raw:Dictionary = Save.snapshot(g)
	var bad:Dictionary = raw.duplicate(true); bad.state.pending_service.game.score += 1; reject(bad,"score/history mismatch")
	bad = raw.duplicate(true); bad.state.pending_service.game.reward = 1000000; reject(bad,"premature reward")
	bad = raw.duplicate(true); bad.state.pending_service.game.tick = -1; reject(bad,"negative tick")
	bad = raw.duplicate(true); bad.state.pending_service.game.tick = 25; reject(bad,"overrun tick")
	bad = raw.duplicate(true); bad.state.pending_service.game.cell = 9; reject(bad,"outside grid")
	bad = raw.duplicate(true); bad.state.pending_service.game.items[1].cell = bad.state.pending_service.game.items[0].cell; reject(bad,"overlapping items")
	bad = raw.duplicate(true); bad.state.pending_service.game.items[0].remaining = 4; reject(bad,"item clock")
	bad = raw.duplicate(true); bad.state.pending_service.game.items[0].kind = "gem"; reject(bad,"unsupported item")
	bad = raw.duplicate(true); bad.state.pending_service.game.player = 1; reject(bad,"other participant")
	bad = raw.duplicate(true); bad.state.pending_service.game.status = "ready"; reject(bad,"ready after time passed")
	bad = raw.duplicate(true); bad.state.pending_service.game.results[0] = 999999; reject(bad,"forged history")
	bad = raw.duplicate(true); bad.state.pending_service.game.extra = true; reject(bad,"unrecognized state")
	bad = raw.duplicate(true); bad.state.specials_enabled = false; reject(bad,"disabled service")
	bad = raw.duplicate(true); bad.state.service_visited.clear(); reject(bad,"unvisited service")
	bad = raw.duplicate(true); bad.state.landing_shop = true; reject(bad,"pending shop")
	bad = raw.duplicate(true); bad.state.landing_queue = [g.lots.keys()[0]]; reject(bad,"pending landing queue")
	bad = raw.duplicate(true); bad.state.pending_service.game.participants.pop_back(); reject(bad,"missing participant")
	bad = raw.duplicate(true); bad.state.pending_service.game.cursor = 1; reject(bad,"forged participant cursor")
	finish_remaining(g)
	bad = Save.snapshot(g); bad.state.pending_service.game.reward += 100; reject(bad,"overpaid result")
	bad = Save.snapshot(g); bad.state.pending_service.game.history[0].reward += 100; reject(bad,"other seat overpayment")
	bad = Save.snapshot(g); bad.state.pending_service.game.history[1].player = 0; reject(bad,"duplicate payee")
	bad = Save.snapshot(g); bad.state.pending_service.game.history.pop_back(); reject(bad,"incomplete final results")

func test_automatic_others() -> void:
	var g = fresh(); open(g)
	var before:Dictionary = Save.snapshot(g)
	check(not Mini.settle_others(g) and Save.snapshot(g) == before,"automatic opponents cannot skip triggering human game")
	Mini.start(g)
	for ignored in range(Mini.TEST_PROFILE.ticks):
		select_kind(g,"coin"); Mini.tick(g)
	var twin = restored(g,"before automatic others")
	check(Mini.settle_others(g) and g.pending_service.game.status == "result","all other seats complete in bounded automatic simulation")
	check(g.current == 0 and g.pending_service.game.history.size() == 4,"automatic others preserve turn and retain independent scores")
	for player in g.players: check(player.cash == 10000,"automatic scores remain unpaid until result claim")
	if twin != null:
		finish_remaining(twin)
		check(Save.snapshot(twin) == Save.snapshot(g),"batched automatic simulation equals individual legal commands")
	before = Save.snapshot(g)
	check(not Mini.settle_others(g) and Save.snapshot(g) == before,"automatic simulation cannot reroll completed results")

func test_guards() -> void:
	var g = fresh(1407,false)
	g.gm_teleport(0,road(g))
	check(g.phase == "land" and g.pending_service.is_empty() and not Mini.enter(g),"specials disabled preserves legacy no-op")
	g = fresh(); g.players[0].god = {"id":"fierce","remaining":3}; g.gm_teleport(0,road(g))
	check(g.phase == "land" and not Mini.enter(g),"fierce cannot enter")
	g = fresh(); g.players[0].pos = road(g); g.phase = "land"; g.steps_left = 1
	check(not Mini.enter(g),"passing does not open minigame")
	g.steps_left = 0; g.landing_pending = true
	check(not Mini.enter(g),"unfinished landing cannot open minigame")
	g = fresh(); g.send_to_facility(1,"hospital",2); g.players[2].god = {"id":"fierce","remaining":3}; open(g)
	check(g.pending_service.game.participants == [0,1,2,3],"test participation includes absent and possessed non-trigger seats")
	finish_remaining(g)
	check(g.pending_service.game.history.size() == 4 and g.players[1].status.kind == "hospital","independent play does not move or release board participants")
	restored(g,"absent participant results")
	g = fresh(); open(g); Mini.start(g); Mini.ai_step(g)
	var before:int = g.players[0].cash
	var destination:int = 0
	for node in g.nodes:
		if node.kind == "unresolved": destination = node.id; break
	check(g.gm_teleport(0,destination) and g.pending_service.is_empty(),"GM teleport discards active minigame")
	check(g.players[0].cash == before and not Mini.close(g),"interrupted score cannot be claimed")
	restored(g,"GM interruption")

func test_matches() -> void:
	var mini_steps:int = 0
	for teams in [[0,1,2,3],[0,0,1,1]]:
		var g = fresh(1400,true,teams)
		g.round_limit = 35
		var steps:int = 0
		while g.phase != "finished" and steps < 14000:
			if g.phase == "minigame": mini_steps += 1
			if not AI.step(g): check(false,"natural match stalls in "+g.phase); break
			steps += 1
		check(g.phase == "finished","natural knight FFA/team match finishes with new services")
	check(mini_steps >= 104,"natural games actually exercised all-seat minigame lifecycle")
