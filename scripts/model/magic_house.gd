class_name RichMagicHouse
extends RefCounted

# Nine traditional-mode effects are visible in the 2022 PC menu capture.
# Selection, odd-card rounding, vacant-road interpretation and defenses remain
# explicit implementation policies pending continuous original-game footage.
const CONDITIONS = ["car", "richest", "most_properties", "most_cards", "male", "female", "possessed", "on_property"]
const CONDITION_NAMES = {"car":"驾驶载具", "richest":"总资产最多", "most_properties":"地产最多", "most_cards":"卡片最多", "male":"所有男性", "female":"所有女性", "possessed":"被神仙附身", "on_property":"站在地产旁"}
# Character/costume sources are catalogued in docs/research/r12-special-services.md.
# This classification is independent of portrait selection and the talent toggle.
const SEX = {"sun_xiaomei":"female", "atu":"male", "qian":"female", "shalong":"male", "jin_beibei":"female", "nintaro":"male", "qian_ge":"male", "sarah":"female", "wumi":"female", "miyamoto":"male", "danny":"male", "tangtang":"female", "john":"male", "wu_meila":"female", "ludwig":"male", "eleven":"female"}
const CATALOG = [
	{"id":"gain_cards", "name":"获得3张卡片", "description":"符合条件的角色各获得3张随机卡，遵守手牌上限。"},
	{"id":"deposit_cash", "name":"存入所有现金", "description":"符合条件的角色将全部现金存入自己的银行账户。"},
	{"id":"prison", "name":"入狱1天", "description":"符合条件的角色入狱1次行动；当前沿用拘留防御流程。"},
	{"id":"lose_cards", "name":"失去一半卡片", "description":"随机失去一半手牌；奇数张暂按向下取整。"},
	{"id":"demolish", "name":"随机摧毁1栋建筑", "description":"每名符合条件的角色随机失去一栋建筑，土地所有权保留。"},
	{"id":"gain_god", "name":"获得地图上1个神仙", "description":"从道路上随机邀请一位神仙附身；没有道路神仙则无效果。"},
	{"id":"teleport_vacant", "name":"随机传送至任意空地", "description":"传送至未建造地产的临路格；空地定义和落点触发仍待核验。"},
	{"id":"destroy_vehicle", "name":"摧毁载具", "description":"符合条件的角色失去摩托或汽车，恢复步行。"},
	{"id":"stay", "name":"原地停留1天", "description":"符合条件的角色下一次行动原地停留。"}
]

static func targets(g, condition:String) -> Array[int]:
	var result:Array[int]=[]
	if not CONDITIONS.has(condition): return result
	var best:int=-1
	for who in range(g.players.size()):
		var p:Dictionary=g.players[who]
		if p.bankrupt or p.status.get("kind","") in ["hospital","prison","vacation"]: continue
		var matched:bool=false
		match condition:
			"car": matched=p.vehicle in ["motorbike","car"]
			"male","female": matched=SEX.get(p.get("character_id","original"),"")==condition
			"possessed": matched=not p.get("god",{}).is_empty()
			"on_property":
				# Functional squares are not property squares even when the demo
				# geometry happens to give them an adjacent lot frontage.
				if g.nodes[p.pos].kind=="road":
					for id in g.lots_at_node(p.pos):
						if g.lots[id].kind!="facility": matched=true
			"richest","most_properties","most_cards":
				var value:int=0
				if condition=="richest": value=g.net_worth(who)
				elif condition=="most_cards": value=p.cards.size()
				else:
					for lot in g.lots.values():
						if lot.kind!="facility" and lot.owner==who: value+=1
				if value>best: result.clear(); best=value
				matched=value==best
		if matched: result.append(who)
	return result

static func vacant_destinations(g) -> Array[int]:
	var roads:Array[int]=[]
	for lot in g.lots.values():
		if lot.kind=="facility" or lot.level>0 or lot.building_type!="vacant": continue
		for road in lot.frontage_nodes:
			var id:int=int(road)
			if not roads.has(id): roads.append(id)
	return roads

static func ai_effect(g) -> String:
	# Evaluate all publicly possible conditions, never read or simulate RNG state.
	# Equal condition weights and utility amounts are original demo AI heuristics.
	var best:String="gain_cards"
	var best_score:float=-INF
	for option in CATALOG:
		var score:float=0.0
		for condition in CONDITIONS:
			for who in targets(g,condition):
				var p:Dictionary=g.players[who]
				var benefit:float=0.0
				match option.id:
					"gain_cards": benefit=mini(3,g.HAND_LIMIT-p.cards.size())*300.0
					"deposit_cash": benefit=-minf(p.cash,10000)*0.12
					"prison","stay": benefit=-800.0
					"lose_cards": benefit=-int(p.cards.size()/2)*300.0
					"destroy_vehicle": benefit=-900.0 if p.vehicle=="car" else -450.0 if p.vehicle=="motorbike" else 0.0
					"demolish":
						var count:int=0
						for lot in g.lots.values():
							if lot.kind!="facility" and lot.owner==who and lot.level>0:
								benefit-=lot.level*float(g.Buildings.PROFILE.upgrade_cost);count+=1
						if count>0: benefit/=count
					# Random gods/teleport have unknown strategic value; score neutral.
				score+=benefit if g.same_team(g.current,who) else -benefit
		if score>best_score: best_score=score;best=option.id
	return best

static func choose(g, effect:String) -> bool:
	if not g.specials_enabled or g.phase!="magic" or g.pending_service.get("kind","")!="magic" or not g.Specials.eligible(g,g.current): return false
	var effect_name:String=""
	for option in CATALOG:
		if option.id==effect: effect_name=option.name
	if effect_name.is_empty(): return false
	g.pending_service.clear()
	g.phase="land"
	var condition:String=CONDITIONS[g.rng.randi_range(0,CONDITIONS.size()-1)]
	# Freeze the target set before applying effects, including ranking changes.
	var affected:Array[int]=targets(g,condition)
	g.magic_last_result={"effect":effect,"condition":condition,"targets":affected.duplicate()}
	var names:Array[String]=[]
	for who in affected: names.append(g.players[who].name)
	g._log("魔法屋：%s → %s；命中：%s。"%[effect_name,CONDITION_NAMES[condition],"无人" if names.is_empty() else "、".join(names)])
	if effect=="prison":
		if not affected.is_empty():
			g.Combat.begin(g,"magic_house",-1,affected,"prison",1)
			g.Combat.advance(g)
		return true
	var card_losers:Array[int]=[]
	for who in affected:
		var p:Dictionary=g.players[who]
		match effect:
			"demolish":
				var buildings:Array=[]
				for lot in g.lots.values():
					if lot.kind!="facility" and lot.owner==who and lot.level>0 and lot.building_type!="vacant": buildings.append(lot.id)
				if not buildings.is_empty():
					var id:String=buildings[g.rng.randi_range(0,buildings.size()-1)]
					var lot:Dictionary=g.lots[id]
					lot.level=0; lot.building_type="vacant"; lot.research={}
					g._log("%s 的%s建筑被摧毁，保留土地产权。"%[p.name,lot.name])
			"gain_cards":
				for ignored in range(3): g.give_card(who,g.random_card())
			"deposit_cash":
				p.deposit+=p.cash; p.cash=0
			"lose_cards":
				var count:int=p.cards.size()/2
				for ignored in range(count): p.cards.remove_at(g.rng.randi_range(0,p.cards.size()-1))
				if count>0: card_losers.append(who)
			"gain_god":
				if not g.road_gods.is_empty():
					var roads:Array=g.road_gods.keys()
					var road:int=roads[g.rng.randi_range(0,roads.size()-1)]
					var god:String=g.road_gods[road]
					g.road_gods.erase(road)
					g.Gods.attach(g,who,god)
			"teleport_vacant":
				var roads:Array[int]=vacant_destinations(g)
				if not roads.is_empty():
					p.pos=roads[g.rng.randi_range(0,roads.size()-1)]; p.previous=-1
					p.erase("next_direction")
					if who==g.current:
						g.active_lot_id=""; g.forced_next=-1; g.cached_next=-1
						g.controlled_path.clear(); g.controlled_dice=0
					# No second arrival chain; the magic action settles only once.
					g._log(p.name+" 被传送到道路%d。"%p.pos)
			"destroy_vehicle":
				p.vehicle="foot"
				if who==g.current: g.dice_count=1; g.controlled_dice=0; g.controlled_path.clear()
			"stay": p.stay_turns=maxi(1,int(p.get("stay_turns",0)))
	# Lost-card gifts occur after the whole batch, so they are not removed again.
	for who in card_losers: g.Traits.on_card_lost(g,who,"magic_house")
	return true
