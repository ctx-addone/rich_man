extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const FIXTURE="res://tests/fixtures/round15-v6-economy.rms"
const FIXTURE_SHA="4F155D07A471E4D640B951DCDBCA7A663FF939019A0E634938D916CE21E8EF7E"
var failures:=0
var rejected:=0
var matches:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func config(interval:int=5)->Dictionary:
	return {"initial_cash":10000,"initial_deposit":0,"inflation_interval":interval}
func fresh(interval:int=5,seed_value:int=1616):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],seed_value,30,{"map_id":"knight_manor","specials_enabled":true,"teams":[0,1,0,1],"economy":config(interval)}),"new economy setup")
	for p in g.players:p.cards.clear()
	return g
func road(g,kind:String)->int:
	for node in g.nodes:
		if node.kind==kind:return node.id
	return -1
func enter(g,kind:String,game_id:String="")->bool:
	g.players[g.current].pos=road(g,kind);g.phase="land"
	return g.News.enter(g) if kind=="news" else g.Minigame.enter(g,game_id)
func reject_save(payload:Dictionary,label:String)->void:
	check(not Save.restore(payload).ok,label);rejected+=1
func finish_activity(g)->void:
	for action in range(1000):
		if g.pending_service.game.status=="result":return
		if not g.Minigame.ai_step(g):check(false,"minigame command advances");return
	check(false,"minigame reaches result within bound")
func test_setup()->void:
	var a=Game.new();var b=Game.new()
	check(a.setup(["A","B"],1601,30),"legacy three-argument setup")
	var legacy=config(0);legacy.policy="legacy_v6"
	check(b.setup(["A","B"],1601,30,{"economy":legacy}),"explicit neutral legacy setup")
	check(Save.snapshot(a)==Save.snapshot(b),"omitted economy matches explicit legacy exactly")
	var resources={"initial_cash":12345,"initial_deposit":67890,"inflation_interval":5}
	check(a.setup(["A","B"],1602,30,{"economy":resources}),"custom starting balances")
	for p in a.players:check(p.cash==12345 and p.deposit==67890,"all seats receive custom balances")
	check(a.economy_config.policy=="r16_samples","explicit economy defaults to sample policy")
	resources.initial_cash=9
	check(a.economy_config.initial_cash==12345,"setup owns a copy of external config")
	var before:Dictionary=Save.snapshot(a)
	for pair in [["initial_cash",-1],["initial_cash",500001],["initial_cash",true],["initial_cash",1.0],["initial_deposit",-1],["initial_deposit",500001],["initial_deposit","100"],["inflation_interval",-1],["inflation_interval",366],["inflation_interval",true],["inflation_interval",2.0],["policy","unknown"],["policy",null],["policy","legacy_v6"],["extra",0]]:
		var bad=config();bad[pair[0]]=pair[1]
		check(not a.setup(["New","Names"],9191,2,{"economy":bad}),"invalid config rejected: "+str(pair))
		check(Save.snapshot(a)==before,"failed setup is atomic including both RNGs")
		rejected+=1
	for bad in [null,[],"bad",true]:
		check(not a.setup(["A","B"],1,3,{"economy":bad}) and Save.snapshot(a)==before,"non-dictionary economy rejected atomically");rejected+=1
	for days in [1000000001,9223372036854775807]:
		check(not a.setup(["A","B"],1,days,{"economy":config()}) and Save.snapshot(a)==before,"oversized duration rejected atomically without touching RNG");rejected+=1
	check(a.setup(["A","B"],1601,30) and a.players[0].cash==10000 and a.players[0].deposit==0 and a.economy_config.policy=="legacy_v6","next setup resets balances and policy")
	for balances in [[0,0],[500000,500000]]:
		check(a.setup(["A","B"],1610,20,{"economy":{"initial_cash":balances[0],"initial_deposit":balances[1],"inflation_interval":365}}),"inclusive resource/interval bounds accepted")
	check(a.setup(["A","B"],1610,20,{"economy":{}}) and a.economy_config=={"initial_cash":10000,"initial_deposit":0,"inflation_interval":0,"policy":"r16_samples"},"empty explicit economy uses sample policy and default resources")
func test_prices()->void:
	var g=fresh()
	for pair in [[1,1],[5,1],[6,2],[10,2],[11,3],[30,6],[31,6]]:
		g.round_number=pair[0];check(g.price_index()==pair[1],"day boundary and final-day clamp: "+str(pair))
	g=fresh(0);g.round_number=999;check(g.price_index()==1,"disabled inflation stays neutral")
	g=fresh();g.round_number=5
	for who in range(3):
		g.phase="end";check(g.end_turn(),"same-day seat advances")
		check(g.round_number==5 and g.price_index()==1,"seat changes do not count as days")
	g.phase="end";check(g.end_turn() and g.round_number==6 and g.price_index()==2,"full round advances price once")
	g=fresh();var lot:Dictionary=g.lots.p_001
	lot.owner=1;lot.building_type="house";lot.level=2
	g.Shop.enter(g)
	var quotes:Array=[g.purchase_cost(lot.id),g.upgrade_cost(lot.id),g.rebuild_cost(lot.id,"house"),g.research_cost(lot.id),g.lot_value(lot.id),g.shop_offers()]
	var static_lots:Dictionary=g.lots.duplicate(true);var static_nodes:Array=g.nodes.duplicate(true)
	var base:int=g.rent_preview(lot.id,0)
	g.round_number=11
	check(g.rent_preview(lot.id,0)==base*3 and g.rent_preview(lot.id,3)==0,"rent scales once and allied rent stays zero")
	check([g.purchase_cost(lot.id),g.upgrade_cost(lot.id),g.rebuild_cost(lot.id,"house"),g.research_cost(lot.id),g.lot_value(lot.id),g.shop_offers()]==quotes,"purchase/construction/research/shop/valuation are not blanket-scaled")
	check(g.lots==static_lots and g.nodes==static_nodes,"pricing leaves map amounts unchanged")
	var payer_before:int=g.players[0].cash;var owner_before:int=g.players[1].cash
	check(g.gm_teleport(0,int(lot.frontage_nodes[0])),"ordinary rent landing")
	check(g.players[0].cash==payer_before-base*3 and g.players[1].cash==owner_before+base*3,"actual rent pays quoted amount exactly once")
	lot.closed_until=20;check(g.rent_preview(lot.id,0)==0,"closed property remains free")
	lot.closed_until=0;g.players[1].status={"kind":"sleepwalk"};check(g.rent_preview(lot.id,0)==0,"sleepwalking owner remains unable to collect")
func test_news()->void:
	var g=fresh();g.round_number=11
	check(enter(g,"news"),"news opens at price3")
	g.pending_service.event_id="house_subsidy"
	check(g.pending_service.pricing=={"day":11,"price":3,"other_divisor":3},"news captures exact pricing context")
	var before:Dictionary=Save.snapshot(g)
	g.News.current(g);g.News.current(g)
	check(Save.snapshot(g)==before,"news display cannot pay or consume RNG")
	var loaded:Dictionary=Save.restore(before);check(loaded.ok,"pending subsidy roundtrip")
	if loaded.ok:
		check(g.News.resolve(g) and loaded.game.News.resolve(loaded.game),"subsidy resolves on original/restored")
		check(g.players[0].cash==25000 and g.players[1].cash==10000,"subsidy applies5000 times3 to actor only")
		check(Save.snapshot(g)==Save.snapshot(loaded.game),"subsidy resumed state/RNG identical")
		check(not g.News.resolve(g) and g.players[0].cash==25000,"subsidy cannot repeat")
	for pair in [["price",2],["day",12],["other_divisor",2],["price",3.0],["day",true],["extra",0]]:
		var bad:Dictionary=before.duplicate(true);bad.state.pending_service.pricing[pair[0]]=pair[1];reject_save(bad,"invalid frozen news pricing "+str(pair))
func test_minigames()->void:
	for game_id in Game.Minigame.TEST_POOL:
		var g=fresh(5,1621);g.round_number=6
		check(enter(g,"minigame",game_id),"explicit game starts: "+game_id)
		check(g.pending_service.pricing=={"day":6,"price":2,"other_divisor":3},"minigame captures service pricing")
		check(g.Minigame.start(g),"game starts playing")
		for tick in range(3):check(g.Minigame.ai_step(g),"sample game advances")
		var before:Dictionary=Save.snapshot(g);var loaded:Dictionary=Save.restore(before)
		check(loaded.ok,"playing new-economy minigame restores: "+game_id)
		if not loaded.ok:continue
		for action in range(1000):
			if g.pending_service.game.status=="result":break
			check(g.Minigame.ai_step(g) and loaded.game.Minigame.ai_step(loaded.game),"restored game advances")
			check(Save.snapshot(g)==Save.snapshot(loaded.game),"each resumed action preserves exact state and RNG")
		check(g.pending_service.game.status=="result","all seats finish: "+game_id)
		var history:Array=g.pending_service.game.history.duplicate(true)
		var awards:Dictionary={}
		for record in history:
			check(record.reward==record.score,"internal v1 reward retains base score")
			var expected:int=record.score*2 if record.player==g.current else int(record.score*2/3)
			check(g.Minigame.cash_reward(g,record)==expected,"actual cash uses trigger or background divisor")
			awards[record.player]=expected
			check(g.players[record.player].cash==10000,"no payout before result acceptance")
		before=Save.snapshot(g);loaded=Save.restore(before)
		check(loaded.ok and Save.snapshot(loaded.game)==before,"result preserves pricing and base histories")
		check(g.Minigame.close(g),"one result claim")
		for who in awards:check(g.players[who].cash==10000+awards[who],"%s seat%d actual=%d expected=%d"%[game_id,who,g.players[who].cash,10000+awards[who]])
		check(not g.Minigame.close(g),"repeat result claim rejected")
		if loaded.ok:
			check(loaded.game.Minigame.close(loaded.game) and Save.snapshot(loaded.game)==Save.snapshot(g),"restored result claim matches original")
	# The trigger need not be seat zero, and disabling inflation does not disable
	# the explicitly chosen sample payout policy for background seats.
	var g=fresh(0);g.current=2
	check(enter(g,"minigame","disarm_bomb"),"nonzero triggering seat enters")
	finish_activity(g)
	var history:Array=g.pending_service.game.history.duplicate(true)
	for record in history:
		check(g.Minigame.cash_reward(g,record)==(record.score if record.player==2 else int(record.score/3)),"price1 keeps new-policy background divisor and correct trigger identity")
	var before:Dictionary=Save.snapshot(g)
	for key in ["pricing"]:
		var bad:Dictionary=before.duplicate(true);bad.state.pending_service.erase(key);reject_save(bad,"sample minigame cannot omit frozen pricing")
	var bad:Dictionary=before.duplicate(true);bad.state.economy_config.policy="legacy_v6"
	reject_save(bad,"legacy strategy cannot retain new-service pricing")
func test_save_config()->void:
	var g=fresh();var before:Dictionary=Save.snapshot(g)
	var bad:Dictionary=before.duplicate(true);bad.state.erase("economy_config")
	reject_save(bad,"new save requires economy config")
	for pair in [["inflation_interval",true],["inflation_interval",366],["policy","bad"],["initial_cash",500001],["extra",0]]:
		bad=before.duplicate(true);bad.state.economy_config[pair[0]]=pair[1];reject_save(bad,"stored invalid economy rejected "+str(pair))
	bad=before.duplicate(true);bad.version=6
	reject_save(bad,"new active economy cannot masquerade as legacy v6")
	bad=before.duplicate(true);bad.state.pending_service={"pricing":{"day":1,"price":1,"other_divisor":3}}
	reject_save(bad,"non-service phase cannot carry frozen pricing")
	bad=before.duplicate(true);bad.state.round_limit=1;bad.state.round_number=2
	reject_save(bad,"finite active game cannot outlive its final day")
	for pair in [["round_number",1000000002],["round_number",9223372036854775807],["round_limit",1000000001],["round_limit",9223372036854775807]]:
		bad=before.duplicate(true);bad.state.round_limit=0;bad.state[pair[0]]=pair[1]
		reject_save(bad,"serialization arithmetic safety rejects extreme calendar value "+str(pair))
func test_transferred_rent()->void:
	var g=fresh();g.round_number=11
	var lot:Dictionary=g.lots.p_001;lot.owner=1;lot.building_type="house";lot.level=5
	g.players[0].cards=["transfer"];g.players[3].cards=["free"]
	var quoted:int=g.rent_preview(lot.id,0)
	check(quoted==3300 and g.gm_teleport(0,int(lot.frontage_nodes[0])) and g.phase=="reaction","price3 rent pauses for transfer")
	check(g.pending_attack.amount==quoted and g.resolve_reaction("transfer",3),"frozen debt transferred without repricing")
	check(g.phase=="reaction" and g.reaction_player()==3 and g.pending_attack.amount==quoted,"new payer can react to original amount")
	var before:Dictionary=Save.snapshot(g);var loaded:Dictionary=Save.restore(before)
	check(loaded.ok,"transferred inflated bill restores")
	check(g.resolve_reaction(""),"transferee accepts debt")
	check(g.players[0].cash==10000 and g.players[1].cash==13300 and g.players[3].cash==6700,"transfer pays3300 rather than9900 and preserves original receiver")
	if loaded.ok:
		check(loaded.game.resolve_reaction("") and Save.snapshot(g)==Save.snapshot(loaded.game),"restored transfer settles identically without double inflation")
	check(not g.resolve_reaction("") and g.players[3].cash==6700,"completed debt cannot repeat")
func test_day_edges()->void:
	var g=fresh();g.round_number=5;g.current=2
	check(g.send_to_facility(3,"hospital",2),"last seat hospitalized")
	g.phase="end";check(g.end_turn() and g.current==3 and g.phase=="detained" and g.price_index()==1,"hospitalized last seat remains in same day")
	check(g.end_turn() and g.current==0 and g.round_number==6 and g.price_index()==2,"detention completes day and inflation occurs once")
	g=fresh();g.round_number=5;g.current=3;g.players[3].cash=0
	check(g.Money.begin(g,3,1000,0,"test_debt"),"last seat incurs unpaid debt")
	g.Combat.advance(g)
	check(g.players[3].bankrupt and g.phase=="end","last seat actually goes bankrupt")
	check(g.end_turn() and g.current==0 and g.round_number==6 and g.price_index()==2,"bankrupt last seat crosses date once")
	g=fresh();g.round_number=5;g.round_limit=5;g.current=3;g.phase="end"
	check(g.end_turn() and g.phase=="finished" and g.round_number==6 and g.price_index()==1,"terminal sentinel does not trigger next-day price2")
	var loaded:Dictionary=Save.restore(Save.snapshot(g))
	check(loaded.ok and loaded.game.price_index()==1,"finished-day price cap survives save")
	var bad:Dictionary=Save.snapshot(g);bad.state.round_number=7
	reject_save(bad,"finite finished game cannot exceed final-day sentinel")
func test_legacy()->void:
	check(FileAccess.get_sha256(FIXTURE).to_upper()==FIXTURE_SHA,"authentic frozen v6 fixture SHA")
	var file=FileAccess.open(FIXTURE,FileAccess.READ);file.seek(44)
	var old:Dictionary=bytes_to_var(file.get_buffer(file.get_length()-44));file.close()
	check(old.version==6 and old.state.pending_service.game.cursor==1,"fixture contains genuine prior-version active background seat")
	var loaded:Dictionary=Save.load_from_file(FIXTURE);check(loaded.ok,"real v6 restores")
	if not loaded.ok:return
	var g=loaded.game;var now:Dictionary=Save.snapshot(g,old.metadata)
	check(g.economy_config=={"initial_cash":10000,"initial_deposit":0,"inflation_interval":0,"policy":"legacy_v6"},"legacy migration adds only neutral economic config")
	now.state.erase("economy_config");now.version=old.version
	for key in ["npcs_enabled","road_npcs","npc_respawn_due","npc_seen","shop_policy"]: now.state.erase(key)
	check(now==old,"all original fields, metadata, history and both RNGs unchanged")
	check(not g.pending_service.has("pricing") and g.price_index()==1,"legacy service gains no pricing schema")
	check(g.purchase_cost("p_001")==2400 and g.upgrade_cost("p_001")==600 and g.rent_preview("p_001",1)==440,"legacy economic quotes preserved")
	var original_cash:Array=[]
	for p in g.players:original_cash.append(p.cash)
	finish_activity(g)
	var history:Array=g.pending_service.game.history.duplicate(true)
	for record in history:check(g.Minigame.cash_reward(g,record)==record.reward,"legacy all-seat award stays1:1")
	check(g.Minigame.close(g),"legacy pending minigame settles")
	for record in history:check(g.players[record.player].cash==original_cash[record.player]+record.reward,"legacy actual payment unchanged")
func test_matches()->void:
	for seed_value in [1609,1619]:
		var g=Game.new()
		check(g.setup(["A","B","C","D"],seed_value,12,{"map_id":"knight_manor","specials_enabled":true,"economy":{"initial_cash":17000,"initial_deposit":4000,"inflation_interval":2}}),"inflation match setup")
		for action in range(20000):
			if g.phase=="finished":break
			if not AI.step(g):check(false,"inflation match stalls at "+g.phase);break
		check(g.phase=="finished" and not g.winners.is_empty(),"inflation game reaches winner normally")
		if g.phase=="finished":matches+=1
func test_unlimited()->void:
	var g=Game.new()
	check(g.setup(["A","B","C","D"],1630,0,{"map_id":"knight_manor","specials_enabled":true,"gods_enabled":true,"teams":[0,1,0,1],"economy":config()}),"unlimited match setup")
	check(g.round_limit==0,"zero rounds remains explicit unlimited")
	var missing_god:String=g.road_gods.values()[0]
	g.road_gods.erase(g.road_gods.keys()[0])
	for turn in range(140):
		g.phase="end"
		check(g.end_turn(),"unlimited day-cycle advances")
		if g.phase=="finished":check(false,"unlimited match must not stop at legacy day cap");return
	check(g.round_number==36 and g.price_index()==8,"unlimited day36 continues inflation beyond30")
	check(g.stock_market.market_round==36,"market continues advancing in unlimited game")
	check(g.lottery_state.draw_count==2 and g.lottery_state.last_draw.round==31 and g.lottery_state.draw_round==46,"unlimited lottery cycles continue beyond30")
	check(g.road_gods.values().has(missing_god),"unlimited god respawn cycle remains active")
	var before:Dictionary=Save.snapshot(g);var loaded:Dictionary=Save.restore(before)
	check(loaded.ok and Save.snapshot(loaded.game)==before,"unlimited state and both RNGs restore exactly")
	if loaded.ok:
		for turn in range(4):
			g.phase="end";loaded.game.phase="end"
			check(g.end_turn() and loaded.game.end_turn() and Save.snapshot(g)==Save.snapshot(loaded.game),"unlimited resumed next day is deterministic")
	# Unlimited removes the time limit, not the last-surviving-team condition.
	for who in [1,3]:
		g.players[who].cash=0;g.players[who].deposit=0;g.players[who].cards.clear()
		check(g.Money.begin(g,who,1000,0,"test_debt"),"unlimited opponent incurs unpaid bill")
		g.Combat.advance(g)
	check(g.phase=="finished" and g.winners==[0,2],"unlimited last surviving team still wins")
	loaded=Save.restore(Save.snapshot(g))
	check(loaded.ok and loaded.game.winners==[0,2],"finished unlimited match restores")
	var legacy=Game.new();legacy.setup(["A","B"],1640,20)
	for version in [1,2,3,4,5,6]:
		var bad:Dictionary=Save.snapshot(legacy);bad.version=version;bad.state.round_limit=0
		reject_save(bad,"legacy schema cannot claim unsupported unlimited period v%d"%version)
	check(legacy.setup(["A","B"],1640,-1) and legacy.round_limit==1,"negative setup rounds preserve historical clamp1")
func _init()->void:
	test_setup();test_prices();test_news();test_minigames();test_save_config();test_transferred_rent();test_day_edges();test_legacy();test_matches();test_unlimited()
	print("ROUND16_ECONOMY failures=",failures," rejected=",rejected," completed_matches=",matches)
	quit(1 if failures else 0)
