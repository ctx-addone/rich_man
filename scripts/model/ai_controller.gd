extends RefCounted

# Original deterministic heuristic, not a reconstruction of the closed-source AI.
# All memory lives in the game (card_used, shopping quota, balances, research).
const CASH_RESERVE := 3000
const GOOD_GODS := ["wealth", "fortune", "angel", "earth", "martial"]
const BAD_GODS := ["poor", "misfortune", "devil", "confused", "fierce"]

static func step(g) -> bool:
	if g.players.is_empty() or g.phase == "finished": return false
	var p: Dictionary = g.players[g.current]
	match g.phase:
		"merchant":
			if p.cards.size()<g.HAND_LIMIT and g.NPC.remaining(g)>0:
				for offer in g.NPC.offers(g):
					if p.cards.count(offer.id)<2 and p.cash>=CASH_RESERVE+offer.price: return g.NPC.buy(g,offer.id)
			return g.NPC.close(g)
		"news": return g.News.resolve(g)
		"minigame": return g.Minigame.ai_step(g)
		"reaction":
			var options: Array = g.reaction_options()
			var defender: int = g.reaction_player()
			for card in ["free", "immune", "transfer", "same_fate"]:
				if not options.has(card): continue
				if card == "transfer":
					var targets: Array = _opponents(g, defender, g.reaction_targets(card))
					if not targets.is_empty(): return g.resolve_reaction(card, _richest(g, targets))
				elif card == "same_fate":
					if g.is_opponent(defender, g.pending_attack.get("attacker", -1)): return g.resolve_reaction(card)
				else: return g.resolve_reaction(card)
			return g.resolve_reaction()
		"roll":
			if not g.is_sleepwalking():
				if not g.card_used and _play_card(g): return true
				if _research(g): return true
				if g.controlled_dice == 0 and g.dice_count != g.max_dice(): return g.set_dice_count(g.max_dice())
			return g.roll_dice()
		"move":
			var moves: Array = g.available_moves()
			if moves.is_empty(): return false
			var best: int = moves[0]
			for road in moves:
				if _road_score(g, road) > _road_score(g, best): best = road
			return g.move_to(best)
		"bank":
			var desired: int = mini(CASH_RESERVE, p.cash + p.deposit)
			if p.cash != desired: return g.bank_transfer(p.cash - desired)
			return g.close_bank()
		"shop":
			if not g.is_sleepwalking() and p.cards.size() < g.HAND_LIMIT and g.shop_remaining() > 0:
				var offers: Array = g.shop_offers()
				for preferred in ["free", "dice", "worker", "immune", "car", "god_bless"]:
					if p.cards.count(preferred) >= 2: continue
					for offer in offers:
						if offer.id == preferred and p.cash >= CASH_RESERVE + offer.price:
							return g.buy_card(preferred)
			return g.close_shop()
		"lottery":
			# At most one ticket per draw; use visible balances and ticket records.
			var has_ticket: bool = false
			for ticket in g.lottery_state.tickets:
				if ticket.player == g.current: has_ticket = true
			if not has_ticket and g.pending_service.get("purchases", 0) == 0 and p.cash >= CASH_RESERVE + g.Specials.TEST_PROFILE.ticket_price:
				var numbers: Array = g.lottery_numbers()
				if not numbers.is_empty() and g.buy_ticket(numbers[(g.current + g.round_number) % numbers.size()]): return true
			return g.close_lottery()
		"magic":
			# Compare visible outcomes across all conditions, before any random draw.
			if g.choose_magic(g.Specials.Magic.ai_effect(g)): return true
			return g.close_magic()
		"land":
			if not g.is_sleepwalking():
				for id in g.lots_at_node(p.pos):
					var lot: Dictionary = g.lots[id]
					if lot.kind == "facility": continue
					if lot.owner < 0:
						var kind: String = "house" if lot.kind == "small" else _large_building(g)
						if p.cash >= g.purchase_cost(id, kind) + 1000 and g.buy_property(id, kind): return true
					elif g.same_team(lot.owner, g.current):
						if p.cash >= CASH_RESERVE + g.upgrade_cost(id) and g.upgrade_property(id): return true
				if _research(g): return true
			return g.end_turn()
		"end", "detained": return g.end_turn()
	return false

static func _richest(g, targets: Array) -> int:
	var best: int = targets[0]
	for who in targets:
		if g.net_worth(who) > g.net_worth(best): best = who
	return best

static func _opponents(g, actor: int, targets: Array) -> Array:
	var result: Array = []
	for who in targets:
		if g.is_opponent(actor, who) and not g.players[who].bankrupt: result.append(who)
	return result

static func _large_building(g) -> String:
	var owned: Array = []
	for lot in g.lots.values():
		if lot.owner == g.current and lot.kind == "large": owned.append(lot.building_type)
	for kind in ["hotel", "mall", "lab", "estate"]:
		if not owned.has(kind): return kind
	return "mall"

static func _research(g) -> bool:
	var p: Dictionary = g.players[g.current]
	for lot in g.lots.values():
		if lot.owner != g.current or lot.building_type != "lab": continue
		if not lot.research.is_empty():
			if g.collect_research(lot.id): return true
		elif p.cash >= CASH_RESERVE + g.research_cost(lot.id):
			var choices: Array = g.research_options(lot.id)
			if not choices.is_empty() and g.start_research(lot.id, choices[0]): return true
	return false

static func _road_score(g, road: int) -> float:
	var score: float = 0
	if g.road_objects.has(road): score -= 2500
	if g.road_gods.has(road): score += 800 if GOOD_GODS.has(g.road_gods[road]) else -1500
	for id in g.lots_at_node(road):
		var lot: Dictionary = g.lots[id]
		if lot.kind == "facility": continue
		if lot.owner < 0: score += 600
		elif g.same_team(lot.owner, g.current): score += 200
		else: score -= g.rent_preview(id, g.current) + (800 if lot.building_type == "hotel" else 0)
	return score

static func _play_card(g) -> bool:
	var p: Dictionary = g.players[g.current]
	for card in ["car", "motorbike", "send_god", "god_bless", "worker", "buy_land", "glory", "misery", "disaster", "audit", "steal", "scheme", "hibernate", "sleepwalk", "turtle", "dice", "super_dice", "robot"]:
		if not p.cards.has(card): continue
		var targets: Array = g.card_targets(card)
		if card in ["car", "motorbike"]:
			if p.vehicle == "car" or (card == "motorbike" and p.vehicle != "foot"): continue
			if g.use_card(card): return true
		elif card == "send_god":
			for who in targets:
				var target: Dictionary = g.players[who]
				if (g.same_team(g.current, who) and (BAD_GODS.has(target.god.get("id", "")) or not target.get("bomb", {}).is_empty())) or (g.is_opponent(g.current, who) and GOOD_GODS.has(target.god.get("id", ""))):
					if g.use_card(card, who): return true
		elif card == "god_bless":
			for target in targets:
				var key: int = int(str(target).get_slice(":", 1))
				if str(target).begins_with("player:") and not g.is_opponent(g.current, key): continue
				var god: String = g.road_gods[key] if str(target).begins_with("road:") else g.players[key].god.id
				if GOOD_GODS.has(god) and g.use_card(card, target): return true
		elif card in ["dice", "super_dice", "robot"]:
			var routes: Array = g.controlled_routes(card)
			if routes.is_empty(): continue
			var best: Dictionary = routes[0]
			var score: float = -INF
			for route in routes:
				var value: float = _road_score(g, route.destination)
				if card == "robot":
					value = 0
					for road in route.path:
						if g.road_objects.has(road):
							if g.same_team(g.current, g.road_objects[road].get("owner", -1)):
								value = -INF
								break
							value += 100
				else:
					for road in route.path:
						if g.road_objects.has(road): value -= 1000
				if value > score: score = value; best = route
			if card == "robot" and score <= 0: continue
			if g.use_card(card, best.path, best.steps): return true
		elif card in ["worker", "buy_land"]:
			for id in targets:
				if card == "buy_land" and (not g.is_opponent(g.current, g.lots[id].owner) or p.cash < g.lot_value(id) + CASH_RESERVE): continue
				if card == "worker" and not g.same_team(g.current, g.lots[id].owner): continue
				if g.use_card(card, id): return true
		elif card in ["glory", "misery", "disaster"]:
			if card != "glory" and not _safe_global_attack(g, card): continue
			if g.use_card(card): return true
		else:
			targets = _opponents(g, g.current, targets)
			if not targets.is_empty() and g.use_card(card, _richest(g, targets)): return true
	return false

static func _safe_global_attack(g, card: String) -> bool:
	# The effect model excludes allied owners. Only spend the global attack when
	# an enemy has a building that can actually be lowered or newly closed.
	for lot in g.lots.values():
		if lot.kind == "facility" or not g.is_opponent(g.current, lot.owner) or lot.level <= 0: continue
		if card == "disaster" or int(lot.get("closed_until",0)) < g.round_number + 6: return true
	return false
