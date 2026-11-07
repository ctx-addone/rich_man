class_name RichMapCatalog
extends RefCounted

const Board = preload("res://scripts/model/board_model.gd")
const DEFAULT_MAP_ID := "integration_city"
const REGISTRY = {
	"integration_city":{"id":"integration_city","name":"集成验证城","description":"117道路、24地产；用于系统验证，非原版地图。","playable":true,"source_status":"prototype","path":"res://data/maps/integration_city.json"},
	"knight_manor":{"id":"knight_manor","name":"骑士庄园（玩法验证版）","description":"102道路、58小地产、4大地产；几何来自描图，价格与未核规则使用测试配置。","playable":true,"source_status":"traced_geometry_test_rules","path":"res://data/maps/knight_manor.json"}
}
const ROAD_KINDS = ["road","start","event","lottery","magic","cash","unresolved","news","minigame"]
const BUILDINGS = ["vacant","house","chain","mall","hotel","estate","bookstore","energy","lab","park"]

static func entries(include_unplayable:bool=false)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for item in REGISTRY.values():
		if include_unplayable or item.playable: result.append(item.duplicate(true))
	return result

static func load_map(id:String)->Dictionary:
	if not REGISTRY.has(id): return {"ok":false,"errors":["地图未注册："+id]}
	if not REGISTRY[id].playable: return {"ok":false,"errors":["地图尚无可玩布局，仅为研究证据："+id]}
	var file=FileAccess.open(REGISTRY[id].path,FileAccess.READ)
	if file==null: return {"ok":false,"errors":["无法读取地图文件："+id]}
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK: return {"ok":false,"errors":["地图JSON解析失败："+parser.get_error_message()]}
	var result:Dictionary=prepare(parser.data)
	if result.ok and result.metadata.id!=id: return {"ok":false,"errors":["地图ID与注册表不一致。"]}
	if result.ok:
		var service_errors:Array[String]=_required_facility_errors(result.layout)
		if not service_errors.is_empty(): return {"ok":false,"errors":service_errors}
	return result

static func _required_facility_errors(layout:Dictionary)->Array[String]:
	var required:Dictionary={"hospital":false,"prison":false}
	for lot in layout.lots:
		if lot.kind=="facility" and required.has(lot.building_type): required[lot.building_type]=true
	var errors:Array[String]=[]
	for kind in required:
		if not required[kind]: errors.append("可玩传统地图缺少必要设施："+kind)
	return errors

static func prepare(data:Variant)->Dictionary:
	var errors:Array[String]=validate(data)
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	var metadata:Dictionary={}
	for key in ["schema_version","id","name","description","playable","source_status","size","start_road","start_bonus"]:
		metadata[key]=data[key]
	metadata.size=[int(data.size[0]),int(data.size[1])]
	for key in ["schema_version","start_road","start_bonus"]: metadata[key]=int(metadata[key])
	if data.has("spawn_roads"):
		metadata.spawn_roads=[]
		for road in data.spawn_roads: metadata.spawn_roads.append(int(road))
	return {"ok":true,"errors":[],"layout":{"roads":data.roads.duplicate(true),"lots":data.lots.duplicate(true)},"metadata":metadata}

static func _integer(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))

static func validate(data:Variant)->Array[String]:
	var errors:Array[String]=[]
	if not data is Dictionary: errors.append("地图必须是对象。");return errors
	if not _integer(data.get("schema_version")) or data.schema_version!=1: errors.append("不支持的地图schema_version。")
	for key in ["id","name","description","source_status"]:
		if not data.get(key) is String or data[key].is_empty(): errors.append("地图缺少文字字段："+key)
	if data.get("playable")!=true or not data.get("playable") is bool: errors.append("研究证据不可作为可玩地图。")
	if not Board._integer_array(data.get("size"),2) or data.size[0]<=0 or data.size[1]<=0:
		errors.append("地图尺寸必须为两个正整数。")
	if not _integer(data.get("start_road")) or data.start_road< -1: errors.append("起点编号无效。")
	if not _integer(data.get("start_bonus")) or data.start_bonus<0: errors.append("起点奖励必须为非负整数。")
	if not data.get("roads") is Array or data.roads.is_empty(): errors.append("地图缺少道路数组。")
	if not data.get("lots") is Array: errors.append("地图缺少地产数组。")
	if not errors.is_empty(): return errors
	if data.start_road>=data.roads.size(): errors.append("起点超出道路范围。")
	if data.start_road==-1 and data.start_bonus!=0: errors.append("无起点地图不能配置起点奖励。")
	if data.has("spawn_roads"):
		if not data.spawn_roads is Array or data.spawn_roads.is_empty(): errors.append("出生道路必须为非空数组。")
		else:
			for road in data.spawn_roads:
				if not _integer(road) or road<0 or road>=data.roads.size(): errors.append("出生道路编号无效。")
	for index in range(data.roads.size()):
		var road:Variant=data.roads[index]
		if not road is Dictionary: errors.append("道路必须是对象。");continue
		if road.get("id")!=str(index): errors.append("运行时道路ID必须按数组顺序连续编号。")
		if road.get("kind") not in ROAD_KINDS: errors.append("不支持的道路类型。")
		if not road.get("name") is String or road.name.is_empty(): errors.append("道路缺少名称。")
		if not road.get("signal",false) is bool: errors.append("道路signal必须为布尔值。")
		if road.has("cash_amount") and (road.get("kind")!="cash" or not _integer(road.cash_amount)): errors.append("现金金额必须属于现金道路且为整数。")
		if road.get("kind")=="cash" and not road.has("cash_amount"): errors.append("现金道路缺少cash_amount。")
		if Board._integer_array(road.get("cell"),2):
			if road.cell[0]<0 or road.cell[1]<0 or road.cell[0]>=data.size[0] or road.cell[1]>=data.size[1]: errors.append("道路超出地图尺寸。")
		if not road.get("exits") is Array or road.exits.is_empty(): errors.append("道路至少需要一个出口。")
		if (index==data.start_road)!=(road.get("kind")=="start"): errors.append("地图必须恰有一个与start_road一致的起点。")
		if road.has("special_override"):
			var special:Variant=road.special_override
			if not special is Dictionary: errors.append("特殊服务覆盖必须是对象。")
			elif special.get("kind") not in ["lottery","magic"] or not special.get("name") is String or special.name.is_empty() or index==data.start_road: errors.append("特殊服务覆盖配置无效。")
	for lot in data.lots:
		if not lot is Dictionary: errors.append("地产必须是对象。");continue
		for key in ["name","street_id","rule_id"]:
			if not lot.get(key) is String or lot[key].is_empty(): errors.append("地产缺少文字元数据："+key)
		for key in ["price","rent"]:
			if not _integer(lot.get(key)) or lot[key]<0: errors.append("地产价格必须为非负整数："+key)
		if lot.get("kind") not in ["small","large","facility"]: errors.append("不支持的地产类型。")
		var allowed:Array=["bank","hospital","prison","shop"] if lot.get("kind")=="facility" else BUILDINGS
		if lot.get("building_type") not in allowed: errors.append("不支持的建筑类型。")
		if lot.get("owner",-1)!=-1: errors.append("地图初始地产不能绑定玩家产权。")
		if Board._integer_array(lot.get("footprint"),4):
			var f:Array=lot.footprint
			if f[0]<0 or f[1]<0 or f[0]+f[2]>data.size[0] or f[1]+f[3]>data.size[1]: errors.append("建筑超出地图尺寸。")
		if lot.has("exit_previous") and not lot.has("exit_road"): errors.append("设施出口方向必须同时指定出口道路。")
		if lot.has("exit_road"):
			if lot.get("building_type") not in ["hospital","prison"]: errors.append("只有医院和监狱支持固定释放出口。")
			if not _integer(lot.exit_road) or lot.exit_road<0 or lot.exit_road>=data.roads.size(): errors.append("设施出口道路无效。")
			else:
				var previous:Variant=lot.get("exit_previous",-1)
				if not _integer(previous) or previous< -1 or previous>=data.roads.size(): errors.append("设施出口前向信息无效。")
				elif previous>=0 and data.roads[int(lot.exit_road)] is Dictionary:
					var exits:Variant=data.roads[int(lot.exit_road)].get("exits",[])
					if not exits is Array or not exits.has(str(int(previous))): errors.append("设施出口前向信息必须连接出口道路。")
	if not errors.is_empty(): return errors
	var board=Board.new()
	errors.append_array(board.load_layout(data))
	if not errors.is_empty(): return errors
	# Connectivity is independent of whether the map has a reward/start tile.
	var anchor:int=maxi(0,int(data.start_road))
	for reverse in [false,true]:
		var seen:Dictionary={str(anchor):true}
		var queue:Array=seen.keys()
		while not queue.is_empty():
			var at:String=queue.pop_front()
			var exits:Array=board.roads[at].exits
			if reverse:
				exits=[]
				for road in board.roads.values():
					if road.exits.has(at): exits.append(road.id)
			for other in exits:
				if not seen.has(other): seen[other]=true;queue.append(other)
		if seen.size()!=board.roads.size(): errors.append("可玩地图道路必须能从起点出发并返回。");break
	return errors
