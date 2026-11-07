extends SceneTree
const Market = preload("res://scripts/model/stock_market.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func account() -> Dictionary:
	return {"id":0,"name":"甲","cash":999,"deposit":10000,"stocks":{},"bankrupt":false}
func _initialize() -> void:
	var m = Market.new()
	m.setup(123)
	var p := account()
	check(m.buy(p,"test_grain",10,1),"Buy uses deposit")
	check(p.cash == 999 and p.deposit == 9600 and m.value(p) == 400,"Deposit + valuation conserved, cash untouched")
	check(m.sell(p,"test_grain",3,1) and p.stocks.test_grain == 7 and p.deposit == 9720,"Partial sell")
	check(m.ledger[0].player_id == 0 and m.ledger[0].amount == 400,"Ledger has identity and gross amount")
	for quantity in [0,-1,1.5,1.0,true,"1",null,100001,9223372036854775807]:
		var before: Dictionary = p.duplicate(true)
		var entries: Array = m.ledger.duplicate(true)
		check(not m.buy(p,"test_grain",quantity,1) and not m.sell(p,"test_grain",quantity,1),"Reject invalid quantity %s" % str(quantity))
		check(p == before and entries == m.ledger,"Invalid orders do not mutate account or ledger")
	check(not m.buy(p,"missing",1,1) and not m.sell(p,"test_tools",1,1),"Reject unknown quote or absent holding")
	check(not m.buy(p,"test_grain",1000,1) and not m.sell(p,"test_grain",8,1),"Reject insufficient funds and shares")
	check(not m.buy(p,"test_grain",1,2),"Reject stale/future round")
	p.bankrupt = true
	check(not m.sell(p,"test_grain",1,1),"Bankrupt account cannot trade")
	p.bankrupt = false
	var before_total: int = p.deposit + m.value(p)
	check(m.liquidate(p,41,1) == 80 and p.stocks.test_grain == 5,"Liquidation sells minimal whole shares")
	check(p.deposit + m.value(p) == before_total and m.ledger[-1].side == "liquidate","Liquidation preserves assets and records reason")
	check(m.liquidate(p,10000,1) == 200 and p.stocks.is_empty(),"Liquidation exhausts stock if insufficient")
	check(m.liquidate(p,0,1) == 0 and m.liquidate(p,100,1) == 0,"Empty/zero liquidation no-op")
	p = account()
	p.deposit = 100000000
	check(m.buy(p,"test_grain",Market.MAX_HOLDING,1) and not m.buy(p,"test_grain",1,1),"Per-company holding cap")
	var twin = Market.new()
	twin.setup(123)
	for round_number in range(2,1002):
		check(m.advance(round_number) and twin.advance(round_number),"One market update per global round")
		check(m.quotes == twin.quotes,"Same seed yields identical quotes/history")
		var snapshot: Dictionary = m.quotes.duplicate(true)
		check(not m.advance(round_number) and not m.advance(round_number-1) and not m.advance(round_number+2),"Reject duplicate/backwards/skipped update")
		check(snapshot == m.quotes,"Rejected update preserves quotes")
		for quote in m.quotes.values():
			check(quote.price >= Market.MIN_PRICE and quote.price <= Market.MAX_PRICE,"Bound prices")
			check(quote.history.size() <= Market.HISTORY_LIMIT and quote.history[-1] == quote.price,"Bound history with current close")
	m.quotes.test_grain.price = Market.MIN_PRICE
	m.quotes.test_tools.price = Market.MAX_PRICE
	m.advance(1002)
	check(m.quotes.test_grain.price >= Market.MIN_PRICE and m.quotes.test_tools.price <= Market.MAX_PRICE,"Extreme quotes respect clamps")
	m.setup(123)
	p = account()
	for i in range(150):
		check(m.buy(p,"test_grain",1,1) and m.sell(p,"test_grain",1,1),"Repeated roundtrip trade")
	check(m.ledger.size() == Market.LEDGER_LIMIT and p.deposit == 10000,"Bound ledger, fee-free deposit conservation")
	m.setup(123)
	twin.setup(123)
	check(m.ledger.is_empty() and m.market_round == 1 and m.quotes == twin.quotes,"New-game reset clears market and ledger")
	var malformed := account()
	malformed.stocks = {"test_grain":-1}
	check(not m.buy(malformed,"test_grain",1,1),"Invalid holdings rejected")
	print("STOCKS_TEST failures=",failures)
	quit(1 if failures else 0)
