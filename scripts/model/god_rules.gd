class_name RichGodRules
extends RefCounted

# Unknown values are explicit integration parameters, never recovered original data.
const PROFILE = {"duration":5,"cash_entry":500,"confused_failure":0.25,"confused_reverse":0.2,"spawn_count":10,"fierce_ignored_kinds":["event","bank"]}
# PROVISIONAL: original refresh interval is unknown. Missing gods wait one
# complete global-round boundary after detection; never respawn during a card.
const CYCLE_PROFILE = {"reappear_after":1,"check_every_rounds":1}
const CATALOG = {
 "wealth":{"name":"财神","description":"入场收取对手现金；测试实现免租，其他费用集合待核验。"},
 "poor":{"name":"穷神","description":"入场向对手支付现金；租金加倍。"},
 "fortune":{"name":"福神","description":"入场获得2卡；停己方地产免费升1级。"},
 "misfortune":{"name":"衰神","description":"入场随机失去2卡；自己地产禁止加盖。"},
 "angel":{"name":"天使","description":"经过地产升1级；每次移动同一地产去重。"},
 "devil":{"name":"恶魔","description":"经过地产降1级；空地保留。"},
 "earth":{"name":"土地公","description":"经过非己方已拥有地产取得所有权。"},
 "confused":{"name":"糊涂神","description":"随机转向，用卡可能失败并消耗；概率为测试值。"},
 "martial":{"name":"武神","description":"普通范围卡增加3格；特殊卡适用范围待核验。"},
 "fierce":{"name":"凶神","description":"阻止已建模银行与机会事件；其他地格名单仍待核验。"}
}
static func id(g,who:int)->String:
 return g.players[who].get("god",{}).get("id","")
static func attach(g,who:int,god_id:String)->bool:
 if who<0 or who>=g.players.size() or g.players[who].bankrupt or not CATALOG.has(god_id): return false
 var p:Dictionary=g.players[who]
 p.bomb={}
 p.god={}
 if g.Traits.deity_immune(g,who,god_id): return true
 p.god={"id":god_id,"remaining":g.Traits.deity_duration(g,who,god_id,PROFILE.duration)}
 if god_id in ["wealth","poor"]:
  for i in range(g.players.size()):
   if not g.is_opponent(i,who) or g.players[i].bankrupt: continue
   var payer:int=i if god_id=="wealth" else who
   var receiver:int=who if god_id=="wealth" else i
   var amount:int=mini(g.players[payer].cash,PROFILE.cash_entry)
   g.players[payer].cash-=amount
   g.players[receiver].cash+=amount
 if god_id=="fortune":
  for ignored in range(2): g.give_card(who,g.random_card())
 if god_id=="misfortune":
  var lost:int=0
  for ignored in range(2):
   if not p.cards.is_empty():
    p.cards.remove_at(g.rng.randi_range(0,p.cards.size()-1))
    lost+=1
  if lost>0: g.Traits.on_card_lost(g,who,"misfortune")
 g.Traits.on_deity_attached(g,who,god_id)
 g._log(p.name+" 附身"+CATALOG[god_id].name+"（基础时长为测试配置）。")
 return true
static func spawn(g)->void:
 var roads:Array=spawn_roads(g)
 for god_id in CATALOG:
  if roads.is_empty(): break
  var index:int=g.rng.randi_range(0,roads.size()-1)
  g.road_gods[roads[index]]=god_id
  roads.remove_at(index)
static func spawn_roads(g)->Array:
 var occupied:Dictionary={}
 for p in g.players: occupied[p.pos]=true
 var roads:Array=[]
 for node in g.nodes:
  if node.id!=int(g.get("start_road") if g.get("start_road")!=null else 0) and not occupied.has(node.id) and not g.road_gods.has(node.id) and not g.road_objects.has(node.id): roads.append(node.id)
 return roads
static func advance_round(g,profile:Dictionary=CYCLE_PROFILE)->void:
 if not g.gods_enabled or g.round_number>g.round_limit: return
 if (g.round_number-1)%maxi(1,int(profile.get("check_every_rounds",1)))!=0: return
 var present:Dictionary={}
 for god_id in g.road_gods.values(): present[god_id]=true
 for p in g.players:
  if not p.bankrupt and not p.get("god",{}).is_empty(): present[p.god.id]=true
 var roads:Array=spawn_roads(g)
 for god_id in CATALOG:
  if present.has(god_id):
   g.god_respawn_due.erase(god_id)
   continue
  if not g.god_respawn_due.has(god_id):
   g.god_respawn_due[god_id]=g.round_number+maxi(1,int(profile.get("reappear_after",1)))
   continue
  if g.round_number<int(g.god_respawn_due[god_id]) or roads.is_empty(): continue
  var index:int=g.rng.randi_range(0,roads.size()-1)
  g.road_gods[roads[index]]=god_id
  roads.remove_at(index)
  g.god_respawn_due.erase(god_id)
  g._log(CATALOG[god_id].name+" 重新出现在道路上（测试刷新规则）。")
static func arrive(g,who:int)->void:
 var p:Dictionary=g.players[who]
 if g.road_gods.has(p.pos):
  var god_id:String=g.road_gods[p.pos]
  g.road_gods.erase(p.pos)
  attach(g,who,god_id)
static func tick(g,who:int)->void:
 var p:Dictionary=g.players[who]
 if p.get("god",{}).is_empty(): return
 p.god.remaining-=1
 if p.god.remaining<=0:
  g._log(p.name+" 的神仙附身结束。")
  p.god={}
static func pass_lots(g)->void:
 var god_id:String=id(g,g.current)
 if god_id not in ["angel","devil","earth"]: return
 for lot_id in g.lots_at_node(g.players[g.current].pos):
  if g.god_pass_seen.has(lot_id): continue
  g.god_pass_seen[lot_id]=true
  var lot:Dictionary=g.lots[lot_id]
  if lot.kind=="facility" or lot.owner<0: continue
  if god_id=="earth" and g.is_opponent(lot.owner,g.current): lot.owner=g.current
  elif god_id=="angel" and lot.building_type!="vacant" and id(g,lot.owner)!="misfortune": lot.level=mini(g.max_level(lot_id),lot.level+1)
  elif god_id=="devil": lot.level=maxi(0,lot.level-1)
static func stop_lot(g,lot:Dictionary)->void:
 if id(g,g.current)=="fortune" and g.same_team(lot.owner,g.current) and lot.building_type!="vacant": lot.level=mini(g.max_level(lot.id),lot.level+1)
static func invite(g)->bool:
 if g.road_gods.is_empty(): return false
 var best:int=-1
 var distance:int=99999
 for road in g.road_gods:
  var d:int=g._distance(g.players[g.current].pos,road)
  if d<distance: best=road; distance=d
 var god_id:String=g.road_gods[best]
 g.road_gods.erase(best)
 attach(g,g.current,god_id)
 return true
static func bless_targets(g)->Array:
 var result:Array=[]
 for road in g.road_gods: result.append("road:%d"%road)
 for who in range(g.players.size()):
  if who!=g.current and not g.players[who].bankrupt and not id(g,who).is_empty(): result.append("player:%d"%who)
 return result
static func bless_target_name(g,target:String)->String:
 if not bless_targets(g).has(target): return "神仙已离场"
 var key:int=int(target.get_slice(":",1))
 if target.begins_with("road:"): return "%02d · %s"%[key,CATALOG[g.road_gods[key]].name]
 return "%s · 附身%s"%[g.players[key].name,CATALOG[id(g,key)].name]
static func bless(g,target:String)->bool:
 if not bless_targets(g).has(target): return false
 var key:int=int(target.get_slice(":",1))
 var god_id:String
 if target.begins_with("road:"):
  god_id=g.road_gods[key]
  g.road_gods.erase(key)
 else:
  god_id=id(g,key)
  g.players[key].god={}
 # Reattachment uses the receiving character's duration and entry effects.
 # Remaining-duration carryover is unknown; this is the explicit test profile.
 return attach(g,g.current,god_id)
