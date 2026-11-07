# 第五轮验证证据

Windows Godot 4.6.2，全部由命令行启动。

- route_planner_test、movement_test、explosives_test、round5_review_test：0 failures。
- core_test：50场固定种子完整逻辑对局，0失败。
- buildings_test、cards_test、combat_test、stocks_test、stock_integration_test、round4_review_test：0失败。
- round5_ui_test：R5_UI failures=0，专项场景用GM/状态数据构造，通过可见按钮提交动作。下拉选项由测试选定，鼠标事件触发确认。
- ui_test：UI_TEST failures=0，基础菜单、GM、建筑、银行、医院监狱和重开；截图保存在base子目录。
- full_ui_match：FULL_UI_MATCH actions=1317 rounds=21 failures=0，无GM完整20轮。没有在这一单局中自然覆盖所有新组合；组合由专项测试覆盖。

截图01路线选择，02车辆及骰面，03传送道路，04梦游，05附身炸弹，06免住院后仍毁车，07自然结算。`.log`保留相应最终运行输出。代码回归通过不等于原版数值、地图和状态时序已经还原。
