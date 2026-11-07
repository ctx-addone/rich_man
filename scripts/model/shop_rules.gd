class_name RichShopRules
extends RefCounted

# PROVISIONAL: random sale is evidenced; count, refresh and stock quantity are not.
const PROFILE={"minimum_offers":5,"maximum_offers":8,"quantity_per_card":1}
const EXCLUDED=["portal","trap","super_dice","teleport","quantum","glory","misery","disaster","rapid_missile"]

static func pool(g)->Array[String]:
 var result:Array[String]=[]
 for card_id in g.CARD_NAMES:
  if card_id not in EXCLUDED: result.append(card_id)
 return result

static func enter(g)->void:
 g.shop_visit_serial+=1
 g.shop_stock.clear()
 if not g.specials_enabled: return
 var remaining:Array[String]=pool(g)
 var count:int=mini(remaining.size(),g.rng.randi_range(PROFILE.minimum_offers,PROFILE.maximum_offers))
 for ignored in range(count):
  var index:int=g.rng.randi_range(0,remaining.size()-1)
  g.shop_stock.append(remaining[index])
  remaining.remove_at(index)

static func offers(g)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var markup:float=0.0
 for lot in g.lots.values():
  if g.is_opponent(lot.owner,g.current) and lot.building_type=="energy" and lot.closed_until<=g.round_number:
   markup+=lot.level*g.Buildings.PROFILE.energy_markup
 var price:int=int(g.Buildings.PROFILE.card_price*(1+markup)*g.Traits.shop_price_multiplier(g,g.current))
 var stock:Array[String]=g.shop_stock if g.specials_enabled else pool(g)
 for card_id in stock: result.append({"id":card_id,"name":g.CARD_NAMES[card_id],"price":price})
 return result

static func purchased(g,card_id:String)->void:
 if g.specials_enabled: g.shop_stock.erase(card_id)
