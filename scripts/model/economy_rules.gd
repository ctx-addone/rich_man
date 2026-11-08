class_name RichEconomyRules
extends RefCounted

# R16: configurable resources are verified; calendar boundaries and defaults are
# TEST. Only supported categories opt in. Transfers never receive a multiplier.
const MAX_INITIAL = 500000
const MAX_INTERVAL = 365
# Serialization/arithmetic guard, not an automatic end date for unlimited play.
const MAX_DAYS = 1000000000
const SAMPLE_POLICY = "r16_samples"
const LEGACY_POLICY = "legacy_v6"

static func legacy() -> Dictionary:
	return {"initial_cash":10000,"initial_deposit":0,"inflation_interval":0,"policy":LEGACY_POLICY}

static func normalize(value:Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var result:Dictionary = legacy()
	result.policy = SAMPLE_POLICY
	for key in value:
		if not result.has(key): return {}
		result[key] = value[key]
	return result if valid(result) else {}

static func valid(config:Variant) -> bool:
	if not config is Dictionary or config.size() != 4: return false
	for key in ["initial_cash","initial_deposit","inflation_interval"]:
		if not config.get(key) is int: return false
	if config.get("policy") not in [LEGACY_POLICY,SAMPLE_POLICY]: return false
	if config.initial_cash < 0 or config.initial_cash > MAX_INITIAL or config.initial_deposit < 0 or config.initial_deposit > MAX_INITIAL: return false
	if config.inflation_interval < 0 or config.inflation_interval > MAX_INTERVAL: return false
	return config.policy != LEGACY_POLICY or config.inflation_interval == 0

static func index(config:Dictionary, day:int, limit:int) -> int:
	var interval:int = config.inflation_interval
	if interval == 0: return 1
	# A finite match's sentinel round is not an extra economic day.
	var economic_day:int = mini(day,limit) if limit > 0 else day
	@warning_ignore("integer_division")
	return 1 + (maxi(1,economic_day)-1)/interval

static func freeze_service(g) -> void:
	if g.economy_config.policy == SAMPLE_POLICY:
		g.pending_service.pricing = {"day":g.round_number,"price":g.price_index(),"other_divisor":3}

static func service_price(g) -> int:
	return int(g.pending_service.get("pricing",{}).get("price",1))

static func minigame_cash(g, record:Dictionary) -> int:
	var pricing:Dictionary = g.pending_service.get("pricing",{})
	if pricing.is_empty(): return int(record.reward)
	var amount:int = int(record.score) * int(pricing.price)
	if record.player != g.current:
		# Filmed price-2 samples pay displayed score * 2/3. Applying the
		# denominator to other prices/modes is explicitly a TEST inference.
		@warning_ignore("integer_division")
		amount = amount/int(pricing.other_divisor)
	return amount

static func service_error(state:Dictionary) -> String:
	var service:Dictionary = state.pending_service
	var monetary_service:bool = state.phase in ["news","minigame"]
	var expected:bool = monetary_service and state.economy_config.policy == SAMPLE_POLICY
	if not expected:
		return "此经济策略或阶段不能包含服务报价" if service.has("pricing") else ""
	var pricing:Variant = service.get("pricing")
	if not pricing is Dictionary or pricing.size() != 3: return "服务缺少冻结物价"
	for key in ["day","price","other_divisor"]:
		if not pricing.get(key) is int: return "服务物价格式无效"
	if pricing.day != state.round_number or pricing.price != index(state.economy_config,state.round_number,state.round_limit) or pricing.other_divisor != 3: return "服务物价与本日规则不一致"
	return ""

static func scoring_state(state:Dictionary) -> Dictionary:
	# v1 minigames retain their exact score/replay schema. The enclosing service
	# owns the monetary quote; it is validated separately by Save.
	if not state.get("pending_service",{}).has("pricing"): return state
	var result:Dictionary = state.duplicate(false)
	result.pending_service = state.pending_service.duplicate(false)
	result.pending_service.erase("pricing")
	return result
