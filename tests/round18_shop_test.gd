extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const FIXTURE="res://tests/fixtures/round17-v8-shop.rms"
var failures:=0
var rejected:=0
var matches:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func fresh(specials:bool=false):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],1818,25,{"shop_policy":"r18_samples","specials_enabled":specials,"talents_enabled":true,"teams":[0,1,0,1],"economy":{"initial_cash":100000,"initial_deposit":100000,"inflation_interval":1}}),"sample setup")
	g.players[0].cards.clear()
	return g
func enter(g)->void:
	for lot in g.lots.values():
		if lot.building_type=="shop":
			check(g.gm_teleport(0,int(lot.frontage_nodes[0])) and g.phase=="shop","enter real fixed shop")
			return
	check(false,"shop found")
func roundtrip(g):
	var before:Dictionary=Save.snapshot(g)
	var loaded:Dictionary=Save.restore(before)
	check(loaded.ok,"save restores")
	if not loaded.ok:return null
	check(Save.snapshot(loaded.game)==before,"entire save and RNG identical")
	return loaded.game
func test_quotes()->void:
	var g=fresh()
	# Independent raw footage observations; not an iteration over production prices.
	var expected={"dice":5000,"stay":4000,"roadblock":4500,"jelly":3400,"robot":2000,"reverse":3000,"transfer":5200,"raise_rent":2000,"rebuild":3000}
	for card in expected:check(g.Shop.quote(g,card).price==expected[card],"filmed regular quote "+card)
	var before:Dictionary=Save.snapshot(g)
	for ignored in range(15):g.shop_offers()
	check(Save.snapshot(g)==before,"viewing quotes never changes stock RNG or game")
	check(g.Shop.quote(g,"portal").is_empty() and g.Shop.quote(g,"unknown").is_empty(),"research/unknown cards have no shop quote")
	g.players[0].character_id="tangtang"
	check(g.Shop.quote(g,"mine").price==600 and not g.Shop.quote(g,"mine").sample_price,"known Tangtang mine600 is preserved without inventing ordinary base")
	check(g.Shop.quote(g,"scheme").price==630 and g.Shop.quote_detail(g.Shop.quote(g,"scheme")).contains("样本价630"),"filmed exceptional scheme quote is not mislabeled as 2400 times30percent")
	for pair in [["jelly",1020],["roadblock",1350],["reverse",900],["transfer",1560]]:
		check(g.Shop.quote(g,pair[0]).price==pair[1],"filmed Tangtang quote "+pair[0])
	var quotes:Array=g.shop_offers()
	g.round_number=19
	check(g.price_index()==19 and g.shop_offers()==quotes,"card price independent from inflation")
	g.talents_enabled=false
	check(g.Shop.quote(g,"jelly").price==3400,"talent toggle disables discount")
	g.talents_enabled=true
	var lot:Dictionary=g.lots.lot_1_1
	lot.owner=2;lot.building_type="energy";lot.level=1
	check(g.Shop.quote(g,"jelly").price==1020,"allied energy excluded")
	lot.owner=1
	check(g.Shop.quote(g,"jelly").price==1173,"TEST energy 15 percent then 30 percent quote")
	lot.closed_until=20
	check(g.Shop.quote(g,"jelly").price==1020,"closed energy excluded")
	lot.closed_until=19
	check(g.Shop.quote(g,"jelly").price==1173,"expiry restores markup")
	check(g.NPC.PROFILE.price==1000,"merchant remains separate fixed1000")
func test_purchase_ai()->void:
	var g=fresh(true);enter(g)
	var offer:Dictionary=g.shop_offers()[0]
	var stock_count:int=g.shop_stock.count(offer.id)
	g.players[0].cash=offer.price-1
	var before:Dictionary=Save.snapshot(g)
	check(not g.buy_card(offer.id) and Save.snapshot(g)==before,"insufficient cash atomic")
	g.players[0].cash=offer.price
	var peer=roundtrip(g)
	check(g.buy_card(offer.id) and g.players[0].cash==0 and g.shop_stock.count(offer.id)==stock_count-1,"exact quote debited and one item sold")
	if peer!=null:check(peer.buy_card(offer.id) and Save.snapshot(peer)==Save.snapshot(g),"active stocked purchase resumes identically")
	check(not g.buy_card(offer.id),"zero cash cannot purchase another item")
	g=fresh();enter(g)
	for ignored in range(g.HAND_LIMIT):g.give_card(0,"dice")
	before=Save.snapshot(g)
	check(not g.buy_card("stay") and Save.snapshot(g)==before,"full hand neither charged nor quota consumed")
	check(g.discard_card(0) and g.buy_card("stay"),"discard permits purchase")
	g=fresh();enter(g)
	g.players[0].cash=AI.CASH_RESERVE+5000
	check(AI.step(g),"AI normal shop command succeeds")
	check(g.players[0].cash>=AI.CASH_RESERVE,"AI observes real price and reserve")
	check(g.shop_purchases==1 or g.phase=="end","AI buys one affordable preferred card or leaves")
func test_legacy()->void:
	check(FileAccess.get_sha256(FIXTURE).to_upper()=="D6F67543C84D2A822B67DBB31D77A853360030EC9F0C81AE83FEB0BE74775417","frozen v8 unchanged")
	var f=FileAccess.open(FIXTURE,FileAccess.READ);f.seek(44)
	var old:Dictionary=bytes_to_var(f.get_buffer(f.get_length()-44));f.close()
	var loaded:Dictionary=Save.load_from_file(FIXTURE)
	check(loaded.ok and old.version==8,"real v8 migrates")
	if not loaded.ok:return
	var g=loaded.game
	var now:Dictionary=Save.snapshot(g,old.metadata)
	check(now.state.shop_policy=="legacy_v8","only neutral old price policy added")
	now.state.erase("shop_policy");now.version=8
	check(now==old,"every old field metadata and RNG retained")
	for offer in g.shop_offers():check(offer.price==210,"old active Tangtang price stays210")
	check(g.players[0].cash==69790 and g.shop_purchases==1 and g.shop_stock.size()==6,"old payment and remaining visit frozen")
	var peer=roundtrip(g)
	var card:String=g.shop_stock[0]
	check(g.buy_card(card) and g.players[0].cash==69580,"old remaining item still debits210")
	if peer!=null:
		check(peer.buy_card(card) and Save.snapshot(peer)==Save.snapshot(g),"old pending purchase continuation exact")
		g.close_shop();peer.close_shop()
		for action in range(200):
			if g.phase=="finished":break
			check(AI.step(g)==AI.step(peer) and Save.snapshot(g)==Save.snapshot(peer),"post-visit old trait rewards and RNG stay deterministic")
func test_validation()->void:
	var g=fresh();var before:Dictionary=Save.snapshot(g)
	for value in [null,1,true,"",{},"future"]:
		check(not g.setup(["X","Y"],2,2,{"shop_policy":value}) and Save.snapshot(g)==before,"bad setup policy atomic")
		var bad:Dictionary=before.duplicate(true);bad.state.shop_policy=value
		check(not Save.restore(bad).ok,"bad saved policy rejected");rejected+=1
	var missing:Dictionary=before.duplicate(true);missing.state.erase("shop_policy")
	check(not Save.restore(missing).ok,"v9 missing policy rejected");rejected+=1
	for version in range(1,9):
		var bad:Dictionary=before.duplicate(true);bad.version=version
		check(not Save.restore(bad).ok,"old version cannot claim new policy");rejected+=1
func test_matches()->void:
	for seed_value in [1811,1823]:
		var g=Game.new()
		check(g.setup(["A","B","C","D"],seed_value,30,{"map_id":"knight_manor","shop_policy":"r18_samples","npcs_enabled":true,"specials_enabled":true,"gods_enabled":true,"talents_enabled":true,"characters":["tangtang","shalong","qian","nintaro"],"economy":{"initial_cash":30000,"initial_deposit":10000,"inflation_interval":5}}),"natural setup")
		var actions:int=0
		while g.phase!="finished" and actions<25000:
			actions+=1
			if not AI.step(g):check(false,"natural match stalled "+g.phase);break
			if g.phase=="shop" or actions%101==0:
				var peer=roundtrip(g)
				if peer==null:break
				g=peer
		check(g.phase=="finished" and not g.winners.is_empty(),"natural priced match ends")
		if g.phase=="finished":matches+=1
func _init()->void:
	test_quotes();test_purchase_ai();test_legacy();test_validation();test_matches()
	print("ROUND18_SHOP failures=",failures," rejected=",rejected," completed_matches=",matches)
	quit(1 if failures else 0)
