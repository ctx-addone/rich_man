extends SceneTree

const Game = preload("res://scripts/game_state.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)

func fresh():
	var game = Game.new()
	game.setup(["甲", "乙", "丙", "丁"], 37)
	return game

func _initialize() -> void:
	var game = fresh()
	check(not game.trade_stock("test_grain", 1, true), "cash cannot directly purchase shares")
	game.gm_teleport(0, 7)
	check(game.bank_transfer(1000), "deposit cash for trading")
	var before: int = game.net_worth(0)
	check(game.trade_stock("test_grain", 20, true), "bank-stage buy succeeds")
	check(game.players[0].deposit == 200 and game.stock_value(0) == 800 and game.net_worth(0) == before, "net worth includes shares without double counting")
	var snapshot: Dictionary = game.players[0].duplicate(true)
	game.phase = "move"
	check(not game.trade_stock("test_grain", 1, false) and game.players[0] == snapshot, "movement forbids atomic stock trade")
	game.phase = "reaction"
	check(not game.trade_stock("test_grain", 1, false), "reaction cannot trade")
	game.phase = "end"
	for ignored in range(3):
		game.end_turn()
		check(game.stock_market.market_round == 1, "market remains stable within same global round")
		game.phase = "end"
	game.end_turn()
	check(game.stock_market.market_round == 2 and game.stock_market.quotes.test_grain.history.size() == 2, "market refreshes exactly once per global round")
	game = fresh()
	game.players[0].deposit = 1000
	game.trade_stock("test_grain", 20, true)
	game.players[0].cash = 0
	var property: Dictionary = game.lots.lot_1_1
	property.owner = 0
	property.level = 1
	property.building_type = "mall"
	game._pay(0, 450, 1)
	check(not game.players[0].bankrupt and property.owner == 0, "stock liquidation prevents unnecessary property sale")
	check(game.players[0].stocks.test_grain == 13 and game.players[0].deposit == 30 and game.players[0].cash == 0, "liquidation sells minimum 7 shares and leaves overage in bank")
	check(game.players[1].cash == 10450 and game.stock_market.ledger[-1].side == "liquidate", "debt settles once and logs forced sale")
	game = fresh()
	game.players[0].deposit = 80
	game.trade_stock("test_grain", 2, true)
	game.players[0].cash = 0
	game._pay(0, 100, 1)
	check(game.players[0].bankrupt and game.players[0].stocks.is_empty() and game.players[1].cash == 10080, "insolvency transfers only realizable assets")
	game = fresh()
	game.players[0].deposit = 80
	game.trade_stock("test_grain", 2, true)
	game.stock_market.quotes.test_grain.price = 45
	game.finish_game()
	check(game.winners == [0], "final ranking includes stock gains")
	check(not game.trade_stock("test_grain", 1, false), "finished game cannot alter ranking through trades")
	game.setup(["甲", "乙", "丙", "丁"], 37)
	check(game.players[0].stocks.is_empty() and game.stock_market.ledger.is_empty() and game.stock_market.market_round == 1, "restart resets portfolio and market history")
	print("R4_STOCK_INTEGRATION failures=", failures)
	quit(1 if failures else 0)
