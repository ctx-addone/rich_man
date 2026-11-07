class_name RichMovementRules
extends RefCounted

static func max_dice(p:Dictionary)->int:
	return {"foot":1,"motorbike":2,"car":3}.get(p.get("vehicle","foot"),1)

static func available_moves(g)->Array[int]:
	var result:Array[int]=[]
	if g.phase!="move" or g.players.is_empty(): return result
	var p:Dictionary=g.players[g.current]
	if not g.controlled_path.is_empty() and g.nodes[p.pos].neighbors.has(g.controlled_path[0]): return [int(g.controlled_path[0])]
	for id in g.nodes[p.pos].neighbors:
		if id!=p.previous or g.nodes[p.pos].neighbors.size()==1: result.append(id)
	if g.forced_next>=0 and g.nodes[p.pos].neighbors.has(g.forced_next): return [g.forced_next]
	if result.size()>1 and ((p.previous>=0 and not p.get("choose_junction",false)) or g.is_sleepwalking()) and not g.gm_choose_route:
		if not result.has(g.cached_next): g.cached_next=result[g.rng.randi_range(0,result.size()-1)]
		return [g.cached_next]
	return result

static func reverse(g,who:int)->void:
	var p:Dictionary=g.players[who]
	var back:int=p.previous
	if back<0: back=g.nodes[p.pos].neighbors[0]
	var others:Array=g.nodes[p.pos].neighbors.duplicate()
	others.erase(back)
	p.previous=others[0] if not others.is_empty() else -1
	p.next_direction=back
	if who==g.current:
		g.controlled_path.clear()
		g.forced_next=back
		g.cached_next=-1

static func robot(g)->void:
	var at:int=g.players[g.current].pos
	var previous:int=g.players[g.current].previous
	for i in range(10):
		var choices:Array=g.nodes[at].neighbors.duplicate()
		if choices.size()>1: choices.erase(previous)
		if choices.is_empty(): break
		var next:int=choices[g.rng.randi_range(0,choices.size()-1)]
		previous=at
		at=next
		g.road_objects.erase(at)
