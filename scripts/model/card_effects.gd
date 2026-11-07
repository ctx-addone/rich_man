class_name RichCardEffects
extends RefCounted

const Catalog = preload("res://scripts/model/cards_catalog.gd")
# All distances and expiry conventions are provisional, not verified original values.
const TEST_RANGE = 6

static func targets(game, card_id: String) -> Array:
	var result: Array = []
	if not Catalog.TARGETS.has(card_id) or game.players.is_empty(): return result
	var actor: Dictionary = game.players[game.current]
	match Catalog.TARGETS[card_id]:
		"dice": return [1,2,3,4,5,6]
		"none": return [-1]
		"player":
			for i in range(game.players.size()):
				var p: Dictionary = game.players[i]
				if i == game.current or p.bankrupt: continue
				# A sleeping road character can still be imprisoned, but cannot defend.
				if not p.status.is_empty() and not (card_id == "scheme" and p.status.get("kind", "") == "hibernate"): continue
				if game._distance(actor.pos, p.pos) > TEST_RANGE: continue
				if card_id == "steal" and (p.cards.is_empty() or actor.cards.size() >= 8): continue
				result.append(i)
		"road":
			for node in game.nodes:
				if (card_id=="missile" or not game.road_objects.has(node.id)) and game._distance(actor.pos,node.id) <= TEST_RANGE: result.append(node.id)
		"lot":
			for id in game.lots:
				var lot: Dictionary = game.lots[id]
				if lot.kind == "facility" or lot.owner < 0: continue
				var nearby := false
				for road in lot.frontage_nodes:
					if game._distance(actor.pos,int(road)) <= TEST_RANGE: nearby = true; break
				if not nearby: continue
				if card_id == "worker" and (lot.owner != game.current or lot.level >= game.max_level(id)): continue
				if card_id == "bulldozer" and lot.level <= 0: continue
				result.append(id)
	return result

static func apply(game, card_id: String, target: Variant = -1, value: int = 0) -> bool:
	var chosen: Variant = value if card_id == "dice" else target
	if not targets(game,card_id).has(chosen): return false
	var actor: Dictionary = game.players[game.current]
	match card_id:
		"dice": game.controlled_dice = value
		"scheme", "hibernate": return game.Combat.begin(game,card_id,game.current,[target],"prison" if card_id=="scheme" else "hibernate",2)
		"missile": return game.Combat.explode(game,target,1,"missile",game.current,false)
		"mine", "roadblock", "portal": game.road_objects[target] = {"kind":card_id,"owner":game.current}
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
