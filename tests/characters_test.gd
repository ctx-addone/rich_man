extends SceneTree
const Traits = preload("res://scripts/model/character_traits.gd")
var failures := 0
class FakeGame:
 extends RefCounted
 var talents_enabled := true
 var players: Array = []
 var current := 0
 var rng := RandomNumberGenerator.new()
 func _init():
  rng.seed = 782
  for i in range(4): players.append({"character_id":"original","god":{},"cards":[],"bankrupt":false})
 func give_card(p: int, id: String) -> bool:
  if players[p].cards.size() >= 8: return false
  players[p].cards.append(id)
  return true
 func random_card() -> String:
  return ["dice","turtle","banana"][rng.randi_range(0,2)]
func check(ok: bool, message: String):
 if not ok: failures += 1; push_error(message)
func select(g, id: String, p: int = 0):
 g.players[p].character_id = id
 g.players[p].cards.clear()
func _initialize():
 var g = FakeGame.new()
 check(Traits.ids().size() == 17,"16 researched characters plus original")
 for id in Traits.ids():
  check(not Traits.display_name(id).is_empty() and not Traits.description(id).is_empty(),"All selections have readable provenance and limits")
  check(Traits.CATALOG[id].has("source") and Traits.CATALOG[id].has("implemented"),"Catalog evidence and status")
 select(g,"sun_xiaomei")
 check(is_equal_approx(Traits.attack_rent_multiplier(g,0),1.2) and Traits.deity_duration(g,0,"martial",4)==14,"Xiaomei rent and martial")
 select(g,"atu")
 check(is_equal_approx(Traits.receive_rent_multiplier(g,0),0.8) and Traits.deity_duration(g,0,"earth",4)==7,"Atu mitigation and earth")
 select(g,"qian",1)
 g.players[1].god={"id":"angel","remaining":2}
 check(Traits.target_immune(g,0,1,"audit") and Traits.target_immune(g,0,1,"steal") and not Traits.target_immune(g,0,1,"turtle"),"Qian deity protection is selective")
 g.players[1].god={}
 check(not Traits.target_immune(g,0,1,"audit") and Traits.npc_immune(g,1,"dog"),"Qian requires a deity; NPC hook explicit")
 select(g,"shalong")
 Traits.on_card_targeted(g,1,0,"turtle")
 Traits.on_shop_exit(g,0)
 check(g.players[0].cards==["banana","turtle"] and Traits.card_range(g,0,"turtle",6)==12,"Shalong event grants and range")
 select(g,"jin_beibei",1)
 check(Traits.target_immune(g,0,1,"send_god") and Traits.deity_duration(g,1,"fortune",4)==7,"Baby off-turn protection")
 g.current=1
 check(not Traits.target_immune(g,0,1,"send_god"),"Baby own-turn exception")
 g.current=0
 select(g,"nintaro")
 Traits.on_deity_attached(g,0,"angel")
 check(g.players[0].cards==["robot"] and Traits.deity_duration(g,0,"angel",4)==8,"Nintaro angel duration and reward")
 select(g,"sarah")
 for god in ["poor","misfortune","confused","fierce"]: check(Traits.deity_immune(g,0,god),"Sarah negative deity immunity")
 check(not Traits.deity_immune(g,0,"devil"),"Devil is not in Sarah immunity list")
 select(g,"wumi")
 Traits.on_release(g,0,"hospital")
 check(g.players[0].cards.is_empty(),"Hospital release does not grant prison talent")
 Traits.on_release(g,0,"prison")
 check(g.players[0].cards==["teleport"] and Traits.card_range(g,0,"reverse",6)>10000,"Wumi prison reward and full map reverse")
 select(g,"miyamoto")
 Traits.on_deity_attached(g,0,"poor")
 check(g.players[0].cards==["send_god"] and Traits.deity_duration(g,0,"poor",4)==5 and Traits.card_range(g,0,"send_god",6)==12,"Miyamoto all deity reward and range")
 select(g,"danny",1)
 check(Traits.target_immune(g,0,1,"sleepwalk") and not Traits.target_immune(g,0,1,"hibernate") and Traits.card_range(g,1,"jelly",6)==12,"Danny specific immunity and range")
 select(g,"tangtang")
 Traits.on_shop_exit(g,0)
 check(g.players[0].cards.size()==1 and Traits.shop_purchase_private(g,0) and is_equal_approx(Traits.shop_price_multiplier(g,0),0.7),"Tangtang private shop and marked provisional discount")
 select(g,"eleven")
 Traits.on_card_used(g,0,"portal")
 check(g.players[0].cards==["super_dice"],"Eleven portal reward; free-card branch remains pending integration")
 select(g,"ludwig",1)
 for p in g.players: p.cards.clear()
 Traits.on_card_lost(g,1,"steal")
 check(g.players[1].cards.size()==1 and g.players[0].cards.is_empty() and g.players[2].cards.is_empty(),"Ludwig without team rewards only self")
 g.players[1].team="blue"; g.players[2].team="blue"; g.players[3].team="red"
 Traits.on_card_lost(g,1,"misfortune")
 check(g.players[1].cards.size()==2 and g.players[2].cards.size()==1 and g.players[3].cards.is_empty(),"Ludwig explicit same team only")
 Traits.on_card_lost(g,1,"used")
 g.current=1
 Traits.on_card_lost(g,1,"steal")
 check(g.players[1].cards.size()==2,"Ludwig excludes ordinary spending and own turn")
 check(Traits.card_range(g,1,"audit",6)==7,"Ludwig +1 range")
 # Reproducibility and both success/failure paths for each unknown probability.
 for pair in [["qian_ge","worker","bulldozer"],["qian_ge","bulldozer","worker"],["john","roadblock","roadblock"],["wu_meila","stay","stay"]]:
  var outcomes: Array = []
  for repetition in range(2):
   g.rng.seed=876
   var sequence: Array = []
   for trial in range(60):
    select(g,pair[0])
    Traits.on_card_used(g,0,pair[1])
    sequence.append(g.players[0].cards.has(pair[2]))
   outcomes.append(sequence)
  check(outcomes[0]==outcomes[1] and outcomes[0].has(true) and outcomes[0].has(false),"Seeded provisional chance repeatable with both outcomes")
 select(g,"shalong")
 g.players[0].cards=["dice","dice","dice","dice","dice","dice","dice","dice"]
 Traits.on_shop_exit(g,0)
 check(g.players[0].cards.size()==8,"Talent grants respect central hand limit")
 g.talents_enabled=false
 for id in Traits.ids():
  select(g,id)
  Traits.on_shop_exit(g,0); Traits.on_deity_attached(g,0,"angel"); Traits.on_release(g,0,"prison"); Traits.on_card_used(g,0,"portal")
  check(g.players[0].cards.is_empty() and Traits.card_range(g,0,"turtle",6)==6 and Traits.deity_duration(g,0,"martial",4)==4 and Traits.attack_rent_multiplier(g,0)==1.0 and Traits.shop_price_multiplier(g,0)==1.0,"Global talent toggle disables all selections")
 print("CHARACTERS_TEST failures=",failures)
 quit(1 if failures else 0)
