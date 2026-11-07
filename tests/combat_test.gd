extends SceneTree
const Game=preload("res://scripts/game_state.gd")
var failures:=0
func check(ok:bool,msg:String)->void:
	if not ok: failures+=1; push_error(msg)
func fresh():
	var g=Game.new()
	g.setup(["A","B","C","D"],9)
	for p in g.players: p.cards=[]
	return g
func _initialize()->void:
	var g=fresh()
	g.players[0].cards=["scheme"]
	g.players[1].cards=["immune","same_fate"]
	check(g.use_card("scheme",1),"attack accepted")
	check(g.current==0 and g.phase=="reaction" and g.reaction_player()==1,"actual victim reacts without actor switch")
	check(g.players[0].cards.is_empty() and g.players[1].status.is_empty(),"attack consumed before reaction; no early hit")
	check(not g.resolve_reaction("transfer",2) and not g.resolve_reaction("immune",2),"illegal response rejected")
	check(not g.end_turn() and not g.roll_dice() and not g.gm_teleport(1,2) and not g.gm_give_card(1,"immune") and not g.send_to_facility(1,"prison",2),"reaction blocks unrelated mutations")
	check(g.resolve_reaction("immune") and g.phase=="roll" and g.players[1].status.is_empty(),"immune restores actor phase")
	check(g.players[1].cards==["same_fate"] and not g.resolve_reaction(),"one reaction exactly once")
	g=fresh()
	g.players[0].cards=["scheme"]
	g.players[1].cards=["transfer"]
	g.players[2].cards=["immune"]
	check(g.use_card("scheme",1) and g.resolve_reaction("transfer",2),"transfer target chosen")
	check(g.reaction_player()==2 and g.players[1].status.is_empty(),"transferred victim owns next reaction")
	check(g.resolve_reaction() and g.players[2].status.kind=="prison" and g.players[2].cards==["immune"],"declining never spends defensive card")
	g=fresh()
	g.players[0].cards=["hibernate"]
	g.players[1].cards=["same_fate","immune","transfer"]
	check(g.use_card("hibernate",1) and g.reaction_options()==["same_fate"],"sleep only same fate")
	check(g.resolve_reaction("same_fate") and g.players[0].status.kind=="hibernate" and g.players[1].status.kind=="hibernate" and g.phase=="end", "same fate applies both and actor can end turn")
	check(not g.use_card("dice",-1,3),"disabled actor cannot use cards")
	g=fresh()
	g.players[0].cards=["scheme"]
	check(g.use_card("scheme",1) and g.pending_attack.is_empty() and g.phase=="roll" and g.players[1].status.remaining==2,"no defensive hand resolves automatically")
	g=fresh()
	g.players[0].cards=["immune"]
	g.road_objects[1]={"kind":"mine","owner":1}
	var lot=g.lots_at_node(1)[0]
	g.lots[lot].level=3
	check(g.roll_dice(2) and g.move_to(1) and g.phase=="reaction","mine pauses movement")
	check(g.lots[lot].level==2 and g.resolve_reaction("immune"),"building damage independent of immunity")
	check(g.phase=="move" and g.steps_left==1 and g.move_to(2),"immune mine resumes remaining movement")
	g=fresh()
	g.players[0].cards=["immune"]
	g.road_objects[1]={"kind":"mine","owner":1}
	check(g.roll_dice(1) and g.move_to(1) and g.resolve_reaction("immune") and g.phase=="land","mine on final step resolves landing")
	g=fresh()
	g.players[0].cards=["missile"]
	g.players[1].pos=2
	g.players[1].cards=["immune"]
	check(g.use_card("missile",2) and g.reaction_player()==1 and g.resolve_reaction(),"missile targeted road reaction")
	check(g.players[1].status.remaining==1 and g.phase=="roll","missile one action hospital")
	g=fresh()
	g.players[0].cards=["scheme"]
	g.players[1].cards=["transfer"]
	g.players[2].cards=["transfer"]
	g.use_card("scheme",1)
	g.resolve_reaction("transfer",2)
	check(not g.reaction_targets("transfer").has(1) and not g.resolve_reaction("transfer",1) and g.players[2].cards==["transfer"],"transfer loops rejected without spending card")
	check(g.resolve_reaction("transfer",0) and g.phase=="end" and g.players[0].status.kind=="prison","transfer back to attacker ends actor action")
	g=fresh()
	g.players[0].cards=["missile","immune"]
	g.players[1].cards=["immune"]
	check(g.use_card("missile",0) and g.reaction_player()==0 and g.resolve_reaction(),"explosion can hit actor")
	check(g.reaction_player()==1 and g.phase=="reaction" and g.resolve_reaction("immune"),"actor hospitalization preserves next victim window")
	check(g.phase=="end" and g.players[1].status.is_empty() and g.players[2].status.kind=="hospital","multi victim explosion completes and ends incapacitated actor")
	g=fresh()
	g.players[0].cards=["hibernate"]
	check(g.use_card("hibernate",1) and g.players[1].status.remaining==2,"hibernate auto resolves")
	g.phase="end"
	g.end_turn()
	check(g.current==1 and g.phase=="detained","hibernate starts skipped action")
	g.end_turn()
	check(g.players[1].status.remaining==1,"one personal action decrements once")
	for ignored in range(3): g.phase="end"; g.end_turn()
	check(g.current==1 and g.phase=="detained","second hibernation action")
	g.end_turn()
	for ignored in range(3): g.phase="end"; g.end_turn()
	check(g.current==1 and g.phase=="roll" and g.players[1].status.is_empty(),"hibernate releases after exactly two skipped actions")
	g=fresh()
	g.players[0].cards=["scheme"]
	g.players[1].cards=["immune"]
	g.use_card("scheme",1)
	g.finish_game()
	check(g.pending_attack.is_empty() and not g.resolve_reaction("immune"),"finish clears pending")
	print("combat_test: ",failures," failures")
	quit(1 if failures else 0)
