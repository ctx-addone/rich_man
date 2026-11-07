class_name RichCardEffects
extends RefCounted

const Catalog = preload("res://scripts/model/cards_catalog.gd")
# All distances and expiry conventions are provisional, not verified original values.
const TEST_RANGE = 6

static func valid_command(game,card_id:String,target:Variant,value:int)->bool:
	if target is Array:
		if card_id=="swap_house":
			if target.size()!=2 or target[0]==target[1] or not targets(game,card_id).has(target[0]) or not targets(game,card_id).has(target[1]): return false
			var first:Dictionary=game.lots[target[0]]
			var second:Dictionary=game.lots[target[1]]
			return game.lots_at_node(game.players[game.current].pos).has(target[0]) and first.building_type in ["house","chain"] and second.owner==game.current and second.level>=1 and second.building_type in ["house","chain"]
		return card_id in ["dice","super_dice","robot"] and game.RoutePlanner.valid_path(game,card_id,target,value)
	var chosen:Variant=value if card_id in ["dice","super_dice"] else target
	if not targets(game,card_id).has(chosen): return false
	if card_id=="teleport": return game.teleport_destinations(target).has(value)
	if card_id=="rebuild":
		var options:Array=game.building_options(target)
		return value>=0 and value<options.size() and options[value]!=game.lots[target].building_type
	if card_id=="buy_land": return game.players[game.current].cash>=game.lot_value(target)
	if card_id=="invite_god" or card_id=="god_bless": return not game.road_gods.is_empty()
	if card_id=="rapid_missile":
		for i in range(game.players.size()):
			if i!=game.current and game.Explosives.on_road(game.players[i]): return true
		return false
	if card_id=="activate":
		for road in game.Explosives.area(game,target):
			if game.road_objects.has(road) and game.road_objects[road].kind in ["mine","explosive","timebomb"]: return true
			for p in game.players:
				if game.Explosives.on_road(p) and p.pos==road and not p.get("bomb",{}).is_empty(): return true
		return false
	return true

static func targets(game, card_id: String) -> Array:
	var result: Array = []
	if not Catalog.TARGETS.has(card_id) or game.players.is_empty(): return result
	var actor: Dictionary = game.players[game.current]
	var card_range:int=game.Traits.card_range(game,game.current,card_id,TEST_RANGE+(3 if game.Gods.id(game,game.current)=="martial" else 0))
	match Catalog.TARGETS[card_id]:
		"dice":
			if card_id=="super_dice": return [-6,-5,-4,-3,-2,-1,1,2,3,4,5,6]
			return range(game.dice_count,game.dice_count*6+1)
		"god": return game.road_gods.keys()
		"none": return [-1]
		"player", "player_road":
			for i in range(game.players.size()):
				var p: Dictionary = game.players[i]
				if (i == game.current and card_id not in ["turtle","stay","reverse","teleport","send_god"]) or p.bankrupt: continue
				if game.Traits.target_immune(game,game.current,i,card_id): continue
				if card_id=="send_god" and p.get("god",{}).is_empty() and p.get("bomb",{}).is_empty(): continue
				# A sleeping road character can still be imprisoned, but cannot defend.
				if not p.status.is_empty() and not (card_id in ["scheme","turtle","hibernate","sleepwalk"] and p.status.get("kind", "") in ["hibernate","sleepwalk"]): continue
				if game._distance(actor.pos, p.pos) > card_range: continue
				if card_id == "steal" and (p.cards.is_empty() or actor.cards.size() >= 8): continue
				result.append(i)
		"road":
			for node in game.nodes:
				if (card_id in ["missile","quantum","activate"] or not game.road_objects.has(node.id)) and game._distance(actor.pos,node.id) <= card_range: result.append(node.id)
		"lot", "lot_pair":
			for id in game.lots:
				var lot: Dictionary = game.lots[id]
				if lot.kind == "facility" or lot.owner < 0: continue
				var nearby := false
				for road in lot.frontage_nodes:
					if game._distance(actor.pos,int(road)) <= card_range: nearby = true; break
				if not nearby: continue
				if card_id=="buy_land" and lot.owner==game.current: continue
				if card_id=="worker" and game.Gods.id(game,lot.owner)=="misfortune": continue
				if card_id == "worker" and (lot.owner != game.current or lot.building_type == "vacant" or lot.level >= game.max_level(id)): continue
				if card_id == "bulldozer" and lot.level <= 0: continue
				result.append(id)
	return result

static func apply(game, card_id: String, target: Variant = -1, value: int = 0) -> bool:
	if target is Array:
		if card_id=="swap_house":
			if not valid_command(game,card_id,target,value): return false
			var a:Dictionary=game.lots[target[0]]
			var b:Dictionary=game.lots[target[1]]
			for field in ["building_type","level","research"]:
				var saved:Variant=a[field]
				a[field]=b[field]
				b[field]=saved
			return true
		if card_id not in ["dice","super_dice","robot"] or not game.RoutePlanner.valid_path(game,card_id,target,value): return false
		if card_id=="robot":
			for road in target: game.road_objects.erase(road)
			return true
		if card_id=="super_dice":
			game.controlled_path.clear()
			if value<0: game.Movement.reverse(game,game.current)
			game.dice_count=1
		game.controlled_path=target.duplicate()
		game.controlled_dice=absi(value)
		return true
	var chosen: Variant = value if card_id in ["dice","super_dice"] else target
	if not targets(game,card_id).has(chosen): return false
	var actor: Dictionary = game.players[game.current]
	match card_id:
		"invite_god": return game.Gods.invite(game)
		"send_god": game.players[target].god={}; game.players[target].bomb={}
		"green":
			game.road_objects.clear()
			game.road_gods.clear()
			for p in game.players: p.god={}; p.bomb={}
		"god_bless":
			var god_id:String=game.road_gods[target]
			game.road_gods.erase(target)
			return game.Gods.attach(game,game.current,god_id)
		"buy_land":
			var lot:Dictionary=game.lots[target]
			var cost:int=game.lot_value(target)
			if actor.cash<cost: return false
			actor.cash-=cost
			game.players[lot.owner].cash+=cost
			lot.owner=game.current
		"monster":
			var street:String=game.lots[target].get("street_id",target)
			for lot in game.lots.values():
				if lot.kind!="facility" and lot.get("street_id",lot.id)==street: lot.level=maxi(0,lot.level-1)
		"magic":
			var pool:Array=actor.cards.duplicate()
			pool.append_array(game.players[target].cards)
			actor.cards.clear()
			game.players[target].cards.clear()
			var actor_count:int=pool.size()/2
			var distributed:int=0
			while not pool.is_empty():
				var index:int=game.rng.randi_range(0,pool.size()-1)
				var recipient:int=game.current if distributed<actor_count else target
				game.give_card(recipient,pool[index])
				pool.remove_at(index)
				distributed+=1
		"dice":
			game.controlled_path.clear()
			game.controlled_dice = value
		"super_dice":
			game.controlled_path.clear()
			if value<0: game.Movement.reverse(game,game.current)
			game.dice_count=1
			game.controlled_dice=absi(value)
		"motorbike", "car":
			actor.vehicle=card_id
			game.controlled_dice=0
			game.controlled_path.clear()
			game.dice_count=game.max_dice()
		"turtle":
			if game.players[target].status.get("kind","") in ["hibernate","sleepwalk"]: game.players[target].status={}
			game.players[target].turtle_turns=3
		"stay": game.players[target].stay_turns=1
		"reverse": game.Movement.reverse(game,target)
		"sleepwalk": return game.Combat.begin(game,card_id,game.current,[target],"sleepwalk",2)
		"teleport":
			if not game.teleport_destinations(target).has(value): return false
			game.players[target].pos=value
			game.players[target].previous=-1
			game.players[target].erase("next_direction")
			if target==game.current: game.forced_next=-1; game.cached_next=-1; game.controlled_path.clear(); game.controlled_dice=0
		"robot": game.Movement.robot(game)
		"quantum": return game.Explosives.blast(game,target,card_id,game.current)
		"rapid_missile": return game.Explosives.rapid_missile(game,game.current)
		"activate": return game.Explosives.activate(game,target,game.current)
		"scheme", "hibernate": return game.Combat.begin(game,card_id,game.current,[target],"prison" if card_id=="scheme" else "hibernate",2)
		"missile": return game.Combat.explode(game,target,1,"missile",game.current,false)
		"mine", "roadblock", "portal", "banana", "trap", "jelly", "timebomb", "explosive": game.road_objects[target] = {"kind":card_id,"owner":game.current}
		"audit":
			var amount: int = int(game.players[target].cash * 15 / 100)
			game.players[target].cash -= amount
			actor.cash += amount
		"equal_pair":
			var total: int = actor.cash + game.players[target].cash
			actor.cash = int(total / 2)
			game.players[target].cash = total - actor.cash
		"equal_all":
			var participants: Array = []
			var total := 0
			for i in range(game.players.size()):
				if not game.players[i].bankrupt and game.players[i].status.is_empty():
					participants.append(i)
					total += game.players[i].cash
			if participants.is_empty(): return false
			var share: int = int(total / participants.size())
			var remainder: int = total % participants.size()
			for i in range(participants.size()): game.players[participants[i]].cash = share + (1 if i < remainder else 0)
		"steal":
			var cards: Array = game.players[target].cards
			var index: int = game.rng.randi_range(0,cards.size()-1)
			if not game.give_card(game.current,cards[index]): return false
			cards.remove_at(index)
			game.Traits.on_card_lost(game,target,"steal")
		"worker": game.lots[target].level += 1
		"bulldozer": game.lots[target].level = maxi(0,game.lots[target].level-1)
		"rebuild":
			var options: Array = game.building_options(target)
			if value < 0 or value >= options.size() or options[value] == game.lots[target].building_type: return false
			game.lots[target].building_type = options[value]
			game.lots[target].level = mini(game.lots[target].level,game.max_level(target))
			game.lots[target].research = {}
		"close_street", "raise_rent":
			var street: String = game.lots[target].get("street_id",target)
			var field := "closed_until" if card_id == "close_street" else "rent_until"
			var duration := 5 if card_id == "close_street" else 6
			for id in game.lots:
				var lot: Dictionary = game.lots[id]
				if lot.kind != "facility" and lot.get("street_id",id) == street: lot[field] = maxi(int(lot.get(field,0)),game.round_number+duration)
		"glory": actor.glory_until = maxi(int(actor.get("glory_until",0)),game.round_number+12)
		"misery", "disaster":
			for lot in game.lots.values():
				if lot.kind == "facility" or lot.owner < 0 or lot.owner == game.current: continue
				if card_id == "misery": lot.closed_until = maxi(int(lot.get("closed_until",0)),game.round_number+6)
				else: lot.level = maxi(0,lot.level-4)
		_: return false
	return true
