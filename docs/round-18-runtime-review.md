# R18 普通商店改动前真实 v8 存档

核对日期：2026-11-08。此 fixture 由改动前的真实 v8 核心与序列化器生成，用于后续商店迁移验证；不得用未来版本重新生成或覆盖。

## 来源与构造

- 来源提交：`d462643ed50074039953a4526fd5a28800d53e32`；生成前 `git status --short` 为空，确认 clean。
- 文件：`tests/fixtures/round17-v8-shop.rms`。
- SHA-256：`D6F67543C84D2A822B67DBB31D77A853360030EC9F0C81AE83FEB0BE74775417`。
- 序列化器原版本：8。使用现有 `Save.save_to_file` 写入，再用同一原版 `Save.load_from_file` 读取，完整 snapshot（包括 metadata、游戏 RNG、股票 RNG）完全相同：`R18_FIXTURE failures=0`，退出码 0。
- 地图 `knight_manor`，种子 180018，40 天，四席队伍 `[0,1,0,1]`。
- 角色 `[tangtang,sun_xiaomei,qian,shalong]`；角色天赋、特殊设施与 NPC 开启，神仙关闭。
- 经济 `{initial_cash:100000, initial_deposit:100000, inflation_interval:15, policy:"r16_samples"}`。

仅通过公开命令和 GM 构造：setup 后将商人放到道路 80、狗放到道路 81，隔离购建过程的随机 NPC 干扰；糖糖传送到 p_001 购买住宅，再次到访升级至 2 级；传送到 p_059 购买商业中心 1 级；进入银行存入 15000 并离开；传送到普通商店道路 9，购买第一项梦游卡一次，停留在商店。没有直接写资金、货单、成绩、phase 或 RNG。

metadata 保存 source_commit、fixture、purpose、完整 generation、原始货单与报价、实际购买项目、gm_used=true、四席 human 控制以及 portraits `[0,1,2,3]`。临时生成脚本已移除；生成日志 `.godot/r18-fixture.log` 保留。

## 原版资金、资源与货单

| 席位 | 现金 | 存款 | 角色 | 队伍 | 道路 | 手牌 |
| --- | ---: | ---: | --- | ---: | ---: | --- |
| 糖糖测试席 / 0 | 69790 | 115000 | tangtang | 0 | 9 | dice, scheme, mine, sleepwalk |
| B / 1 | 100000 | 100000 | sun_xiaomei | 1 | 45 | dice, scheme, mine |
| C / 2 | 100000 | 100000 | qian | 0 | 90 | dice, scheme, mine |
| D / 3 | 100000 | 100000 | shalong | 1 | 44 | dice, scheme, mine |

各席无股票、无异常状态、无神仙附身、未破产；载具均为步行。糖糖持有 p_001 住宅 2 级、p_059 商业中心 1 级。其他席资源未改动。

原 v8 普通商店基价 300，糖糖当时测试折扣 `0.7`，本局没有敌方能源加价，因此每项实际报价 **210**。这只是冻结版本的实现基线，不是新研究对原作票价/折扣的结论；后续明确修正也不能倒扣已经成交的 210。

| 字段 | 冻结值 |
| --- | --- |
| current / phase | 0 / shop |
| round_number / round_limit / price_index | 1 / 40 / 1 |
| shop_visit_serial | 1 |
| shop_purchases / shop_remaining | 1 / 2 |
| 初始七项货单 | sleepwalk, roadblock, god_bless, hibernate, free, timebomb, monster |
| 已购买 | sleepwalk / 梦游卡 / 210 |
| 仍在售六项 | roadblock, god_bless, hibernate, free, timebomb, monster |
| 剩余货品原报价 | 每项 210 |
| pending_service | `{}` |
| landing_pending / landing_shop / landing_queue | false / false / `[]` |
| road_npcs | merchant 位于 80 / owner -1；dog 位于 81 / owner -1 |
| npc_seen / npc_respawn_due | `[]` / `{}` |
| 游戏 RNG seed / state | 180018 / -6584216747192011210 |
| 股票 RNG seed / state | 180018 / -2743283195675294884 |

旧版普通店状态由 `phase="shop"`、`shop_stock`、`shop_purchases` 和 `shop_visit_serial` 表示，并不使用 pending_service 保存货单。顶层 state 共 51 个字段；有 economy_config 与四个 NPC 字段，没有后续商店 schema/报价策略新字段。

## 后续迁移验收边界

1. 原 fixture 保持 SHA 不变；新版读取时保留以上余额、已购梦游卡、地产、其他席资源、地图、NPC、日期、经济策略和两个 RNG。
2. 不得因为载入新商店系统而重新抽这次七项货单、补回已买的梦游卡、重置购买数，或提前执行糖糖离店赠卡。
3. 若新版本修改普通卡价、糖糖折扣或离店规则，必须明确旧局未完成访问是否保留旧报价/旧政策；不能静默把已发生交易按新价重新计算。此次原基线为 300×0.7=210，剩余每项报价也为 210。
4. 成交前后、离店前后各保存并恢复，必须继续只扣一次钱、只发一次卡；糖糖离店随机赠卡只在明确 close 执行一次，不能在读档时抽 RNG。
5. 新版所需字段应做有版本边界的迁移；升版白名单需保留 8。旧版状态缺少新字段是合法历史事实，新版载荷缺少必需字段则应拒绝。

冻结阶段仅新增 fixture 和本文，未修改核心、商店、天赋或保存器；后续 UI 工作按以下合同开展。

## R18 商店界面集成

本任务修改 `scripts/main.gd`，新增 `tests/round18_shop_ui_test.gd`；未修改商店核心、天赋或保存器。

- 新局 `main.shop_policy` 为 `Game.Shop.SAMPLE_POLICY`，地图预览与正式 setup 明确传递，成功开局从模型同步。
- 读档从模型恢复 shop_policy；“相同设置 · 再来一局”沿用已载入策略，不把旧局悄悄改为新报价。
- 卡牌商店仍以 `offer.price` 显示购买按钮最终现金金额；在每个商品下调用 `Shop.quote_detail(offer)` 展示基础价、糖糖折扣、能源加价及暂定基价标记。没有把 policy/schema 等技术字段显示给玩家。
- 满手时保留“返回对局弃牌”提示；满手、现金不足或限购已用尽均禁用购买，成交后刷新当前货单。
- 主菜单版本标为 `v0.18`。

## 初版目录阶段的专项 GUI 验证

2026-11-08，Godot 4.6.2 Windows，GUI 1440×900，执行：

```powershell
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --resolution 1440x900 --log-file .godot/r18-shop-ui.log --script tests/round18_shop_ui_test.gd
```

结果 `ROUND18_SHOP_UI failures=0`，退出码 0。测试固定种子 180018，普通商店自然抽到路障卡，不直接写货单；通过公开 GM 命令隔离其他 NPC 和构造满手/资金边界。界面操作使用实际按钮点击。

已验证：

1. 新主菜单版本与 `r18_samples` 开局；糖糖路障卡基础价 4500、三折后最终价 **1350**，界面报价说明与按钮一致，成交实际扣除 1350 并只给一张卡。
2. 满手时提示并禁购；返回对局弃一张后可购。资金降至 0 时禁购，恢复资金后能正常交易。
3. 已购货品从本次货单消失，购买次数增加一次；不重抽其他商品。
4. 真正点击“存读档 → 新建存档 → 读取 → 确认读取”，新普通商店的完整 snapshot 与策略保持一致。
5. 离开普通商店后进入独立 NPC 商人，糖糖仍按 NPC 固定 **1000** 购买，未套用普通商店三折。
6. 真正 v8 fixture 在新 UI 载入后，路障卡仍报价 **210**、说明为糖糖七折，继续购买扣除 210、购买次数从 1 增至 2。
7. 从该旧局“相同设置 · 再来一局”保留 `legacy_v8`，糖糖路障卡仍报价 210。

初版原始日志保留为 `docs/testing/round18/shop-ui-initial-catalog.log`，此次无警告/错误；原 v8 生成日志归档 `docs/testing/round18/v8-fixture-generation.log`。此阶段的单份库存说明仅记录当时实现，最终库存和截图以以下最终验证为准。

这是专项验证，不是本轮最终目录冻结后的完整长局回归。尚未在本测试中构造能源加价地产；能源公式、整数取整、更多卡价及数据来源由模型与目录测试负责。新价表后续若继续补充，应在最终发布前重新执行该专项，以更新截图和日志。

## 完整热座局的普通商店购买覆盖

`tests/full_ui_match.gd` 已扩展普通商店分支：自然到访、尚未覆盖购买且有空手牌位时，通过真实“浏览商店”打开货单，选择启用的购买按钮，从按钮可见文本读取最终价格，再实际点击购买。测试核对报价与显示一致、现金差等于当时显示价、手牌增加一张、余量减少一次，以及该卡库存 `count` 减少一份；然后返回对局并正常离店。重复卡尚有其他槽时不能断言整种卡消失。

满手或没有可支付的商品时正常离开，等待后续访问；不直接写手牌、余额或货单，不使用 GM。累计 `shop_purchases` 与实际交易记录，并增加 `RICHMAN_TEST_REQUIRE_SHOP=1` 断言至少一次真正购买。首笔购买前截图为 `06-natural-shop-quote.png`，终局日志输出 `FULL_UI_SHOP_PURCHASES` 及玩家、日数、卡牌、显示价、实际扣款和策略。

## 最终九槽目录专项复跑

最终目录确定为 28 种普通样本基价、11 种普通基价仍用测试 300；谋划卡普通样本 2400，糖糖特殊样本 630，不强行套成 720。随后增补糖糖地雷样本 600；地雷普通基价仍未证，保留测试 300，不据此反推普通价 2000。新策略库存为九槽、有放回抽样；每买一次仅移除一个槽位，剩余可购数量随库存变化。旧 `legacy_v8` 维持原 5—8 种不重复货单与限购 3。九槽每槽一份及均匀抽样属于当前实现推导，不声称原作完整概率已核清。

为增加重复库存与特殊报价的实际 UI 覆盖，用公开 Game.setup/GM 隔离 NPC/普通商店到访命令搜索自然货单，未写 shop_stock：原种子 180018 的新版九槽不含路障；找到种子 **180231**，自然货单为 `[hibernate,god_bless,scheme,scheme,roadblock,equal_all,roadblock,monster,mine]`。搜索日志 `docs/testing/round18/shop-seed-search.log` 保留，临时搜索脚本已删除；真实 v8 fixture 不受新测试种子影响。

最终 `round18_shop_ui_test.gd` 使用种子 180231，复跑结果 `ROUND18_SHOP_UI failures=0`、退出码 0。除原有资金、满手、报价、保存恢复、NPC 与旧档兼容检查外，新增验证：九槽初始可买 9；谋划卡显示“糖糖样本价630”；路障原有两份，买一次 count 从 2 减至 1；通过真实弃牌/购买操作在同次访问连续买两张路障和两张谋划，总购买 4、剩余 5 槽，证明没有旧 3 张限制；重复商品只有在分别买完两份后才消失。

地雷样本增补后又仅复跑该专项，新增 `mine.price==600` 与“糖糖样本价600”界面说明断言，仍为 0 失败。最终完整原始日志为 `docs/testing/round18/shop-ui.log`，无错误或警告；增补前通过日志另外保留 `shop-ui-before-mine-sample.log`。四张截图已由最终运行更新：`01-sample-shop-quotes.png`、`02-insufficient-cash.png`、`03-independent-npc-price.png`、`04-legacy-shop-quotes.png`。

## 最终完整热座 GUI 结果

专项之后顺序运行唯一完整 GUI 进程，没有并行窗口。完整局环境：

```powershell
$env:RICHMAN_TEST_MAP='knight_manor'
$env:RICHMAN_TEST_TEAMS='2v2'
$env:RICHMAN_TEST_TURNS='40'
$env:RICHMAN_TEST_SEED='1512'
$env:RICHMAN_TEST_REQUIRE_SHOP='1'
$env:RICHMAN_TEST_REQUIRE_MERCHANT='1'
$env:RICHMAN_TEST_REQUIRE_INFLATION='1'
$env:RICHMAN_TEST_OUTPUT='res://docs/testing/round18/hotseat'
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --resolution 1440x900 --log-file .godot/r18-hotseat-1512.log --script tests/full_ui_match.gd
```

单次种子 1512 自然完成，没有替换种子、重启对局、GM 构造或直接写手牌/资金/库存；不需要额外弃牌也自然买到普通店商品。此进程在增加糖糖地雷 600 样本前加载；四席均非糖糖，新增条件不会影响本局报价或路径。未因此重复启动长局，增补后的糖糖专属显示由后续专项验证。

```text
FULL_UI_MATCH actions=3062 rounds=41 failures=0
FULL_UI_MINIGAMES ["toss_dolls", "disarm_bomb", "catch_coins"]
FULL_UI_MERCHANT_ACTIONS 6
FULL_UI_SHOP_PURCHASES 1 transactions=[{ "player": 3, "day": 5, "card": "same_fate", "displayed_price": 3600, "paid": 3600, "policy": "r18_samples" }]
FULL_UI_ECONOMY { "initial_cash": 100000, "initial_deposit": 100000, "inflation_interval": 15, "policy": "r16_samples" } final_price=3
```

结果退出码 0。第 5 天第 4 席自然进入普通店，实际通过 UI 购买同命卡；显示与扣款均为 3600，获得一张卡且同种库存减少一份。普通店真实购买、自然商人遇见、跨涨价边界、卡牌与银行、自然结果页、未使用 GM、队伍配置保持的断言全部通过。40 天结束后内部 round_number=41 是结束标记，不代表又进行了第 41 天行动。

完整日志 `docs/testing/round18/hotseat/full-match-seed1512.log` 原样归档，无错误或警告；`06-natural-shop-quote.png` 与 `07-natural-results.png` 已目视核验。该自然局抽到投娃娃、拆炸弹和接金币，不宣称覆盖打气球或所有事件分支；高物价下不同商品/能源叠加等边界仍由模型专项测试负责。
