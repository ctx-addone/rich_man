class_name RichBoardModel
extends RefCounted

## Rules-independent topology and off-road lots. Does not encode unverified R11 prices.
## JSON layout coordinates use integer cells; frontage is explicit, never screen-distance inferred.
var roads: Dictionary = {}
var lots: Dictionary = {}
var frontage: Dictionary = {}

func load_layout(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var new_roads: Dictionary = {}
	var new_lots: Dictionary = {}
	var new_frontage: Dictionary = {}
	if not layout.get("roads", null) is Array or not layout.get("lots", null) is Array:
		errors.append("Layout must contain roads and lots arrays.")
		return errors
	for item in layout.roads:
		if not item is Dictionary or not item.get("id", null) is String:
			errors.append("Road requires a string ID.")
			continue
		var id: String = item.id
		if id.is_empty() or new_roads.has(id):
			errors.append("Empty or duplicate road ID: " + id)
			continue
		if not _integer_array(item.get("cell", null), 2):
			errors.append("Road requires an integer cell: " + id)
			continue
		if not item.get("exits", null) is Array:
			errors.append("Road requires exits: " + id)
			continue
		var cell := Vector2i(int(item.cell[0]), int(item.cell[1]))
		for existing in new_roads.values():
			if existing.cell == cell: errors.append("Road cells overlap: " + id)
		new_roads[id] = {"id": id, "cell": cell, "exits": item.exits.duplicate(), "event_ids": item.get("event_ids", []).duplicate()}
		new_frontage[id] = []
	for road in new_roads.values():
		var seen: Array = []
		for target in road.exits:
			if not target is String or not new_roads.has(target):
				errors.append("Unknown exit on road: " + road.id)
			elif target == road.id or seen.has(target):
				errors.append("Self or duplicate exit on road: " + road.id)
			seen.append(target)
	for item in layout.lots:
		if not item is Dictionary or not item.get("id", null) is String:
			errors.append("Lot requires a string ID.")
			continue
		var id: String = item.id
		if id.is_empty() or new_lots.has(id):
			errors.append("Empty or duplicate lot ID: " + id)
			continue
		if not _integer_array(item.get("footprint", null), 4):
			errors.append("Lot requires [x,y,width,height] integer footprint: " + id)
			continue
		var f: Array = item.footprint
		var footprint := Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
		if footprint.size.x <= 0 or footprint.size.y <= 0:
			errors.append("Nonpositive footprint: " + id)
			continue
		if not item.get("frontage_nodes", null) is Array or item.frontage_nodes.is_empty():
			errors.append("Lot requires at least one frontage road: " + id)
			continue
		var events = item.get("trigger_events", null)
		if not events is Array:
			errors.append("Lot requires explicit trigger_events: " + id)
			continue
		for event in events:
			if event not in ["pass", "stop", "leave_service", "turn_start", "round_end"]:
				errors.append("Unknown trigger event: " + id)
		for road in new_roads.values():
			if footprint.has_point(road.cell): errors.append("Building overlaps walkable road: " + id + "/" + road.id)
		for other in new_lots.values():
			if footprint.intersects(other.footprint): errors.append("Building footprints overlap: " + id + "/" + other.id)
		var seen: Array = []
		for road_id in item.frontage_nodes:
			if not road_id is String or not new_roads.has(road_id):
				errors.append("Unknown frontage: " + id)
				continue
			if seen.has(road_id):
				errors.append("Duplicate frontage: " + id)
				continue
			seen.append(road_id)
			if not is_edge_adjacent(new_roads[road_id].cell, footprint):
				errors.append("Frontage must touch a building side: " + id + "/" + road_id)
			new_frontage[road_id].append(id)
		new_lots[id] = {
			"id": id, "footprint": footprint, "frontage_nodes": seen,
			"kind": str(item.get("kind", "small")), "building_type": str(item.get("building_type", "vacant")),
			"owner": int(item.get("owner", -1)), "level": int(item.get("level", 0)),
			"trigger_events": events.duplicate(), "rule_id": str(item.get("rule_id", "UNVERIFIED")),
		}
	# Atomic replacement: malformed imports never partially corrupt a playable board.
	if errors.is_empty():
		roads = new_roads
		lots = new_lots
		frontage = new_frontage
	return errors

static func _integer_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for n in value:
		if not (n is int or n is float): return false
		if not is_finite(float(n)) or float(n) != floorf(float(n)): return false
	return true

static func is_edge_adjacent(cell: Vector2i, footprint: Rect2i) -> bool:
	var along_x := cell.x >= footprint.position.x and cell.x < footprint.end.x
	var along_y := cell.y >= footprint.position.y and cell.y < footprint.end.y
	return (along_x and (cell.y == footprint.position.y - 1 or cell.y == footprint.end.y)) or (along_y and (cell.x == footprint.position.x - 1 or cell.x == footprint.end.x))

func lots_for_event(road_id: String, event: String) -> Array[String]:
	var result: Array[String] = []
	for lot_id in frontage.get(road_id, []):
		if lots[lot_id].trigger_events.has(event) and not result.has(lot_id): result.append(lot_id)
	return result

func lot_at_cell(cell: Vector2i) -> String:
	for lot in lots.values():
		if lot.footprint.has_point(cell): return lot.id
	return ""

func set_lot_state(lot_id: String, owner: int, level: int, building_type: String) -> bool:
	if not lots.has(lot_id) or owner < -1 or level < 0: return false
	# Building-specific level limits and costs belong to the verified rule catalogue.
	lots[lot_id].owner = owner
	lots[lot_id].level = level
	lots[lot_id].building_type = building_type
	return true
