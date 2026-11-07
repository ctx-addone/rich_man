extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1; push_error(message)
func _initialize()->void:
	var g=Game.new()
	g.setup(["甲","乙","丙","丁"],42)
	check(g.nodes.size()==117, "Integration map contains 117 roads")
	var queue:Array[int]=[0]
	var visited:Array[int]=[0]
	while not queue.is_empty():
		var at:int=queue.pop_front()
		for target in g.nodes[at].neighbors:
			check(g.nodes[target].neighbors.has(at), "Road adjacency symmetric")
			if not visited.has(target): visited.append(target); queue.append(target)
	check(visited.size()==g.nodes.size(), "Every road reachable")
	for n in g.nodes: check(not n.has("owner"),"Road has no ownership")
	var lot:Dictionary=g.lots.lot_1_1
	var a:int=int(lot.frontage_nodes[0])
	var b:int=int(lot.frontage_nodes[1])
	g.gm_teleport(0,a)
	check(g.buy_property(lot.id),"Buy via frontage A")
	g.gm_teleport(0,b)
	check(g.upgrade_property(lot.id) and lot.owner==0 and lot.level==2,"Frontage B shares same ownership")
	g.end_turn()
	g.gm_teleport(1,a)
	check(g.players[1].cash==9120,"Rent charged once from frontage A")
	g.setup(["甲","乙","丙","丁"],42)
	g.players[0].pos=6
	g.players[0].previous=5
	g.roll_dice(3)
	g.move_to(7)
	check(g.phase=="bank" and g.steps_left==2,"Passing bank interrupts with remaining steps")
	check(g.bank_transfer(3000) and g.players[0].deposit==3000,"Deposit works")
	check(not g.bank_transfer(8000),"Reject insufficient cash")
	check(g.bank_transfer(-1000) and g.net_worth(0)==10000,"Withdrawal conserves assets")
	check(not g.end_turn(),"Cannot abandon unresolved bank phase")
	g.close_bank()
	g.move_to(8)
	check(g.phase=="move","Contiguous bank frontage does not open twice")
	g.move_to(9)
	check(g.phase=="land" and g.players[0].pos==9,"Bank resumes to final stop")
	g.setup(["甲","乙","丙","丁"],42)
	g.gm_teleport(0,7)
	check(g.phase=="bank" and g.steps_left==0,"GM bank landing opens service")
	check(g.close_bank() and g.phase=="land","Final bank stop closes once without reopening")
	g.setup(["甲","乙","丙","丁"],42)
	g.lots.lot_1_1.owner=1
	g.lots.lot_1_1.level=1
	g.players[0].cash=0
	g.nodes[a].kind="event"
	g.gm_teleport(0,a)
	check(g.players[0].bankrupt and g.players[0].cash==0 and g.players[0].cards.is_empty(),"Bankrupt landing cannot award event cash or cards")
	g.setup(["甲","乙","丙","丁"],42)
	check(g.use_card("dice",-1,3),"Remote die selectable")
	check(g.use_card("scheme",1),"Multiple cards possible, scheme targets opponent")
	check(g.players[1].status.kind=="prison" and g.players[1].status.remaining==2,"Scheme enters prison")
	g.roll_dice()
	check(g.last_roll==3,"Chosen die value")
	g.gm_teleport(0,0)
	g.end_turn()
	check(g.phase=="detained" and not g.roll_dice(),"Prison blocks movement")
	g.end_turn()
	check(g.players[1].status.remaining==1,"Detained turn counted once")
	for i in range(3): g.phase="end"; g.end_turn()
	check(g.phase=="detained","Second missed turn")
	g.end_turn()
	for i in range(3): g.phase="end"; g.end_turn()
	check(g.current==1 and g.phase=="roll" and g.players[1].status.is_empty(),"Release after two missed actions")
	g.setup(["甲","乙","丙","丁"],42)
	check(g.use_card("mine",1),"Place mine on nearby road")
	g.roll_dice(2)
	g.move_to(1)
	check(g.players[0].status.kind=="hospital" and g.phase=="end" and g.steps_left==0,"Mine sends passing player to hospital")
	check(not g.road_objects.has(1),"Mine consumed")
	check(g.gm_release(0) and g.players[0].pos==1,"Release restores original road")
	g.finish_game()
	check(not g.roll_dice() and not g.gm_cash(0,100) and not g.send_to_facility(0,"hospital",2),"Finished game rejects mutations")
	# These accounting tests lock provisional policy, not verified original-game economics.
	g.setup(["甲","乙","丙","丁"],42)
	g.lots.lot_1_1.owner=1
	g.lots.lot_1_1.level=2
	g.players[0].cash=100
	g.players[0].deposit=1000
	g.gm_teleport(0,a)
	check(g.players[0].cash==0 and g.players[0].deposit==220, "Cash spent before withdrawing only deposit shortfall")
	check(g.players[1].cash==10880 and not g.players[0].bankrupt, "Full rent transferred from sufficient savings")
	check(g.players[0].cash+g.players[0].deposit+g.players[1].cash==11100, "Rent conserves combined liquid balances")
	g.setup(["甲","乙","丙","丁"],42)
	g.lots.lot_1_1.owner=1
	g.lots.lot_1_1.level=2
	g.players[0].cash=100
	g.players[0].deposit=100
	var sale:Dictionary=g.lots.lot_7_9
	sale.owner=0
	sale.level=3
	sale.building_type="house"
	var retained:Dictionary=g.lots.lot_13_9
	retained.owner=0
	retained.level=1
	retained.building_type="house"
	g.gm_teleport(0,a)
	check(g.players[0].deposit==0 and g.players[0].cash==520, "Insufficient deposit precedes 1200 half-price liquidation and 880 rent")
	check(sale.owner==-1 and sale.level==0 and sale.building_type=="vacant", "Liquidation resets one whole lot")
	check(retained.owner==0 and retained.level==1, "Liquidation stops once debt is covered")
	for frontage in sale.frontage_nodes: check(g.lots_at_node(int(frontage)).has(sale.id) and g.lots[sale.id].owner==-1, "Every sold entrance shares released title")
	check(g.players[0].cash+g.players[0].deposit+g.players[1].cash==11400, "Debt transfer conserved after bank-funded liquidation")
	g.setup(["甲","乙","丙","丁"],42)
	g.lots.lot_1_1.owner=1
	g.lots.lot_1_1.level=1
	g.players[0].cash=120
	g.players[0].deposit=100
	g.gm_teleport(0,a)
	check(g.players[0].cash==0 and g.players[0].deposit==0 and not g.players[0].bankrupt, "Exact payment leaves solvent zero balance")
	g.setup(["甲","乙","丙","丁"],42)
	g.lots.lot_1_1.owner=1
	g.lots.lot_1_1.level=1
	g.players[0].cash=10
	g.players[0].deposit=20
	g.gm_teleport(0,a)
	check(g.players[0].bankrupt and g.players[1].cash==10030, "Insolvency pays only available liquid assets")
	g.setup(["甲","乙","丙","丁"],42)
	g.finish_game()
	check(g.winners==[0,1,2,3], "Equal net assets tie")
	g.setup(["甲","乙","丙","丁"],42)
	for i in [0,1,2]: g.players[i].bankrupt=true
	g.current=3
	g.phase="end"
	g.end_turn()
	check(g.phase=="finished" and g.winners==[3], "Last survivor wins immediately")
	g.setup(["甲","乙","丙","丁"],42,1)
	g.players[0].bankrupt=true
	g.current=3
	g.phase="end"
	g.end_turn()
	check(g.phase=="finished" and g.round_number==2, "Round cap honored when wrapping past bankrupt first seat")
	g.setup(["甲","乙","丙","丁"],42)
	g.players[1].bankrupt=true
	g.phase="end"
	g.end_turn()
	check(g.current==2 and g.round_number==1, "Skip bankrupt seat without extra round")
	g.setup(["甲","乙","丙","丁"],42)
	var original_cards:Array=g.players[0].cards.duplicate()
	check(not g.use_card("scheme",0) and not g.use_card("scheme",99), "Reject self and nonexistent scheme targets")
	check(not g.use_card("mine",-1) and not g.use_card("dice",-1,7), "Reject invalid road and die value")
	g.players[1].pos=40
	check(not g.use_card("scheme",1) and not g.use_card("mine",40), "Reject targets outside temporary range")
	check(g.players[0].cards==original_cards and not g.card_used and g.controlled_dice==0 and g.road_objects.is_empty(), "Rejected card commands leave hand and effects intact")
	check(not g.buy_property() and not g.upgrade_property() and not g.bank_transfer(100) and not g.close_bank() and not g.end_turn(), "Reject commands outside valid phases")
	g.roll_dice(1)
	check(not g.use_card("dice",-1,2) and not g.roll_dice() and not g.move_to(40), "Move phase rejects cards, reroll and illegal edge")
	check(g.players[0].cards==original_cards, "Wrong-phase card command does not consume")
	for seed_value in range(1,51):
		g.setup(["甲","乙","丙","丁"],seed_value)
		var actions:=0
		while g.phase!="finished" and actions<5000:
			actions+=1
			match g.phase:
				"roll":
					for card in g.players[g.current].cards.duplicate():
						var targets:Array=g.card_targets(card)
						if not targets.is_empty(): g.use_card(card,targets[0],targets[0])
					g.roll_dice()
				"move":
					var choices:Array=g.available_moves()
					check(not choices.is_empty(),"No stuck movement")
					if choices.is_empty(): break
					g.move_to(choices[g.rng.randi_range(0,choices.size()-1)])
				"bank": g.bank_transfer(int(g.players[g.current].cash/2)); g.close_bank()
				"land":
					if not g.buy_property(): g.upgrade_property()
					g.end_turn()
				"end","detained": g.end_turn()
			for p in g.players: check(p.cash>=0 and p.deposit>=0,"Nonnegative balances")
		check(g.phase=="finished" and not g.winners.is_empty(),"Full match completes seed %d"%seed_value)
	print("R2_CORE failures=",failures," complete_matches=50")
	quit(1 if failures else 0)
