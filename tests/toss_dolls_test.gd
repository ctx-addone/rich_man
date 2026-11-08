extends SceneTree
const Game = preload("res://scripts/game_state.gd")
const Dolls = preload("res://scripts/model/toss_dolls_rules.gd")
const Save = preload("res://scripts/model/save_game.gd")
const AI = preload("res://scripts/model/ai_controller.gd")
var failures:int = 0

func check(ok:bool, label:String) -> void:
	if not ok: failures += 1; push_error(label)

func fresh(seed_value:int=1501):
	var g = Game.new()
	check(g.setup(["A","B","C","D"],seed_value,20,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":false,"talents_enabled":false}),"map setup")
	return g

func road(g) -> int:
	for node in g.nodes:
		if node.kind == "minigame": return node.id
	return -1

func open(g) -> void:
	check(g.gm_teleport(g.current,road(g)) and g.Minigame.gm_choose_ready(g,"toss_dolls"),"actual map entry with explicit GM fixture selection")
	check(g.pending_service.game.id == "toss_dolls" and g.pending_service.game.status == "ready","dolls ready state")

func restored(g,label:String):
	var snapshot:Dictionary = Save.snapshot(g)
	var result:Dictionary = Save.restore(snapshot)
	check(result.ok,label+" restores: "+str(result.get("error","")))
	if not result.ok: return null
	check(Save.snapshot(result.game) == snapshot,label+" preserves every field and RNG")
	return result.game

func reject(raw:Dictionary, label:String) -> void:
	var copy:Dictionary = raw.duplicate(true)
	check(not Save.restore(raw).ok,label+" rejected")
	check(raw == copy,label+" rejection is pure")

func choose_and_tick(g,bin_id:int) -> void:
	check(Dolls.toss(g,bin_id) and Dolls.tick(g),"one object consumes one legal input")

func advance_to(g,kind:String) -> bool:
	var count:int = 0
	while g.pending_service.game.status == "playing" and g.pending_service.game.queue[0] != kind and count < Dolls.TEST_PROFILE.ticks:
		Dolls.ai_step(g); count += 1
	return g.pending_service.game.status == "playing" and g.pending_service.game.queue[0] == kind

func _init() -> void:
	test_commands()
	test_bombs_and_scores()
	test_automatic_scores()
	test_queue_and_timeout()
	test_validation()
	test_guards()
	test_matches()
	print("TOSS_DOLLS_TEST failures=",failures)
	quit(1 if failures else 0)

func test_commands() -> void:
	var g = fresh(); open(g)
	var before:Dictionary = Save.snapshot(g)
	check(not Dolls.toss(g,0) and not Dolls.tick(g) and not Dolls.close(g) and not Dolls.settle_others(g),"ready cannot advance, claim or skip manual player")
	check(Save.snapshot(g) == before,"ready rejections do not change random state")
	restored(g,"ready")
	check(Dolls.start(g) and not Dolls.start(g),"explicit start once")
	before = Save.snapshot(g)
	var target:int = Dolls.ai_bin(g)
	check(target in [0,1,2] and Save.snapshot(g) == before,"AI only reads visible queue head")
	check(not Dolls.toss(g,-1) and not Dolls.toss(g,3) and not g.Minigame.select_cell(g,4),"invalid bin and cross-game command rejected")
	check(Save.snapshot(g) == before,"invalid commands do not redraw queue")
	var visible:Array = g.pending_service.game.queue.duplicate()
	check(Dolls.toss(g,target),"click locks one throw")
	before = Save.snapshot(g)
	check(not Dolls.toss(g,target) and not Dolls.toss(g,(target+1)%3),"rapid repeated clicks cannot throw one object twice or change a locked choice")
	check(Save.snapshot(g) == before,"duplicate throw has no RNG or score effect")
	var twin = restored(g,"queued human throw")
	check(Dolls.tick(g),"time tick resolves queued throw")
	check(g.pending_service.game.events.size() == 1 and g.pending_service.game.events[0].kind == visible[0],"actual preview head is consumed")
	for index in range(visible.size()-1): check(g.pending_service.game.queue[index] == visible[index+1],"future preview remains truthful")
	if twin != null:
		Dolls.tick(twin)
		check(Save.snapshot(twin) == Save.snapshot(g),"queued input survives load exactly")
	restored(g,"active queue")

func test_bombs_and_scores() -> void:
	for color in ["blue","pink"]:
		var g = fresh(); open(g); Dolls.start(g)
		check(advance_to(g,color),"seed contains tested doll")
		var old_score:int = g.pending_service.game.score
		choose_and_tick(g,0 if color == "blue" else 2)
		check(g.pending_service.game.score == old_score+350,"single correct doll matches filmed +350")
		check(advance_to(g,"bomb"),"seed contains subsequent bomb")
		var other:String = "pink" if color == "blue" else "blue"
		var other_count:int = g.pending_service.game.baskets[other]
		choose_and_tick(g,0 if color == "blue" else 2)
		check(g.pending_service.game.status == "participant_result" and g.pending_service.game.reason == "bomb_"+color,"bomb in basket ends this participant early")
		check(g.pending_service.game.baskets[color] == 0 and g.pending_service.game.baskets[other] == other_count,"only hit basket is cleared")
		check(g.pending_service.game.score == other_count*350 and g.players[0].cash == 10000,"retained other basket determines score without premature payment")
		restored(g,"early bomb result")
		check(not Dolls.close(g),"first participant result cannot claim whole game")
	var g = fresh(); open(g); Dolls.start(g)
	check(advance_to(g,"bomb"),"held bomb fixture")
	var score:int = g.pending_service.game.score
	check(Dolls.tick(g),"unhandled object reaches deadline")
	check(g.pending_service.game.reason == "held_bomb" and g.pending_service.game.score == score,"TEST held bomb ends without fabricating basket loss")
	restored(g,"held bomb result")
	g = fresh(); open(g); Dolls.start(g)
	check(advance_to(g,"blue"),"wrong color fixture")
	score = g.pending_service.game.score
	choose_and_tick(g,2)
	check(g.pending_service.game.score == score and g.pending_service.game.status == "playing","TEST wrong-color doll grants no points and keeps playing")
	check(advance_to(g,"pink"),"discard fixture")
	score = g.pending_service.game.score
	choose_and_tick(g,1)
	check(g.pending_service.game.score == score,"discarded doll gives no points")

func test_automatic_scores() -> void:
	var manual = fresh(1511); open(manual)
	var automatic = restored(manual,"initial deterministic pair")
	if automatic == null: return
	Dolls.start(manual); Dolls.start(automatic)
	while manual.pending_service.game.status == "playing":
		var target:int = Dolls.ai_bin(manual)
		Dolls.toss(manual,target); Dolls.tick(manual)
		Dolls.ai_step(automatic)
		check(Save.snapshot(manual) == Save.snapshot(automatic),"AI is exactly equivalent to visible human commands")
	check(manual.pending_service.game.status == "participant_result","manual trigger finishes before other automatic seats")
	var twin = restored(manual,"before automatic participants")
	check(Dolls.settle_others(manual),"other local seats automatically play bounded legal command sequence")
	if twin != null:
		var budget:int = 200
		while twin.pending_service.game.status != "result" and budget > 0: Dolls.ai_step(twin); budget -= 1
		check(budget > 0 and Save.snapshot(twin) == Save.snapshot(manual),"batch simulation equals individual steps")
	check(manual.current == 0 and manual.pending_service.game.history.size() == 4,"all seats get independent records and original board turn remains")
	var records:Array = manual.pending_service.game.history.duplicate(true)
	for player in manual.players: check(player.cash == 10000,"automatic simulation has not paid early")
	restored(manual,"final unclaimed results")
	check(Dolls.close(manual) and not Dolls.close(manual) and manual.phase == "land","all rewards claim once and return to board")
	for record in records: check(manual.players[record.player].cash == 10000+record.reward,"individual reward credited to correct player")
	check(not Dolls.enter(manual),"same landing cannot reroll")
	restored(manual,"claimed rewards")

func test_validation() -> void:
	var g = fresh(); open(g); Dolls.start(g); Dolls.ai_step(g)
	check(not Dolls.state_error({"phase":"minigame"},g).is_empty(),"direct malformed state validation is safe")
	var raw:Dictionary = Save.snapshot(g)
	var bad:Dictionary = raw.duplicate(true); bad.state.pending_service.game.score += 350; reject(bad,"forged score")
	bad = raw.duplicate(true); bad.state.pending_service.game.baskets.blue += 1; reject(bad,"forged basket")
	bad = raw.duplicate(true); bad.state.pending_service.game.choice = 3; reject(bad,"illegal bin")
	bad = raw.duplicate(true); bad.state.pending_service.game.queue[0] = "ingot"; reject(bad,"wrong game object")
	bad = raw.duplicate(true); bad.state.pending_service.game.events[0].bin = -2; reject(bad,"invalid history input")
	bad = raw.duplicate(true); bad.state.pending_service.game.tick = 0; reject(bad,"clock before recorded input")
	bad = raw.duplicate(true); bad.state.pending_service.game.spawned += 1; reject(bad,"invented extra supply")
	bad = raw.duplicate(true); bad.state.pending_service.game.reward = 999999; reject(bad,"early reward")
	bad = raw.duplicate(true); bad.state.pending_service.game.reason = "time_up"; reject(bad,"invented ending")
	bad = raw.duplicate(true); bad.state.pending_service.game.participants.pop_back(); reject(bad,"omitted participant")
	bad = raw.duplicate(true); bad.state.pending_service.game.cell = 4; reject(bad,"cross-game field")
	bad = raw.duplicate(true); bad.version = 5; reject(bad,"new doll game in legacy v5")
	while g.pending_service.game.status == "playing": Dolls.ai_step(g)
	Dolls.settle_others(g)
	bad = Save.snapshot(g); bad.state.pending_service.game.history[0].reward += 350; reject(bad,"forged completed reward")
	bad = Save.snapshot(g); bad.state.pending_service.game.history[1].player = 0; reject(bad,"duplicate recipient")
	bad = Save.snapshot(g); bad.state.pending_service.game.history[0].events.append({"kind":"blue","bin":0}); reject(bad,"event after completion")
	bad = Save.snapshot(g); bad.state.pending_service.game.history[0].baskets.blue = float(bad.state.pending_service.game.history[0].baskets.blue); reject(bad,"noninteger history basket")

func test_queue_and_timeout() -> void:
	var g = fresh(); open(g); Dolls.start(g)
	var count:int = 0
	while g.pending_service.game.status == "playing":
		Dolls.ai_step(g); count += 1
		if g.pending_service.game.queue.size() == 2 and g.pending_service.game.status == "playing": restored(g,"shrinking finite preview")
	check(count == Dolls.TEST_PROFILE.items_total and g.pending_service.game.reason == "queue_empty","finite supply empties before timer")
	check(g.pending_service.game.tick < Dolls.TEST_PROFILE.ticks and g.pending_service.game.spawned == Dolls.TEST_PROFILE.items_total,"early finish keeps unexpired timer and finite supply count")
	restored(g,"queue-empty result")
	g = fresh(); open(g); Dolls.start(g)
	check(advance_to(g,"blue"),"ordinary held doll fixture")
	var queue:Array = g.pending_service.game.queue.duplicate()
	var before_events:Array = g.pending_service.game.events.duplicate(true)
	var before_rng:int = g.rng.state
	check(Dolls.tick(g) and g.pending_service.game.queue == queue and g.pending_service.game.events == before_events and g.rng.state == before_rng,"unthrown ordinary doll remains held without reroll or score")
	restored(g,"held doll while timer advances")
	while g.pending_service.game.status == "playing": Dolls.tick(g)
	check(g.pending_service.game.reason == "time_up" and g.pending_service.game.tick == Dolls.TEST_PROFILE.ticks,"unresolved ordinary doll can reach real time limit")
	restored(g,"timeout result")

func test_guards() -> void:
	var g = fresh(); open(g)
	check(not Dolls.enter(g),"already open service cannot enter twice")
	g.Minigame.gm_choose_ready(g,"catch_coins")
	var before:Dictionary = Save.snapshot(g)
	check(not Dolls.start(g) and not Dolls.tick(g) and not Dolls.toss(g,1) and not Dolls.close(g) and not Dolls.settle_others(g),"doll methods reject catch game")
	check(Save.snapshot(g) == before,"cross-game rejection preserves all state")
	g = fresh(); open(g); Dolls.start(g); Dolls.ai_step(g)
	check(g.gm_teleport(0,0) and g.pending_service.is_empty() and not Dolls.close(g),"GM interruption discards unpaid service")
	check(g.players[0].cash == 10000,"interrupted scoring gives no cash")

func test_matches() -> void:
	var seen:Dictionary = {}
	for teams in [[0,1,2,3],[0,0,1,1]]:
		seen.merge(natural_match(1400,teams))
	# Growing the verified game pool changes random selection. Preserve actual
	# natural coverage rather than replacing it with a forced phase/GM entry.
	for seed_value in range(1510,1516):
		if seen.has("toss_dolls"): break
		seen.merge(natural_match(seed_value,[0,1,2,3]))
	check(seen.has("toss_dolls"),"natural whole-game regression actually enters doll minigame")

func natural_match(seed_value:int,teams:Array) -> Dictionary:
	var seen:Dictionary = {}
	var g = Game.new()
	g.setup(["A","B","C","D"],seed_value,35,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":false,"talents_enabled":false,"teams":teams})
	var count:int = 0
	while g.phase != "finished" and count < 18000:
		if g.phase == "minigame": seen[g.pending_service.game.id] = true
		if not AI.step(g): check(false,"AI stalls in "+g.phase); break
		count += 1
	check(g.phase == "finished","natural FFA/team knight match completes with mixed minigames")
	if seen.has("toss_dolls"): print("TOSS_NATURAL_COVERAGE seed=",seed_value," teams=",teams)
	return seen
