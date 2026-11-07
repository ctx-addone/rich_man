extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func fresh():
	var g = Game.new()
	g.setup(["A","B","C","D"],37)
	for p in g.players: p.cards = []
	return g
func _initialize() -> void:
	# A defended arrival must restore pass services once, then retain the route.
	var g = fresh()
	g.players[0].pos = 6
	g.players[0].previous = 5
	g.players[0].cards = ["immune"]
	g.road_objects[7] = {"kind":"mine","owner":1}
	check(g.roll_dice(3) and g.move_to(7) and g.phase == "reaction", "Bank mine interrupts arrival")
	check(g.resolve_reaction("immune") and g.phase == "bank" and g.steps_left == 2, "Defended bank mine resumes service with remaining steps")
	check(g.bank_transfer(1000) and g.trade_stock("test_grain",10,true), "Stock trading works after defended bank arrival")
	check(g.close_bank() and g.phase == "move" and g.move_to(8) and g.phase == "move", "Adjacent bank frontage does not replay service")
	check(g.move_to(9) and g.phase == "land", "Bank mine resumed path reaches final landing")
	# An undefended bank mine must suppress service and end the actor's action.
	g = fresh()
	g.players[0].pos = 6
	g.players[0].previous = 5
	g.road_objects[7] = {"kind":"mine","owner":1}
	check(g.roll_dice(3) and g.move_to(7) and g.phase == "end" and not g.bank_transfer(1000), "Incapacitated bank arrival never opens service")
	# Chain transfer then same-fate should affect the original attacker exactly once.
	g = fresh()
	g.players[0].cards = ["scheme","immune"]
	g.players[1].cards = ["transfer"]
	g.players[2].cards = ["same_fate"]
	check(g.use_card("scheme",1) and g.resolve_reaction("transfer",2) and g.resolve_reaction("same_fate"), "Transferred scheme accepts same fate")
	check(g.players[1].status.is_empty() and g.players[0].status.kind == "prison" and g.players[2].status.kind == "prison", "Same fate uses original attacker, not transferor")
	check(g.players[0].cards == ["immune"] and g.phase == "end" and g.pending_attack.is_empty(), "Same fate does not recursively consume attacker defence")
	# R11 evidence permits imprisonment to replace sleeping status; no passive defence while asleep.
	g = fresh()
	g.players[0].cards = ["hibernate", "scheme"]
	g.players[1].cards = ["immune"]
	check(g.use_card("hibernate", 1) and g.players[1].status.kind == "hibernate", "Winter applies without immune defence")
	check(g.use_card("scheme", 1) and g.players[1].status.kind == "prison" and g.phase == "roll", "Imprisonment can replace road sleeping status")
	check(g.players[1].cards == ["immune"], "Sleeping target does not spend unavailable passive defence")
	# A final-step immune mine still charges rent, liquidates shares, and ends cleanly.
	g = fresh()
	g.players[0].cards = ["immune"]
	g.players[0].deposit = 1000
	g.trade_stock("test_grain",25,true)
	g.players[0].cash = 0
	var lot: Dictionary = g.lots.lot_1_1
	lot.owner = 1
	lot.building_type = "mall"
	lot.level = 2
	g.road_objects[1] = {"kind":"mine","owner":1}
	check(g.roll_dice(1) and g.move_to(1) and g.resolve_reaction("immune"), "Mine immunity finishes arrival")
	check(g.pending_attack.is_empty() and g.phase == "land" and not g.players[0].bankrupt, "Final-step rent and liquidation leave no stale reaction")
	check(g.stock_market.ledger[-1].side == "liquidate", "Mine-resumed rent can automatically sell shares")
	g.finish_game()
	var saved: Array = g.players.duplicate(true)
	check(not g.resolve_reaction() and not g.end_turn() and not g.trade_stock("test_grain",1,false), "Terminal state rejects continued actions")
	check(saved == g.players, "Rejected terminal actions preserve account state")
	# Terminal valuation must not refresh quotes for an unplayable next round.
	g = fresh()
	g.round_limit = 1
	g.players[0].cash = 9000
	g.players[0].deposit = 1000
	g.trade_stock("test_grain",25,true)
	var closing_value: int = g.net_worth(0)
	var closing_quotes: Dictionary = g.stock_market.quotes.duplicate(true)
	var closing_ledger: Array = g.stock_market.ledger.duplicate(true)
	for ignored in range(4): g.phase = "end"; g.end_turn()
	check(g.phase == "finished", "Round limit terminates match")
	check(g.round_number == 2 and g.stock_market.market_round == 1, "Termination counter can reach 2 but one-round market remains at 1")
	check(g.stock_market.quotes == closing_quotes and g.stock_market.ledger == closing_ledger, "Terminal boundary preserves last playable prices, history and ledger")
	check(g.net_worth(0) == closing_value and g.winners == [0,1,2,3], "No untradeable closing-price change alters winner")
	print("ROUND4_REVIEW failures=",failures)
	quit(1 if failures else 0)
