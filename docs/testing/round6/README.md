# 第六轮验证证据

2026-11-08，Godot 4.6.2，1440×900。全部通过后提交。

- 15项逻辑套件：characters、gods、round6_review、core（50局）、buildings、cards、combat、stocks、stock_integration、route_planner、movement、explosives、round4_review、round5_review、board_model；0失败。
- round6_ui_test：默认天赋/神仙、角色选择、GM附身时长与奖励、神眷目标、5卡合成、绿化、换屋、图鉴及结算；真实鼠标输入，0失败。
- full_ui_match：默认启用天赋/神仙，从菜单进入20轮对局，自然结算，无GM；actions=1471，rounds=21，failures=0。

01—05截图是新功能验证；07为自然对局结算。UI测试会直接构造部分卡牌和地产状态，不是纯自然流程；full_ui_match单独验证无GM完整闭环。旧界面回归使用中性开关，避免随机神仙改变固定场景。测试不证明全部原版规则或全部卡牌组合一致。
