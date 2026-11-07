extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,msg:String)->void:
	if not ok: failures+=1; push_error(msg)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C"],11,30)
	for p in g.players: p.cards=[]
	return g
func _initialize()->void:
	var g=fresh()
	g.players[0].cards=["car","dice","super_dice"]
	check(g.use_card("car") and g.max_dice()==3 and g.dice_count==3,"car grants optional 3 dice")
	check(g.card_targets("dice").front()==3 and g.card_targets("dice").back()==18,"controlled legal sum bounds")
	check(g.use_card("dice",-1,14) and not g.set_dice_count(1),"pending controlled roll locks dice count")
	check(g.roll_dice() and g.last_dice.size()==3 and g.last_roll==14,"multi controlled sum")
	for face in g.last_dice: check(face>=1 and face<=6,"all controlled faces legal")
	g=fresh()
	g.players[0].cards=["turtle","dice"]
	check(g.use_card("turtle",0) and g.players[0].turtle_turns==3,"turtle self target")
	check(g.use_card("dice",-1,5) and g.roll_dice() and g.last_roll==5 and g.players[0].turtle_turns==2,"control overrides turtle consumes one duration")
	g=fresh()
	g.players[0].cards=["stay"]
	check(g.use_card("stay",0) and g.roll_dice() and g.phase=="land" and g.players[0].cash==10000 and g.last_roll==0,"stay card repeats landing without movement or start reward")
	g=fresh()
	g.players[0].pos=5;g.players[0].previous=4
	g.players[0].cards=["super_dice"]
	check(g.use_card("super_dice",-1,-2) and g.roll_dice() and g.available_moves()==[4],"super backward turns toward previous")
	check(g.move_to(4) and g.move_to(3) and g.players[0].pos==3,"super exact backwards steps")
	g=fresh()
	g.players[0].cards=["sleepwalk"]
	g.players[1].cards=["same_fate","dice"]
	check(g.use_card("sleepwalk",1) and g.phase=="reaction" and g.current==0,"sleepwalk reaction keeps actor")
	check(g.resolve_reaction("same_fate") and g.is_sleepwalking() and g.phase=="roll","same fate sleepwalk permits movement")
	check(not g.use_card("dice",-1,1) and not g.discard_card(0) and not g.can_trade_stocks(),"sleepwalk action guards")
	check(g.roll_dice() and g.available_moves().size()==1,"sleepwalk initial direction automatic")
	while g.phase=="move": g.move_to(g.available_moves()[0])
	var moved:int=g.players[0].pos
	check(moved!=0 and g.phase in ["land","end"],"sleepwalk truly travels")
	g.players[0].status.remaining=0
	check(g.gm_release(0) and g.players[0].pos==moved,"release keeps sleepwalk position")
	g=fresh()
	g.players[0].pos=6;g.players[0].previous=5
	g.players[0].status={"kind":"sleepwalk","remaining":2,"return_pos":6,"return_previous":5}
	check(g.roll_dice(1),"sleepwalk rolls")
	g.steps_left=2
	check(g.move_to(7) and g.phase=="move" and not g.bank_transfer(1),"sleepwalk skips bank without dropping steps")
	g=fresh()
	g.players[0].cards=["teleport"]
	check(not g.use_card("teleport",1,-1) and g.players[0].cards.has("teleport"),"invalid teleport atomic")
	check(g.use_card("teleport",1,40) and g.players[1].pos==40 and g.current==0 and g.phase=="roll","teleport player and road contract")
	g=fresh()
	g.road_objects[1]={"kind":"banana","owner":1}
	check(g.roll_dice(1) and g.move_to(1) and g.steps_left==1 and g.move_to(2),"banana grants extra actual step")
	g=fresh()
	g.road_objects[1]={"kind":"jelly","owner":1}
	check(g.roll_dice(6) and g.move_to(1) and g.steps_left==2 and g.available_moves()==[0],"jelly reverse two steps")
	g=fresh()
	g.road_objects[1]={"kind":"trap","owner":1}
	check(g.roll_dice(6) and g.move_to(1) and g.steps_left==0 and g.players[0].stay_turns==1,"trap stops and arms one stay")
	g=fresh()
	var fork:int=-1
	for n in g.nodes:
		if n.neighbors.size()>2: fork=n.id;break
	g.players[0].pos=fork;g.players[0].previous=g.nodes[fork].neighbors[0]
	g.roll_dice(3)
	check(g.available_moves().size()>1,"starting at junction allows choice")
	g.players[0].choose_junction=false
	var choice:Array=g.available_moves()
	check(choice.size()==1 and choice==g.available_moves(),"passing junction choice stable cached")
	g=fresh()
	g.players[0].cards=["robot"]
	g.players[0].previous=79
	g.road_objects[4]={"kind":"mine","owner":1}
	check(g.use_card("robot") and not g.road_objects.has(4),"robot clears forward obstacles")
	g=fresh()
	g.players[0].cards=["dice"]
	g.players[0].pos=5;g.players[0].previous=4
	check(not g.use_card("dice",[6,8],2) and g.players[0].cards.has("dice"),"invalid controlled path preserves hand")
	check(g.use_card("dice",[6,7,8],3) and g.roll_dice(),"controlled route accepted")
	check(g.move_to(6) and g.move_to(7) and g.phase=="bank" and g.controlled_path==[8],"bank pauses selected path")
	check(g.close_bank() and g.available_moves()==[8] and g.move_to(8),"bank resumes selected path without replay")
	g=fresh()
	g.players[0].cards=["super_dice"]
	g.players[0].pos=5;g.players[0].previous=4
	check(g.use_card("super_dice",[4,3],-2) and g.roll_dice() and g.available_moves()==[4],"selected negative route survives reverse")
	check(g.move_to(4) and g.move_to(3),"selected negative route traverses exactly")
	g=fresh()
	g.players[0].pos=12;g.players[0].previous=11
	g.players[0].status={"kind":"sleepwalk","remaining":1,"return_pos":0,"return_previous":-1}
	check(g.send_to_facility(0,"hospital",1) and g.gm_release(0) and g.players[0].pos==12,"hospital interrupts sleepwalk at current position")
	print("movement_test: %d failures"%failures)
	quit(1 if failures else 0)
