# v0.1 命令行验收记录

日期：2026-11-08。引擎：本机 Godot 4.6.2 stable。平台：Windows，Compatibility / OpenGL，1440×900 验收画布。

## 结果

- 核心规则：`tests/core_test.gd` 通过。50 个固定随机种子的自然完整对局，以及地图连通、非法操作、买地、升级、收租、地铁、红灯、免租、自动变卖、破产跳过、平局、最后存活者及起点奖励等边界。
- 界面冒烟：`tests/ui_test.gd` 通过，`UI_TEST failures=0`。通过 Godot 引擎鼠标输入完成主菜单、地图、角色、交接、掷骰、选路、购买、缴租、GM 修改与结算、重开、离开确认。最终矢量素材接入后已重跑。
- 完整界面对局：`tests/full_ui_match.gd` 通过，`FULL_UI_MATCH actions=1388 rounds=21 failures=0`。从菜单开始，20 轮后自然结算，没有 GM；包含卡牌、换乘、买地与升级。21 是结束第20轮后核心计数器的值，不代表多玩了一轮。actions 包括等待自动走格的检查次数，不是玩家操作次数。
- 图形测试参考 Roadseer 的 CLI 启动、引擎输入事件与视口截图方法，没有通过桌面 UI 操作 Godot 编辑器。

## 复跑

在项目根目录执行 PowerShell：

```powershell
$richmanEngine = 'D:/software/Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe'
& $richmanEngine --headless --path . --editor --import --quit
& $richmanEngine --headless --path . --script res://tests/core_test.gd
& $richmanEngine --path . --script res://tests/ui_test.gd --log-file ./docs/ui-test.log
& $richmanEngine --path . --script res://tests/full_ui_match.gd --log-file ./docs/full-ui-match.log
```

图形测试会短暂打开独立游戏窗口并自动退出。不要在其运行期间手动干预该测试窗口。实际试玩请运行根目录 `start_game.cmd`。

## 截图

- `01-menu.png`：主菜单。
- `02-map.png`：唯一地图预览。
- `03-characters.png`：四个角色及热座设置。
- `04-game.png`：购地后的对局。
- `05-gm.png`：GM面板。
- `06-results.png`：GM结算界面。
- `07-natural-results.png`：不使用GM的自然20轮结算。

## 实际限制

这些是程序测试和截图检查，不等同真人完整试玩；单局时长、经济平衡、路线策略价值尚需试玩验证。没有联网、AI、存档、独立PVE战役及最终3D表现。交付为Godot源项目和本机启动脚本，未导出独立安装包。
