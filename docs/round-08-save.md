# 第八轮：安全存档与精确恢复

存档是本地独立文件列表，由主界面每次生成新文件；不假定原版有固定槽数。原作单人可保存、每次生成新条目的二手证据见本轮研究；允许保存的具体阶段仍未知。本项目允许每个同步命令完成后的稳定阶段，包括行走选择、银行、商店、反应窗口和结算。函数执行到一半的内部奖励状态拒绝保存。

## 接口

- snapshot(game,metadata={})：深拷贝完整模型快照。
- restore(snapshot)：返回 {ok,error,game,metadata}；验证后创建新的Game，永不修改调用方当前局。
- save_to_file(game,path,metadata={})：返回 {ok,error}。UI负责动态文件名与标题。
- load_from_file(path)：验证并恢复新Game。
- peek_file(path)：完整校验后只返回 metadata、round_number、phase、current、player_name，适合列表展示，不使用或推进当前局的随机数。

metadata由主界面保存席位控制方式、原创头像、GM标记、强制骰、交接、反应确认、选择状态等，并在读回时单独验证；核心对metadata只允许普通数据，禁止对象/脚本资源。

## 格式与一致性

版本1使用Godot普通Variant二进制，不是JSON。64位整数RNG seed/state与字典整数道路key、Vector2、Rect2i、typed Array保持原类型。骰子和股票拥有独立随机数状态，两者分别恢复。bytes_to_var不启用对象加载；文件带魔数、长度、SHA256校验且上限16MiB，拒绝损坏、未知版本、未知地图结构、错误玩家/地块/道路引用、卡牌及反应状态。

保存所有脚本变量，除board_model、stock_market和rng对象外分别序列化普通状态。地图结构当前按已知布局重建校验，恢复后board_model.lots与game.lots重新共享同一字典，避免买卖只改一份产权。原型地图改变时需要迁移或提升schema；不承诺任意未来版本向前兼容。

写入先生成.writing文件、flush、重新读取校验。已有目标先移到唯一backup再替换，失败恢复；成功才删除backup。异常失败不会先截断原文件。突然断电发生在换名步骤中可能留下backup，需要人工恢复；不宣称跨平台断电事务保证。SHA256用于检测损坏，不用于对抗用户主动修改重算校验。

## 验证

save_test覆盖初始/行走/金损反应快照、文件覆盖、标题控制信息、骰子和股票RNG续演一致、反应恢复后只继续一次落地、非法位置与版本、损坏校验、对象metadata拒绝且原字节保留。完整10轮局在每条命令后序列化重建，230步自然完成，覆盖roll/move/land/bank/shop/end；另有独立reaction恢复测试。未用此局声称覆盖所有特殊状态组合；后续新增系统必须扩大快照校验与组合恢复测试。

独立审查补强：next_direction/glory_until/choose_junction/team等可选玩家字段单独校验；detained必须具备有效滞留状态，神仙剩余时长必须为正。restore首先深拷贝输入，两个恢复实例不共享玩家/地产/市场/metadata状态。save_test与round8_save_review均0失败，酒店待付款恢复后住宿续行一致。

复杂续演补测：遥控8步在银行暂停时存盘，剩6步与control路径恢复后正确走到13号路；真实飞弹→地雷→炸药连爆同时命中两位持防御卡玩家，至少4次防御窗口逐次恢复完全一致；医院剩2次行动的detained存盘，跳回合后恢复原路；梦游行走中存盘，继续移动并只扣1次持续。全部通过文件save/load而非仅内存clone，SAVE_TEST failures=0。
