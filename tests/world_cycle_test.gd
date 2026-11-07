extends SceneTree
const Game=preload("res://scripts/game_state.gd")
const Gods=preload("res://scripts/model/god_rules.gd")
const Shop=preload("res://scripts/model/shop_rules.gd")
const AI=preload("res://scripts/model/ai_controller.gd")
var failures:int=0
func check(value:bool,label:String)->void:
 if not value: failures+=1; printerr(label)
func game(seed_value:int=91):
 var g=Game.new()
 g.setup(["A","B"],seed_value,100,{"gods_enabled":true,"specials_enabled":true})
 return g
func _init()->void:
 var a=game()
 var b=game()
 check(a.road_gods==b.road_gods,"seed repeats initial population")
 for g in [a,b]:
  g.road_gods.clear()
  g.players[0].pos=12
  g.players[1].pos=13
  g.road_objects[14]={"kind":"mine","owner":0}
  g.players[1].god={"id":"angel","remaining":4}
  g.round_number=2
  Gods.advance_round(g)
  check(g.road_gods.is_empty() and g.god_respawn_due.size()==9,"first missing observation schedules without spawning")
  Gods.advance_round(g)
  check(g.road_gods.is_empty(),"repeated same boundary cannot bypass cooldown")
  g.round_number=3
  Gods.advance_round(g)
  check(g.road_gods.size()==9 and g.god_respawn_due.is_empty(),"nine missing types return, attached angel stays unique")
  check(not g.road_gods.has(0) and not g.road_gods.has(12) and not g.road_gods.has(13) and not g.road_gods.has(14),"spawn excludes start, all players and road objects")
  var unique:Dictionary={}
  for god_id in g.road_gods.values(): unique[god_id]=true
  check(unique.size()==9 and not unique.has("angel"),"road population has unique absent ids")
 check(a.road_gods==b.road_gods and a.rng.state==b.rng.state,"refresh uses deterministic game RNG")
 a.players[0].cards=["green"]
 check(a.use_card("green"),"green executed")
 check(a.road_gods.is_empty() and a.god_respawn_due.is_empty(),"green has no immediate regeneration")
 a.round_number=4;Gods.advance_round(a)
 check(a.road_gods.is_empty(),"green remains effective until cooldown elapses")
 a.round_number=5;Gods.advance_round(a)
 check(a.road_gods.size()==10,"long game recovers all types after green")
 a.road_gods.clear();a.god_respawn_due.clear()
 a.phase="roll";a.card_used=false;a.players[0].cards=["robot"]
 var route:Dictionary=a.controlled_routes("robot")[0]
 a.gm_spawn_god(route.path[0],"earth")
 check(a.use_card("robot",route.path,route.steps),"robot executes route")
 check(a.road_gods.is_empty() and a.god_respawn_due.is_empty(),"robot clearing does not spawn or schedule during card")
 a.gods_enabled=false
 a.gm_spawn_god(20,"wealth")
 a.round_number=6;Gods.advance_round(a)
 check(a.road_gods.size()==1 and a.god_respawn_due.is_empty(),"automatic off preserves explicit GM god without repopulating")
 a.gods_enabled=true;a.road_gods.clear();a.god_respawn_due.clear()
 a.round_number=2;Gods.advance_round(a,{"check_every_rounds":2,"reappear_after":3})
 check(a.god_respawn_due.is_empty(),"configured check frequency")
 a.round_number=3;Gods.advance_round(a,{"check_every_rounds":2,"reappear_after":3})
 check(a.god_respawn_due.wealth==6,"configured cooldown stored as absolute round")
 a.round_number=5;Gods.advance_round(a,{"check_every_rounds":2,"reappear_after":3})
 check(a.road_gods.is_empty(),"configured cooldown enforced")
 a.round_number=7;Gods.advance_round(a,{"check_every_rounds":2,"reappear_after":3})
 check(a.road_gods.size()==10,"first eligible check after due respawns")
 var c=game(33)
 var d=game(33)
 Shop.enter(c);Shop.enter(d)
 check(c.shop_stock==d.shop_stock and c.shop_stock.size()>=5 and c.shop_stock.size()<=8,"seeded random 5 to 8 offers")
 var stock:Array=c.shop_stock.duplicate()
 var rng_state:int=c.rng.state
 for ignored in range(10): Shop.offers(c)
 check(c.shop_stock==stock and c.rng.state==rng_state,"UI offers queries do not reroll or consume RNG")
 var ids:Dictionary={}
 for offer in Shop.offers(c):
  ids[offer.id]=true
  check(offer.id not in Shop.EXCLUDED,"advanced pool excluded")
 check(ids.size()==stock.size(),"different card types in one visit")
 c.phase="shop";c.players[0].cards.clear()
 var card_id:String=c.shop_stock[0]
 check(c.buy_card(card_id),"buy random stock card")
 check(not c.shop_stock.has(card_id) and not c.buy_card(card_id),"one copy per visit, stale selection cannot rebuy")
 for ignored in range(2): check(c.buy_card(c.shop_stock[0]),"buy next distinct card")
 check(c.shop_remaining()==0 and not c.buy_card(c.shop_stock[0]),"three card cap preserved")
 c.close_shop()
 Shop.enter(c)
 check(c.shop_visit_serial==2 and c.shop_stock.size()>=5,"new visit replenishes independently")
 var legacy=Game.new()
 legacy.setup(["A","B"],33,20)
 Shop.enter(legacy)
 check(legacy.shop_stock.is_empty() and Shop.offers(legacy).size()==Shop.pool(legacy).size(),"legacy full pool remains")
 legacy.phase="shop";legacy.players[0].cards.clear()
 check(legacy.buy_card("dice") and legacy.buy_card("dice"),"legacy duplicate purchase allowed")
 c.talents_enabled=true;c.players[0].character_id="tangtang"
 var lot:Dictionary=c.lots.values()[0]
 lot.owner=1;lot.building_type="energy";lot.level=2;lot.closed_until=0
 var expected:int=int(c.Buildings.PROFILE.card_price*(1.0+2*c.Buildings.PROFILE.energy_markup)*c.Traits.shop_price_multiplier(c,0))
 check(Shop.offers(c)[0].price==expected,"energy markup and Tangtang discount compose")
 c.phase="shop";c.players[0].cards.clear();c.close_shop()
 check(c.players[0].cards.size()==1,"leave-shop talent preserved")
 test_ai_services()
 print("WORLD_CYCLE_TEST failures=",failures)
 quit(1 if failures else 0)

func test_ai_services()->void:
 var g=game(41)
 g.road_gods.clear()
 g.players[0].pos=g.Specials.LOTTERY_ROAD
 g.steps_left=1
 check(g.Specials.enter(g,"lottery"),"AI lottery fixture enters")
 check(AI.step(g) and g.lottery_state.tickets.size()==1 and g.players[0].cash>=AI.CASH_RESERVE,"AI buys one affordable ticket")
 check(AI.step(g) and g.phase!="lottery","AI closes lottery on next step")
 g.service_visited.clear()
 check(g.Specials.enter(g,"lottery"),"same draw lottery revisit")
 check(AI.step(g) and g.phase!="lottery" and g.lottery_state.tickets.size()==1,"AI avoids duplicate spending during same draw")
 g.current=1;g.players[1].pos=g.Specials.LOTTERY_ROAD
 g.players[1].cash=AI.CASH_RESERVE+g.Specials.TEST_PROFILE.ticket_price-1
 g.service_visited.clear()
 check(g.Specials.enter(g,"lottery") and AI.step(g) and g.phase!="lottery","AI keeps cash reserve and exits expensive service")
 check(g.lottery_state.tickets.size()==1,"poor AI never buys ticket")
 g.players[1].pos=g.Specials.MAGIC_ROAD
 g.service_visited.clear()
 check(g.Specials.enter(g,"magic"),"AI magic fixture enters")
 check(AI.step(g) and g.phase=="land" and g.magic_last_result.effect=="gain_cards","AI commits magic once then resumes landing")
 var completed:int=0
 var saw_lottery:bool=false
 var saw_magic:bool=false
 for seed_value in [11,19,37,53]:
  g=Game.new()
  g.setup(["A","B","C","D"],seed_value,50,{"gods_enabled":true,"specials_enabled":true,"talents_enabled":true,"characters":["eleven","nintaro","shalong","sarah"]})
  var actions:int=0
  while g.phase!="finished" and actions<20000:
   saw_lottery=saw_lottery or g.phase=="lottery"
   saw_magic=saw_magic or g.phase=="magic"
   actions+=1
   if not AI.step(g):
    check(false,"enabled AI stalled in %s seed %d"%[g.phase,seed_value])
    break
   for p in g.players: check(p.cash>=0 and p.deposit>=0 and p.cards.size()<=g.HAND_LIMIT,"AI maintains balances and hand cap")
  check(g.phase=="finished" and not g.winners.is_empty(),"enabled 50-round AI match completes")
  if g.phase=="finished": completed+=1
 check(saw_lottery and saw_magic,"natural full matches visit lottery and magic")
 print("WORLD_AI completed_matches=",completed)
