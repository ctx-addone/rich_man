class_name RichCharacterTraits
extends RefCounted

# Provisional deterministic balancing profile, NOT original game values.
const TEST_PROFILE = {"worker_exchange_probability": 0.35, "roadblock_refund_probability": 0.30, "stay_refund_probability": 0.30, "shop_price_multiplier": 0.70}
const CATALOG = {
 "original": {"name":"原创无天赋", "description":"原创几何外观；不启用角色天赋。", "unknowns":"无", "source":"本项目原创", "implemented":"implemented"},
 "sun_xiaomei": {"name":"孙小美", "description":"收租/爆炸伤害 +20%；武神附身 +10 天。", "unknowns":"热斗伤害未接；持续单位待实机核验。", "source":"https://gl.ali213.net/html/2022-10/934689_3.html", "implemented":"partial"},
 "atu": {"name":"阿土伯", "description":"租金/爆炸损失减免20%；土地公附身 +3 天。", "unknowns":"热斗伤害未接。", "source":"https://gl.ali213.net/html/2022-10/934689_4.html", "implemented":"partial"},
 "qian": {"name":"钱夫人", "description":"免疫乞丐、狗；有神仙时免疫拾取和查账选中。", "unknowns":"乞丐/狗 NPC 尚未实现，仅保留免疫接口。", "source":"https://gl.ali213.net/html/2022-10/934689_5.html", "implemented":"partial"},
 "shalong": {"name":"沙隆巴斯", "description":"被乌龟选中获得香蕉皮；离商店得乌龟；乌龟范围 ×2。", "unknowns":"范围叠加顺序、满手处理待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_6.html", "implemented":"implemented"},
 "jin_beibei": {"name":"金贝贝", "description":"财神/福神 +3 天；自身回合外不可被对手送神选中。", "unknowns":"团队资格待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_7.html", "implemented":"implemented"},
 "nintaro": {"name":"忍太郎", "description":"天使/恶魔持续 ×2；神仙附身获得机器娃娃。", "unknowns":"持续计数与满手处理待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_8.html", "implemented":"implemented"},
 "qian_ge": {"name":"千哥 / 大老千", "description":"机器工人与工程车用后有概率互相生成。", "unknowns":"原版概率未知；测试概率35%，非原版数值。", "source":"https://gl.ali213.net/html/2022-10/934689_9.html", "implemented":"partial"},
 "sarah": {"name":"莎拉公主", "description":"免疫衰神、穷神、糊涂神、凶神。", "unknowns":"免疫后的神仙落点规则待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_10.html", "implemented":"implemented"},
 "wumi": {"name":"乌咪", "description":"出狱获得传送卡；转向全图可用。", "unknowns":"出院不会触发；全图范围不移除目标资格限制。", "source":"https://gl.ali213.net/html/2022-10/934689_11.html", "implemented":"implemented"},
 "miyamoto": {"name":"宫本宝藏", "description":"所有神仙持续 +1 天；附身得送神；送神范围 ×2。", "unknowns":"持续单位与满手处理待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_12.html", "implemented":"implemented"},
 "danny": {"name":"小丹尼", "description":"免疫梦游；果冻墙/香蕉皮范围 ×2。", "unknowns":"范围叠加顺序待核验。", "source":"https://gl.ali213.net/html/2022-10/934689_13.html", "implemented":"implemented"},
 "tangtang": {"name":"糖糖", "description":"离商店随机得1卡；秘密购卡；商店大幅折扣。", "unknowns":"原版折扣未知，测试七折；随机池暂用已实现卡池。", "source":"https://gl.ali213.net/html/2022-10/934689_14.html", "implemented":"partial"},
 "john": {"name":"约翰乔", "description":"使用路障概率返还；路障范围 ×2。", "unknowns":"原版概率未知；测试30%，非原版数值。", "source":"https://gl.ali213.net/html/2022-10/934689_15.html", "implemented":"partial"},
 "wu_meila": {"name":"舞美拉", "description":"使用停留概率返还；停留范围 ×2。", "unknowns":"原版概率未知；测试30%，非原版数值。", "source":"https://gl.ali213.net/html/2022-10/934689_16.html", "implemented":"partial"},
 "ludwig": {"name":"路德维希", "description":"回合外意外失牌，我方全体各得1卡；所有卡范围 +1。", "unknowns":"完整团队模式未实现；仅相同有效team获牌，无team只自己；随机池待核验。", "source":"https://richman.fandom.com/zh/wiki/路德維希", "implemented":"partial"},
 "eleven": {"name":"十一", "description":"用传送门得超级骰子；在金钱防御中用免费卡得遥控骰子。", "unknowns":"免费触发金额、奖励与满手处理仍待原版核验。", "source":"https://richman.fandom.com/zh/wiki/十一", "implemented":"partial"}
}

static func ids() -> Array[String]:
 var result: Array[String] = []
 for id in CATALOG: result.append(id)
 return result

static func display_name(id: String) -> String:
 return CATALOG.get(id, CATALOG.original).name

static func description(id: String) -> String:
 var entry: Dictionary = CATALOG.get(id, CATALOG.original)
 return entry.description + "\n" + entry.unknowns

static func character(p: Dictionary) -> String:
 return str(p.get("character_id", "original"))

static func enabled(g, p: int) -> bool:
 return g.talents_enabled and p >= 0 and p < g.players.size() and character(g.players[p]) != "original" and CATALOG.has(character(g.players[p]))

static func _is(g, p: int, id: String) -> bool:
 return enabled(g,p) and character(g.players[p]) == id

static func attack_rent_multiplier(g, p: int) -> float:
 return 1.2 if _is(g,p,"sun_xiaomei") else 1.0

static func receive_rent_multiplier(g, p: int) -> float:
 return 0.8 if _is(g,p,"atu") else 1.0

static func card_range(g, actor: int, card_id: String, base: int) -> int:
 if not enabled(g,actor): return base
 var id: String = character(g.players[actor])
 if id == "wumi" and card_id == "reverse": return 2147483647
 if id == "ludwig": return base + 1
 var doubled := (id == "shalong" and card_id == "turtle") or (id == "miyamoto" and card_id == "send_god") or (id == "danny" and card_id in ["jelly","banana"]) or (id == "john" and card_id == "roadblock") or (id == "wu_meila" and card_id == "stay")
 return base * 2 if doubled else base

static func _same_team(a: Dictionary, b: Dictionary) -> bool:
 var team: Variant = a.get("team", null)
 return team != null and str(team) != "" and str(team) != "-1" and team == b.get("team", null)

static func target_immune(g, actor: int, target: int, card_id: String) -> bool:
 if _is(g,target,"danny") and card_id == "sleepwalk": return true
 if _is(g,target,"qian") and card_id in ["steal","audit"] and not g.players[target].get("god",{}).is_empty(): return true
 return _is(g,target,"jin_beibei") and card_id == "send_god" and g.current != target and actor != target and not _same_team(g.players[actor],g.players[target])

static func deity_immune(g, p: int, god: String) -> bool:
 return _is(g,p,"sarah") and god in ["poor","misfortune","confused","fierce"]

static func deity_duration(g, p: int, god: String, base: int) -> int:
 if _is(g,p,"sun_xiaomei") and god == "martial": return base + 10
 if _is(g,p,"atu") and god == "earth": return base + 3
 if _is(g,p,"jin_beibei") and god in ["wealth","fortune"]: return base + 3
 if _is(g,p,"nintaro") and god in ["angel","devil"]: return base * 2
 return base + 1 if _is(g,p,"miyamoto") else base

static func on_deity_attached(g, p: int, _god: String) -> void:
 if _is(g,p,"nintaro"): g.give_card(p,"robot")
 if _is(g,p,"miyamoto"): g.give_card(p,"send_god")

# Call once after successful consumption. Failed/rejected actions never award.
static func on_card_used(g, p: int, card_id: String) -> void:
 if _is(g,p,"qian_ge") and card_id in ["worker","bulldozer"] and g.rng.randf() < TEST_PROFILE.worker_exchange_probability:
  g.give_card(p,"worker" if card_id == "bulldozer" else "bulldozer")
 if _is(g,p,"john") and card_id == "roadblock" and g.rng.randf() < TEST_PROFILE.roadblock_refund_probability: g.give_card(p,card_id)
 if _is(g,p,"wu_meila") and card_id == "stay" and g.rng.randf() < TEST_PROFILE.stay_refund_probability: g.give_card(p,card_id)
 if _is(g,p,"eleven") and card_id == "portal": g.give_card(p,"super_dice")
 if _is(g,p,"eleven") and card_id == "free": g.give_card(p,"dice")

# Successful target selection, even if a subsequent defense prevents the effect.
static func on_card_targeted(g, _actor: int, target: int, card_id: String) -> void:
 if _is(g,target,"shalong") and card_id == "turtle": g.give_card(target,"banana")

static func on_shop_exit(g, p: int) -> void:
 if _is(g,p,"shalong"): g.give_card(p,"turtle")
 if _is(g,p,"tangtang"): g.give_card(p,g.random_card())

static func on_release(g, p: int, status_kind: String) -> void:
 if _is(g,p,"wumi") and status_kind == "prison": g.give_card(p,"teleport")

static func on_card_lost(g, p: int, reason: String = "unexpected") -> void:
 if not _is(g,p,"ludwig") or g.current == p or reason not in ["steal","magic_house","misfortune"]: return
 for i in range(g.players.size()):
  if not g.players[i].get("bankrupt",false) and (i == p or _same_team(g.players[p],g.players[i])): g.give_card(i,g.random_card())

static func shop_price_multiplier(g, p: int) -> float:
 return TEST_PROFILE.shop_price_multiplier if _is(g,p,"tangtang") else 1.0

static func shop_purchase_private(g, p: int) -> bool:
 return _is(g,p,"tangtang")

static func npc_immune(g, p: int, npc_id: String) -> bool:
 return _is(g,p,"qian") and npc_id in ["beggar","dog"]
