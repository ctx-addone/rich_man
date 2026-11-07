# 街区大亨 · R11玩法重建

当前为 v0.2 系统验证版本，**尚未完成《大富翁11》还原**。完整目标见 [目标与完成门槛](docs/r11-target.md)，本轮事实与差距见 [第二轮验收](docs/round-02-report.md)。

## 启动

Windows 双击 `start_game.cmd`。脚本通过 Godot 命令行导入并启动；默认引擎为 `D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64.exe`，也可设置 `RICHMAN_GODOT_BIN`。无需联网服务。

## 当前可以体验

- 主菜单 → 地图 → 四个角色 → 同机热座对局 → 结算与重开。
- 117个道路节点、24个独立地块；16块2×2小地产、5块4×4大地产及银行、医院、监狱。多入口共享同一产权。
- 购买、升级、收租与破产；现金、存款及净资产分开显示。
- 经过银行暂停移动，存取款后继续剩余步数。
- 谋划卡使对手入狱；道路地雷使经过者住院；停留期间不能行走和主动出牌，结束指定次数的停留回合后返回原路线。
- 遥控骰子可以选择1～6点。当前仅实现上述3张卡，不代表完整卡池。
- 点击道路看关联建筑，点击建筑高亮全部入口；被拘留人物显示在对应设施内。
- F1打开GM：资金、指定骰子、传送、发牌、住院/入狱、解除状态、强制结算。

## 测试参数与待完成项

本图是集成验证布局，**不是原作地图**。初始现金10000、地产1200、升级600、3级上限、平方租金、起点1000奖励，以及现金→存款→半价变现的清偿顺序，仍是临时规则。攻击距离6、按个人错过行动计时、地雷仅损伤临街建筑也未完成原版核验。

大小地产目前仍共用住宅规则；七类大型建筑、连锁/街道加成、股票/月结、反制与连爆、神仙、角色天赋、全卡池、原版地图机关、热斗、组队、挑战AI和存档尚未完成。旧版地铁/全城红绿灯留作扩展需求，不算11代已还原内容。

## 验证

```powershell
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/board_model_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/core_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/ui_test.gd
& 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe' --path . --script tests/full_ui_match.gd
```

验证范围与局限见 [第二轮证据](docs/testing/round2/README.md)。界面测试必须使用有图形输出的Godot，不能加headless。

## 策划与素材

[本地策划索引](docs/README.md) · [飞书R11重建目录](https://dcncd5jl63xs.feishu.cn/wiki/Vx2FwJzWNiBjJuk24Qoc0a2NnEy)

当前使用原创几何SVG及程序绘图；[指定Gmail账号的Figma草稿](https://www.figma.com/design/DczcPjRbOMMmaFGoUEI2QX?node-id=3-2)保留第一版15个素材。未使用其他账号。本轮没有新增Figma稿或正式立绘。第三方参考图仅在本地研究缓存，不作为游戏资产。

第一版历史基线是提交 `9f65804`，旧00—06策划及第一轮截图保留供比较；它们不代表当前规则。
