# 第十一轮测试证据

2026-11-08，Godot 4.6.2，Windows，渲染UI使用GL Compatibility、1440×900。通过命令行执行，没有操作Godot编辑器。

- model-results.json：30套模型测试，退出码全部0，脚本错误全部0。默认地图布局指纹、50场核心长局、团队/AI/反应/卡牌/服务等回归通过。
- map_catalog_test.log：非法加载原子性、非零起点、不同尺寸、多银行/商店/乐透、医院/监狱独立出口，以及默认图原地释放兼容。
- round11_save_test.log：真实v1/v2/v3文件哈希和原字段/RNG/股市/元数据保留；120动作历史续演、v4服务中断保存与500动作双续演、43项非法数据拒绝。针对审查发现的静态地产配置覆盖和空出口字段注入均有回归。
- ui.log：地图目录、研究地图禁选、实际标题、非法开局保留当前局、存读档、无GM的10轮上限全电脑自然结算、相同地图重开；failures=0，frames=220。
- 01-map-selection.png、02-loaded-map.png、03-natural-results.png：已目视检查地图选择、恢复局内和自然结算，没有布局溢出。

存档校验最后修复后重跑save_test、round8_save_review_test、round9_save_test、round10_save_test、round11_save_test和渲染UI，以上结果为最终版本。

测试只能证明实现与明确的测试契约一致；不能证明当前经济数值、骑士庄园路线或全部原作设施规则已还原。本轮没有导出安装包，JSON运行资源的导出包含规则仍需在首次导出时验收。
