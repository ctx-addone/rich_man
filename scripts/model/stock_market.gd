extends RefCounted
## Provisional offline market. Only use of bank deposits is verified R11 behavior.
const CATALOG = [
	{"id":"test_grain", "name":"测试谷物公司", "price":40},
	{"id":"test_tools", "name":"测试工具公司", "price":65},
	{"id":"test_transit", "name":"测试运输公司", "price":90},
	{"id":"test_energy", "name":"测试能源公司", "price":120},
]
const MIN_PRICE := 1
const MAX_PRICE := 1000
const MAX_HOLDING := 100000
const HISTORY_LIMIT := 30
const LEDGER_LIMIT := 200
const MAX_DEPOSIT := 9000000000000000
var quotes: Dictionary = {}
var ledger: Array[Dictionary] = []
var market_round := 1
var rng := RandomNumberGenerator.new()

func setup(seed_value: int = 0) -> void:
	quotes.clear()
	ledger.clear()
	market_round = 1
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	for item in CATALOG:
		quotes[item.id] = {"name":item.name,"price":item.price,"previous":item.price,"history":[int(item.price)]}

## Caller invokes once at the global round boundary, never at each player turn.
func advance(round_number: int) -> bool:
	if round_number != market_round + 1 or quotes.is_empty(): return false
	for item in CATALOG:
		var quote: Dictionary = quotes[item.id]
		quote.previous = quote.price
		var change: int = rng.randi_range(-10,10)
		quote.price = clampi(int(quote.price) + change, MIN_PRICE, MAX_PRICE)
		quote.history.append(quote.price)
		if quote.history.size() > HISTORY_LIMIT: quote.history.pop_front()
	market_round = round_number
	return true

func _valid_account(player: Dictionary) -> bool:
	if player.get("bankrupt",false): return false
	if typeof(player.get("deposit")) != TYPE_INT: return false
	if player.deposit < 0 or player.deposit > MAX_DEPOSIT: return false
	if typeof(player.get("stocks",{})) != TYPE_DICTIONARY: return false
	for id in player.get("stocks",{}):
		var held: Variant = player.stocks[id]
		if not quotes.has(id) or typeof(held) != TYPE_INT or held < 0 or held > MAX_HOLDING: return false
	return true

func can_trade(player: Dictionary, stock_id: String, quantity: Variant, buying: bool) -> bool:
	if not _valid_account(player) or not quotes.has(stock_id): return false
	if typeof(quantity) != TYPE_INT: return false
	if quantity <= 0 or quantity > MAX_HOLDING: return false
	var held: int = player.get("stocks",{}).get(stock_id,0)
	var amount: int = quantity * int(quotes[stock_id].price)
	if buying: return held <= MAX_HOLDING - quantity and player.deposit >= amount
	return held >= quantity and player.deposit <= MAX_DEPOSIT - amount

func buy(player: Dictionary, stock_id: String, quantity: Variant, round_number: int) -> bool:
	return _trade(player,stock_id,quantity,round_number,true,"buy")

func sell(player: Dictionary, stock_id: String, quantity: Variant, round_number: int) -> bool:
	return _trade(player,stock_id,quantity,round_number,false,"sell")

func _trade(player: Dictionary, stock_id: String, quantity: Variant, round_number: int, buying: bool, side: String) -> bool:
	if round_number != market_round or not can_trade(player,stock_id,quantity,buying): return false
	var price: int = quotes[stock_id].price
	var amount: int = quantity * price
	if not player.has("stocks"): player.stocks = {}
	var held: int = player.stocks.get(stock_id,0)
	player.stocks[stock_id] = held + quantity if buying else held - quantity
	if player.stocks[stock_id] == 0: player.stocks.erase(stock_id)
	player.deposit += -amount if buying else amount
	ledger.append({"player":str(player.get("name","")),"player_id":player.get("id",-1),"round":round_number,"stock_id":stock_id,"side":side,"quantity":quantity,"price":price,"amount":amount})
	if ledger.size() > LEDGER_LIMIT: ledger.pop_front()
	return true

func value(player: Dictionary) -> int:
	var total := 0
	for id in player.get("stocks",{}):
		if quotes.has(id): total += int(player.stocks[id]) * int(quotes[id].price)
	return total

## Sells whole shares in catalog order until needed new deposit is raised.
## Returns actual deposit proceeds (can exceed needed by less than one share).
func liquidate(player: Dictionary, needed: int, round_number: int) -> int:
	if needed <= 0 or round_number != market_round or not _valid_account(player): return 0
	var raised := 0
	for item in CATALOG:
		if raised >= needed: break
		var held: int = player.get("stocks",{}).get(item.id,0)
		var price: int = quotes[item.id].price
		# Bound before ceil division to avoid overflow on a very large needed value.
		var shortfall: int = mini(needed - raised, held * price)
		var quantity: int = (shortfall + price - 1) / price
		if quantity > 0 and _trade(player,item.id,quantity,round_number,false,"liquidate"):
			raised += quantity * price
	return raised
