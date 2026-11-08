extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
var failures:=0
var rejected:=0
var duplicate_seed:=-1
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func fresh(policy:String="r18_samples",specials:bool=false,seed_value:int=1881):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],seed_value,30,{"shop_policy":policy,"specials_enabled":specials,"npcs_enabled":true,"talents_enabled":true,"characters":["tangtang","shalong","qian","nintaro"],"teams":[0,1,0,1]}),"independent shop setup")
	g.road_npcs.clear();g.players[0].cards.clear()
	return g
func energy(g,slot:int,owner:int,level:int)->Dictionary:
	var candidates:Array=g.lots.values().filter(func(lot):return lot.kind=="large")
	var lot:Dictionary=candidates[slot]
	lot.owner=owner;lot.building_type="energy";lot.level=level
	return lot
func test_integer_and_scope()->void:
	var g=fresh()
	var first:Dictionary=energy(g,0,1,1)
	check(g.Shop.quote(g,"turtle").price==1380,"exact integer quote does not truncate floating1380 to1379")
	check(g.Shop.quote(g,"jelly").price==1173,"independent filmed base times TEST energy and trait")
	var second:Dictionary=energy(g,1,3,2)
	check(g.Shop.quote(g,"jelly").price==1479 and g.Shop.quote(g,"jelly").energy_percent==45,"multiple enemy centers add TEST levels once")
	energy(g,2,2,5)
	check(g.Shop.quote(g,"jelly").price==1479,"allied center never adds markup")
	first.closed_until=2
	check(g.Shop.quote(g,"jelly").price==1326,"closed center removed independently")
	second.owner=-1
	check(g.Shop.quote(g,"jelly").price==1020,"unowned center adds no charge")
	first.closed_until=0;second.owner=3
	g.current=2
	check(g.Shop.quote(g,"jelly").price==4930 and g.Shop.quote(g,"jelly").discount_percent==100,"team member does not inherit Tangtang personal discount")
	g.current=0
	var before:Dictionary=Save.snapshot(g)
	var peer:Dictionary=Save.restore(before)
	check(peer.ok,"multiple legal energy buildings save")
	if peer.ok:check(peer.game.shop_offers()==g.shop_offers() and Save.snapshot(peer.game)==before,"prices and both RNGs survive roundtrip")
	g=fresh();energy(g,0,1,1)
	var fallback:String=""
	for card in g.Shop.pool(g):
		if not g.Shop.SAMPLE_PRICES.has(card):fallback=card;break
	if fallback!="":
		var offer:Dictionary=g.Shop.quote(g,fallback)
		check(offer.price==103 and not offer.sample_price,"unknown price explicitly TEST and fractional103.5 floors once")
	# The underlying bank accounts remain separate; a quote neither spends
	# money nor changes land valuation, taxes, or the fixed NPC shelf.
	var shelf_before:Array=[]
	g.NPC.gm_place(g,"merchant",4);g.gm_teleport(0,4)
	check(g.phase=="merchant","discounted character opens independent NPC")
	shelf_before=g.NPC.offers(g)
	for offer in shelf_before:check(offer.price==1000,"NPC is unaffected by personal discount and current energy TEST")
	check(g.NPC.buy(g,"dice") and g.players[0].cash==9000,"actual NPC payment remains1000")
	check(g.pending_service.purchases==1 and g.shop_purchases==0,"ordinary shop quota untouched by NPC")
func test_legacy_energy()->void:
	var g=fresh("legacy_v8")
	energy(g,0,1,1)
	check(g.Shop.quote(g,"jelly").price==241 and g.Shop.quote(g,"jelly").discount_percent==70,"historical seven-tenths floating order retained")
	energy(g,1,3,2)
	check(g.Shop.quote(g,"jelly").price==304,"legacy multi-center historical truncation retained")
	var before:Dictionary=Save.snapshot(g);var loaded:Dictionary=Save.restore(before)
	check(loaded.ok,"legacy policy with energy saves as new version")
	if loaded.ok:check(loaded.game.Shop.quote(loaded.game,"jelly").price==304 and Save.snapshot(loaded.game)==before,"legacy policy does not silently become new price after load")
	g.talents_enabled=false
	check(g.Shop.quote(g,"jelly").price==435,"legacy toggle removes trait only")
func enter_shop(g)->void:
	for lot in g.lots.values():
		if lot.building_type=="shop":
			check(g.gm_teleport(0,int(lot.frontage_nodes[0])) and g.phase=="shop","enter actual shop for shelf test")
			return
	check(false,"shop exists")
func reject(payload:Dictionary,label:String)->void:
	check(not Save.restore(payload).ok,"reject shelf corruption "+label);rejected+=1
func test_nine_slots()->void:
	var g
	var repeated:String=""
	# Exercise the real seeded generator, without manually inventing a shelf.
	for seed_value in range(1800,1900):
		g=fresh("r18_samples",true,seed_value);enter_shop(g)
		check(g.shop_stock.size()==9 and g.shop_remaining()==9 and g.shop_offers().size()==9,"new policy generates nine separate slots")
		for card in g.shop_stock:
			if g.shop_stock.count(card)>1:repeated=card;break
		if repeated!="":duplicate_seed=seed_value;break
	check(repeated!="","real seeded generation produces duplicate merchandise")
	if repeated=="":return
	var peer=fresh("r18_samples",true,duplicate_seed);enter_shop(peer)
	check(Save.snapshot(g)==Save.snapshot(peer),"duplicate shelf generator deterministic with both RNGs")
	var before:Dictionary=Save.snapshot(g)
	var loaded:Dictionary=Save.restore(before)
	check(loaded.ok,"v9 sample policy accepts actual duplicate shelf")
	if not loaded.ok:return
	check(Save.snapshot(loaded.game)==before,"duplicate shelf count/order/RNG exactly restored")
	peer=loaded.game
	var prior_copies:int=g.shop_stock.count(repeated)
	var price:int=g.Shop.quote(g,repeated).price
	g.gm_cash(0,200000);peer.gm_cash(0,200000)
	var cash:int=g.players[0].cash
	check(g.buy_card(repeated) and peer.buy_card(repeated),"buy one duplicated product on original and restored")
	check(g.shop_stock.count(repeated)==prior_copies-1 and g.shop_stock.size()==8 and g.shop_purchases==1,"one purchase removes exactly one copy")
	check(g.players[0].cash==cash-price and g.players[0].cards.count(repeated)==1,"one duplicated slot charges and grants once")
	check(Save.snapshot(g)==Save.snapshot(peer),"duplicate purchase continues identically after save")
	for bought in range(1,9):
		while g.players[0].cards.size()>=g.HAND_LIMIT:check(g.discard_card(0),"public discard makes room to finish shelf")
		var next:String=g.shop_stock[0]
		check(g.buy_card(next),"purchase slot number"+str(bought+1))
		check(g.shop_purchases==bought+1 and g.shop_remaining()==8-bought,"quota tracks consumed slots")
		if bought==3:check(g.phase=="shop" and g.shop_stock.size()==5,"fourth purchase is not blocked by old three-card cap")
		loaded=Save.restore(Save.snapshot(g))
		check(loaded.ok,"partly purchased nine-slot shelf saves at"+str(bought+1))
		if loaded.ok:check(Save.snapshot(loaded.game)==Save.snapshot(g),"partial shelf restores exactly")
	check(g.shop_stock.is_empty() and g.shop_offers().is_empty() and g.shop_remaining()==0,"all nine slots exhausted")
	var empty:Dictionary=Save.snapshot(g)
	check(not g.buy_card(repeated) and Save.snapshot(g)==empty,"tenth purchase fails atomically")
	check(g.close_shop() and g.phase=="end","empty shop still exits normally")
	for mutation in ["too_many","missing_slot","wrong_count","over_limit","invalid_card"]:
		var bad:Dictionary=before.duplicate(true)
		match mutation:
			"too_many":bad.state.shop_stock.append(repeated)
			"missing_slot":bad.state.shop_stock.pop_back()
			"wrong_count":bad.state.shop_purchases=1
			"over_limit":bad.state.shop_stock.clear();bad.state.shop_purchases=10
			"invalid_card":bad.state.shop_stock[0]="portal"
		reject(bad,mutation)
func test_legacy_shelf()->void:
	var g=fresh("legacy_v8",true);enter_shop(g)
	var unique:Dictionary={}
	for card in g.shop_stock:unique[card]=true
	check(g.shop_stock.size()>=5 and g.shop_stock.size()<=8 and unique.size()==g.shop_stock.size(),"legacy generator retains5to8 unique stock")
	var bad:Dictionary=Save.snapshot(g)
	bad.state.shop_stock[1]=bad.state.shop_stock[0]
	reject(bad,"legacy duplicate not silently accepted")
	g.gm_cash(0,200000)
	for ignored in range(3):check(g.buy_card(g.shop_stock[0]),"legacy purchases still allowed within three")
	var before:Dictionary=Save.snapshot(g)
	check(g.shop_remaining()==0 and not g.buy_card(g.shop_stock[0]) and Save.snapshot(g)==before,"legacy fourth purchase still rejected atomically")
	check(Save.restore(before).ok,"legacy active shelf retains original count invariant")
func test_scheme_exception()->void:
	var g=fresh()
	var offer:Dictionary=g.Shop.quote(g,"scheme")
	check(offer.price==630 and offer.sample_override and offer.trait_price==630,"filmed scheme630 exception is preserved")
	var detail:String=g.Shop.quote_detail(offer)
	check(detail.contains("630") and not detail.contains("3折"),"quote explains exception without pretending630 is2400times30percent")
	energy(g,0,1,1)
	check(g.Shop.quote(g,"scheme").price==724,"TEST energy applies once after630 exception and floors724.5")
	g.talents_enabled=false
	check(g.Shop.quote(g,"scheme").price==2760 and not g.Shop.quote(g,"scheme").sample_override,"talent off uses regular2400 plus TEST energy")
	g=fresh("legacy_v8")
	check(g.Shop.quote(g,"scheme").price==210 and not g.Shop.quote(g,"scheme").sample_override,"new scheme exception cannot alter legacy pricing")
func _init()->void:
	test_integer_and_scope();test_legacy_energy();test_nine_slots();test_legacy_shelf();test_scheme_exception()
	print("ROUND18_SHOP_REVIEW failures=",failures," rejected=",rejected," duplicate_seed=",duplicate_seed)
	quit(1 if failures else 0)
