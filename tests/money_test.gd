extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1; push_error(message)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C"],17,20,{"talents_enabled":true,"characters":["eleven","original","original"]})
	for p in g.players: p.cards.clear()
	return g
func loss(g,amount:int=1000)->void:
	g.Money.begin(g,0,amount,1,"rent")
	g.Combat.advance(g)
func _init()->void:
	var g=fresh()
	g.players[0].cards=["free"]
	loss(g)
	check(g.phase=="reaction" and g.players[0].cash==10000,"money pending before liquidation")
	check(g.reaction_options()==["free"],"only free eligible")
	check(not g.gm_cash(0,1) and not g.gm_give_card(0,"dice"),"external mutation remains blocked")
	check(g.resolve_reaction("free"),"free consumed")
	check(g.players[0].cash==10000 and g.players[1].cash==10000 and g.players[0].cards==["dice"],"waiver and eleven reward")
	g=fresh();g.players[0].cards=["free"];loss(g,499)
	check(g.phase=="roll" and g.players[0].cash==9501 and g.players[0].cards.has("free"),"below threshold no defense")
	g=fresh();g.players[0].cards=["transfer"];g.players[2].cards=["transfer","free"]
	loss(g)
	check(g.resolve_reaction("transfer",2),"money transfer")
	check(g.reaction_player()==2 and not g.reaction_targets("transfer").has(0),"transfer cannot loop to visited payer")
	check(g.resolve_reaction("free"),"transferee may waive")
	check(g.players[0].cash==10000 and g.players[2].cash==10000,"no payment on waived transfer")
	g=fresh();g.players[0].cards=["transfer"];loss(g);g.resolve_reaction("transfer",2)
	check(g.players[0].cash==10000 and g.players[2].cash==9000 and g.players[1].cash==11000,"receiver retained after transfer")
	g=fresh();g.players[0].cards=["transfer"];g.players[1].cash=0
	loss(g);g.resolve_reaction("transfer",1)
	check(not g.players[1].bankrupt and g.players[1].cash==0,"creditor self-payment does not liquidate or bankrupt")
	check(not g.Money.begin(g,0,500,9,"rent"),"invalid receiver rejected")
	g=fresh();g.players[0].cards=["free"];g.players[0].status={"kind":"sleepwalk","remaining":2};loss(g)
	check(g.players[0].cash==9000 and g.players[0].cards.has("free"),"sleeping cannot react")
	g=fresh();g.players[0].cards=["free"]
	var lot:Dictionary=g.lots.small_1_6
	lot.owner=1;lot.building_type="house";lot.level=5
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	check(g.phase=="reaction" and g.landing_pending,"real rent pauses landing")
	g.resolve_reaction("free")
	check(g.phase=="land" and not g.landing_pending and g.players[0].cash==10000,"landing resumes exactly once")
	g=fresh();g.players[0].cards=["free"]
	lot=g.lots.small_1_6;lot.owner=1;lot.building_type="house";lot.level=5
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	var second:Dictionary=g.lots.small_4_6
	second.owner=2;second.building_type="house";second.level=5
	g.landing_queue.append(second.id)
	var rent:int=g.rent_preview(second.id,0)
	g.resolve_reaction("free")
	check(g.players[0].cash==10000-rent and g.players[1].cash==10000 and g.players[2].cash==10000+rent,"remaining frontage queue charged once after waiver")
	check(not g.landing_pending and g.phase=="land","multi-lot landing completes")
	g=fresh();g.players[0].cards=["free"]
	for candidate in g.lots.values():
		if candidate.kind=="large": lot=candidate;break
	lot.owner=1;lot.building_type="hotel";lot.level=5
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	check(g.phase=="reaction","hotel money defense available")
	g.resolve_reaction("free")
	check(g.players[0].status.get("kind","")=="vacation" and g.players[0].cash==10000,"hotel stay independent of waiver")
	g=fresh();g.players[0].cash=0;g.players[0].deposit=0;loss(g)
	check(g.players[0].bankrupt and g.phase=="end","bankruptcy does not leave reaction stuck")
	g=fresh();g.players[0].cash=0;g.players[0].deposit=0
	lot=g.lots.small_1_6;lot.owner=1;lot.building_type="house";lot.level=5
	g.gm_teleport(0,int(lot.frontage_nodes[0]))
	check(g.players[0].bankrupt and not g.landing_pending and g.landing_queue.is_empty(),"bankruptcy clears interrupted landing")
	g.end_turn()
	check(g.current==1 and g.phase=="roll","next player begins cleanly")
	g=fresh();g.players[0].cards=["audit"];g.players[1].cards=["free"]
	check(g.use_card("audit",1) and g.reaction_player()==1,"audit reaches money reaction")
	g.resolve_reaction("free")
	check(g.players[1].cash==10000 and g.phase=="roll","audit waived and caster action resumes")
	print("MONEY_TEST failures=",failures)
	quit(1 if failures else 0)
