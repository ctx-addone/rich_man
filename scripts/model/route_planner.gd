class_name RichRoutePlanner
extends RefCounted

# Pure topology queries: path excludes the origin; steps is signed for super dice.
# Multi-dice controlled sums are a provisional project rule, not verified R11 data.
static func routes(g, card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if g.players.is_empty() or g.current < 0 or g.current >= g.players.size(): return result
	var p: Dictionary = g.players[g.current]
	var origin: int = p.pos
	if origin < 0 or origin >= g.nodes.size(): return result
	var minimum := 1
	var maximum := 6
	match card_id:
		"dice":
			minimum = g.dice_count
			maximum = minimum * 6
			if minimum < 1 or minimum > 3: return result
		"super_dice": pass
		"robot": minimum = 10; maximum = 10
		_: return result
	var path: Array[int] = []
	_walk(g, origin, int(p.previous), path, minimum, maximum, 1, _first(g, p, false), result)
	if card_id == "super_dice":
		_walk(g, origin, int(p.previous), path, minimum, maximum, -1, _first(g, p, true), result)
	return result

static func valid_path(g, card_id: String, path: Array, steps: int) -> bool:
	if g.players.is_empty() or g.current < 0 or g.current >= g.players.size(): return false
	if path.is_empty() or path.size() != absi(steps): return false
	match card_id:
		"dice":
			if g.dice_count < 1 or g.dice_count > 3: return false
			if steps < g.dice_count or steps > g.dice_count * 6: return false
		"super_dice":
			if steps == 0 or absi(steps) > 6: return false
		"robot":
			if steps != 10: return false
		_: return false
	var p: Dictionary = g.players[g.current]
	var at: int = p.pos
	var previous: int = p.previous
	if at < 0 or at >= g.nodes.size(): return false
	var choices: Array[int] = _first(g, p, card_id == "super_dice" and steps < 0)
	for i in range(path.size()):
		if typeof(path[i]) != TYPE_INT: return false
		var next: int = path[i]
		if not choices.has(next): return false
		previous = at
		at = next
		choices = _onward(g, at, previous)
	return true

static func _first(g, p: Dictionary, backward: bool) -> Array[int]:
	var at: int = p.pos
	var neighbors: Array = g.nodes[at].neighbors
	if backward:
		var back: int = p.previous
		if back < 0 and not neighbors.is_empty(): back = neighbors[0]
		if neighbors.has(back): return [back]
		return []
	if p.has("next_direction") and neighbors.has(p.next_direction):
		return [int(p.next_direction)]
	return _onward(g, at, int(p.previous))

static func _onward(g, at: int, previous: int) -> Array[int]:
	var choices: Array[int] = []
	var neighbors: Array = g.nodes[at].neighbors
	for next in neighbors:
		if next < 0 or next >= g.nodes.size(): continue
		if next != previous or neighbors.size() == 1:
			if not choices.has(int(next)): choices.append(int(next))
	return choices

static func _walk(g, at: int, previous: int, path: Array[int], minimum: int, maximum: int, sign_value: int, choices: Array[int], result: Array[Dictionary]) -> void:
	if path.size() >= minimum:
		result.append({"destination": at, "steps": path.size() * sign_value, "path": path.duplicate()})
	if path.size() >= maximum: return
	for next in choices:
		path.append(next)
		_walk(g, next, at, path, minimum, maximum, sign_value, _onward(g, next, at), result)
		path.pop_back()
