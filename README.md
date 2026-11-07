# 街区大亨 · R11玩法重建

当前为 v0.12 系统验证版本，**尚未完成《大富翁11》还原**。完整目标见 [目标与完成门槛](docs/r11-target.md)，本轮事实与差距见 [第十二轮验收](docs/round-12-report.md)。

## 启动

Windows 双击 `start_game.cmd`。脚本通过 Godot 命令行导入并启动；默认引擎为 `D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64.exe`，也可设置 `RICHMAN_GODOT_BIN`。无需联网服务。

## 当前可以体验

- 主菜单 → 地图 → 四个角色 → 单机对战或同机热座 → 结算与重开。默认一名真人、三名电脑，每席可切换控制。
- 可逐席分配队伍，提供四人混战和2对2预设；队友免租、可以出资加盖，资金和产权保持独立。按最后存活队伍或团队净资产判胜，结算与重开保留队伍。
- 书店/地产公司为队友提供收益，能源加价只影响敌方；卡牌逐项区分己方、敌方和范围作用，部分卡可影响队友，爆炸仍可能误伤。电脑识别队伍并避免主动伤害队友。
- 电脑使用普通游戏命令完成用卡、行走、银行、购卡、地产、研究和防御；可暂停或随时接管。当前为原创基础策略，未复刻原作算法或挑战难度。
- 存读档采用历史记录列表，每次保存新建文件；可恢复移动、银行和未结算防御，以及骰子/股市随机状态。主菜单和局内均可读取，读档后电脑先暂停。存档位于Godot用户数据目录的 `saves` 文件夹，损坏或不兼容记录会拒绝加载。v4支持v1/v2/v3旧存档迁移并校验地图配置，未分队旧局按独立阵营恢复，旧地图保留原事件格；新设施中途、货单与神仙冷却也可恢复。
- 地图来自JSON配置，起点、奖励、设施出口可分别设置；菜单区分可玩验证图与禁选的骑士庄园研究项。默认图继续使用原地释放规则，不能视为原作设施出口已还原。`data/maps/*.json` 是运行必需资源，未来导出包需包含。
- 117个道路节点、24个独立地块；15块2×2小地产、5块4×4大地产及银行、医院、监狱、商店。多入口共享同一产权。
- 购买、升级、收租与破产；现金、存款及净资产分开显示。
- 经过银行暂停移动，存取款后继续剩余步数。
- 谋划卡使对手入狱；道路地雷使经过者住院；停留期间不能行走和主动出牌，结束指定次数的停留回合后返回原路线。
- 住宅/连锁店与七类大型建筑可选择、升级和改建；五级研究池依次接入传送门、超级骰、陷阱、传送和量子飞弹。
- 商店现金购卡、每次到访限购、8张手牌上限和弃牌；周期存款利息。开启特殊设施后，每次到访抽取固定货单，购买后售罄，查询与读档不刷新。
- 经过乐透站可选号购票，保存与离站保留剩余步数；每15个完整全局轮开奖，按测试奖池规则派奖。乐透范围01—30；魔法屋九项传统效果与八种条件已接入，包括随机摧毁一栋、失半卡、入狱、取神、传送、失去载具和停留。取整、空地定义和防御细节仍为明确暂定规则。
- 道路神仙缺席后按测试冷却补回，避免长局耗尽；不会在清障的同一步立即重生。
- 48项卡牌均有可执行入口，图鉴标注实现边界，不代表全部原版交互完成。六类卡牌集齐5张自动合成。无懈/转移/同命支持受击玩家交接及连锁事件的逐次防御。
- 租金、商城、酒店、查账先展示待支付事件，合格玩家可免费、转移或承受；转移接收者继续应对，免费不免住宿。触发门槛500及转移链规则为测试配置。十一使用免费后获得遥控骰子。
- 16位原作角色规则可选，保留原创无天赋选项和4种原创占位外观；10种神仙道路相遇、附身、替换、到期及事件效果接入。天赋和道路神仙均可关闭，缺少的NPC/模式依赖在图鉴中标注。
- 载具可选1～3骰；遥控/超级骰选择合法路线与落点；普通穿越岔路随机，停在岔路后可选方向。梦游自动移动，乌龟、转向、停留和道路物件接入同一行程。
- 地雷/飞弹等连爆；附身炸弹按30实际道路步倒数、追上传递；住院防御不撤回车辆及建筑损害。爆炸范围等仍为测试参数。
- 股票窗口支持用存款买卖、持仓估值、行情历史与交易记录；股票计入净资产，资金不足时可自动卖股偿债。公司、价格与行情算法均为测试配置。
- 点击道路看关联建筑，点击建筑高亮全部入口；被拘留人物显示在对应设施内。
- 神眷可邀请地面或他人附身神仙；机器娃娃清除路径上的道路神仙及物件。
- F1打开GM：资金、指定骰子、传送、发牌、住院/入狱、解除状态、载具、剩1步炸弹、道路神仙放置/附身/清除、地产产权/建筑/等级配置、手动岔路及强制结算。

## 测试参数与待完成项

本图是集成验证布局，**不是原作地图**。价格、5级上限、各类型租金表、商店限购3张、利息和清偿顺序仍是临时规则，集中在 `scripts/model/building_rules.gd` 的 PROFILE/RENTS。攻击距离6、异常状态计时、地雷范围、传送门移动边界也未完成原版核验。

大小地产、股票、移动、连爆、神仙、角色天赋、金损反应、基础AI和存档已有可执行流程，但真实数值与全部交互仍缺；原版清偿、全部金损类别、神仙原版循环规则、NPC、新闻、完整乐透/魔法屋规则、原版地图/设施出口/机关、热斗、完整团队交互、挑战领主及其AI尚未完成。自由组队已有完整流程，但不等于挑战组队完成。神仙时长与入场金额、角色返牌概率及购卡折扣为集中测试配置。旧版地铁/全城红绿灯留作扩展需求，不算11代已还原内容。

## 验证

```powershell
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/board_model_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/core_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/buildings_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/cards_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/stocks_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/stock_integration_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/round4_review_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/route_planner_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/movement_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/explosives_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/round5_review_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/round3_ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/round4_ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/round5_ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/full_ui_match.gd
```

此前新增测试包括 `characters_test.gd`、`gods_test.gd`、`money_test.gd`、`god_interactions_test.gd` 等。第八轮增加基础AI与保存测试。第九轮增加特殊设施与循环。本轮新增 `teams_test.gd`、`team_ai_test.gd`、`team_interactions_test.gd`、`round10_save_test.gd`、`round10_ui_test.gd`；28套模型回归通过。验证范围与局限见 [第十轮证据](docs/testing/round10/README.md)。界面测试必须使用有图形输出的Godot，不能加headless；环境变量 `RICHMAN_TEST_OUTPUT` 可指定截图归档目录。

## 策划与素材

[本地策划索引](docs/README.md) · [飞书R11重建目录](https://dcncd5jl63xs.feishu.cn/wiki/Vx2FwJzWNiBjJuk24Qoc0a2NnEy)

当前使用原创几何SVG及程序绘图；[指定Gmail账号的Figma草稿](https://www.figma.com/design/DczcPjRbOMMmaFGoUEI2QX?node-id=3-2)保留第一版15个素材。未使用其他账号。本轮新增队伍设置、团队资产和结果显示，没有新增Figma稿或正式立绘。第三方参考图仅在本地研究缓存，不作为游戏资产。

第一版历史基线是提交 `9f65804`，旧00—06策划及第一轮截图保留供比较；它们不代表当前规则。

第十一轮增加地图配置、v4保存迁移及地图选择UI验证，见 [本轮证据](docs/testing/round11/README.md)。乐透和魔法的新实机证据与当前测试参数存在差异，见 [设施补证](docs/research/r11-facility-exits.md)。

第十二轮扩充传统魔法屋并修正已知效果差异，电脑按可见条件评估选择。见 [效果与实施边界](docs/round-12-services.md)、[本轮证据](docs/testing/round12/README.md)。
