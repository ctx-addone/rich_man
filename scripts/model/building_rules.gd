extends RefCounted
# All numeric values below are a provisional integration profile, not verified R11 data.
const PROFILE = {"provisional":true,"shop_purchase_limit":3,"max_level":5,"upgrade_cost":600,"land_price":1200,"energy_income":300,"card_price":300,"bookstore_chance_per_level":0.2,"month_days":20,"interest_rate":0.02,"street_bonus":0.25,"chain_bonus":0.5,"estate_discount":0.1,"energy_markup":0.15,"hotel_turns":1,"research_turns":2,"research_cost":400,"rebuild_cost":500}
const NAMES = {"vacant":"空地","house":"住宅","chain":"连锁店","mall":"商业中心","hotel":"大饭店","estate":"地产公司","bookstore":"书店","energy":"能源中心","lab":"研究所","park":"公园"}
const DESC = {"house":"同街持有地产增加租金。","chain":"同一所有者的连锁店形成收益联动。","mall":"对手停留时转盘决定租金。","hotel":"收取租金并使对手停留度假。","estate":"降低所有者应付地产租金。","bookstore":"所有者离开商店时有机会获赠卡片。","energy":"增加对手购卡价格；所有者停留获得收入。","lab":"选择卡片研究，完成后领取。","park":"不产生租金。"}
const RENTS = {"house":[0,220,440,660,880,1100],"chain":[0,180,360,540,720,900],"mall":[0,400,800,1200,1600,2000],"hotel":[0,160,320,480,640,800],"estate":[0,0,0,0,0,0],"bookstore":[0,0,0,0,0,0],"energy":[0,0,0,0,0,0],"lab":[0,0,0,0,0,0],"park":[0,0,0,0,0,0]}
static func options(kind:String)->Array[String]:
	var out:Array[String]=[]
	out.assign(["house","chain"] if kind=="small" else ["mall","hotel","estate","bookstore","energy","lab","park"] if kind=="large" else [])
	return out
static func rent(game,lot:Dictionary,payer:int=-1)->int:
	if lot.owner<0 or lot.level<=0 or lot.get("closed_until",0)>game.round_number: return 0
	var kind:String=lot.building_type
	var amount:float=RENTS.get(kind,RENTS.house)[clampi(lot.level,0,5)]
	var count:=0
	for other in game.lots.values():
		if other.id==lot.id or other.owner!=lot.owner or other.level<=0: continue
		if kind=="house" and other.get("street_id","")==lot.get("street_id",""): count+=1
		elif kind=="chain" and other.building_type=="chain": count+=1
	if kind=="house": amount*=1.0+count*PROFILE.street_bonus
	if kind=="chain": amount*=1.0+count*PROFILE.chain_bonus
	if payer>=0:
		var discount:=0.0
		for other in game.lots.values():
			if other.owner==payer and other.building_type=="estate" and other.get("closed_until",0)<=game.round_number: discount+=other.level*PROFILE.estate_discount
		amount*=1.0-minf(discount,0.8)
	if lot.get("rent_until",0)>game.round_number: amount*=2
	if game.players[lot.owner].get("glory_until",0)>game.round_number: amount*=2
	return maxi(0,int(amount))
