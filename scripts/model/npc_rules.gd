class_name RichNPCRules
extends RefCounted

# Prices/limit and six-card shelf are filmed. Spawn, roaming, cooldown and
# harmful NPC amounts are explicit TEST rules pending original-game evidence.
const MERCHANT_CARDS = ["dice","stay","roadblock","jelly","robot","reverse"]
const PROFILE = {"price":1000,"purchase_limit":2,"dog_days":2,"beggar_cash":5000,"respawn_days":3}
const KINDS = ["merchant","dog","beggar"]

static func title(kind:String) -> String:
	return {"merchant":"白衣神秘人","dog":"野狗","beggar":"乞丐"}.get(kind,kind)

static func description(kind:String) -> String:
	return {"merchant":"六种常用卡，每张1000，每次限购两张；离开后消失。触发与刷新边界见测试说明。", "dog":"徒步碰到可能入院；载具和钱夫人天赋可免疫，可用防御卡应对。当前入院2次行动、每日移动1格为测试参数。", "beggar":"破产角色留下的乞丐，碰到需支付现金；钱夫人天赋免疫。当前收费5000、每日移动1格为测试参数。"}.get(kind,"")

static func at(g, road:int) -> Array[String]:
	var result:Array[String]=[]
	for id in g.road_npcs:
		if g.road_npcs[id].road==road: result.append(id)
	return result

static func _spawn_roads(g) -> Array[int]:
	var roads:Array[int]=[]
	for node in g.nodes:
		if node.id==g.start_road or not at(g,node.id).is_empty() or g.road_objects.has(node.id) or g.road_gods.has(node.id): continue
		var occupied:bool=false
		for p in g.players:
			if not p.bankrupt and p.pos==node.id: occupied=true
		if not occupied: roads.append(node.id)
	return roads

static func _spawn(g, kind:String) -> void:
	var roads:Array[int]=_spawn_roads(g)
	if roads.is_empty(): return
	g.road_npcs[kind]={"kind":kind,"road":roads[g.rng.randi_range(0,roads.size()-1)],"owner":-1}
	g.npc_respawn_due.erase(kind)

static func populate(g) -> void:
	if not g.npcs_enabled: return
	_spawn(g,"merchant")
	_spawn(g,"dog")

static func on_bankrupt(g, who:int) -> void:
	if not g.npcs_enabled: return
	g.road_npcs["beggar:%d"%who]={"kind":"beggar","road":g.players[who].pos,"owner":who}
	g._log("%s 破产后成为道路乞丐（移动与讨款数值为测试规则）。" % g.players[who].name)

static func advance_day(g) -> void:
	if not g.npcs_enabled or (g.round_limit>0 and g.round_number>g.round_limit): return
	# NPC movement does not itself strike a stationary player. Encounter is
	# checked when a player's ordinary movement/landing arrives on its road.
	for id in g.road_npcs:
		var npc:Dictionary=g.road_npcs[id]
		if npc.kind=="merchant": continue
		var choices:Array=g.nodes[npc.road].neighbors
		if not choices.is_empty(): npc.road=choices[g.rng.randi_range(0,choices.size()-1)]
	for kind in ["merchant","dog"]:
		if g.npc_respawn_due.has(kind) and g.round_number>=g.npc_respawn_due[kind]: _spawn(g,kind)

static func _remove(g, id:String) -> void:
	var kind:String=g.road_npcs[id].kind
	g.road_npcs.erase(id)
	if kind in ["merchant","dog"]: g.npc_respawn_due[kind]=g.round_number+PROFILE.respawn_days

static func encounter(g, arrival:bool) -> bool:
	if not g.npcs_enabled or g.phase not in ["move","land"] or not g.pending_service.is_empty() or not g.pending_attack.is_empty(): return false
	var p:Dictionary=g.players[g.current]
	if p.bankrupt: return false
	for id in at(g,p.pos):
		if g.npc_seen.has(id): continue
		var npc:Dictionary=g.road_npcs[id]
		if npc.kind=="merchant":
			# Directly filmed encounters stop here; pass-through entry is unverified.
			if g.steps_left>0 or not p.status.is_empty() or g.Gods.id(g,g.current)=="fierce": continue
			g.npc_seen.append(id)
			g.pending_service={"kind":"merchant","npc_id":id,"road":p.pos,"purchases":0,"bought":[],"return_phase":g.phase}
			g.phase="merchant"
			g._log("遇到白衣神秘人：每张1000，限购两张。")
			return true
		g.npc_seen.append(id)
		if g.Traits.npc_immune(g,g.current,npc.kind):
			g._log("钱夫人免疫"+title(npc.kind)+"。")
			continue
		if npc.kind=="dog":
			_remove(g,id)
			if p.vehicle!="foot":
				g._log("驾驶载具避开野狗。")
				continue
			g.Combat.begin(g,"dog",-1,[g.current],"hospital",PROFILE.dog_days,arrival)
			g.Combat.advance(g)
			return true
		g.Money.begin(g,g.current,PROFILE.beggar_cash,-1,"beggar")
		if not g.pending_attack.is_empty(): g.pending_attack.arrival=arrival
		g.Combat.advance(g)
		return true
	return false

static func remaining(g) -> int:
	return maxi(0,PROFILE.purchase_limit-int(g.pending_service.purchases)) if g.phase=="merchant" else 0

static func offers(g) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if g.phase!="merchant": return result
	for card in MERCHANT_CARDS:
		if not g.pending_service.bought.has(card): result.append({"id":card,"name":g.CARD_NAMES[card],"price":PROFILE.price})
	return result

static func buy(g, card_id:String) -> bool:
	if not g.npcs_enabled or g.phase!="merchant" or remaining(g)<=0 or not MERCHANT_CARDS.has(card_id): return false
	var p:Dictionary=g.players[g.current]
	if p.bankrupt or not p.status.is_empty() or p.cards.size()>=g.HAND_LIMIT or p.cash<PROFILE.price or g.pending_service.bought.has(card_id): return false
	if not g.give_card(g.current,card_id): return false
	p.cash-=PROFILE.price
	g.pending_service.bought.append(card_id)
	g.pending_service.purchases+=1
	g._log(p.name+" 从神秘人购入"+("一张卡片（秘密购买）" if g.Traits.shop_purchase_private(g,g.current) else g.CARD_NAMES[card_id])+"，支付1000。")
	return true

static func close(g) -> bool:
	if not g.npcs_enabled or g.phase!="merchant" or g.pending_service.get("kind")!="merchant": return false
	var service:Dictionary=g.pending_service.duplicate(true)
	g.pending_service.clear()
	if g.road_npcs.has(service.npc_id): _remove(g,service.npc_id)
	g.phase=service.return_phase
	# Bookstores explicitly apply to this NPC; character 'shop exit' bonuses
	# are not silently extended to merchants without supporting evidence.
	g.bookstore_exit_rewards()
	if service.return_phase=="move": g._resume_road_arrival()
	else: g._continue_land()
	return true

static func gm_place(g, kind:String, road:int, owner:int=-1) -> bool:
	if not g.npcs_enabled or g.phase in ["finished","reaction","merchant"] or kind not in KINDS or road<0 or road>=g.nodes.size(): return false
	if kind=="beggar" and (owner<0 or owner>=g.players.size() or not g.players[owner].bankrupt): return false
	if kind!="beggar" and owner!=-1: return false
	var id:String="beggar:%d"%owner if kind=="beggar" else kind
	g.road_npcs[id]={"kind":kind,"road":road,"owner":owner}
	g.npc_respawn_due.erase(kind)
	return true

static func gm_remove(g, id:String) -> bool:
	if not g.npcs_enabled or not g.road_npcs.has(id) or g.phase in ["finished","reaction"]: return false
	if g.phase=="merchant" and g.pending_service.npc_id==id: return false
	_remove(g,id)
	return true

static func _known_id(id:Variant, count:int) -> bool:
	if not id is String: return false
	if id in ["merchant","dog"]: return true
	for who in range(count):
		if id=="beggar:%d"%who: return true
	return false

static func state_error(state:Dictionary, g) -> String:
	if not state.get("npcs_enabled") is bool or not state.get("road_npcs") is Dictionary or not state.get("npc_respawn_due") is Dictionary or not state.get("npc_seen") is Array: return "道路NPC字段无效"
	var count:int=state.players.size()
	if not state.npcs_enabled and (not state.road_npcs.is_empty() or not state.npc_respawn_due.is_empty() or not state.npc_seen.is_empty() or state.phase=="merchant"): return "未开启NPC但存在NPC状态"
	for id in state.road_npcs:
		var npc:Variant=state.road_npcs[id]
		if not _known_id(id,count) or not npc is Dictionary or npc.size()!=3 or npc.get("kind") not in KINDS or not npc.get("road") is int or not npc.get("owner") is int: return "NPC记录格式无效"
		if npc.road<0 or npc.road>=g.nodes.size(): return "NPC道路无效"
		if npc.kind=="beggar":
			if npc.owner<0 or npc.owner>=count or not state.players[npc.owner].bankrupt or id!="beggar:%d"%npc.owner: return "乞丐来源必须为对应破产席"
		elif id!=npc.kind or npc.owner!=-1: return "NPC身份无效"
	for kind in state.npc_respawn_due:
		if kind not in ["merchant","dog"] or state.road_npcs.has(kind) or not state.npc_respawn_due[kind] is int or state.npc_respawn_due[kind]<1 or state.npc_respawn_due[kind]>g.Economy.MAX_DAYS+4: return "NPC重现时点无效"
	var seen:Dictionary={}
	for id in state.npc_seen:
		if not _known_id(id,count) or seen.has(id): return "NPC经过记录无效"
		seen[id]=true
	if state.phase!="merchant": return ""
	var service:Dictionary=state.pending_service
	if service.size()!=6 or service.get("kind")!="merchant" or not service.get("npc_id") is String or not service.get("road") is int or not service.get("purchases") is int or not service.get("bought") is Array or service.get("return_phase") not in ["move","land"]: return "神秘人服务格式无效"
	if not state.road_npcs.has(service.npc_id) or state.road_npcs[service.npc_id].kind!="merchant" or state.road_npcs[service.npc_id].road!=service.road or not seen.has(service.npc_id): return "神秘人与服务位置不一致"
	var p:Dictionary=state.players[state.current]
	if p.pos!=service.road or p.bankrupt or not p.status.is_empty() or p.god.get("id","")=="fierce" or not state.pending_attack.is_empty() or state.steps_left!=0: return "神秘人参与者或行动状态无效"
	if (service.return_phase=="land")!=state.landing_pending: return "神秘人返回阶段无效"
	if service.purchases!=service.bought.size() or service.purchases<0 or service.purchases>PROFILE.purchase_limit: return "神秘人购买次数无效"
	var bought:Dictionary={}
	for card in service.bought:
		if not card is String or not MERCHANT_CARDS.has(card) or bought.has(card): return "神秘人货单无效"
		bought[card]=true
	return ""
