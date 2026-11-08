extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Save=preload("res://scripts/model/save_game.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
const FIXTURE="res://tests/fixtures/round16-v7-priced-service.rms"
const SHA="48AA4EB9A113A04C6E432E1BB0D65A13855EDBD874195441215EC27F2CC19B5A"
var failures:=0
var rejected:=0
var matches:=0
var restores:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func fresh(seed_value:int=1717):
	var g=Game.new()
	check(g.setup(["A","B","C","D"],seed_value,40,{"npcs_enabled":true,"specials_enabled":true,"talents_enabled":true,"teams":[0,1,0,1]}),"NPC setup")
	g.road_npcs.clear();g.npc_respawn_due.clear()
	for p in g.players:p.cards.clear()
	return g
func road(g,kind:String)->int:
	for node in g.nodes:
		if node.kind==kind:return node.id
	for lot in g.lots.values():
		if lot.building_type==kind:return int(lot.frontage_nodes[0])
	return -1
func plain(g)->int:
	for node in g.nodes:
		if node.kind=="road" and g.lots_at_node(node.id).is_empty() and node.neighbors.size()==2:return node.id
	return 4
func approach(g,target:int,steps:int=1)->void:
	g.players[g.current].pos=g.nodes[target].neighbors[0]
	g.players[g.current].previous=-1;g.players[g.current].choose_junction=true
	g.phase="roll"
	check(g.roll_dice(steps) and g.available_moves().has(target),"target is reachable ordinary step")
	check(g.move_to(target),"ordinary arrival executes")
func roundtrip(g,label:String):
	var before:Dictionary=Save.snapshot(g)
	var loaded:Dictionary=Save.restore(before)
	check(loaded.ok,"save restores "+label+": "+str(loaded.get("error","")))
	if not loaded.ok:return null
	restores+=1
	check(Save.snapshot(loaded.game)==before,"save preserves state/RNG "+label)
	return loaded.game
func reject(payload:Dictionary,label:String)->void:
	check(not Save.restore(payload).ok,"reject "+label);rejected+=1
func test_setup_legacy()->void:
	var a=Game.new();var b=Game.new()
	a.setup(["A","B"],1701,20);b.setup(["A","B"],1701,20,{"npcs_enabled":false})
	check(Save.snapshot(a)==Save.snapshot(b),"default NPC off preserves prior setup and RNG")
	var before:Dictionary=Save.snapshot(a)
	for bad in [1,"yes",null]:
		check(not a.setup(["X","Y"],1,2,{"npcs_enabled":bad}) and Save.snapshot(a)==before,"invalid NPC switch atomic")
	a.setup(["A","B"],1701,20,{"npcs_enabled":true});b.setup(["A","B"],1701,20,{"npcs_enabled":true})
	check(a.road_npcs==b.road_npcs and a.rng.state==b.rng.state,"seeded NPC population deterministic")
	check(a.road_npcs.size()==2 and a.road_npcs.has("dog") and a.road_npcs.has("merchant"),"initial population has no unrelated beggar")
	for npc in a.road_npcs.values():
		check(npc.road!=a.start_road and a.NPC.at(a,npc.road).size()==1,"initial population unique and excludes start")
	check(FileAccess.get_sha256(FIXTURE).to_upper()==SHA,"genuine v7 fixture unchanged")
	var f=FileAccess.open(FIXTURE,FileAccess.READ);f.seek(44)
	var old:Dictionary=bytes_to_var(f.get_buffer(f.get_length()-44));f.close()
	check(old.version==7,"fixture encoded version7")
	var loaded:Dictionary=Save.load_from_file(FIXTURE);check(loaded.ok,"real v7 fixture migrates")
	if loaded.ok:
		var now:Dictionary=Save.snapshot(loaded.game,old.metadata)
		check(not now.state.npcs_enabled and now.state.road_npcs.is_empty() and now.state.npc_respawn_due.is_empty() and now.state.npc_seen.is_empty(),"migration adds exactly neutral NPC values")
		for key in ["npcs_enabled","road_npcs","npc_respawn_due","npc_seen","shop_policy"]:now.state.erase(key)
		now.version=7
		check(now==old,"v7 every old field and both RNGs preserved")
		var peer=roundtrip(loaded.game,"migrated priced service")
		if peer!=null:
			for action in range(250):
				if loaded.game.phase=="finished":break
				check(AI.step(loaded.game)==AI.step(peer) and Save.snapshot(loaded.game)==Save.snapshot(peer),"legacy service continues deterministically")
func test_dog()->void:
	var g=fresh();var target:int=plain(g)
	check(g.NPC.gm_place(g,"dog",target),"place dog")
	approach(g,target,3)
	check(g.phase=="end" and g.players[0].status.kind=="hospital" and g.players[0].status.remaining==2 and g.steps_left==0,"passing dog interrupts remaining movement with TEST detention")
	check(not g.road_npcs.has("dog") and g.npc_respawn_due.dog==4,"dog encounter schedules TEST cooldown")
	roundtrip(g,"dog hospitalization")
	for vehicle in ["motorbike","car"]:
		g=fresh();target=plain(g);g.gm_vehicle(0,vehicle);g.NPC.gm_place(g,"dog",target)
		approach(g,target,3)
		check(g.phase=="move" and g.steps_left==2 and g.players[0].status.is_empty() and g.players[0].vehicle==vehicle and not g.road_npcs.has("dog"),"vehicle prevents dog and retains remaining movement "+vehicle)
	for talents in [false,true]:
		g=fresh();target=plain(g);g.talents_enabled=talents;g.players[0].character_id="qian";g.NPC.gm_place(g,"dog",target)
		approach(g,target,2)
		check(g.players[0].status.is_empty()==talents and g.road_npcs.has("dog")==talents,"money lady immunity respects talent toggle")
	for response in ["immune","transfer"]:
		g=fresh();target=plain(g);g.players[0].cards=[response];g.NPC.gm_place(g,"dog",target)
		approach(g,target,3)
		check(g.phase=="reaction" and g.pending_attack.source=="dog" and g.steps_left==2,"dog opens response before losing movement")
		var peer=roundtrip(g,"dog "+response+" pending")
		check(not g.NPC.gm_place(g,"dog",target) and not g.NPC.gm_remove(g,"dog"),"GM cannot alter pending response")
		var recipient:int=1 if response=="transfer" else -1
		check(g.resolve_reaction(response,recipient),"resolve dog "+response)
		if peer!=null:check(peer.resolve_reaction(response,recipient) and Save.snapshot(g)==Save.snapshot(peer),"restored dog reaction resumes exactly")
		check(g.phase=="move" and g.steps_left==2 and g.players[0].status.is_empty() and g.npc_seen==["dog"],"dog response resumes without retrigger")
		if response=="transfer":check(g.players[1].status.kind=="hospital","dog transfer affects chosen player")
		check(not g.NPC.encounter(g,true),"same arrival dog cannot repeat")
func test_merchant_and_order()->void:
	var g=fresh();var target:int=plain(g);g.NPC.gm_place(g,"merchant",target)
	approach(g,target,2)
	check(g.phase=="move" and g.pending_service.is_empty() and g.npc_seen.is_empty(),"merchant does not open on passing")
	g=fresh();target=plain(g);g.NPC.gm_place(g,"merchant",target)
	approach(g,target)
	check(g.phase=="merchant" and g.NPC.offers(g).size()==6 and g.pending_service.return_phase=="move","merchant opens on final ordinary step")
	var before:Dictionary=Save.snapshot(g)
	g.NPC.offers(g);g.NPC.remaining(g);check(Save.snapshot(g)==before,"merchant queries do not consume RNG or change state")
	check(g.NPC.buy(g,"dice") and not g.NPC.buy(g,"dice") and g.NPC.buy(g,"stay") and not g.NPC.buy(g,"roadblock"),"merchant distinct stock and total two limit")
	check(g.players[0].cash==8000 and g.players[0].cards==["dice","stay"],"merchant exact charge and inventory")
	var peer=roundtrip(g,"merchant two purchased")
	check(g.NPC.close(g) and not g.NPC.close(g),"merchant closes once")
	if peer!=null:check(peer.NPC.close(peer) and Save.snapshot(g)==Save.snapshot(peer),"merchant resumes identical landing")
	check(not g.road_npcs.has("merchant") and g.npc_respawn_due.merchant==4 and g.phase=="land","merchant closes into map loop and schedules cooldown")
	for kind in ["bank","lottery","shop"]:
		g=fresh();target=road(g,kind);check(target>=0,"service road exists "+kind)
		g.NPC.gm_place(g,"dog",target);g.NPC.gm_place(g,"merchant",target);g.players[0].cards=["immune"]
		approach(g,target)
		check(g.phase=="reaction","dog precedes merchant and "+kind)
		check(g.resolve_reaction("immune") and g.phase=="merchant","dog response advances to colocated merchant")
		roundtrip(g,"merchant sharing "+kind)
		check(g.NPC.close(g) and g.phase==kind,"merchant leaves into "+kind)
		if kind=="bank":g.close_bank()
		elif kind=="lottery":g.close_lottery()
		else:g.close_shop()
		check(g.phase==("end" if kind=="shop" else "land") and g.npc_seen.size()==2,"service final landing cannot replay NPC effects "+kind)
		roundtrip(g,"after shared "+kind)
	g=fresh();var lot:Dictionary={}
	for candidate in g.lots.values():
		if candidate.kind=="small":lot=candidate;break
	target=int(lot.frontage_nodes[0]);lot.owner=1;lot.building_type="house";lot.level=1
	var rent:int=g.rent_preview(lot.id,0);g.NPC.gm_place(g,"merchant",target)
	approach(g,target)
	check(g.phase=="merchant" and g.players[0].cash==10000,"merchant precedes property bill")
	g.NPC.close(g)
	check(g.players[0].cash==10000-rent and g.players[1].cash==10000+rent,"property bill continues exactly once after merchant")
func test_beggar()->void:
	var g=fresh();var target:int=plain(g)
	check(not g.NPC.gm_place(g,"beggar",target,2),"living player cannot be beggar owner")
	g.players[2].cash=0;g.players[2].pos=target;g._pay(2,1)
	check(g.players[2].bankrupt and g.road_npcs.has("beggar:2") and g.road_npcs["beggar:2"].owner==2,"debt bankruptcy creates own NPC")
	approach(g,target,3)
	check(g.players[0].cash==5000 and g.players[2].cash==0 and g.phase=="move" and g.steps_left==2,"same-team beggar charges once, owner remains bankrupt")
	check(not g.NPC.encounter(g,true) and g.players[0].cash==5000,"beggar same-arrival reentry cannot double-charge")
	roundtrip(g,"beggar paid during movement")
	for response in ["free","transfer"]:
		g=fresh();target=plain(g);g.players[2].cash=0;g.players[2].pos=target;g._pay(2,1)
		g.players[0].cards=[response];approach(g,target,2)
		check(g.phase=="reaction" and g.pending_attack.amount==5000,"beggar provisional money reaction")
		var peer=roundtrip(g,"beggar pending "+response);var recipient:int=1 if response=="transfer" else -1
		g.resolve_reaction(response,recipient)
		if peer!=null:check(peer.resolve_reaction(response,recipient) and Save.snapshot(peer)==Save.snapshot(g),"beggar response deterministic")
		check(g.players[0].cash==10000 and g.phase=="move" and g.steps_left==1,"beggar response preserves original payer and movement")
		if response=="transfer":check(g.players[1].cash==5000,"transferred beggar bill charged only once")
	g=fresh();target=plain(g);g.players[0].character_id="qian";g.players[2].cash=0;g.players[2].pos=target;g._pay(2,1)
	approach(g,target,2);check(g.players[0].cash==10000 and g.phase=="move","qian immune to beggar")
	g=fresh();target=plain(g);g.players[2].cash=0;g.players[2].pos=target;g._pay(2,1);g.players[0].cash=100
	approach(g,target,2)
	check(g.phase=="finished" and g.winners==[1,3] and g.players[0].bankrupt and g.pending_attack.is_empty() and g.pending_service.is_empty(),"beggar debt final team bankruptcy finishes immediately")
	check(g.road_npcs.has("beggar:0") and not g.NPC.encounter(g,true),"newly bankrupt identity cannot act after final victory")
	roundtrip(g,"finished after beggar bankruptcy")
func test_day_and_gm()->void:
	var g=fresh();var target:int=plain(g)
	g.NPC.gm_place(g,"dog",target);g.NPC.gm_place(g,"merchant",target)
	var peer=roundtrip(g,"colocated NPCs")
	for day in range(1,4):
		var prior:int=g.road_npcs.dog.road
		for seat in range(4):
			g.phase="end";peer.phase="end";g.end_turn();peer.end_turn()
			if seat<3:check(g.road_npcs.dog.road==prior,"NPC only moves at day boundary")
		check(g.nodes[prior].neighbors.has(g.road_npcs.dog.road) and g.road_npcs.merchant.road==target,"dog takes one neighboring step; merchant stationary")
		check(Save.snapshot(g)==Save.snapshot(peer),"day NPC movement deterministic after load")
	check(g.NPC.gm_remove(g,"dog") and not g.NPC.gm_remove(g,"dog"),"GM remove once")
	var due:int=g.npc_respawn_due.dog
	g.round_number=due-1;g.NPC.advance_day(g);check(not g.road_npcs.has("dog"),"cooldown not early")
	g.round_number=due;g.NPC.advance_day(g);check(g.road_npcs.has("dog") and not g.npc_respawn_due.has("dog"),"cooldown restores population once due")
	for command in ["hospital","prison","teleport","fierce","finish"]:
		g=fresh();target=plain(g);g.NPC.gm_place(g,"merchant",target);approach(g,target)
		match command:
			"hospital","prison":g.send_to_facility(0,command,2)
			"teleport":g.gm_teleport(0,g.nodes[target].neighbors[0])
			"fierce":g.gm_god(0,"fierce")
			"finish":g.finish_game()
		check(g.pending_service.is_empty() and g.phase!="merchant" and g.players[0].cash==10000,"GM interrupts merchant without reward "+command)
		roundtrip(g,"merchant interruption "+command)
func test_transferred_immunity()->void:
	# Selecting an immune transfer target is the project's TEST policy; original
	# NPC-specific transfer targeting and ordering remain unverified.
	for source in ["dog","beggar"]:
		for protection in ["qian","motorbike","car"]:
			var g=fresh();var target:int=plain(g)
			if source=="beggar":
				g.players[2].cash=0;g.players[2].pos=target;g._pay(2,1)
			else:g.NPC.gm_place(g,"dog",target)
			if protection=="qian":g.players[1].character_id="qian"
			else:g.gm_vehicle(1,protection)
			g.players[0].cards=["transfer"];g.players[1].cards=["immune","free"]
			approach(g,target,2)
			check(g.phase=="reaction" and g.reaction_targets("transfer").has(1),"NPC transfer can select protected target under TEST policy")
			var peer=roundtrip(g,"transfer to "+protection+" "+source)
			g.resolve_reaction("transfer",1)
			if peer!=null:check(peer.resolve_reaction("transfer",1) and Save.snapshot(g)==Save.snapshot(peer),"protected target restored transfer identical")
			var protected:bool=source=="dog" or protection=="qian"
			if protected:
				check(g.phase=="move" and g.players[1].status.is_empty() and g.players[1].cash==10000 and g.players[1].cards==["immune","free"],"automatic target immunity avoids extra card consumption")
			else:
				check(g.phase=="reaction" and g.reaction_player()==1,"vehicle does not protect against transferred beggar bill")
				g.resolve_reaction();check(g.players[1].cash==5000,"unprotected recipient pays beggar")
			check(g.players[0].cash==10000 and g.steps_left==1,"original mover resumes once")
func test_merchant_limits()->void:
	var g=fresh();var target:int=plain(g)
	g.NPC.gm_place(g,"merchant",target);approach(g,target)
	g.players[0].cash=999
	check(not g.NPC.buy(g,"dice") and g.players[0].cash==999 and g.pending_service.purchases==0,"insufficient cash does not consume stock or quota")
	g.players[0].cash=1000
	check(g.NPC.buy(g,"dice") and g.players[0].cash==0,"exact-price cash purchase succeeds")
	g=fresh();target=plain(g);g.NPC.gm_place(g,"merchant",target)
	for ignored in range(g.HAND_LIMIT):g.give_card(0,"dice")
	approach(g,target);check(not g.NPC.buy(g,"stay") and g.pending_service.purchases==0 and g.players[0].cash==10000,"full hand cannot buy or lose cash")
	check(g.discard_card(0) and g.NPC.buy(g,"stay"),"discard in merchant frees real hand slot")
	# Direct landing has a different continuation contract from an ordinary
	# movement arrival; both must survive saves without opening twice.
	g=fresh();target=plain(g);g.NPC.gm_place(g,"merchant",target);g.gm_teleport(0,target)
	check(g.phase=="merchant" and g.pending_service.return_phase=="land" and g.landing_pending,"direct landing records pending landing")
	var peer=roundtrip(g,"direct land merchant")
	check(g.NPC.close(g) and g.phase=="land" and not g.landing_pending,"direct landing closes all pending effects")
	if peer!=null:check(peer.NPC.close(peer) and Save.snapshot(g)==Save.snapshot(peer),"direct landing resumes identically")
func test_strict_save()->void:
	var g=fresh();var target:int=plain(g);g.NPC.gm_place(g,"merchant",target);approach(g,target)
	var base:Dictionary=Save.snapshot(g)
	for pair in [["npcs_enabled",false],["npc_seen",[]],["npc_seen",["merchant","merchant"]],["npc_seen",["unknown"]],["npc_respawn_due",{"merchant":4}],["npc_respawn_due",{"dog":true}],["npc_respawn_due",{"beggar":4}]]:
		var bad:Dictionary=base.duplicate(true);bad.state[pair[0]]=pair[1];reject(bad,str(pair))
	for pair in [["road",-1],["road",true],["owner",0],["owner",1.0],["kind","dog"],["extra",0]]:
		var bad:Dictionary=base.duplicate(true);bad.state.road_npcs.merchant[pair[0]]=pair[1];reject(bad,"npc "+str(pair))
	for pair in [["purchases",3],["purchases",true],["bought",["dice"]],["bought",["dice","dice"]],["npc_id","dog"],["road",target+1],["return_phase","land"],["extra",0]]:
		var bad:Dictionary=base.duplicate(true);bad.state.pending_service[pair[0]]=pair[1];reject(bad,"merchant "+str(pair))
	for key in ["npcs_enabled","road_npcs","npc_respawn_due","npc_seen","shop_policy"]:
		var bad:Dictionary=base.duplicate(true);bad.state.erase(key);reject(bad,"missing v8 "+key)
	var bad:Dictionary=base.duplicate(true);bad.state.steps_left=1;reject(bad,"merchant cannot be pass service")
	bad=base.duplicate(true);bad.state.players[0].god={"id":"fierce","remaining":2};reject(bad,"merchant fierce invalid")
	bad=base.duplicate(true);bad.version=7;reject(bad,"forged v7 with active NPC")
	bad=base.duplicate(true);bad.state.road_npcs["beggar:0"]={"kind":"beggar","road":target,"owner":0};reject(bad,"living beggar forged")
func test_matches()->void:
	for seed_value in [1711,1723,1733]:
		var g=Game.new()
		g.setup(["A","B","C","D"],seed_value,25,{"map_id":"knight_manor","npcs_enabled":true,"specials_enabled":true,"gods_enabled":true,"talents_enabled":true,"economy":{"initial_cash":30000,"initial_deposit":10000,"inflation_interval":5}})
		var count:int=0
		while g.phase!="finished" and count<25000:
			count+=1
			if not AI.step(g):check(false,"natural AI stalled "+g.phase);break
			if count%47==0 or g.phase in ["merchant","reaction"]:
				var loaded=roundtrip(g,"natural "+g.phase)
				if loaded==null:break
				g=loaded
		check(g.phase=="finished" and not g.winners.is_empty(),"natural NPC match completes seed"+str(seed_value))
		if g.phase=="finished":matches+=1
func _init()->void:
	test_setup_legacy();test_dog();test_merchant_and_order();test_beggar();test_day_and_gm();test_transferred_immunity();test_merchant_limits();test_strict_save();test_matches()
	print("ROUND17_NPC failures=",failures," rejected=",rejected," restores=",restores," completed_matches=",matches)
	quit(1 if failures else 0)
