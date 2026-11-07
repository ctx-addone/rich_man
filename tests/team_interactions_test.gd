extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures := 0
func check(ok:bool, message:String)->void:
	if not ok: failures += 1; push_error(message)
func fresh():
	var g = Game.new()
	g.setup(["A","B","C","D"], 137, 20, {"teams":[0,1,0,1]})
	for p in g.players: p.cards.clear(); p.pos=0
	return g
func own(g,id:String,who:int,kind:String="house",level:int=2)->void:
	g.lots[id].owner=who
	g.lots[id].building_type=kind
	g.lots[id].level=level
func _init()->void:
	var g=fresh()
	own(g,"small_1_6",2)
	own(g,"small_4_6",1)
	g.players[0].pos=int(g.lots.small_1_6.frontage_nodes[0])
	g.players[0].cards=["worker"]
	check(g.card_targets("worker").has("small_1_6") and not g.card_targets("worker").has("small_4_6"),"worker selects allied, not enemy lots")
	check(g.use_card("worker","small_1_6") and g.lots.small_1_6.level==3 and g.lots.small_1_6.owner==2,"worker builds without changing allied ownership")
	g=fresh(); own(g,"small_1_6",2); own(g,"small_4_6",1)
	var before:int=g.rent_preview("small_1_6",1)
	g.players[0].cards=["glory"]
	check(g.use_card("glory") and g.rent_preview("small_1_6",1)==before*2,"glory benefits allied landlord")
	check(not g.players[1].has("glory_until") and g.rent_preview("small_1_6",0)==0,"enemy excluded from glory and allied rent remains zero")
	for card in ["misery","disaster"]:
		g=fresh(); own(g,"small_1_6",2); own(g,"small_4_6",1)
		g.players[0].cards=[card]
		check(g.use_card(card),"global team effect executes")
		check(g.lots.small_1_6.level==2 and g.lots.small_1_6.closed_until==0,"global opponent effect preserves allied lot")
		check(g.lots.small_4_6.level==0 if card=="disaster" else g.lots.small_4_6.closed_until>0,"global opponent effect changes enemy lot")
	g=fresh(); own(g,"small_1_6",1); own(g,"lot_1_1",2,"estate",2)
	var discounted:int=g.rent_preview("small_1_6",0)
	g.lots.lot_1_1.owner=3
	check(discounted<g.rent_preview("small_1_6",0),"allied estate discounts visitor rent; hostile estate does not")
	g=fresh(); own(g,"lot_1_1",2,"energy",2)
	var ally_price:int=g.shop_offers()[0].price
	g.lots.lot_1_1.owner=1
	check(g.shop_offers()[0].price>ally_price,"only hostile energy increases shop price")
	g=fresh(); g.Gods.attach(g,0,"wealth")
	check(g.players[2].cash==10000 and g.players[1].cash==9500 and g.players[0].cash==11000,"wealth entry collects from opposing teams only")
	g=fresh(); g.Gods.attach(g,0,"poor")
	check(g.players[2].cash==10000 and g.players[1].cash==10500 and g.players[0].cash==9000,"poor entry pays opposing teams only")
	g=fresh(); own(g,"small_1_6",2); g.players[0].pos=int(g.lots.small_1_6.frontage_nodes[0]); g.players[0].god={"id":"earth","remaining":5}
	g.Gods.pass_lots(g)
	check(g.lots.small_1_6.owner==2,"earth does not take allied property")
	g.players[0].god={"id":"fortune","remaining":5}; g.Gods.stop_lot(g,g.lots.small_1_6)
	check(g.lots.small_1_6.level==3,"fortune upgrades allied property")
	# The enemy-targeted missile chooses opponents, but its explosion retains friendly fire.
	g=fresh(); g.players[0].pos=60; g.players[1].pos=10; g.players[2].pos=30; g.players[3].pos=45
	g.players[0].cards=["rapid_missile"]
	check(g.use_card("rapid_missile"),"rapid missile executes against opponents")
	check(g.players[1].status.get("kind")=="hospital" and g.players[3].status.get("kind")=="hospital" and g.players[2].status.is_empty(),"remote ally is not a direct missile target")
	g=fresh(); g.players[0].pos=60; g.players[1].pos=10; g.players[2].pos=11; g.players[3].pos=45
	g.players[0].cards=["rapid_missile"]; g.use_card("rapid_missile")
	check(g.players[2].status.get("kind")=="hospital","allied bystander still takes explosion damage")
	g=fresh(); g.players[0].cards=["steal"]; g.players[2].cards=["dice"]
	check(g.card_targets("steal").has(2) and g.use_card("steal",2),"manual pickpocket can target ally; team is not blanket immunity")
	for card in ["scheme","sleepwalk"]:
		g=fresh(); g.players[0].cards=[card]
		check(not g.card_targets(card).has(2) and g.card_targets(card).has(1),"opponent-only card filters allied targets: "+card)
		check(not g.use_card(card,2) and g.players[0].cards==[card],"invalid allied target does not consume card")
	print("TEAM_INTERACTIONS failures=",failures)
	quit(1 if failures else 0)
