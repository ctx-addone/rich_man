extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1;push_error(label)
func fresh():
	var g=Game.new();g.setup(["A","B","C","D"],1431,20,{"map_id":"knight_manor","specials_enabled":true})
	return g
func at(g,kind:String)->int:
	for node in g.nodes:
		if node.kind==kind:return node.id
	return -1
func _init()->void:
	var g=fresh();var place:int=at(g,"minigame")
	g.players[0].pos=place;g.players[0].cards=["stay"]
	g.service_visited.append(place)
	check(g.use_card("stay",0),"real stay card sets landing intent")
	var payload:Dictionary=Save.snapshot(g)
	var restored:Dictionary=Save.restore(payload)
	check(restored.ok,"unconsumed stay card effect saves")
	var before_pos:int=g.players[0].pos
	g.players[0].bomb={"remaining":5,"owner":1}
	check(g.roll_dice() and g.phase=="minigame" and g.players[0].pos==before_pos and g.last_roll==0,"stay card re-enters minigame without moving")
	check(g.players[0].bomb.remaining==5 and g.players[0].stay_turns==0 and not g.players[0].has("stay_landing"),"no movement bomb countdown; landing intent consumed once")
	if restored.ok:
		restored.game.players[0].bomb={"remaining":5,"owner":1}
		restored.game.roll_dice()
		check(Save.snapshot(g)==Save.snapshot(restored.game),"stay landing and RNG reproduce after save")
	check(not g.roll_dice(),"cannot repeat roll while playing service")
	for value in [false,1,"yes",null]:
		var bad:Dictionary=payload.duplicate(true);bad.state.players[0].stay_landing=value
		check(not Save.restore(bad).ok,"invalid optional stay intent rejected")
	var bad:Dictionary=payload.duplicate(true);bad.state.players[0].stay_turns=0
	check(not Save.restore(bad).ok,"expired stay intent rejected")
	g=fresh();g.players[0].pos=at(g,"news");g.players[0].cards=["stay"]
	check(g.use_card("stay",0) and g.roll_dice() and g.phase=="news","shared stop pipeline also enters news")
	g=fresh();g.players[0].pos=place;g.players[0].stay_turns=1
	check(g.roll_dice() and g.phase=="end" and g.pending_service.is_empty(),"unverified magic/trap and historical untagged stay retain prior policy")
	print("STAY_LANDING_TEST failures=",failures)
	quit(0 if failures==0 else 1)
