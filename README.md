# 街区大亨 · R11玩法重建

当前为 v0.3 系统验证版本，**尚未完成《大富翁11》还原**。完整目标见 [目标与完成门槛](docs/r11-target.md)，本轮事实与差距见 [第三轮验收](docs/round-03-report.md)。

## 启动

Windows 双击 `start_game.cmd`。脚本通过 Godot 命令行导入并启动；默认引擎为 `D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64.exe`，也可设置 `RICHMAN_GODOT_BIN`。无需联网服务。

## 当前可以体验

- 主菜单 → 地图 → 四个角色 → 同机热座对局 → 结算与重开。
- 117个道路节点、24个独立地块；15块2×2小地产、5块4×4大地产及银行、医院、监狱、商店。多入口共享同一产权。
- 购买、升级、收租与破产；现金、存款及净资产分开显示。
- 经过银行暂停移动，存取款后继续剩余步数。
- 谋划卡使对手入狱；道路地雷使经过者住院；停留期间不能行走和主动出牌，结束指定次数的停留回合后返回原路线。
- 住宅/连锁店与七类大型建筑可选择、升级和改建，具有不同租金及被动效果；研究所当前只产出传送门，其他研究项目待实现。
- 商店现金购卡、每次到访限购、8张手牌上限和弃牌；周期存款利息。
- 17项卡牌效果可执行，包含选点骰子、查账、现金均分、拾取、改建、停业、涨价、路障和传送门等；图鉴收录48项及实现边界，不代表全卡池已完成。
- 点击道路看关联建筑，点击建筑高亮全部入口；被拘留人物显示在对应设施内。
- F1打开GM：资金、指定骰子、传送、发牌、住院/入狱、解除状态、强制结算。

## 测试参数与待完成项

本图是集成验证布局，**不是原作地图**。价格、5级上限、各类型租金表、商店限购3张、利息和清偿顺序仍是临时规则，集中在 `scripts/model/building_rules.gd` 的 PROFILE/RENTS。攻击距离6、异常状态计时、地雷范围、传送门移动边界也未完成原版核验。

大小地产已有独立规则，但真实数值与全部交互仍缺；股票、完整清偿、反制与连爆、神仙、角色天赋、其余卡牌、原版地图/随机路口/设施出口、热斗、组队、挑战AI和存档尚未完成。旧版地铁/全城红绿灯留作扩展需求，不算11代已还原内容。

## 验证

```powershell
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/board_model_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/core_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/buildings_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/cards_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/round3_ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/full_ui_match.gd
```

验证范围与局限见 [第三轮证据](docs/testing/round3/README.md)。界面测试必须使用有图形输出的Godot，不能加headless。

## 策划与素材

[本地策划索引](docs/README.md) · [飞书R11重建目录](https://dcncd5jl63xs.feishu.cn/wiki/Vx2FwJzWNiBjJuk24Qoc0a2NnEy)

当前使用原创几何SVG及程序绘图；[指定Gmail账号的Figma草稿](https://www.figma.com/design/DczcPjRbOMMmaFGoUEI2QX?node-id=3-2)保留第一版15个素材。未使用其他账号。本轮没有新增Figma稿或正式立绘。第三方参考图仅在本地研究缓存，不作为游戏资产。

第一版历史基线是提交 `9f65804`，旧00—06策划及第一轮截图保留供比较；它们不代表当前规则。
