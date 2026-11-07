# 第七轮验证证据

2026-11-08，Godot 4.6.2；UI输出1440×900。

- 18项逻辑套件均0失败：money、god_interactions、round7_review、characters、gods、round6_review、core（50局）、buildings、cards、combat、stocks、stock_integration、route_planner、movement、explosives、round4_review、round5_review、board_model。
- round4_ui_test、round6_ui_test、round7_ui_test分别覆盖旧攻防交接、角色与神仙、新金损及GM配置，均0失败。三目录保留兼容回归截图；当前轮截图00—04为新功能。
- full_ui_match无GM自然结算，actions=1330，rounds=21，failures=0；07为自然结算截图。

金损测试覆盖延期扣款、阈值两侧、拒用、免费、转移收款不变、防循环、转移后防御、自付无清偿、破产后清队列、酒店费用与住宿分离、多个地块继续和混合金损/住院事件。神仙测试覆盖他人附身、免疫、新宿主天赋、路径清神、六配方及容量边界。GM在未决反应中不能修改地产。

测试只证明当前实现按模型运行。原版阈值、费用范围、神仙返回规则、全部模式、全部地图和NPC未由这些用例证明。旧卡牌测试中的“免费未实现”和“满手拾取必拒绝”已按新增行为修正。
