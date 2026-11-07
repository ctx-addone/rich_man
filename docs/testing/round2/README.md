# 第二轮引擎验收

Godot 4.6.2，2026-11-08。命令见仓库README。

- `tests/board_model_test.gd`：多入口共享地块、占地合法性、非法导入原子回滚；`BOARD_MODEL_CONTRACT failures=0`。
- `tests/core_test.gd`：银行中断与继续移动、拘留到期、地雷、卡牌目标、经济及完整比赛；`R2_CORE failures=0 complete_matches=50`。
- `tests/ui_test.gd`：真实Godot鼠标输入，包括通过GM构造设施场景；`UI_TEST failures=0`，见 `ui-test.log`。
- `tests/full_ui_match.gd`：菜单起始、选点卡、掷骰、分岔、购买/升级、银行、正常结算，不用GM；`FULL_UI_MATCH actions=1408 rounds=21 failures=0`，见 `full-ui-match.log`。

截图：01菜单，02地图，03角色，04地块共享产权与入口，05GM，06GM结算，07自然结算，08监狱，09医院，10银行。

本轮检查过04地块显示和10银行转账截图，并修正价格裁切和SpinBox步进偏移。当前地图和数值是明确标记的集成测试规则；这些检查不证明《大富翁11》数值与全量玩法已还原。

独立只读审查发现银行整百步进还会阻止取出780等余额，已将步进改为1；最后一次UI回归包含精确存入/取出780并归零的断言，通过。其他已审查阶段没有发现确定的阻断问题，不等于对完整原版规则的认证。
