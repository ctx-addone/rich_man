class_name RichExplosives
extends RefCounted

# Graph-distance radius is a test parameter, NOT a recovered original radius.
const TEST_RADIUS = 1
const SPECS = {
	"mine":{"days":2,"damage":1,"chain":true},
	"missile":{"days":1,"damage":1,"chain":true},
	"timebomb":{"days":4,"damage":2,"chain":false},
	"quantum":{"days":5,"damage":-1,"chain":true},
	"explosive":{"days":8,"damage":0,"chain":false},
	"rapid_missile":{"days":3,"damage":1,"chain":true},
}

static func on_road(p:Dictionary)->bool:
	return not p.bankrupt and p.status.get("kind","") not in ["hospital","prison","vacation"]

static func area(g, road:int)->Array:
	var result:Array=[]
	for node in g.nodes:
		if g._distance(road,node.id)<=TEST_RADIUS: result.append(node.id)
	return result

static func blast(g,road:int,source:String,attacker:int,arrival:bool=false,days_override:int=-1)->bool:
	if g.phase=="finished" or road<0 or road>=g.nodes.size() or not SPECS.has(source): return false
	return run(g,[{"road":road,"source":source,"owner":attacker,"days":days_override}],arrival)

# Collect every blast before opening reactions. Road objects are consumed when queued,
# so rings and overlapping roots cannot detonate one object twice.
static func run(g,events:Array,arrival:bool)->bool:
	if events.is_empty() or g.phase=="finished": return false
	var cursor:=0
	while cursor<events.size():
		var e:Dictionary=events[cursor]
		cursor+=1
		var spec:Dictionary=SPECS[e.source]
		var roads:Array=area(g,e.road)
		var victims:Array=[]
		for i in range(g.players.size()):
			var p:Dictionary=g.players[i]
			if on_road(p) and roads.has(p.pos):
				victims.append(i)
				p.vehicle="foot"
		var days:int=e.get("days",-1)
		if days<0: days=spec.days
		g.Combat.begin(g,e.source,e.owner,victims,"hospital",days,arrival)
		var damaged:Dictionary={}
		for road in roads:
			for id in g.lots_at_node(road):
				if damaged.has(id) or g.lots[id].kind=="facility": continue
				damaged[id]=true
				if spec.damage<0:
					g.lots[id].level=0
					g.lots[id].building_type="vacant"
					g.lots[id].research={}
				elif spec.damage>0: g.lots[id].level=maxi(0,g.lots[id].level-spec.damage)
			if spec.chain and g.road_objects.has(road) and g.road_objects[road].kind in ["mine","explosive"]:
				var object:Dictionary=g.road_objects[road]
				events.append({"road":road,"source":object.kind,"owner":object.get("owner",-1)})
				g.road_objects.erase(road)
		g._log("%s爆炸：测试图距离半径%d，住院%d次行动；建筑与载具独立结算。"%[g.CARD_NAMES.get(e.source,e.source),TEST_RADIUS,days])
	return true

static func arrive(g,who:int)->bool:
	var p:Dictionary=g.players[who]
	if not on_road(p) or not g.road_objects.has(p.pos): return false
	var object:Dictionary=g.road_objects[p.pos]
	if object.kind=="timebomb":
		if not p.get("bomb",{}).is_empty(): return false
		g.road_objects.erase(p.pos)
		p.god={}
		p.bomb={"remaining":30,"owner":object.get("owner",-1)}
		g._log(p.name+" 附上定时炸弹：30个实际道路步。")
		return false
	if object.kind not in ["mine","explosive"]: return false
	g.road_objects.erase(p.pos)
	return blast(g,p.pos,object.kind,object.get("owner",-1),true)

static func after_step(g,who:int)->bool:
	var p:Dictionary=g.players[who]
	if not on_road(p) or p.get("bomb",{}).is_empty(): return false
	p.bomb.remaining-=1
	if p.bomb.remaining<=0:
		var owner:int=p.bomb.owner
		p.bomb={}
		return blast(g,p.pos,"timebomb",owner,true)
	# Only the moving carrier hands off once; recipients do not immediately pass back.
	for i in range(g.players.size()):
		var other:Dictionary=g.players[i]
		if i!=who and on_road(other) and other.pos==p.pos and other.get("bomb",{}).is_empty():
			other.god={}
			other.bomb=p.bomb
			p.bomb={}
			g._log("定时炸弹由%s传给%s。"%[p.name,other.name])
			break
	return false

static func activate(g,road:int,attacker:int,arrival:bool=false)->bool:
	if g.phase=="finished" or road<0 or road>=g.nodes.size(): return false
	var roads:Array=area(g,road)
	var events:Array=[]
	for r in roads:
		if g.road_objects.has(r) and g.road_objects[r].kind in ["mine","explosive","timebomb"]:
			var object:Dictionary=g.road_objects[r]
			events.append({"road":r,"source":object.kind,"owner":object.get("owner",attacker)})
			g.road_objects.erase(r)
	for p in g.players:
		if on_road(p) and roads.has(p.pos) and not p.get("bomb",{}).is_empty():
			events.append({"road":p.pos,"source":"timebomb","owner":p.bomb.owner})
			p.bomb={}
	return run(g,events,arrival)

static func rapid_missile(g,attacker:int)->bool:
	var events:Array=[]
	var seen:Dictionary={}
	for i in range(g.players.size()):
		var p:Dictionary=g.players[i]
		if i!=attacker and on_road(p) and not seen.has(p.pos):
			seen[p.pos]=true
			events.append({"road":p.pos,"source":"rapid_missile","owner":attacker})
	return run(g,events,false)
