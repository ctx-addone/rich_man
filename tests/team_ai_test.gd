extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1; printerr(label)
func fresh(teams:Array=[0,0,1,1],seed_value:int=13):
	var g=Game.new()
	g.setup(["A","B","C","D"],seed_value,40,{"teams":teams})
	for p in g.players: p.cards.clear()
	return g
func _init()->void:
	test_targeting()
	test_reactions()
	test_property_and_traits()
	test_matches()
	print("TEAM_AI_TEST failures=",failures)
	quit(1 if failures else 0)

func test_targeting()->void:
	var g=fresh()
	check(g.same_team(0,0) and g.same_team(0,1) and not g.is_opponent(0,0) and g.is_opponent(0,2),"self is allied and never enemy")
	for card in ["audit","steal","scheme","hibernate","sleepwalk","turtle"]:
		g=fresh()
		g.players[0].cards=[card]
		g.players[1].cash=90000;g.players[1].cards=["dice"]
		g.players[2].cash=20000;g.players[2].cards=["dice"]
		g.players[3].cash=10000;g.players[3].cards=["dice"]
		var ally:Dictionary=g.players[1].duplicate(true)
		check(AI._play_card(g),"AI uses legal enemy-targeted "+card)
		check(g.players[1]==ally,"rich ally remains untouched by "+card)
		check(g.players[0].cards.count(card)==0,"targeted card consumed once "+card)
	g=fresh();g.players[0].cards=["audit"]
	g.players[2].pos=50;g.players[3].pos=50
	var before:int=g.rng.state
	check(not AI._play_card(g) and g.players[0].cards==["audit"] and g.rng.state==before,"no eligible enemy retains card without peeking RNG")
	g=fresh();g.gm_god(1,"poor");g.players[0].cards=["send_god"]
	check(AI._play_card(g) and g.players[1].god.is_empty(),"send god helps ally with bad attachment")
	g=fresh();g.gm_god(1,"angel");g.players[0].cards=["send_god"]
	check(not AI._play_card(g) and g.players[1].god.id=="angel","send god preserves allied good attachment")
	g=fresh();g.gm_god(1,"angel");g.gm_god(2,"wealth");g.players[0].cards=["god_bless"]
	check(AI._play_card(g) and g.players[1].god.id=="angel" and g.players[2].god.is_empty() and g.players[0].god.id=="wealth","bless takes enemy god instead of allied god")
	g=fresh();g.players[0].cards=["buy_land"]
	g.lots.small_1_6.owner=1
	g.players[0].pos=int(g.lots.small_1_6.frontage_nodes[0])
	check(not AI._play_card(g) and g.lots.small_1_6.owner==1,"purchase card does not move allied ownership")
	for card in ["misery","disaster"]:
		g=fresh();g.players[0].cards=[card]
		g.lots.small_1_6.owner=1;g.lots.small_1_6.level=2;g.lots.small_1_6.building_type="house"
		g.lots.small_4_6.owner=2;g.lots.small_4_6.level=2;g.lots.small_4_6.building_type="house"
		var ally_lot:Dictionary=g.lots.small_1_6.duplicate(true)
		check(AI._play_card(g) and g.lots.small_1_6==ally_lot,"enemy-only global attack preserves allied property "+card)
		g=fresh();g.players[0].cards=[card]
		g.lots.small_1_6.owner=1;g.lots.small_1_6.level=2;g.lots.small_1_6.building_type="house"
		check(not AI._play_card(g),"global attack retained without useful enemy property "+card)
	g=fresh();g.players[0].cards=["robot"]
	for node in g.nodes: g.road_objects[node.id]={"kind":"mine","owner":1}
	check(not AI._play_card(g) and g.road_objects.size()==g.nodes.size(),"robot will not clear an allied trap route")

func test_reactions()->void:
	var g=fresh()
	g.players[2].cards=["transfer"]
	g.players[1].cash=50000;g.players[3].cash=200000
	g.Money.begin(g,2,1000,0,"audit");g.Combat.advance(g)
	check(g.reaction_player()==2 and g.current==0,"reaction defender differs from active player")
	check(AI.step(g),"AI resolves money transfer")
	check(g.players[1].cash==49000 and g.players[3].cash==200000 and g.players[2].cash==10000,"transfer targets defender enemy, never richest teammate")
	g=fresh();g.players[2].cards=["transfer"]
	for who in [0,1]: g.players[who].status={"kind":"hospital","remaining":2,"return_pos":0,"return_previous":-1}
	g.Money.begin(g,2,1000,-1,"audit");g.Combat.advance(g)
	check(AI.step(g) and g.players[2].cash==9000 and g.players[2].cards==["transfer"] and g.players[3].cash==10000,"no hostile transfer target accepts loss without hurting ally")
	g=fresh();g.current=1;g.players[0].cards=["same_fate"]
	g.Combat.begin(g,"scheme",1,[0],"prison",2);g.Combat.advance(g)
	check(AI.step(g) and g.players[0].cards==["same_fate"] and g.players[1].status.is_empty(),"same fate does not retaliate against friendly attacker")
	g=fresh();g.current=2;g.players[0].cards=["same_fate"]
	g.Combat.begin(g,"scheme",2,[0],"prison",2);g.Combat.advance(g)
	check(AI.step(g) and g.players[0].cards.is_empty() and g.players[2].status.get("kind","")=="prison","same fate still retaliates against hostile attacker")

func test_property_and_traits()->void:
	var g=fresh()
	var lot:Dictionary=g.lots.small_1_6
	lot.owner=1;lot.level=1;lot.building_type="house"
	g.players[0].pos=int(lot.frontage_nodes[0]);g.players[0].cash=20000;g.phase="land"
	var owner_cash:int=g.players[1].cash
	check(AI.step(g) and lot.level==2 and lot.owner==1 and g.players[1].cash==owner_cash,"AI funds normal allied upgrade without moving ownership")
	g.phase="roll";g.players[0].cards=["worker"]
	check(AI._play_card(g) and lot.level==3 and lot.owner==1,"AI worker upgrades legal allied target")
	g=fresh();lot=g.lots.small_1_6
	lot.owner=1;lot.level=1;lot.building_type="hotel"
	var road:int=int(lot.frontage_nodes[0])
	var allied_score:float=AI._road_score(g,road)
	lot.owner=2
	check(allied_score>AI._road_score(g,road),"allied frontage has no hostile hotel penalty")
	g=fresh();g.talents_enabled=true;g.players[1].character_id="ludwig"
	g.Traits.on_card_lost(g,1,"steal")
	check(g.players[0].cards.size()==1 and g.players[1].cards.size()==1 and g.players[2].cards.is_empty(),"Ludwig rewards live integer team only")
	g.players[0].bankrupt=true;g.players[0].cards.clear()
	g.Traits.on_card_lost(g,1,"misfortune")
	check(g.players[0].cards.is_empty() and g.players[1].cards.size()==2,"Ludwig skips bankrupt ally")
	g=fresh();g.talents_enabled=true;g.players[1].character_id="jin_beibei"
	check(not g.Traits.target_immune(g,0,1,"send_god") and g.Traits.target_immune(g,2,1,"send_god"),"Jin Beibei distinguishes ally and enemy outside own turn")
	g.players[0].team="blue";g.players[1].team="blue"
	check(not g.Traits.target_immune(g,0,1,"send_god"),"legacy manually assigned string team stays compatible")

func test_matches()->void:
	var completed:int=0
	for teams in [[0,0,1,1],[0,1,2,3]]:
		for seed_value in [11,19,37,53]:
			var g=Game.new()
			g.setup(["A","B","C","D"],seed_value,50,{"teams":teams,"gods_enabled":true,"talents_enabled":true,"specials_enabled":true,"characters":["ludwig","jin_beibei","eleven","shalong"]})
			var actions:int=0
			while g.phase!="finished" and actions<20000:
				actions+=1
				if not AI.step(g):
					check(false,"team AI stalled at %s seed %d teams %s"%[g.phase,seed_value,str(teams)])
					break
				for p in g.players: check(p.cash>=0 and p.deposit>=0 and p.cards.size()<=g.HAND_LIMIT,"team match economy and hand invariants")
			check(g.phase=="finished" and not g.winners.is_empty(),"natural 50-round match completes")
			if g.phase=="finished": completed+=1
	var g=fresh([0,0,1,1],29)
	var twin=fresh([0,0,1,1],29)
	for ignored in range(200):
		if g.phase=="finished": break
		check(AI.step(g)==AI.step(twin),"same public team state chooses same action")
		check(g.players==twin.players and g.phase==twin.phase and g.rng.state==twin.rng.state,"team policy deterministic trajectory")
	print("TEAM_AI completed_matches=",completed)
