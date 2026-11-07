extends RefCounted

# Debug actions modify the live model only between unresolved gameplay events.
static func configure_lot(game, lot_id: String, owner: int, kind: String, level: int) -> bool:
	if game.phase in ["reaction", "finished", "move"] or not game.lots.has(lot_id): return false
	var lot: Dictionary = game.lots[lot_id]
	if lot.kind == "facility" or owner < -1 or owner >= game.players.size(): return false
	if owner >= 0 and game.players[owner].bankrupt: return false
	if not game.building_options(lot_id).has(kind) or level < 1 or level > game.max_level(lot_id): return false
	lot.owner = owner
	lot.building_type = kind if owner >= 0 else "vacant"
	lot.level = level if owner >= 0 else 0
	lot.research = {}
	lot.closed_until = 0
	lot.rent_until = 0
	game._log("GM 配置地产：" + lot.name)
	return true
