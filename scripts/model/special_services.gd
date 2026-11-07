class_name RichSpecialServices
extends RefCounted

# R11 evidence: lottery pass service; 5,000/base ticket; 15-day draws (C).
# Remaining numeric values and settlement policy are integration parameters.
const TEST_PROFILE = {"number_min":1,"number_max":10,"ticket_price":5000,"visit_limit":3,"draw_interval":15,"initial_pot":10000,"demolish_levels":1}
const CONDITIONS = ["car","richest","most_properties"]
const CONDITION_NAMES = {"car":"驾驶汽车","richest":"总资产最多","most_properties":"地产最多"}
const MAGIC = [
	{"id":"demolish","name":"摧毁建筑","description":"随机条件筛选在场角色，其地产降低1级（层数为测试配置）。"},
	{"id":"gain_cards","name":"获得3张卡片","description":"随机条件筛选在场角色，获得3张随机卡；遵守手牌上限。"},
	{"id":"deposit_cash","name":"存入所有现金","description":"随机条件筛选在场角色，将全部现金存入银行。"}
]

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
	var result:Array[int]=[]
	var best:int=-1
	for who in range(g.players.size()):
		var p:Dictionary=g.players[who]
		# Disappeared lords do not participate. Sleepwalking does not disappear.
		if p.bankrupt or p.status.get("kind","") in ["hospital","prison","vacation"]: continue
		if condition=="car":
			if p.vehicle=="car": result.append(who)
			continue
		var value:int=g.net_worth(who) if condition=="richest" else 0
		if condition=="most_properties":
			for lot in g.lots.values():
				if lot.owner==who: value+=1
		if value>best: result.clear(); best=value
		if value==best: result.append(who)
	return result

static func choose(g, effect:String) -> bool:
	if not g.specials_enabled or g.phase!="magic" or g.pending_service.get("kind","")!="magic" or not eligible(g,g.current): return false
	var valid:bool=false
	var effect_name:String=""
	for option in MAGIC:
		if option.id==effect: valid=true; effect_name=option.name
	if not valid: return false
	# Selection commits before the random condition is drawn; never redraw empty sets.
	g.pending_service.clear()
	g.phase="land"
	var condition:String=CONDITIONS[g.rng.randi_range(0,CONDITIONS.size()-1)]
	var affected:Array[int]=targets(g,condition)
	g.magic_last_result={"effect":effect,"condition":condition,"targets":affected.duplicate()}
	for who in affected:
		match effect:
			"demolish":
				for lot in g.lots.values():
					if lot.owner==who and lot.level>0:
						lot.level=maxi(0,lot.level-TEST_PROFILE.demolish_levels)
						if lot.level==0: lot.building_type="vacant"; lot.research={}
			"gain_cards":
				for ignored in range(3): g.give_card(who,g.random_card())
			"deposit_cash":
				g.players[who].deposit+=g.players[who].cash
				g.players[who].cash=0
	g._log("魔法屋：%s → %s，影响%d名在场角色。"%[effect_name,CONDITION_NAMES[condition],affected.size()])
	return true
