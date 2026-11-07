class_name RichCombatRules
extends RefCounted

# Provisional: zero-radius road blast; frontage damage independent of personal defence.
static func begin(g, source:String, attacker:int, victims:Array, kind:String, days:int, arrival:bool=false) -> bool:
	if not g.pending_attack.is_empty() or g.phase=="finished": return false
	g.pending_attack={"source":source,"attacker":attacker,"queue":victims.duplicate(),"kind":kind,"days":days,"target":-1,"visited":[],"return_phase":g.phase,"arrival":arrival}
	g.phase="reaction"
	return true

static func explode(g, road:int, days:int, source:String, attacker:int, arrival:bool) -> bool:
	var victims:Array=[]
	for i in range(g.players.size()):
		if not g.players[i].bankrupt and g.players[i].pos==road and g.players[i].status.get("kind","") not in ["hospital","prison","vacation"]: victims.append(i)
	if not begin(g,source,attacker,victims,"hospital",days,arrival): return false
	for id in g.lots_at_node(road):
		if g.lots[id].kind!="facility": g.lots[id].level=maxi(0,g.lots[id].level-1)
	g._log("爆炸：同格角色待判定，临街建筑降1层；范围待核验，暂不含连爆。")
	return true

static func targets(g, card:String) -> Array[int]:
	var result:Array[int]=[]
	if g.phase!="reaction" or g.pending_attack.is_empty() or card!="transfer": return result
	for i in range(g.players.size()):
		if i!=g.reaction_player() and not g.pending_attack.visited.has(i) and not g.players[i].bankrupt and g.players[i].status.is_empty(): result.append(i)
	return result

static func options(g) -> Array[String]:
	var result:Array[String]=[]
	var who:int=g.reaction_player()
	if who<0 or not g.players[who].status.is_empty(): return result
	var attack:Dictionary=g.pending_attack
	for card in ["immune","transfer","same_fate"]:
		if not g.players[who].cards.has(card): continue
		if card in ["immune","transfer"] and attack.kind in ["hospital","prison"]:
			if card!="transfer" or not targets(g,card).is_empty(): result.append(card)
		elif card=="same_fate" and attack.source in ["scheme","hibernate"] and attack.attacker>=0 and attack.attacker!=who and g.players[attack.attacker].status.is_empty(): result.append(card)
	return result

static func apply_hit(g, who:int) -> void:
	var a:Dictionary=g.pending_attack
	if a.kind=="hibernate":
		var p:Dictionary=g.players[who]
		p.status={"kind":"hibernate","remaining":a.days,"return_pos":p.pos,"return_previous":p.previous}
		g._log("%s 冬眠%d次行动（计时规则待核验）。"%[p.name,a.days])
	else: g.send_to_facility(who,a.kind,a.days,true)

static func advance(g) -> void:
	if g.pending_attack.is_empty(): return
	var a:Dictionary=g.pending_attack
	while not a.queue.is_empty():
		var who:int=a.queue.pop_front()
		if a.visited.has(who) or g.players[who].bankrupt: continue
		a.target=who
		a.visited.append(who)
		g.phase="reaction"
		if not options(g).is_empty():
			g._log("等待%s选择防御或承受效果。"%g.players[who].name)
			return
		apply_hit(g,who)
	var prior:String=a.return_phase
	var arrival:bool=a.arrival
	g.pending_attack={}
	if not g.players[g.current].status.is_empty():
		g.steps_left=0
		g.controlled_dice=0
		g.phase="end"
	else:
		g.phase=prior
		if arrival: g._continue_arrival()

static func resolve(g, card:String, target:int) -> bool:
	if g.phase!="reaction" or g.reaction_player()<0: return false
	var a:Dictionary=g.pending_attack
	var who:int=a.target
	if card!="" and not options(g).has(card): return false
	if card=="transfer" and not targets(g,card).has(target): return false
	if card!="transfer" and target!=-1: return false
	if card!="":
		g.players[who].cards.erase(card)
		g._log("%s 使用%s反应。"%[g.players[who].name,g.CARD_NAMES[card]])
	match card:
		"transfer": a.queue.push_front(target)
		"same_fate":
			apply_hit(g,who)
			apply_hit(g,a.attacker)
		"immune": pass
		_: apply_hit(g,who)
	advance(g)
	return true
