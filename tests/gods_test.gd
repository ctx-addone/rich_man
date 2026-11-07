extends SceneTree
const Game = preload("res://scripts/game_state.gd")
var failures := 0
func check(value:bool,label:String)->void:
 if not value: failures+=1; printerr(label)
func _init()->void:
 var g=Game.new()
 g.setup(["A","B"],17,20)
 check(g.road_gods.is_empty(),"neutral fixtures")
 g.setup(["A","B"],17,20,{"gods_enabled":true,"talents_enabled":true,"characters":["nintaro","sarah"]})
 check(g.road_gods.size()==10,"ten gods spawn")
 g.players[0].cards.clear()
 check(g.gm_god(0,"angel"),"attach")
 check(g.players[0].god.remaining==10 and g.players[0].cards.has("robot"),"attach talent")
 g.gm_bomb(0,30)
 check(g.players[0].god.is_empty(),"bomb replaces god")
 g.gm_god(0,"fortune")
 check(g.players[0].bomb.is_empty(),"god replaces bomb")
 g.gm_bomb(1,30)
 g.gm_god(1,"poor")
 check(g.players[1].god.is_empty() and g.players[1].bomb.is_empty(),"immune arrival clears slot")
 var lot:Dictionary=g.lots.small_1_6
 lot.owner=1; lot.building_type="house"; lot.level=1
 g.players[0].pos=int(lot.frontage_nodes[0])
 g.gm_god(0,"angel")
 g.Gods.pass_lots(g);g.Gods.pass_lots(g)
 check(lot.level==2,"frontage event dedup")
 g.gm_god(0,"wealth")
 check(g.rent_preview(lot.id,0)==0,"wealth rent")
 g.gm_god(0,"poor")
 check(g.rent_preview(lot.id,0)==880,"poor rent")
 g.players[0].cards=["green"]
 check(g.use_card("green"),"green")
 check(g.players[0].god.is_empty() and g.road_gods.is_empty(),"green all slots")
 g.players[0].cards=["invite_god"]
 check(not g.use_card("invite_god") and g.players[0].cards.size()==1,"invalid command retains card")
 g.players[0].cards=["missile","missile","missile","missile"]
 g.give_card(0,"missile")
 check(g.players[0].cards==["rapid_missile"],"automatic five craft")
 g.players[0].god={"id":"martial","remaining":1}
 g.phase="end";g.end_turn()
 check(g.players[0].god.is_empty(),"expiry")
 print("GODS TEST failures=",failures)
 quit(0 if failures==0 else 1)
