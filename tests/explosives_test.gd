extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Blast=preload("res://scripts/model/explosives.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1; push_error(message)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C","D"],12)
	for p in g.players: p.cards=[]; p.pos=40; p.bomb={}
	g.players[0].pos=60
	return g
func _initialize()->void:
	var g=fresh()
	g.players[1].pos=3
	g.players[1].cards=["immune"]
	g.players[1].vehicle="car"
	g.road_objects[2]={"kind":"mine","owner":0}
	g.road_objects[3]={"kind":"explosive","owner":0}
	check(Blast.blast(g,1,"missile",0),"missile accepted")
	check(g.road_objects.is_empty(),"mine then explosive chain consumed once")
	check(g.pending_attack.events.size()==2,"three distinct blast events queued")
	g.Combat.advance(g)
	check(g.reaction_player()==1 and g.pending_attack.days==2,"mine window preserves own days")
	check(g.players[1].vehicle=="foot","vehicle destroyed before immune")
	check(g.resolve_reaction("immune"),"mine immunity resolves")
	check(g.players[1].status.remaining==8,"later explosive retains eight days")
	check(g.pending_attack.is_empty() and g.phase=="roll","chain drains and restores phase")
	g=fresh()
	var id=g.lots_at_node(1)[0]
	g.lots[id].level=6
	Blast.blast(g,1,"missile",0)
	check(g.lots[id].level==5,"multi frontage building damaged once per event")
	g.Combat.advance(g)
	Blast.blast(g,1,"explosive",0)
	check(g.lots[id].level==5,"unverified explosive building damage omitted")
	g.Combat.advance(g)
	Blast.blast(g,1,"quantum",0)
	check(g.lots[id].level==0 and g.lots[id].building_type=="vacant","quantum flattens building")
	g.Combat.advance(g)
	g=fresh()
	g.players[0].pos=1
	g.road_objects[1]={"kind":"timebomb","owner":1}
	check(not Blast.arrive(g,0) and g.players[0].bomb.remaining==30,"attachment starts at thirty")
	for step in range(29): check(not Blast.after_step(g,0),"first twenty nine steps safe")
	check(g.players[0].bomb.remaining==1,"twenty nine actual steps")
	check(Blast.after_step(g,0) and g.players[0].bomb.is_empty(),"thirtieth step detonates")
	g.Combat.advance(g)
	check(g.players[0].status.remaining==4,"timebomb four days")
	g=fresh()
	g.players[0].pos=1
	g.players[1].pos=1
	g.players[0].bomb={"remaining":20,"owner":2}
	Blast.after_step(g,0)
	check(g.players[0].bomb.is_empty() and g.players[1].bomb.remaining==19,"moving carrier transfers preserved countdown once")
	check(Blast.activate(g,1,0) and g.players[1].bomb.is_empty(),"activation detonates attached bomb")
	g.Combat.advance(g)
	check(g.players[1].status.remaining==4,"activated attached bomb applies four days")
	g=fresh()
	g.players[1].pos=1
	g.players[2].pos=1
	g.players[3].pos=10
	check(Blast.rapid_missile(g,0) and g.pending_attack.events.size()==1,"rapid targets multiple roads with coincident roads deduplicated")
	g.Combat.advance(g)
	check(g.players[1].status.remaining==3 and g.players[2].status.remaining==3 and g.players[3].status.remaining==3,"rapid all opponents hit")
	g=fresh()
	g.players[1].pos=1
	g.players[1].cards=["immune"]
	g.Combat.begin(g,"scheme",0,[1],"prison",2)
	g.Combat.advance(g)
	Blast.blast(g,1,"missile",0)
	check(g.pending_attack.source=="scheme" and g.pending_attack.events.size()==1,"existing reaction never overwritten")
	g.resolve_reaction("immune")
	check(g.players[1].status.kind=="hospital" and g.players[1].status.remaining==1,"queued blast proceeds after old reaction")
	g=fresh()
	g.players[0].pos=0
	g.players[0].cards=["immune"]
	g.players[0].bomb={"remaining":2,"owner":1}
	check(g.roll_dice(2) and g.players[0].bomb.remaining==2,"rolling does not decrement bomb")
	check(g.move_to(1) and g.players[0].bomb.remaining==1,"real first road step decrements once")
	check(g.move_to(2) and g.phase=="reaction" and g.players[0].bomb.is_empty(),"real expiry suspends arrival")
	check(g.resolve_reaction("immune") and g.phase=="land","immune expiry resumes final landing once")
	g=fresh()
	g.players[0].pos=0
	g.players[0].bomb={"remaining":10,"owner":1}
	check(g.gm_teleport(0,5) and g.players[0].bomb.remaining==10,"teleport is not an actual road step")
	g=fresh()
	g.players[1].pos=1
	g.players[1].cards=["immune","transfer"]
	g.road_objects[1]={"kind":"mine","owner":0}
	g.road_objects[2]={"kind":"mine","owner":0}
	Blast.blast(g,1,"missile",0)
	check(g.pending_attack.events.size()==2 and g.road_objects.is_empty(),"adjacent mines cannot amplify into an infinite ring")
	g.Combat.advance(g)
	g.resolve_reaction("immune")
	check(g.phase=="reaction" and g.pending_attack.source=="mine","next event opens separate defense window")
	g.resolve_reaction("transfer",0)
	check(g.players[0].status.remaining==2 and g.players[1].status.remaining==2,"transferred event and later event both retained")
	print("explosives_test: ",failures," failures")
	quit(1 if failures else 0)
