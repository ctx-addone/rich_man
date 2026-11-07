extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Services=preload("res://scripts/model/special_services.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
func check(ok:bool,label:String)->void:
	if not ok: failures+=1; printerr(label)
func fresh(rounds:int=40):
	var g=Game.new()
	g.setup(["A","B","C","D"],91,rounds,{"specials_enabled":true})
	return g
func enter_lottery(g,steps:int=3)->void:
	g.players[0].pos=16; g.players[0].previous=15
	g.roll_dice(steps)
	g.move_to(17)
func force_condition(g,index:int)->void:
	for seed_value in range(1,1000):
		var probe=RandomNumberGenerator.new()
		probe.seed=seed_value
		if probe.randi_range(0,Services.CONDITIONS.size()-1)==index:
			g.rng.seed=seed_value
			return
func _init()->void:
	var old=Game.new()
	old.setup(["A","B"],91)
	var g=fresh()
	check(old.nodes.size()==117 and g.nodes.size()==117,"geometry stays 117 roads")
	for i in range(117): check(old.nodes[i].pos==g.nodes[i].pos and old.nodes[i].neighbors==g.nodes[i].neighbors,"special layout preserves roads")
	check(old.nodes[17].kind=="event" and g.nodes[17].kind=="lottery" and g.nodes[51].kind=="magic","old fixtures opt out")
	enter_lottery(g)
	check(g.phase=="lottery" and g.steps_left==2,"passing lottery suspends remaining movement")
	var before:int=g.players[0].cash
	var rng_before:int=g.rng.state
	check(not g.buy_ticket(0) and g.players[0].cash==before and g.rng.state==rng_before,"invalid number is atomic")
	check(g.buy_ticket(3) and g.lottery_state.tickets==[{"player":0,"number":3}],"number chosen and ticket recorded")
	check(g.players[0].cash==5000 and g.lottery_state.pot==15000,"ticket price enters test pool")
	g.players[0].cash=4999
	check(not g.buy_ticket(4) and g.pending_service.purchases==1,"cash-only purchase cannot overdraft")
	check(g.close_lottery() and g.phase=="move" and g.steps_left==2,"leave resumes same movement")
	check(not g.close_lottery() and not g.buy_ticket(1),"closed service cannot issue another ticket")
	g.players[0].pos=16; g.players[0].previous=15; g.steps_left=1
	g.move_to(17)
	check(g.phase=="land" and g.pending_service.is_empty(),"same journey revisit does not reopen lottery")
	g=fresh(); enter_lottery(g,1)
	check(g.phase=="lottery" and g.steps_left==0,"final step still offers lottery")
	g.close_lottery()
	check(g.phase=="land" and g.service_visited==[17],"landing cannot offer second lottery")
	g=fresh(); g.players[0].cash=30000; enter_lottery(g)
	check(g.buy_ticket(1) and g.buy_ticket(1) and g.buy_ticket(2) and not g.buy_ticket(3),"test policy permits repeated numbers but caps visit at three tickets")
	check(g.lottery_state.tickets.size()==3 and g.players[0].cash==15000,"failed fourth purchase has no charge")
	g=fresh(); g.players[0].cash=5000; enter_lottery(g)
	check(g.buy_ticket(1) and g.players[0].cash==0 and not g.players[0].bankrupt,"exact ticket price leaves zero cash without bankruptcy")
	g=fresh(); g.players[0].pos=16; g.players[0].previous=15
	g.controlled_path=[17,18,19]; g.roll_dice(3); g.move_to(17)
	check(g.controlled_path==[18,19] and g.phase=="lottery","lottery keeps controlled route remainder")
	g.close_lottery(); g.move_to(18); g.move_to(19)
	check(g.controlled_path.is_empty() and g.phase=="land","controlled route completes after service")
	for status_kind in ["sleepwalk","hibernate"]:
		g=fresh(); g.players[0].pos=17; g.phase="move"; g.steps_left=1
		g.players[0].status={"kind":status_kind,"remaining":1}
		check(not Services.enter(g,"lottery"),"incapacitated visitor cannot shop lottery")
	g=fresh(); g.players[0].pos=17; g.players[0].god={"id":"fierce","remaining":2}
	check(not Services.enter(g,"lottery"),"fierce visitor skips lottery")
	g.players[0].pos=51
	check(not Services.enter(g,"magic"),"fierce visitor skips magic")
	g=fresh(); g.players[0].cards=["immune"]; g.road_objects[17]={"kind":"mine","owner":1}
	enter_lottery(g)
	check(g.phase=="reaction" and g.pending_service.is_empty(),"arrival defense precedes lottery")
	g.resolve_reaction("immune")
	check(g.phase=="lottery" and g.steps_left==2,"successful defense resumes pass service")
	g.close_lottery(); check(g.phase=="move","post-defense lottery still resumes movement")
	g=fresh(); g.players[0].cards=["immune"]; g.road_objects[17]={"kind":"mine","owner":1}
	enter_lottery(g); g.resolve_reaction()
	check(g.phase=="end" and g.pending_service.is_empty(),"hospitalized arrival never opens service")
	# Winning number is predicted from a clone, without changing the game's RNG.
	g=fresh(); var probe=RandomNumberGenerator.new(); probe.state=g.rng.state
	var winning:int=probe.randi_range(Services.TEST_PROFILE.number_min,Services.TEST_PROFILE.number_max)
	g.lottery_state.pot=10001
	g.lottery_state.tickets=[{"player":0,"number":winning},{"player":1,"number":winning},{"player":2,"number":winning}]
	g.players[2].bankrupt=true; g.round_number=16
	Services.advance_round(g)
	check(g.players[0].cash==15001 and g.players[1].cash==15000 and g.players[2].cash==10000,"pool divided by eligible tickets with stable remainder")
	check(g.lottery_state.pot==0 and g.lottery_state.tickets.is_empty() and g.lottery_state.draw_count==1,"draw settles tickets exactly once")
	rng_before=g.rng.state; Services.advance_round(g)
	check(g.lottery_state.draw_count==1 and g.rng.state==rng_before,"same boundary cannot draw or pay twice")
	g=fresh(); g.round_number=16; Services.advance_round(g)
	check(g.lottery_state.pot==10000 and g.lottery_state.draw_round==31,"no winner carries pool to next period")
	g=fresh(15); probe.state=g.rng.state; winning=probe.randi_range(Services.TEST_PROFILE.number_min,Services.TEST_PROFILE.number_max)
	g.lottery_state.tickets=[{"player":1,"number":winning}]
	g.round_number=15; g.current=3; g.phase="end"; g.end_turn()
	check(g.phase=="finished" and g.lottery_state.draw_count==1 and g.winners==[1],"final completed period pays before match ranking")
	g=fresh(14); g.round_number=14; g.current=3; g.phase="end"; g.end_turn()
	check(g.phase=="finished" and g.lottery_state.draw_count==0,"early match ending does not invent a draw")
	# Magic only stops; passing the road never selects an effect.
	g=fresh(); g.players[0].pos=50; g.players[0].previous=49; g.roll_dice(2); g.move_to(51)
	check(g.phase=="move" and g.magic_last_result.is_empty(),"passing magic house does not activate it")
	g=fresh(); g.gm_teleport(0,51); rng_before=g.rng.state
	check(g.phase=="magic" and g.magic_options().size()==9 and g.rng.state==rng_before,"magic menu draws no condition")
	check(not g.choose_magic("invented") and g.rng.state==rng_before and g.phase=="magic","invalid effect consumes nothing")
	force_condition(g,0); g.choose_magic("demolish")
	check(g.magic_last_result.targets.is_empty() and g.magic_last_result.condition=="car" and g.phase=="land","empty condition consumes visit without reroll")
	rng_before=g.rng.state
	check(not g.choose_magic("demolish") and g.rng.state==rng_before,"magic effect cannot repeat")
	g=fresh(); g.players[0].vehicle="car"; g.players[1].vehicle="car"
	g.players[1].status={"kind":"hospital","remaining":1}
	g.lots.small_1_6.owner=0; g.lots.small_1_6.level=2; g.lots.small_1_6.building_type="house"
	g.lots.small_4_6.owner=1; g.lots.small_4_6.level=2; g.lots.small_4_6.building_type="house"
	g.gm_teleport(0,51); force_condition(g,0); g.choose_magic("demolish")
	check(g.lots.small_1_6.level==0 and g.lots.small_1_6.owner==0 and g.lots.small_4_6.level==2,"demolition removes one whole building, excludes disappeared players and preserves ownership")
	g=fresh(); g.players[0].vehicle="car"; g.gm_teleport(0,51); force_condition(g,0)
	g.choose_magic("deposit_cash")
	check(g.players[0].cash==0 and g.players[0].deposit==10000,"deposit effect conserves wealth")
	g=fresh()
	check(Services.targets(g,"richest")==[0,1,2,3] and Services.targets(g,"most_properties")==[0,1,2,3],"test policy includes every tied leader")
	for absent in ["hospital","prison","vacation"]:
		g.players[1].status={"kind":absent,"remaining":1}
		check(not Services.targets(g,"richest").has(1),"absent role excluded: "+absent)
	g=fresh(); g.players[0].vehicle="car"; g.players[0].cards=["free","free","free","free","free","free","free"]
	g.gm_teleport(0,51); force_condition(g,0); g.choose_magic("gain_cards")
	check(g.players[0].cards.size()==8,"magic card reward respects hand limit")
	g=fresh(); g.players[0].cards=["free"]
	g.lots.small_13_14.owner=1; g.lots.small_13_14.level=3; g.lots.small_13_14.building_type="house"
	g.gm_teleport(0,51)
	check(g.phase=="reaction" and g.landing_pending,"frontage payment precedes magic")
	g.resolve_reaction("free")
	check(g.phase=="magic" and not g.landing_pending,"payment defense resumes pending magic landing")
	g.close_magic(); check(g.end_turn() and g.current==1,"magic exit allows normal next player")
	for road in [17,51]:
		for interrupted in ["hospital","prison","vacation","teleport"]:
			g=fresh(); g.gm_teleport(0,road)
			check(not g.pending_service.is_empty(),"GM interruption starts in service")
			if interrupted=="vacation": g.send_on_vacation(0,"lot_1_1")
			elif interrupted=="teleport": g.gm_teleport(0,0)
			else: g.send_to_facility(0,interrupted,2)
			check(g.pending_service.is_empty() and g.phase in ["end","land"],"GM interruption clears pending service: "+interrupted)
			check(not g.buy_ticket(1) and not g.choose_magic("gain_cards"),"interrupted service commands cannot execute")
		g=fresh(); g.gm_teleport(0,road)
		check(g.gm_god(0,"fierce") and g.pending_service.is_empty() and g.phase=="land","GM fierce possession closes now-ineligible service")
	g=fresh(); g.gm_teleport(0,51); force_condition(g,1); g.choose_magic("deposit_cash")
	for p in g.players: check(p.cash==0 and p.deposit==10000,"richest tied effect actually applies to every leader")
	g=fresh(); g.gm_teleport(0,51); force_condition(g,2); g.choose_magic("deposit_cash")
	for p in g.players: check(p.cash==0 and p.deposit==10000,"property tied effect actually applies to every leader")
	var matches:int=0
	for seed_value in [7,23,41]:
		g=fresh(35); g.rng.seed=seed_value
		var actions:int=0
		while g.phase!="finished" and actions<20000:
			actions+=1
			var ok:bool
			if g.phase=="lottery": ok=g.close_lottery()
			elif g.phase=="magic": ok=g.choose_magic("gain_cards")
			else: ok=AI.step(g)
			if not ok: check(false,"full service match stalled at "+g.phase); break
		check(g.phase=="finished" and not g.winners.is_empty(),"35-round service-enabled match closes")
		if g.phase=="finished": matches+=1
	print("SERVICES_TEST failures=",failures," completed_matches=",matches)
	quit(0 if failures==0 else 1)
