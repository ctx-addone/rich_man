# 第四轮验证证据

Godot 4.6.2，Windows Compatibility图形模式。所有脚本通过命令行运行。

| 脚本 | 结果 |
|---|---|
| stocks_test | STOCKS_TEST failures=0 |
| stock_integration_test | R4_STOCK_INTEGRATION failures=0 |
| combat_test | combat_test: 0 failures |
| round4_review_test | ROUND4_REVIEW failures=0 |
| core_test | R3_CORE failures=0 complete_matches=50 |
| buildings_test / cards_test | 0失败，保留原脚本输出前缀 |
| round4_ui_test | R4_UI failures=0 |
| full_ui_match | FULL_UI_MATCH actions=1402 rounds=21 failures=0 |

专项UI用真实Godot鼠标事件操作可见按钮；银行位置、持牌和攻击环境用测试数据构造，明确是GM验证场景。截图01股票、02防御交接、03防御选择、04冬眠、05转移目标。07是无GM完整20轮结算。

全文日志保存在同目录。完整界面对局在终局行情修正前已启动，且该对局未持股；修正后的终局持股场景由round4_review_test专门验证。模型测试通过不证明原作数值或时序已复原。
