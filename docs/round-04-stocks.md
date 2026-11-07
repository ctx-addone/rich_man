# 第四轮：独立股票模型

已核实：11代本地比赛支持股票，使用银行存款投资。依据见 [经济研究 B02/B03](https://dcncd5jl63xs.feishu.cn/wiki/YW57wzRQSiTST8kB7nBcj9vWnDe)。其余下列数值与策略全部是可替换的**测试参数，不是原版数值**。

## 测试规则

- 四家虚构测试企业：谷物、工具、运输、能源，初价40/65/90/120。
- 每完整全局轮刷新一次，各股独立均匀整数变动 −10～+10，价格限制1～1000。初始第1轮不刷新；拒绝重复、倒退或跳轮刷新。
- 不收手续费；每家公司每位玩家最多100000股；只接受正整数类型，不自动截断浮点数。不存在融券或负持仓。
- 买卖以当轮报价即时结算银行存款，不改变现金。存款技术上限9×10^15用于防整数溢出。
- 当前股数×当前报价计入净资产。清算接口按目录顺序卖出足以覆盖缺口的最少整数股，可能多卖不足一股价格的金额；不足时全部卖出。款项进入存款，由调用方决定如何提款和其他资产清偿顺序。此顺序未核实为11代规则。
- 每股保存最近30轮价格，交易账本保留最近200笔；当前持仓不依赖历史账本重建。

## 集成接口

`stock_market.gd` 为独立 RefCounted。`setup(seed_value)`清理报价/账本并设置第1轮，非零seed可重现；玩家股票在`player.stocks`字典，主游戏新局必须重新创建玩家持仓。

- `quotes[id]`：`name, price, previous, history`，history为整数价格数组。
- `advance(round_number)->bool`：仅接受严格下一轮，主游戏全局轮边界调用一次。
- `can_trade(player, stock_id, quantity, buying)->bool`：检查账户、余额、持仓与份额；操作阶段由主游戏控制。
- `buy/sell(player, stock_id, quantity, round_number)->bool`：检查成功后原子更新存款和持仓，无效交易不变更账户或账本。
- `value(player)->int`：现价估值。
- `liquidate(player, needed, round_number)->int`：新增存款金额；`needed`指新增资金缺口，不是目标总存款。
- `ledger`记录`player, player_id, round, stock_id, side, quantity, price, amount`。`side`为`buy/sell/liquidate`；`amount`为正的成交金额，费用为零。同名玩家使用`player_id`区分。

独立市场随机数不消耗主游戏骰子随机流。对外字段可供UI读取，主游戏不应直接改报价或持仓。进入市场面板不刷新价格。可交易阶段、设施限制和整体破产清算优先级由主游戏配置并标记测试规则。

## 验证

`tests/stocks_test.gd`覆盖存款守恒、现金不变、部分卖出、非法数量/超额/无持仓/破产拒绝、无效请求无副作用、持仓上限、1000轮seed一致性、历史/账本长度、价格上下限、清算最小股数与不足清算，以及新局市场重置。
