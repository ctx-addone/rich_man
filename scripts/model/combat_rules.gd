class_name RichCombatRules
extends RefCounted

const Explosives = preload("res://scripts/model/explosives.gd")

static func begin(g, source:String, attacker:int, victims:Array, kind:String, days:int, arrival:bool=false) -> bool:
	if g.phase=="finished": return false
	var event := {"source":source,"attacker":attacker,"queue":victims.duplicate(),"kind":kind,"days":days,"target":-1,"visited":[]}
	if not g.pending_attack.is_empty():
		g.pending_attack.events.append(event)
		g.pending_attack.arrival = g.pending_attack.arrival or arrival
		return true
	event.merge({"return_phase":g.phase,"arrival":arrival,"events":[]})
	g.pending_attack=event
	g.phase="reaction"
	return true

static func explode(g, road:int, days:int, source:String, attacker:int, arrival:bool) -> bool:
	return Explosives.blast(g,road,source,attacker,arrival,days)

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
	for card in ["immune","transfer","same_fate","free"]:
		if not g.players[who].cards.has(card): continue
		if attack.kind=="money" and attack.amount>=g.Money.TEST_PROFILE.reaction_threshold:
			if card=="free" or (card=="transfer" and not targets(g,card).is_empty()): result.append(card)
		elif card in ["immune","transfer"] and attack.kind in ["hospital","prison"]:
			if card!="transfer" or not targets(g,card).is_empty(): result.append(card)
		elif card=="same_fate" and attack.source in ["scheme","hibernate","sleepwalk"] and attack.attacker>=0 and attack.attacker!=who and g.players[attack.attacker].status.is_empty(): result.append(card)
	return result

static func apply_hit(g, who:int) -> void:
	var a:Dictionary=g.pending_attack
	if a.kind=="money":
		g._pay(who,a.amount,a.receiver)
		return
	if g.Traits.target_immune(g,a.attacker,who,a.source): return
	if a.kind in ["hibernate","sleepwalk"]:
		var p:Dictionary=g.players[who]
		p.turtle_turns=0
		p.status={"kind":a.kind,"remaining":a.days,"return_pos":p.pos,"return_previous":p.previous}
		g._log("%s %s%d次行动（计时规则待核验）。"%[p.name,"梦游" if a.kind=="sleepwalk" else "冬眠",a.days])
	else:
		var prior:Dictionary=g.players[who].status
		# Multiple blast events retain the longest hospitalization, never shorten it.
		var days:int=maxi(a.days,int(prior.get("remaining",0))) if prior.get("kind","")==a.kind else int(a.days)
		g.send_to_facility(who,a.kind,days,true)

static func advance(g) -> void:
	if g.pending_attack.is_empty(): return
	var a:Dictionary=g.pending_attack
	while true:
		if a.queue.is_empty():
			if a.events.is_empty(): break
			var next:Dictionary=a.events.pop_front()
			for key in ["source","attacker","queue","kind","days","target","visited"]: a[key]=next[key]
			for key in ["amount","receiver"]: a[key]=next.get(key,0 if key=="amount" else -1)
			continue
		var who:int=a.queue.pop_front()
		if a.visited.has(who) or g.players[who].bankrupt: continue
		a.target=who
		a.visited.append(who)
		g.phase="reaction"
		if not options(g).is_empty():
			g._log("等待%s选择防御或承受效果。"%g.players[who].name)
			return
		apply_hit(g,who)
		if g.phase=="finished": return
	var prior:String=a.return_phase
	var arrival:bool=a.arrival
	g.pending_attack={}
	if g.players[g.current].bankrupt or (not g.players[g.current].status.is_empty() and g.players[g.current].status.get("kind","")!="sleepwalk"):
		g.landing_pending=false
		g.landing_queue.clear()
		g.landing_hotel=""
		g.steps_left=0
		g.controlled_dice=0
		g.phase="end"
	else:
		g.phase=prior
		if arrival: g._resume_road_arrival()
		elif g.landing_pending: g._continue_land()

static func resolve(g, card:String, target:int) -> bool:
	if g.phase!="reaction" or g.reaction_player()<0: return false
	var a:Dictionary=g.pending_attack
	var who:int=a.target
	if card!="" and not options(g).has(card): return false
	if card=="transfer" and not targets(g,card).has(target): return false
	if card!="transfer" and target!=-1: return false
	if card!="":
		g.players[who].cards.erase(card)
		g.reaction_reward_active=true
		g.Traits.on_card_used(g,who,card)
		g.reaction_reward_active=false
		g._log("%s 使用%s反应。"%[g.players[who].name,g.CARD_NAMES[card]])
	match card:
		"transfer": a.queue.push_front(target)
		"same_fate":
			apply_hit(g,who)
			apply_hit(g,a.attacker)
		"immune", "free": pass
		_: apply_hit(g,who)
	if g.phase=="finished": return true
	advance(g)
	return true
