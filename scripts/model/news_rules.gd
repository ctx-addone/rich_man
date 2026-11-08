class_name RichNewsRules
extends RefCounted

# Original R11 PC first-person report + filmed news panel support this subset.
# Equal weights, subsidy amount and service eligibility are explicit test policy.
const CATALOG = [
	{"id":"release_prisoners", "name":"释放在押者", "description":"当前仍在监狱中的未破产角色全部获释，返回各自记录的释放位置。", "source":"https://www.chuapp.com/article/288938.html"},
	{"id":"house_subsidy", "name":"房屋补贴", "description":"当前角色获得房屋补贴，金额按本次新闻的物价结算。", "source":"https://www.bilibili.com/video/BV18HeHz7EdD/?p=8&t=125", "source_base":"https://www.gamespark.jp/imgs/zoom/627516.png"}
]
const TEST_PROFILE = {"event_ids":["release_prisoners","house_subsidy"], "weights":[1,1], "house_subsidy_amount":5000, "price_index":1}

static func event_info(id:String)->Dictionary:
	for event in CATALOG:
		if event.id==id: return event.duplicate(true)
	return {}

static func eligible(g)->bool:
	return g.current>=0 and g.current<g.players.size() and not g.players[g.current].bankrupt and g.players[g.current].status.is_empty() and g.Gods.id(g,g.current)!="fierce"

static func enter(g)->bool:
	if not g.specials_enabled or g.phase!="land" or g.steps_left!=0 or g.landing_pending or not eligible(g): return false
	if not g.landing_queue.is_empty() or not g.landing_hotel.is_empty(): return false
	if not g.pending_attack.is_empty() or not g.pending_service.is_empty(): return false
	var road:int=g.players[g.current].pos
	if road<0 or road>=g.nodes.size() or g.nodes[road].kind!="news" or g.service_visited.has(road): return false
	var id:String=TEST_PROFILE.event_ids[g.rng.randi_range(0,TEST_PROFILE.event_ids.size()-1)]
	g.service_visited.append(road)
	g.pending_service={"kind":"news","road":road,"event_id":id}
	g.Economy.freeze_service(g)
	g.phase="news"
	g._log("新闻："+event_info(id).name+"（已核验事件子集）。")
	return true

static func targets(g,id:String)->Array[int]:
	var result:Array[int]=[]
	if id=="house_subsidy":
		if g.current>=0 and g.current<g.players.size() and not g.players[g.current].bankrupt: result.append(g.current)
		return result
	if id!="release_prisoners": return result
	for who in range(g.players.size()):
		if not g.players[who].bankrupt and g.players[who].status.get("kind","")=="prison": result.append(who)
	return result

static func current(g)->Dictionary:
	if g.phase!="news" or g.pending_service.get("kind","")!="news": return {}
	var result:Dictionary=event_info(str(g.pending_service.get("event_id","")))
	if not result.is_empty():
		result.targets=targets(g,result.id)
		if result.id=="house_subsidy": result.description="当前角色获得%d现金（本次物价×%d）。" % [subsidy(g),g.Economy.service_price(g)]
	return result

static func subsidy(g)->int:
	return int(TEST_PROFILE.house_subsidy_amount) * g.Economy.service_price(g)

static func resolve(g)->bool:
	if not g.specials_enabled or g.phase!="news" or g.pending_service.get("kind","")!="news" or not eligible(g) or not g.pending_attack.is_empty(): return false
	if g.pending_service.get("road",-1)!=g.players[g.current].pos: return false
	var id:String=str(g.pending_service.get("event_id",""))
	if event_info(id).is_empty(): return false
	# Clear before applying effects: re-entry/repeated confirmation cannot apply twice.
	var affected:Array[int]=targets(g,id)
	var amount:int=subsidy(g)
	g.pending_service.clear()
	g.phase="land"
	if id=="house_subsidy":
		g.players[g.current].cash+=amount
		g._log("新闻结算：房屋补贴，获得%d现金。"%amount)
		return true
	var released:int=0
	for who in affected:
		if g.gm_release(who): released+=1
	g._log("新闻结算：释放在押者，共%d人获释。"%released)
	return true

static func state_error(state:Dictionary,g)->String:
	state=g.Economy.scoring_state(state)
	if state.get("phase")!="news" or not state.get("specials_enabled") is bool or state.specials_enabled!=true: return "新闻阶段或服务开关无效"
	var service:Variant=state.get("pending_service")
	if not service is Dictionary or service.size()!=3: return "新闻记录字段无效"
	if service.get("kind")!="news" or not service.get("road") is int or not service.get("event_id") is String: return "新闻记录类型无效"
	if event_info(service.event_id).is_empty(): return "新闻事件未知"
	var road:int=service.road
	if road<0 or road>=g.nodes.size() or g.nodes[road].kind!="news": return "新闻道路无效"
	var players:Variant=state.get("players")
	var who:Variant=state.get("current")
	if not players is Array or not who is int or who<0 or who>=players.size() or not players[who] is Dictionary: return "新闻当前玩家无效"
	var p:Dictionary=players[who]
	if not p.get("pos") is int or p.pos!=road or not p.get("bankrupt") is bool or p.bankrupt: return "新闻玩家位置或破产状态无效"
	if not p.get("status") is Dictionary or not p.status.is_empty() or not p.get("god") is Dictionary or p.god.get("id","")=="fierce": return "新闻玩家资格无效"
	if not state.get("steps_left") is int or state.steps_left!=0 or not state.get("landing_pending") is bool or state.landing_pending: return "新闻落点尚未完成"
	if not state.get("landing_queue") is Array or not state.landing_queue.is_empty() or state.get("landing_hotel")!="": return "新闻落点队列尚未完成"
	if not state.get("pending_attack") is Dictionary or not state.pending_attack.is_empty(): return "新闻仍有待处理攻击"
	var visited:Variant=state.get("service_visited")
	if not visited is Array: return "新闻访问记录无效"
	var seen:Dictionary={}
	for item in visited:
		if not item is int or item<0 or item>=g.nodes.size() or seen.has(item): return "新闻访问记录无效"
		seen[item]=true
	if not seen.has(road): return "新闻缺少本次访问记录"
	return ""
