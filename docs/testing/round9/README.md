# 第九轮验证证据

Godot 4.6.2 stable，Compatibility，Windows。模型使用命令行headless；UI使用实际图形输出和鼠标事件，1440×900视口。没有用headless截图代替界面验证。

- `model-results.json`：24套模型测试退出码和错误扫描；各同名log保留断言及完整输出。
- `services_test.log`：服务生命周期、条件、资金与局末边界，3场完整对局。
- `world_cycle_test.log`：神仙冷却、随机库存、服务AI、4场50轮上限对局。
- `round9_save_test.log`：真实v1兼容、44项坏数据、服务与随机状态恢复。
- `round9-ui.log`：实际走入乐透、UI购票、保存后读取续行、魔法提交、商店购买。`01`至`05`截图分别记录选项、票据、魔法菜单、结果与商店。
- `full-ui-match.log`：20轮上限全人类热座自然结算，actions=1360、rounds=21、failures=0、无GM；`07-natural-results.png`。
- `round8-save-ui.log`和`round8-handoff-ui.log`：本轮重跑的历史保存/托管及人机防御交接；截图放在对应子目录。

专项UI中的GM只构造目标场景，完整热座及AI对局不用GM强制结算。测试验证本版本实现，不证明未知原作数值正确。已目视检查新设施选择、票据、魔法屋和商店截图，滚动区内控件正常。

另重跑第3轮历史商店界面：显式关闭特殊设施以使用固定货池；酒店、研究、满手牌、限购、卡牌目标选择均通过。日志为 round3-legacy-shop-ui.log，截图在 round3-legacy。新随机商店由 round9_ui_test 单独验证。
