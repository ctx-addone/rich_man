class_name RichShopRules
extends RefCounted

# Historical pre-R18 stock profile, retained only for old-game compatibility.
const PROFILE={"minimum_offers":5,"maximum_offers":8,"quantity_per_card":1}
const EXCLUDED=["portal","trap","super_dice","teleport","quantum","glory","misery","disaster","rapid_missile"]
const LEGACY_POLICY = "legacy_v8"
const SAMPLE_POLICY = "r18_samples"
const SAMPLE_SLOTS = 9
# Frozen by policy version; extending this table later requires a new policy
# so historical ongoing visits keep their exact prices.
const SAMPLE_PRICES = {
 "dice":5000,"stay":4000,"roadblock":4500,"jelly":3400,"robot":2000,"reverse":3000,"transfer":5200,
 "worker":4400,"explosive":4000,"rebuild":3000,"send_god":2400,"turtle":4000,"timebomb":2400,"missile":6000,
 "immune":3000,"scheme":2400,"raise_rent":2000,"monster":5500,"free":4200,"same_fate":3600,
 "banana":2000,"car":5600,"motorbike":4000,"steal":3600,"activate":7500,"close_street":4000,"invite_god":3800,"bulldozer":2400
}
# The same filmed card is 2400 for Shalong and 630 for Tangtang. Do not
# silently replace the latter with 720 to force a universal 30% rule.
const TANGTANG_QUOTES = {"scheme":630,"mine":600}

static func valid_policy(value:Variant)->bool:
 return value is String and value in [LEGACY_POLICY,SAMPLE_POLICY]

static func purchase_limit(policy:String)->int:
 return SAMPLE_SLOTS if policy==SAMPLE_POLICY else 3

static func quote(g, card_id:String)->Dictionary:
 if not pool(g).has(card_id): return {}
 var markup:float=0.0
 var energy_percent:int=0
 for lot in g.lots.values():
  if g.is_opponent(lot.owner,g.current) and lot.building_type=="energy" and lot.closed_until<=g.round_number:
   markup+=lot.level*g.Buildings.PROFILE.energy_markup
   energy_percent+=lot.level*15 # Existing TEST rule; not an original-game rate.
 var samples:bool=g.shop_policy==SAMPLE_POLICY
 var base:int=int(SAMPLE_PRICES.get(card_id,g.Buildings.PROFILE.card_price)) if samples else int(g.Buildings.PROFILE.card_price)
 var discount:int=30 if samples and g.Traits.shop_purchase_private(g,g.current) else 100
 var override:bool=samples and discount==30 and TANGTANG_QUOTES.has(card_id)
 var price:int
 if samples:
  @warning_ignore("integer_division")
  price=base*(100+energy_percent)*discount/10000
  if override:
   @warning_ignore("integer_division")
   price=int(TANGTANG_QUOTES[card_id])*(100+energy_percent)/100
 else:
  # Preserve historical floating-point order and provisional 70% trait.
  price=int(base*(1+markup)*g.Traits.shop_price_multiplier(g,g.current))
  discount=70 if g.Traits.shop_purchase_private(g,g.current) else 100
 return {"id":card_id,"name":g.CARD_NAMES[card_id],"price":price,"base_price":base,"discount_percent":discount,"energy_percent":energy_percent,"sample_price":samples and SAMPLE_PRICES.has(card_id),"sample_override":override,"trait_price":int(TANGTANG_QUOTES.get(card_id,0)) if override else 0,"policy":g.shop_policy}

static func quote_detail(offer:Dictionary)->String:
 var result:String="基础 %d"%offer.base_price
 if offer.sample_override: result+=" · 糖糖样本价%d"%offer.trait_price
 elif offer.discount_percent<100: result+=" · 糖糖%d折"%(offer.discount_percent/10)
 if offer.energy_percent>0: result+=" · 能源加价%d%%（暂定）"%offer.energy_percent
 if not offer.sample_price: result+=" · 暂定基价"
 return result

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
 if g.shop_policy==SAMPLE_POLICY:
  # Filmed 3x3 shelf can contain duplicate cards. Each slot is a separate copy.
  # Uniform sampling remains TEST; the real distribution is unverified.
  for ignored in range(SAMPLE_SLOTS): g.shop_stock.append(remaining[g.rng.randi_range(0,remaining.size()-1)])
  return
 var count:int=mini(remaining.size(),g.rng.randi_range(PROFILE.minimum_offers,PROFILE.maximum_offers))
 for ignored in range(count):
  var index:int=g.rng.randi_range(0,remaining.size()-1)
  g.shop_stock.append(remaining[index])
  remaining.remove_at(index)

static func offers(g)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var stock:Array[String]=g.shop_stock if g.specials_enabled else pool(g)
 for card_id in stock: result.append(quote(g,card_id))
 return result

static func purchased(g,card_id:String)->void:
 if g.specials_enabled: g.shop_stock.erase(card_id)
