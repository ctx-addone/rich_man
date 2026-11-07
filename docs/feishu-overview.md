# 街区大亨：单机热座原型策划总纲

版本：0.1。项目工作名，非正式发行名称。本文档及同目录各分类文档描述当前可玩原型；数值用于验证玩法，不代表最终商业版本。

## 目标与边界

先还原经典地产棋盘游戏的完整体验：掷骰前进、选择路线、买地建房、支付租金、使用少量卡牌、破产退出和最终结算。用一张原创测试地图验证路口、地铁与红绿灯对路线选择的影响。不复刻任何商业作品的角色、地图、美术、台词或数值表。

第一版为 Godot 4 俯视角 2D 单机游戏，四名角色没有专属技能。所有席位由人操作，在同一台电脑轮流交接，也可以由一人控制全部席位测试。无需联网、账号或 AI 行为树。单机热座不等于单人战役；独立 PVE 挑战关卡留待后续版本。

## 完整体验路径

主菜单 → 地图选择（一张地图）→ 角色与席位设置 → 对局 → 结果排名 → 重开或回主菜单。

局内反复执行：交接当前玩家 → 可选卡牌操作 → 掷骰 → 按步数移动及路口选路 → 落点处理 → 结束回合 → 下一玩家。最终由破产淘汰或轮次上限触发整局结算。

## 本版必须成立的体验

- 玩家能辨识当前角色、现金、所在位置、地产归属、当前轮数和当前操作阶段。
- 道路连续可走，分岔可选择；地铁和信号灯规则在操作时清楚可见。
- 买地、升级和租金产生可追溯的资金变化，资产归属不会丢失或重复。
- 卡牌有合法使用时机与明确反馈，不需要角色技能系统。
- 任一可达状态都能继续行动或结束比赛，不因资产不足、破产或红灯卡死。
- GM 可以快速构造租金、破产、地铁、路口和结算场景。

## 暂不制作

在线联机、自动匹配、AI、独立剧情/PVE、股票市场、复杂商业建筑、角色天赋、长线养成、付费系统和正式 3D 素材。后续 3D 化复用对局数据与规则，重做场景表现和镜头。

## 分类文档

1. [功能与流程](https://dcncd5jl63xs.feishu.cn/docx/OAjhdayfaoy9Vsxrm9gcIEffnEg)
2. [地图策划](https://dcncd5jl63xs.feishu.cn/docx/KG8TdQAH7oNAfsxQtphc1qT8nsf)
3. [建筑与经济](https://dcncd5jl63xs.feishu.cn/docx/DRNUdF3ucoZyKMx9ZxvcMZupnjy)
4. [角色与卡牌](https://dcncd5jl63xs.feishu.cn/docx/ByANdMVo5oCHNVxlHAKcHtk5nFe)
5. [GM与验收](https://dcncd5jl63xs.feishu.cn/docx/Vb0Zd90L9ofwgmxT6eic7Rkpnpd)
6. [基础美术素材](https://dcncd5jl63xs.feishu.cn/docx/EwSbd3XfYoE31vxmm9DcoKVYnDQ)

## 外部交付

目标飞书目录：<https://dcncd5jl63xs.feishu.cn/wiki/YhkJwzoYfimqWMksQPRccTVanlc>。本地 Markdown 为可审阅、可导入的版本；是否已同步飞书以交付记录为准，本文不表示已经写入外部服务。

Figma 仅允许使用经确认的 `dynamic08triumph@gmail.com` 账号。本版允许以程序绘制的方块与色彩替代正式美术，不使用或修改 `Houkai.dynamic` 账号下文件。
