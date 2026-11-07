class_name RichSpecialServices
extends RefCounted

# R11 UI confirms numbers 01..30. The 1,500 screenshot uses Tangtang, so it
# does not establish a universal base price. Price/quota/pool remain provisional.
const TEST_PROFILE = {"number_min":1,"number_max":30,"ticket_price":5000,"visit_limit":3,"draw_interval":15,"initial_pot":10000}
const Magic = preload("res://scripts/model/magic_house.gd")
const CONDITIONS = Magic.CONDITIONS
const CONDITION_NAMES = Magic.CONDITION_NAMES
const MAGIC = Magic.CATALOG

static func initial_lottery() -> Dictionary:
	return {"pot":TEST_PROFILE.initial_pot,"tickets":[],"draw_round":1+TEST_PROFILE.draw_interval,"last_draw":{},"last_winners":[],"draw_count":0}

static func eligible(g, who:int) -> bool:
	return who>=0 and who<g.players.size() and not g.players[who].bankrupt and g.players[who].status.is_empty() and g.Gods.id(g,who)!="fierce"

static func enter(g, kind:String) -> bool:
	if not g.specials_enabled or not eligible(g,g.current) or not g.pending_attack.is_empty(): return false
	var road:int=g.players[g.current].pos
	if g.service_visited.has(road): return false
	if kind not in ["lottery","magic"] or road < 0 or road >= g.nodes.size() or g.nodes[road].kind != kind: return false
	g.service_visited.append(road)
	g.pending_service={"kind":kind,"road":road,"purchases":0}
	g.phase=kind
	g._log("进入"+("乐透站" if kind=="lottery" else "魔法屋")+"；规则子集与测试参数见说明。")
	return true

static func numbers() -> Array[int]:
	var result:Array[int]=[]
	for number in range(TEST_PROFILE.number_min,TEST_PROFILE.number_max+1): result.append(number)
	return result

static func buy(g, number:int) -> bool:
	if g.phase!="lottery" or not g.specials_enabled or g.pending_service.get("kind","")!="lottery" or not eligible(g,g.current): return false
	if not numbers().has(number) or g.pending_service.purchases>=TEST_PROFILE.visit_limit or g.players[g.current].cash<TEST_PROFILE.ticket_price: return false
	g.players[g.current].cash-=TEST_PROFILE.ticket_price
	g.lottery_state.pot+=TEST_PROFILE.ticket_price
	g.lottery_state.tickets.append({"player":g.current,"number":number})
	g.pending_service.purchases+=1
	g._log("%s 购入乐透号码%d；第%d轮开奖。"%[g.players[g.current].name,number,g.lottery_state.draw_round])
	return true

static func close(g, kind:String) -> bool:
	if g.phase!=kind or g.pending_service.get("kind","")!=kind: return false
	g.pending_service.clear()
	if kind=="lottery":
		g.phase="move"
		g._check_movement()
	else: g.phase="land"
	return true

static func advance_round(g) -> void:
	if not g.specials_enabled or g.round_number<g.lottery_state.draw_round or g.round_number>g.round_limit+1: return
	var number:int=g.rng.randi_range(TEST_PROFILE.number_min,TEST_PROFILE.number_max)
	var winning_tickets:Array=[]
	for ticket in g.lottery_state.tickets:
		if ticket.number==number and not g.players[ticket.player].bankrupt: winning_tickets.append(ticket)
	var pot:int=g.lottery_state.pot
	var payouts:Dictionary={}
	if not winning_tickets.is_empty():
		var share:int=pot/winning_tickets.size()
		var remainder:int=pot%winning_tickets.size()
		for i in range(winning_tickets.size()):
			var who:int=winning_tickets[i].player
			var amount:int=share+(1 if i<remainder else 0)
			g.players[who].cash+=amount
			payouts[who]=int(payouts.get(who,0))+amount
		g.lottery_state.pot=0
	g.lottery_state.last_winners=payouts.keys()
	g.lottery_state.last_draw={"round":g.round_number,"number":number,"pot":pot,"payouts":payouts}
	g.lottery_state.tickets.clear()
	g.lottery_state.draw_count+=1
	g.lottery_state.draw_round=g.round_number+TEST_PROFILE.draw_interval
	g._log("乐透开奖：号码%d，%s。"%[number,"无人中奖，奖金滚存" if payouts.is_empty() else "奖金已自动发放"])

static func options() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for item in MAGIC: result.append(item.duplicate())
	return result

static func targets(g, condition:String) -> Array[int]:
	return Magic.targets(g,condition)

static func choose(g, effect:String) -> bool:
	return Magic.choose(g,effect)
