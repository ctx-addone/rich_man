class_name RichGame
extends RefCounted

const Explosives = preload("res://scripts/model/explosives.gd")
const RoutePlanner = preload("res://scripts/model/route_planner.gd")
const Movement = preload("res://scripts/model/movement_rules.gd")
const Money = preload("res://scripts/model/money_rules.gd")
const Combat = preload("res://scripts/model/combat_rules.gd")
const Buildings = preload("res://scripts/model/building_rules.gd")
const Market = preload("res://scripts/model/stock_market.gd")
const Gods = preload("res://scripts/model/god_rules.gd")
const Specials = preload("res://scripts/model/special_services.gd")
const Shop = preload("res://scripts/model/shop_rules.gd")
const Maps = preload("res://scripts/model/map_catalog.gd")
const Teams = preload("res://scripts/model/team_rules.gd")
const Traits = preload("res://scripts/model/character_traits.gd")
const HAND_LIMIT = 8
var map_id: String = Maps.DEFAULT_MAP_ID
var map_metadata: Dictionary = {}
var start_road: int = 0
var start_bonus: int = 1000
var gods_enabled := false
var talents_enabled := false
var specials_enabled := false
var lottery_state: Dictionary = Specials.initial_lottery()
var service_visited: Array[int] = []
var pending_service: Dictionary = {}
var magic_last_result: Dictionary = {}
var god_respawn_due: Dictionary = {}
var shop_stock: Array[String] = []
var shop_visit_serial: int = 0
var road_gods: Dictionary = {}
var god_pass_seen: Dictionary = {}
const BoardModel = preload("res://scripts/model/board_model.gd")
const CardsCatalog = preload("res://scripts/model/cards_catalog.gd")
const CardEffects = preload("res://scripts/model/card_effects.gd")
const CARD_NAMES = CardsCatalog.NAMES
const CARD_DESCRIPTIONS = CardsCatalog.DESCRIPTIONS
const CARD_TARGETS = CardsCatalog.TARGETS
const TEST_CARD_RANGE = 6
var board_model = BoardModel.new()
var stock_market = Market.new()
var lots: Dictionary = {}
var nodes: Array[Dictionary] = []
var players: Array[Dictionary] = []
var current := 0
var round_number := 1
var round_limit := 20
var phase := "roll"
var steps_left := 0
var last_roll := 0
var last_dice: Array[int] = []
var dice_count := 1
var gm_choose_route := false
var forced_next := -1
var cached_next := -1
var logs: Array[String] = []
var winners: Array[int] = []
var traffic_phase := 0
var rng := RandomNumberGenerator.new()
var card_used := false
var controlled_dice := 0
var controlled_path: Array = []
var active_lot_id := ""
var road_objects: Dictionary = {}
var bank_visited: Array[String] = []
var shop_purchases: int = 0
var pending_attack: Dictionary = {}
var landing_pending := false
var landing_queue: Array = []
var landing_hotel := ""
var landing_shop := false
var reaction_reward_active := false

func setup(names: Array, seed_value: int = 0, rounds: int = 20, options: Dictionary = {}) -> bool:
	var requested_id:Variant=options.get("map_id",Maps.DEFAULT_MAP_ID)
	if not requested_id is String: return false
	var prepared:Dictionary=Maps.load_map(requested_id)
	if not prepared.ok: return false
	specials_enabled = options.get("specials_enabled",false)
	lottery_state = Specials.initial_lottery()
	service_visited.clear()
	pending_service.clear()
	magic_last_result.clear()
	god_respawn_due.clear()
	shop_stock.clear()
	shop_visit_serial=0
	gods_enabled = options.get("gods_enabled",false)
	talents_enabled = options.get("talents_enabled",false)
	road_gods.clear()
	god_pass_seen.clear()
	stock_market.setup(seed_value)
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	pending_attack.clear()
	landing_pending=false
	landing_queue.clear()
	landing_hotel=""
	controlled_path.clear()
	dice_count=1
	last_dice.clear()
	gm_choose_route=false
	forced_next=-1
	cached_next=-1
	players.clear()
	logs.clear()
	winners.clear()
	road_objects.clear()
	bank_visited.clear()
	shop_purchases = 0
	current = 0
	round_number = 1
	round_limit = maxi(1, rounds)
	phase = "roll"
	steps_left = 0
	last_roll = 0
	controlled_dice = 0
	card_used = false
	active_lot_id = ""
	_build_map(prepared)
	for n in names:
		players.append({"id":players.size(), "name":str(n), "cash":10000, "deposit":0, "stocks":{}, "pos":start_road, "previous":-1, "bankrupt":false, "cards":["dice","scheme","mine"], "status":{},"vehicle":"foot","turtle_turns":0,"stay_turns":0})
	var characters: Array = options.get("characters",[])
	for i in range(players.size()):
		players[i].character_id = str(characters[i]) if i<characters.size() else ""
		players[i].god = {}
	Teams.assign(self,options.get("teams",null))
	if gods_enabled: Gods.spawn(self)
	_log(map_metadata.name+"："+map_metadata.description)
	return true

func _build_map(prepared:Dictionary={}) -> void:
	if prepared.is_empty(): prepared=Maps.load_map(map_id)
	assert(prepared.get("ok",false),str(prepared.get("errors",[])))
	map_metadata=prepared.metadata.duplicate(true)
	map_id=map_metadata.id
	start_road=int(map_metadata.start_road)
	start_bonus=int(map_metadata.start_bonus)
	nodes.clear()
	for spec in prepared.layout.roads:
		var kind:String=spec.kind
		var title:String=spec.name
		if specials_enabled and spec.has("special_override"):
			kind=spec.special_override.kind
			title=spec.special_override.name
		var neighbors:Array=[]
		for road in spec.exits: neighbors.append(int(road))
		nodes.append({"id":int(spec.id),"pos":Vector2(spec.cell[0],spec.cell[1]),"kind":kind,"name":title,"neighbors":neighbors,"signal":spec.get("signal",false)})
	var errors:Array=board_model.load_layout(prepared.layout)
	assert(errors.is_empty(),str(errors))
	lots=board_model.lots
	for spec in prepared.layout.lots:
		lots[spec.id].name=spec.name
		lots[spec.id].price=int(spec.price)
		lots[spec.id].rent=int(spec.rent)
		lots[spec.id].street_id=spec.street_id
		lots[spec.id].research={}
		lots[spec.id].closed_until=0
		lots[spec.id].rent_until=0

func lots_at_node(node_id: int) -> Array[String]:
	var result: Array[String] = []
	for id in board_model.frontage.get(str(node_id),[]): result.append(id)
	return result

func facility_lot(kind: String) -> Dictionary:
	for lot in lots.values():
		if lot.kind=="facility" and lot.building_type==kind: return lot
	return {}

func signal_state(_id: int) -> String: return "此验证地图无红绿灯"

func is_sleepwalking() -> bool:
	return not players.is_empty() and players[current].status.get("kind","")=="sleepwalk"

func max_dice() -> int:
	return Movement.max_dice(players[current]) if not players.is_empty() else 1

func set_dice_count(count: int) -> bool:
	if phase!="roll" or is_sleepwalking() or count<1 or count>max_dice() or controlled_dice!=0: return false
	dice_count=count
	return true

func available_moves() -> Array[int]:
	return Movement.available_moves(self)

func roll_dice(forced: int = 0) -> bool:
	if phase!="roll" or players.is_empty() or (not players[current].status.is_empty() and not is_sleepwalking()): return false
	var p:Dictionary=players[current]
	dice_count=clampi(dice_count,1,max_dice())
	last_dice.clear()
	if int(p.get("stay_turns",0))>0:
		p.stay_turns-=1
		last_roll=0
		controlled_dice=0
		phase="end"
		_log("停留：原地结束行动，不重复触发落点（测试规则）。")
		return true
	if is_sleepwalking(): forced=0; controlled_dice=0; controlled_path.clear()
	if int(p.get("turtle_turns",0))>0 and controlled_dice==0 and forced==0:
		last_dice.append(1)
	elif forced>0 or controlled_dice>0:
		var total:int=clampi(forced,1,18) if forced>0 else controlled_dice
		# A controlled total is split into legal faces; super dice uses one die.
		var count:int=mini(dice_count,total)
		for i in range(count):
			var face:int=mini(6,total-(count-i-1))
			last_dice.append(face)
			total-=face
	else:
		for i in range(dice_count): last_dice.append(rng.randi_range(1,6))
	if int(p.get("turtle_turns",0))>0: p.turtle_turns-=1
	last_roll=0
	for face in last_dice: last_roll+=face
	controlled_dice=0
	steps_left=last_roll
	active_lot_id=""
	bank_visited.clear()
	service_visited.clear()
	pending_service.clear()
	god_pass_seen.clear()
	cached_next=-1
	p.choose_junction=nodes[p.pos].neighbors.size()>2
	if p.has("next_direction"): forced_next=p.next_direction
	phase="move"
	_log("%s 掷出%s，共%d步。"%[p.name,str(last_dice),last_roll])
	return true

func move_to(node_id: int) -> bool:
	if not available_moves().has(node_id): return false
	var p: Dictionary=players[current]
	p.previous=p.pos
	p.pos=node_id
	if not controlled_path.is_empty(): controlled_path.pop_front()
	p.erase("next_direction")
	p.choose_junction=false
	cached_next=-1
	forced_next=-1
	steps_left-=1
	if node_id==start_road: p.cash+=start_bonus; _log("经过起点获得%d（地图测试配置）。"%start_bonus)
	if Explosives.after_step(self,current):
		Combat.advance(self)
		return true
	return _resume_road_arrival()

func _resume_road_arrival() -> bool:
	var p:Dictionary=players[current]
	var node_id:int=p.pos
	if Explosives.arrive(self,current):
		Combat.advance(self)
		return true
	if road_objects.has(node_id) and road_objects[node_id].kind!="timebomb":
		var object_owner:int=road_objects[node_id].get("owner",-1)
		var object_kind:String=road_objects[node_id].kind
		road_objects.erase(node_id)
		if object_kind=="portal":
			var choices:Array=[]
			for road in nodes:
				if road.id!=node_id: choices.append(road.id)
			controlled_path.clear()
			p.pos=choices[rng.randi_range(0,choices.size()-1)]
			p.previous=-1
			steps_left=0
			_continue_arrival()
			return true
		if object_kind=="banana":
			steps_left+=1
		elif object_kind=="jelly":
			controlled_path.clear()
			Movement.reverse(self,current)
			steps_left=2
		elif object_kind=="trap":
			p.stay_turns=1
			steps_left=0
		elif object_kind=="roadblock":
			steps_left=0
			# Arrival still resolves pass services before the final landing.
		else:
			Combat.explode(self,node_id,2,"mine",object_owner,true)
			Combat.advance(self)
			return true
	Gods.arrive(self,current)
	if Gods.id(self,current)=="confused" and rng.randf()<Gods.PROFILE.confused_reverse: Movement.reverse(self,current)
	_continue_arrival()
	return true

func _continue_arrival() -> void:
	Gods.pass_lots(self)
	var node_id:int=players[current].pos
	for id in board_model.lots_for_event(str(node_id),"pass"):
		if lots[id].building_type=="bank" and not bank_visited.has(id) and not is_sleepwalking() and Gods.id(self,current)!="fierce":
			bank_visited.append(id)
			phase="bank"
			_log("经过银行，可调整现金与存款；剩余%d步。"%steps_left)
			return
	if nodes[node_id].kind=="lottery" and Specials.enter(self,"lottery"): return
	_check_movement()

func _check_movement() -> void:
	if steps_left<=0: _land()
	elif available_moves().is_empty(): steps_left=0; _land()

func bank_transfer(amount: int) -> bool:
	if phase!="bank" or amount==0 or is_sleepwalking(): return false
	var p: Dictionary=players[current]
	if amount>p.cash or -amount>p.deposit: return false
	p.cash-=amount
	p.deposit+=amount
	_log("银行转账：现金%+d，存款%+d。"%[-amount,amount])
	return true

func close_bank() -> bool:
	if phase!="bank": return false
	phase="move"
	_check_movement()
	return true

func _land() -> void:
	var continuing_shop:bool=phase=="shop"
	phase="land"
	active_lot_id=""
	landing_shop=continuing_shop
	landing_pending=true
	landing_queue=board_model.lots_for_event(str(players[current].pos),"stop").duplicate()
	landing_hotel=""
	_log("%s 停在%s。"%[players[current].name,nodes[players[current].pos].name])
	_continue_land()

func _continue_land() -> void:
	if not landing_pending or phase=="finished": return
	var p:Dictionary=players[current]
	if p.bankrupt:
		landing_pending=false
		landing_queue.clear()
		phase="end"
		return
	if not landing_hotel.is_empty():
		var hotel:String=landing_hotel
		landing_hotel=""
		landing_pending=false
		landing_queue.clear()
		send_on_vacation(current,hotel)
		return
	while not landing_queue.is_empty():
		var id:String=landing_queue.pop_front()
		var lot:Dictionary=lots[id]
		if lot.kind=="facility":
			if lot.building_type=="shop" and not is_sleepwalking():
				phase="shop"
				if not landing_shop:
					shop_purchases=0
					Shop.enter(self)
			continue
		active_lot_id=id
		Gods.stop_lot(self,lot)
		if is_opponent(lot.owner,current):
			var cost:int=rent_preview(id,current)
			if lot.building_type=="mall":
				var multiplier:int=rng.randi_range(1,3)
				cost*=multiplier
				_log("商业中心转盘：%d倍。"%multiplier)
			if lot.building_type=="hotel" and lot.level>0 and lot.closed_until<=round_number: landing_hotel=id
			_log("待结算%s租金%d。"%[lot.name,cost])
			if cost>0:
				Money.begin(self,current,cost,lot.owner,"rent")
				Combat.advance(self)
				return
			if not landing_hotel.is_empty(): _continue_land(); return
		elif lot.owner==current and lot.building_type=="energy" and lot.closed_until<=round_number:
			p.cash+=int(Buildings.PROFILE.energy_income)*lot.level
			_log("能源中心发放收益%d。"%(int(Buildings.PROFILE.energy_income)*lot.level))
	landing_pending=false
	if nodes[p.pos].kind=="magic" and Specials.enter(self,"magic"): return
	if nodes[p.pos].kind=="event" and Gods.id(self,current)!="fierce":
		if rng.randi_range(0,1)==0: p.cash+=500; _log("机会奖励500。")
		else:
			var card:String=CARD_NAMES.keys()[rng.randi_range(0,CARD_NAMES.size()-1)]
			if give_card(current,card): _log("机会获得"+CARD_NAMES[card])

func _selected_lot(id: String) -> Dictionary:
	if id.is_empty(): id=active_lot_id
	if not lots_at_node(players[current].pos).has(id): return {}
	return lots[id]

func building_options(lot_id:String)->Array[String]:
	return Buildings.options(lots[lot_id].kind) if lots.has(lot_id) else []
func building_name(kind:String)->String: return Buildings.NAMES.get(kind,kind)
func building_description(kind:String)->String: return Buildings.DESC.get(kind,"")
func max_level(_lot_id:String)->int: return Buildings.PROFILE.max_level
func max_building_level(lot_id:String)->int: return max_level(lot_id)
func purchase_cost(lot_id:String,_type:String="")->int: return int(lots[lot_id].price) if lots.has(lot_id) else 0
func upgrade_cost(lot_id:String)->int: return int(Buildings.PROFILE.upgrade_cost) if lots.has(lot_id) else 0
func rebuild_cost(_lot_id:String,_type:String)->int: return Buildings.PROFILE.rebuild_cost
func research_cost(_lot_id:String)->int: return Buildings.PROFILE.research_cost
func lot_value(lot_id:String)->int:
	var lot:Dictionary=lots[lot_id]
	return int(lot.price+Buildings.PROFILE.upgrade_cost*maxi(0,lot.level-1))
func rent_preview(lot_id:String,visitor_id:int=-1)->int:
	if lots.has(lot_id) and visitor_id>=0 and same_team(lots[lot_id].owner,visitor_id): return 0
	return Buildings.rent(self,lots[lot_id],visitor_id) if lots.has(lot_id) else 0
func buy_property(lot_id:String="",building_type:String="")->bool:
	if phase!="land" or players[current].bankrupt or is_sleepwalking(): return false
	var lot:=_selected_lot(lot_id)
	if lot.is_empty() or lot.kind=="facility" or lot.owner!=-1: return false
	if building_type.is_empty(): building_type="house" if lot.kind=="small" else "mall"
	if not building_options(lot.id).has(building_type) or players[current].cash<purchase_cost(lot.id,building_type): return false
	players[current].cash-=purchase_cost(lot.id,building_type)
	lot.owner=current
	lot.level=1
	lot.building_type=building_type
	lot.research={}
	phase="end"
	_log("购买%s，建造%s。"%[lot.name,building_name(building_type)])
	return true
func can_upgrade_property(lot_id:String="")->bool:
	if phase!="land" or players[current].bankrupt or is_sleepwalking(): return false
	var lot:=_selected_lot(lot_id)
	if Gods.id(self,current)=="misfortune": return false
	if lot.is_empty() or lot.kind=="facility" or lot.building_type=="vacant" or not same_team(lot.owner,current) or players[lot.owner].bankrupt or lot.level>=max_level(lot.id) or players[current].cash<upgrade_cost(lot.id): return false
	return true
func upgrade_property(lot_id:String="")->bool:
	if not can_upgrade_property(lot_id): return false
	var lot:=_selected_lot(lot_id)
	players[current].cash-=upgrade_cost(lot.id)
	lot.level+=1
	phase="end"
	_log("%s 为%s加盖，产权仍归%s。"%[players[current].name,lot.name,players[lot.owner].name])
	return true
func rebuild_property(lot_id:String,building_type:String)->bool:
	if phase!="land" or players[current].bankrupt or is_sleepwalking(): return false
	var lot:=_selected_lot(lot_id)
	if lot.is_empty() or lot.owner!=current or not building_options(lot_id).has(building_type) or lot.building_type==building_type: return false
	if players[current].cash<rebuild_cost(lot_id,building_type): return false
	players[current].cash-=rebuild_cost(lot_id,building_type)
	lot.building_type=building_type
	lot.research={}
	phase="end"
	return true
func research_options(lot_id:String)->Array[String]:
	var result:Array[String]=[]
	if not lots.has(lot_id): return result
	# Verified research pool remains incomplete; only currently playable cards offered.
	var pool:Array=["portal","super_dice","trap","teleport","quantum"]
	for i in range(mini(lots[lot_id].level,pool.size())): result.append(pool[i])
	return result
func start_research(lot_id:String,card_id:String)->bool:
	if is_sleepwalking() or phase not in ["land","roll"] or not lots.has(lot_id): return false
	var lot:Dictionary=lots[lot_id]
	if lot.owner!=current or lot.building_type!="lab" or not lot.research.is_empty() or not research_options(lot_id).has(card_id) or lot.closed_until>round_number: return false
	if players[current].cash<research_cost(lot_id): return false
	players[current].cash-=research_cost(lot_id)
	lot.research={"card_id":card_id,"remaining":Buildings.PROFILE.research_turns}
	return true
func collect_research(lot_id:String)->bool:
	if is_sleepwalking() or phase not in ["roll","land","shop"] or not lots.has(lot_id): return false
	var lot:Dictionary=lots[lot_id]
	if lot.owner!=current or lot.building_type!="lab" or lot.level<=0 or lot.research.is_empty() or lot.research.remaining>0 or lot.closed_until>round_number: return false
	if not give_card(current,lot.research.card_id): return false
	lot.research={}
	return true
func give_card(player_id:int,card_id:String)->bool:
	if phase=="reaction" and not reaction_reward_active: return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or players[player_id].bankrupt or not CARD_NAMES.has(card_id): return false
	if players[player_id].cards.size()>=HAND_LIMIT:
		_log("手牌已满，无法领取"+CARD_NAMES[card_id])
		return false
	players[player_id].cards.append(card_id)
	_auto_craft(player_id)
	return true
func discard_card(index:int)->bool:
	if is_sleepwalking() or phase not in ["roll","land","shop"] or index<0 or index>=players[current].cards.size(): return false
	players[current].cards.remove_at(index)
	return true
func shop_offers()->Array[Dictionary]:
	return Shop.offers(self)
func shop_remaining()->int:
	return maxi(0,int(Buildings.PROFILE.shop_purchase_limit)-shop_purchases) if phase=="shop" else 0
func buy_card(card_id:String)->bool:
	if is_sleepwalking() or phase!="shop" or shop_remaining()<=0 or players[current].cards.size()>=HAND_LIMIT: return false
	for offer in shop_offers():
		if offer.id==card_id and players[current].cash>=offer.price:
			if not give_card(current,card_id): return false
			players[current].cash-=offer.price
			shop_purchases+=1
			Shop.purchased(self,card_id)
			return true
	return false
func close_shop()->bool:
	if phase!="shop": return false
	phase="end"
	Traits.on_shop_exit(self,current)
	for lot in lots.values():
		if same_team(lot.owner,current) and lot.building_type=="bookstore" and lot.level>0 and lot.closed_until<=round_number:
			if rng.randf()<minf(1.0,lot.level*Buildings.PROFILE.bookstore_chance_per_level):
				for i in range(rng.randi_range(1,3)): give_card(current,CARD_NAMES.keys()[rng.randi_range(0,CARD_NAMES.size()-1)])
	return true
func send_on_vacation(player_id:int,lot_id:String)->void:
	var p:Dictionary=players[player_id]
	p.status={"kind":"vacation","remaining":Buildings.PROFILE.hotel_turns,"return_pos":p.pos,"return_previous":p.previous,"lot_id":lot_id}
	if player_id==current:
		pending_service.clear()
		steps_left=0
		phase="end"
func _tick_economy()->void:
	# Final settlement uses the last playable day's quotes, not an unplayed day.
	# Lottery tickets for the just-completed final day still settle before ranking.
	Specials.advance_round(self)
	if round_number <= round_limit:
		stock_market.advance(round_number)
		Gods.advance_round(self)
	if (round_number-1)%int(Buildings.PROFILE.month_days)==0:
		for p in players:
			if not p.bankrupt:
				var interest:int=int(p.deposit*Buildings.PROFILE.interest_rate)
				p.deposit+=interest
		_log("月结：存款利息已入账（测试参数）。")
	for lot in lots.values():
		if lot.owner<0 or lot.building_type!="lab" or lot.level<=0 or lot.research.is_empty() or lot.closed_until>round_number: continue
		lot.research.remaining=maxi(0,lot.research.remaining-1)
		if lot.research.remaining==0 and give_card(lot.owner,lot.research.card_id):
			_log("研究完成："+CARD_NAMES[lot.research.card_id])
			lot.research={}

func _distance(from: int, to: int) -> int:
	var queue: Array=[from]
	var distances: Dictionary={from:0}
	while not queue.is_empty():
		var at: int=queue.pop_front()
		if at==to: return distances[at]
		for next in nodes[at].neighbors:
			if not distances.has(next): distances[next]=distances[at]+1; queue.append(next)
	return 9999

func card_targets(card_id:String)->Array:
	return CardEffects.targets(self,card_id)
func use_card(card_id:String,target:Variant=-1,value:int=0)->bool:
	if phase!="roll" or not players[current].status.is_empty() or not CARD_NAMES.has(card_id) or not players[current].cards.has(card_id): return false
	if not CardEffects.valid_command(self,card_id,target,value): return false
	var index:int=players[current].cards.find(card_id)
	players[current].cards.remove_at(index)
	if Gods.id(self,current)=="confused" and rng.randf()<Gods.PROFILE.confused_failure:
		card_used=true
		_log("糊涂神：卡片失败，已消耗。")
		return true
	if not CardEffects.apply(self,card_id,target,value):
		players[current].cards.insert(index,card_id)
		return false
	Traits.on_card_used(self,current,card_id)
	if target is int and CardsCatalog.TARGETS.get(card_id,"") in ["player","player_road"]: Traits.on_card_targeted(self,current,target,card_id)
	card_used=true
	_log("%s 使用%s。"%[players[current].name,CARD_NAMES[card_id]])
	if not pending_attack.is_empty(): Combat.advance(self)
	return true

func send_to_facility(player_id: int, kind: String, days: int, combat_internal: bool = false) -> bool:
	if phase=="reaction" and not combat_internal: return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or kind not in ["hospital","prison"] or days<1: return false
	var p: Dictionary=players[player_id]
	if p.bankrupt or facility_lot(kind).is_empty(): return false
	var prior: Dictionary=p.status
	if prior.get("kind","")=="sleepwalk": prior={}
	var destination:Dictionary=facility_lot(kind)
	p.status={"kind":kind,"remaining":days,"return_pos":destination.get("exit_road",prior.get("return_pos",p.pos)),"return_previous":destination.get("exit_previous",-1) if destination.has("exit_road") else prior.get("return_previous",p.previous)}
	_log("%s 进入%s，滞留%d次行动。"%[p.name,"医院" if kind=="hospital" else "监狱",days])
	if player_id==current:
		pending_service.clear()
		steps_left=0
		controlled_dice=0
		# The interrupted action already happened; detention starts on next turn.
		phase="end"
	return true

func gm_release(player_id: int) -> bool:
	if phase=="reaction": return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or players[player_id].status.is_empty(): return false
	var p: Dictionary=players[player_id]
	if p.status.get("kind","")!="sleepwalk":
		p.pos=p.status.return_pos
		p.previous=p.status.return_previous
	var released_kind:String=p.status.get("kind","")
	p.status={}
	Traits.on_release(self,player_id,released_kind)
	if player_id==current and phase=="detained": phase="roll"
	_log(p.name+" 返回原路线。")
	return true

func end_turn() -> bool:
	if phase not in ["land","end","detained"]: return false
	if phase=="detained" or is_sleepwalking(): players[current].status.remaining=maxi(0,players[current].status.remaining-1)
	Gods.tick(self,current)
	_check_winner()
	if phase=="finished": return true
	for ignored in range(players.size()):
		current=(current+1)%players.size()
		if current==0:
			round_number+=1
			_tick_economy()
			if round_number>round_limit: finish_game(); return true
		if not players[current].bankrupt: break
	phase="roll"
	pending_service.clear()
	controlled_path.clear()
	dice_count=1
	forced_next=-1
	cached_next=-1
	steps_left=0
	card_used=false
	controlled_dice=0
	active_lot_id=""
	if not players[current].status.is_empty():
		if players[current].status.remaining<=0: gm_release(current)
		elif not is_sleepwalking(): phase="detained"
	return true

func _pay(player_id: int, amount: int, receiver: int = -1) -> void:
	# A transferred debt to its creditor cancels itself; never liquidate assets to pay oneself.
	if receiver==player_id or amount<=0: return
	var p: Dictionary=players[player_id]
	# Provisional debt policy: cash -> deposit -> stocks -> half-price property liquidation.
	# Neither stock liquidation priority nor property discount is verified R11.
	var stock_shortfall: int = maxi(0, amount-p.cash-p.deposit)
	if stock_shortfall > 0: stock_market.liquidate(p, stock_shortfall, round_number)
	var withdrawal: int=mini(p.deposit,maxi(0,amount-p.cash))
	p.deposit-=withdrawal
	p.cash+=withdrawal
	for lot in lots.values():
		if p.cash>=amount: break
		if lot.owner==player_id:
			p.cash+=int(lot_value(lot.id)/2)
			lot.owner=-1
			lot.level=0
			lot.building_type="vacant"
			lot.research={}
	var paid: int=mini(p.cash,amount)
	p.cash-=paid
	if receiver>=0: players[receiver].cash+=paid
	if paid<amount:
		p.bankrupt=true
		p.cards.clear()
		p.status={}
		_log(p.name+" 无法偿付，破产。")
		_check_winner()

func net_worth(player_id: int) -> int:
	var total: int=players[player_id].cash+players[player_id].deposit+stock_value(player_id)
	for lot in lots.values():
		if lot.owner==player_id: total+=lot_value(lot.id)
	return total

func stock_value(player_id: int) -> int:
	if player_id < 0 or player_id >= players.size(): return 0
	return stock_market.value(players[player_id])

func can_trade_stocks() -> bool:
	return not players.is_empty() and phase in ["roll", "bank", "land", "end", "shop"] and not players[current].bankrupt and players[current].status.is_empty()

func trade_stock(stock_id: String, quantity: Variant, buying: bool) -> bool:
	if not can_trade_stocks(): return false
	var success: bool = stock_market.buy(players[current], stock_id, quantity, round_number) if buying else stock_market.sell(players[current], stock_id, quantity, round_number)
	if success: _log("%s %s%s %d份。" % [players[current].name, "买入" if buying else "卖出", stock_market.quotes[stock_id].name, quantity])
	return success

func _check_winner() -> void:
	if team_scores().size()<=1: finish_game()

func finish_game() -> void:
	pending_service.clear()
	pending_attack.clear()
	landing_pending=false
	landing_queue.clear()
	landing_hotel=""
	phase="finished"
	winners=Teams.winner_members(self)
	_log("比赛结束，按未破产队伍成员净资产合计结算；获胜名单含全队席位。")

func same_team(player_a:int,player_b:int)->bool:
	return Teams.same(self,player_a,player_b)
func is_opponent(player_a:int,player_b:int)->bool:
	return Teams.opponent(self,player_a,player_b)
func team_members(team_id:int,include_bankrupt:bool=true)->Array[int]:
	return Teams.members(self,team_id,include_bankrupt)
func team_scores()->Dictionary:
	return Teams.scores(self)
func active_teams()->Array[int]:
	return Teams.active(self)

func gm_cash(player_id: int, delta: int) -> bool:
	if phase=="reaction": return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or players[player_id].bankrupt: return false
	players[player_id].cash=maxi(0,players[player_id].cash+delta)
	return true

func gm_teleport(player_id: int, node_id: int) -> bool:
	if phase=="reaction": return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or node_id<0 or node_id>=nodes.size() or players[player_id].bankrupt or not players[player_id].status.is_empty(): return false
	players[player_id].pos=node_id
	players[player_id].previous=-1
	players[player_id].erase("next_direction")
	if player_id==current:
		controlled_path.clear()
		controlled_dice=0
		forced_next=-1
		cached_next=-1
		steps_left=0
		bank_visited.clear()
		service_visited.clear()
		pending_service.clear()
		if nodes[node_id].kind=="lottery" and Specials.enter(self,"lottery"): return true
		for id in lots_at_node(node_id):
			if lots[id].building_type=="bank":
				bank_visited.append(id)
				phase="bank"
				return true
		_land()
	return true

func gm_give_card(player_id: int, card_id: String) -> bool:
	if phase=="reaction": return false
	if phase=="finished" or player_id<0 or player_id>=players.size() or not CARD_NAMES.has(card_id) or players[player_id].bankrupt: return false
	return give_card(player_id,card_id)

func gm_vehicle(player_id: int, kind: String) -> bool:
	if phase in ["finished", "reaction"] or player_id < 0 or player_id >= players.size() or players[player_id].bankrupt or kind not in ["foot", "motorbike", "car"]: return false
	players[player_id].vehicle = kind
	if player_id == current:
		dice_count = mini(dice_count, max_dice())
		controlled_dice = 0
		controlled_path.clear()
	return true

func gm_bomb(player_id: int, remaining: int) -> bool:
	if phase in ["finished", "reaction"] or player_id < 0 or player_id >= players.size() or players[player_id].bankrupt or remaining < 0 or remaining > 30: return false
	if remaining>0: players[player_id].god={}
	players[player_id].bomb = {"remaining":remaining, "owner":-1} if remaining > 0 else {}
	return true

func _log(message: String) -> void:
	logs.append(message)
	if logs.size()>150: logs.pop_front()

func reaction_player() -> int:
	return int(pending_attack.get("target",-1)) if phase=="reaction" else -1

func reaction_description() -> String:
	if reaction_player()<0: return ""
	if pending_attack.kind=="money": return "待支付 %d 给 %s；免费免本次支付，转移改变付款人，其他后果继续。" % [pending_attack.amount,players[pending_attack.receiver].name if pending_attack.receiver>=0 else "银行"]
	return "%s：%s，持续%d次行动（计时规则待核验）。" % [CARD_NAMES.get(pending_attack.source,pending_attack.source), {"hospital":"住院","prison":"入狱","hibernate":"冬眠","sleepwalk":"梦游"}.get(pending_attack.kind,pending_attack.kind),pending_attack.days]

func reaction_options() -> Array[String]:
	return Combat.options(self)

func reaction_targets(card_id:String) -> Array[int]:
	return Combat.targets(self,card_id)

func resolve_reaction(card_id:String="",target:int=-1) -> bool:
	return Combat.resolve(self,card_id,target)

func teleport_destinations(_player_id:int)->Array[int]:
	var result:Array[int]=[]
	for n in nodes: result.append(n.id)
	return result

func controlled_routes(card_id:String)->Array[Dictionary]:
	return RoutePlanner.routes(self,card_id)

func random_card()->String:
	return CARD_NAMES.keys()[rng.randi_range(0,CARD_NAMES.size()-1)]
func gm_god(player_id:int,god_id:String)->bool:
	if phase in ["reaction","finished"] or player_id<0 or player_id>=players.size(): return false
	if god_id=="": players[player_id].god={}; return true
	var attached:bool=Gods.attach(self,player_id,god_id)
	if attached and player_id==current and Gods.id(self,current)=="fierce" and phase in ["lottery","magic"]:
		Specials.close(self,phase)
	return attached
func gm_spawn_god(road:int,god_id:String)->bool:
	if phase in ["reaction","finished"] or road<0 or road>=nodes.size(): return false
	if god_id=="": road_gods.erase(road); return true
	if not Gods.CATALOG.has(god_id): return false
	road_gods[road]=god_id
	return true
func craft_recipes()->Array:
	var result:Array=[]
	for pair in [["send_god","green"],["invite_god","god_bless"],["raise_rent","glory"],["monster","disaster"],["close_street","misery"],["missile","rapid_missile"]]:
		result.append({"id":pair[1],"input":pair[0],"output":pair[1],"count":5,"available":not players.is_empty() and players[current].cards.count(pair[0])>=5})
	return result
func craft_card(recipe_id:String)->bool:
	if phase!="roll" or not players[current].status.is_empty(): return false
	for recipe in craft_recipes():
		if recipe.id==recipe_id and recipe.available:
			for ignored in range(5): players[current].cards.erase(recipe.input)
			return give_card(current,recipe.output)
	return false

func _auto_craft(who:int)->void:
	for recipe in craft_recipes():
		if players[who].cards.count(recipe.input)>=5:
			for ignored in range(5): players[who].cards.erase(recipe.input)
			players[who].cards.append(recipe.output)
			_log(players[who].name+" 自动合成"+CARD_NAMES[recipe.output])

func lottery_numbers() -> Array[int]:
	return Specials.numbers()
func buy_ticket(number:int) -> bool:
	return Specials.buy(self,number)
func close_lottery() -> bool:
	return Specials.close(self,"lottery")
func magic_options() -> Array[Dictionary]:
	return Specials.options()
func choose_magic(effect:String) -> bool:
	return Specials.choose(self,effect)
func close_magic() -> bool:
	return Specials.close(self,"magic")
