extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1; printerr(label)
func fresh(assignment:Variant=[0,0,1,1],rounds:int=25):
	var g=Game.new()
	g.setup(["A","B","C","D"],27,rounds,{"teams":assignment})
	return g
func land_at(g,lot_id:String)->void:
	g.gm_teleport(g.current,int(g.lots[lot_id].frontage_nodes[0]))
func _init()->void:
	var g=Game.new()
	g.setup(["A","B","C","D"],27)
	for who in range(4): check(g.players[who].team==who,"default FFA assigns independent team")
	check(g.is_opponent(0,1) and g.same_team(0,0) and not g.same_team(-1,-1) and not g.is_opponent(-1,0),"team identity validates players")
	for bad in [[0,0,0,0],[0,1],[0,1,2,4],[0,1,2,-1],[0,1,2,true],[0,1,2,1.0],["blue","blue","red","red"],{},null]:
		check(not Game.Teams.valid_assignment(bad,4),"invalid assignment rejected: "+str(bad))
		g=fresh(bad)
		for who in range(4): check(g.players[who].team==who,"invalid assignment falls back atomically")
	check(Game.Teams.valid_assignment([0,2],2) and Game.Teams.valid_assignment([3,1,3,0],4),"noncontiguous team ids valid")
	g=fresh()
	check(g.same_team(0,1) and g.is_opponent(0,2) and not g.is_opponent(1,0),"explicit ally and opponent identity")
	check(g.team_members(0)==[0,1] and g.active_teams()==[0,1] and g.team_scores()=={0:20000,1:20000},"team queries expose independent wealth aggregation")
	g.players[0].team="blue";g.players[1].team="blue"
	check(g.same_team(0,1),"legacy string trait fixtures remain compatible")
	g.players[1].erase("team")
	check(not g.same_team(0,1) and g.same_team(1,1),"missing team means independent identity")
	g=fresh()
	var lot:Dictionary=g.lots.small_1_6
	lot.owner=1;lot.building_type="house";lot.level=1
	g.players[0].god={"id":"poor","remaining":3}
	check(g.rent_preview(lot.id,0)==0 and g.rent_preview(lot.id,2)>0,"ally immunity precedes rent multipliers")
	var payer_cash:int=g.players[0].cash
	var owner_cash:int=g.players[1].cash
	land_at(g,lot.id)
	check(g.phase=="land" and g.players[0].cash==payer_cash and g.players[1].cash==owner_cash,"ally landing never queues rent")
	check(g.can_upgrade_property(lot.id) and g.upgrade_property(lot.id),"ally can help upgrade small property")
	check(lot.owner==1 and lot.level==2 and g.players[0].cash==payer_cash-g.upgrade_cost(lot.id) and g.players[1].cash==owner_cash,"acting ally pays while owner retains property")
	check(not g.upgrade_property(lot.id),"one upgrade consumes landing action")
	g=fresh(); lot=g.lots.lot_1_1
	lot.owner=1;lot.building_type="hotel";lot.level=1
	land_at(g,lot.id)
	check(g.phase=="land" and g.players[0].status.is_empty() and g.players[0].cash==10000,"friendly hotel neither charges nor detains")
	check(g.upgrade_property(lot.id) and lot.owner==1 and lot.level==2,"large allied building may be upgraded")
	g=fresh();lot=g.lots.lot_1_1;lot.owner=1;lot.building_type="mall";lot.level=1
	var rng_before:int=g.rng.state
	land_at(g,lot.id)
	check(g.phase=="land" and g.rng.state==rng_before and g.players[0].cash==10000,"friendly mall skips fee and random multiplier")
	g=fresh();lot=g.lots.small_1_6;lot.owner=2;lot.building_type="house";lot.level=1
	land_at(g,lot.id)
	check(g.players[0].cash<10000 and not g.can_upgrade_property(lot.id) and not g.upgrade_property(lot.id),"enemy rent stays active and enemy upgrade rejected")
	g=fresh();lot=g.lots.small_1_6;lot.owner=1;lot.building_type="house";lot.level=1
	land_at(g,lot.id);g.players[0].cash=g.upgrade_cost(lot.id)-1
	check(not g.upgrade_property(lot.id) and lot.level==1 and g.players[1].cash==10000,"ally funds are never implicitly borrowed")
	g.players[0].cash=g.upgrade_cost(lot.id)
	check(g.upgrade_property(lot.id) and g.players[0].cash==0,"exact upgrade funds allowed")
	g=fresh();lot=g.lots.small_1_6;lot.owner=1;lot.building_type="house";lot.level=g.max_level(lot.id)
	land_at(g,lot.id);check(not g.upgrade_property(lot.id),"max level applies to allied upgrade")
	lot.level=1;g.players[0].god={"id":"misfortune","remaining":2}
	check(not g.upgrade_property(lot.id),"acting player's misfortune still blocks upgrade")
	g.players[0].god={};g.players[0].status={"kind":"sleepwalk","remaining":1}
	check(not g.upgrade_property(lot.id),"sleepwalker cannot assist upgrades")
	g=fresh();lot=g.lots.small_1_6;lot.owner=1;lot.building_type="chain";lot.level=1
	land_at(g,lot.id)
	check(not g.rebuild_property(lot.id,"house"),"team assistance does not grant owner-only rebuild")
	g=fresh();lot=g.lots.lot_1_1;lot.owner=1;lot.building_type="bookstore";lot.level=5
	g.players[0].cards.clear();g.phase="shop";g.close_shop()
	check(g.players[0].cards.size()>=1 and g.players[1].cards.size()==3,"allied bookstore rewards departing shopper rather than owner")
	g=fresh();lot=g.lots.lot_1_1;lot.owner=2;lot.building_type="bookstore";lot.level=5
	g.players[0].cards.clear();g.phase="shop";g.close_shop()
	check(g.players[0].cards.is_empty(),"enemy bookstore gives no team benefit")
	g=fresh();g.players[0].cash=30000;g.players[1].cash=1;g.players[2].cash=20000;g.players[3].cash=20000
	g.finish_game()
	check(g.winners==[2,3],"team combined wealth beats richest individual")
	g=fresh();g.finish_game();check(g.winners==[0,1,2,3],"tied teams jointly win")
	g=fresh();g.players[1].bankrupt=true;g.players[1].cash=999999
	check(g.team_members(0)==[0,1] and g.team_members(0,false)==[0] and g.team_scores()[0]==10000,"bankrupt member excluded from score but remains a member")
	g._check_winner();check(g.phase!="finished","one bankrupt teammate does not eliminate the team")
	g.players[2].bankrupt=true;g._check_winner();check(g.phase!="finished","opposing team survives through its last member")
	g.players[3].bankrupt=true;g._check_winner()
	check(g.phase=="finished" and g.winners==[0,1],"last surviving team wins including bankrupt teammate")
	g=fresh();g.players[0].cash=0;g.players[0].deposit=0
	var ally_cash:int=g.players[1].cash
	g._pay(0,500,2)
	check(g.players[0].bankrupt and g.players[1].cash==ally_cash and g.phase!="finished","debt never borrows teammate funds or prematurely eliminates team")
	g=fresh([0,0,1,1],1);g.players[0].cash=30000;g.players[1].cash=1;g.players[2].cash=20000;g.players[3].cash=20000
	g.current=3;g.phase="end";g.end_turn()
	check(g.phase=="finished" and g.winners==[2,3],"real turn limit dispatches team settlement")
	g=Game.new();g.setup(["A","B"],27);g.players[0].cash=15000;g.finish_game()
	check(g.winners==[0],"FFA winner unchanged")
	var completed:int=0
	for assignment in [[0,0,1,1],[0,1,0,2],[0,0,0,1],[0,1,2,3]]:
		g=fresh(assignment,30)
		var actions:int=0
		while g.phase!="finished" and actions<20000:
			actions+=1
			if not AI.step(g): check(false,"team match stalled: "+g.phase);break
		check(g.phase=="finished" and not g.winners.is_empty(),"team configuration completes 30-round match")
		if g.phase=="finished": completed+=1
	print("TEAMS_TEST failures=",failures," completed_matches=",completed)
	quit(0 if failures==0 else 1)
