class_name RichCardsCatalog
extends RefCounted

# implemented means executable provisional rules, not verified original fidelity.
const NAMES = {
  "god_bless": "神眷卡",
  "green": "绿化卡",
  "send_god": "送神卡",
  "invite_god": "请神卡",
  "magic": "魔术卡",
  "monster": "怪兽卡",
  "swap_house": "换屋卡",
  "buy_land": "购地卡",
  "same_fate": "同命卡",
  "transfer": "转移卡",
  "immune": "无懈卡",
  "missile": "飞弹卡",
  "hibernate": "冬眠卡",
  "rebuild": "改建卡",
  "close_street": "停业卡",
  "bulldozer": "工程车卡",
  "dice": "遥控骰子卡",
  "roadblock": "路障卡",
  "mine": "地雷卡",
  "audit": "查账卡",
  "equal_pair": "均贫卡",
  "equal_all": "均富卡",
  "steal": "拾取卡",
  "scheme": "谋划卡",
  "raise_rent": "涨价卡",
  "worker": "机器工人卡",
  "portal": "随意门卡",
  "glory": "辉煌卡",
  "misery": "窘困卡",
  "disaster": "灾祸卡",
  "turtle": "乌龟卡",
  "stay": "停留卡",
  "reverse": "转向卡",
  "sleepwalk": "梦游卡",
  "motorbike": "机车卡",
  "car": "汽车卡",
  "super_dice": "超级骰子卡",
  "teleport": "传送卡",
  "robot": "机器娃娃卡",
  "banana": "香蕉皮卡",
  "trap": "陷阱卡",
  "jelly": "果冻墙卡",
  "quantum": "量子飞弹卡",
  "rapid_missile": "急速弹卡",
  "activate": "启动卡",
  "timebomb": "定时炸弹卡",
  "explosive": "炸药卡"
}
const DESCRIPTIONS = {
  "god_bless": "指定场上地面神仙附身；附身他人的神仙目标尚未接入。",
  "green": "清全场道具、神仙，包括附身神仙与炸弹（11代社区证据）。",
  "send_god": "移除周围角色或自己的神仙/定时炸弹。",
  "invite_god": "最近地面神仙附身；平距按地图顺序，测试规则。",
  "magic": "与附近角色平均剩余手牌，随机分配，奇数留目标；时序为测试规则。",
  "monster": "指定街道建筑降低1级。",
  "swap_house": "交换当前位置房屋与附近己方至少1级住宅或连锁店，土地所有权不变；交换等级研究为测试规则。",
  "buy_land": "市价强购附近对手地产，建筑保留；价格及资格为测试规则。",
  "same_fate": "反应谋划/冬眠/梦游时自己仍受效果，施卡者同受；无递归反击，规则待核验。",
  "transfer": "反应时将住院/入狱转给另一个未命中且无状态角色；无金钱转嫁，规则待核验。",
  "immune": "反应时可拒用或免除一次住院/入狱；建筑损伤独立结算，规则待核验。",
  "missile": "选道路爆炸使测试半径1内角色住院1次行动、临街建筑降1层，连爆地雷/炸药；载具独立毁坏，无热斗。",
  "hibernate": "指定对手冬眠2次行动；计时及目标资格尚待核验。",
  "rebuild": "选择附近一块地产及新建筑类型，保留等级并清除旧研究。 范围、计时及边界为测试规则。",
  "close_street": "所选地产整街停业5轮。 范围、计时及边界为测试规则。",
  "bulldozer": "选择附近一块地产降低1级。 范围、计时及边界为测试规则。",
  "dice": "选择下一次路线及落点，总步数范围为当前骰数至骰数×6。 范围、计时及边界为测试规则。",
  "roadblock": "道路放路障；经过者停止剩余移动并结算落点。 范围、计时及边界为测试规则。",
  "mine": "道路放地雷；测试半径1内角色住院2次行动，临街建筑降1层并连爆；载具独立毁坏，暂无热斗。 范围、计时及边界为测试规则。",
  "audit": "获得附近对手现金的15%，向下取整。 范围、计时及边界为测试规则。",
  "equal_pair": "与附近指定对手平均现金，奇数余款留给目标。 范围、计时及边界为测试规则。",
  "equal_all": "场上未破产且未离场角色平均现金，余款按席位分配。 范围、计时及边界为测试规则。",
  "steal": "从附近对手随机取1张牌；自己满8张时不能使用。 范围、计时及边界为测试规则。",
  "scheme": "附近指定对手入狱2次行动。 范围、计时及边界为测试规则。",
  "raise_rent": "所选地产整街租金翻倍6轮。 范围、计时及边界为测试规则。",
  "worker": "选择附近己方一块地产增加1级。 范围、计时及边界为测试规则。",
  "portal": "放置一次性传送门；踩中随机转移至另一道路并结束移动。 范围、计时及边界为测试规则。",
  "glory": "自己全部地产租金翻倍12轮。 范围、计时及边界为测试规则。",
  "misery": "其他玩家全部地产停业6轮。 范围、计时及边界为测试规则。",
  "disaster": "其他玩家全部建筑降低4级，最低0级。 范围、计时及边界为测试规则。",
  "turtle": "3次移动每次1步；遥控可覆盖。 范围、时序、优先级为测试规则，未实机核验。",
  "stay": "下一次行动原地停留，不重放落点。 范围、时序、优先级为测试规则，未实机核验。",
  "reverse": "周围角色反向 范围、时序、优先级为测试规则，未实机核验。",
  "sleepwalk": "2次自动移动，禁出牌、交易、银行及购建；仍付普通租金。 范围、时序、优先级为测试规则，未实机核验。",
  "motorbike": "可用骰子数上限 2 范围、时序、优先级为测试规则，未实机核验。",
  "car": "可用骰子数上限 3 范围、时序、优先级为测试规则，未实机核验。",
  "super_dice": "向前或向后选目的地 范围、时序、优先级为测试规则，未实机核验。",
  "teleport": "指定附近角色到指定道路，不立即触发事件，继续原行动。 范围、时序、优先级为测试规则，未实机核验。",
  "robot": "选择前方10步路径，清沿途道路物件。 范围、时序、优先级为测试规则，未实机核验。",
  "banana": "踩到前滑 1 步 范围、时序、优先级为测试规则，未实机核验。",
  "trap": "触碰停止，并在下一次行动原地停留1次。 范围、时序、优先级为测试规则，未实机核验。",
  "jelly": "触碰转向后移动2步替代剩余步数。 范围、时序、优先级为测试规则，未实机核验。",
  "quantum": "测试图距离半径1内建筑夷平、角色住院5次行动，并引爆地雷及炸药；保留地权，未实现热斗，范围与时序待核验。",
  "rapid_missile": "向道路上的对手位置发弹，同格共用爆点；测试半径1、住院3次行动、建筑降1层并连爆。未实现热斗，叠加规则待核验。",
  "activate": "引爆测试半径1内已建模的地面炸物和附身炸弹；没有对象时不耗牌。地图机关尚未实现，范围和时序待核验。",
  "timebomb": "经过附身，30个实际道路步后爆炸；追上无弹角色时传递，住院4次行动、建筑降2层。未实现热斗，计步边界待核验。",
  "explosive": "触碰或被连爆引爆，测试半径1内住院8次行动，毁车；当前不损坏建筑，也不继续传播。未实现热斗，范围与时序待核验。"
}
const TARGETS = {
  "god_bless": "god",
  "green": "none",
  "send_god": "player",
  "invite_god": "none",
  "magic": "player",
  "monster": "lot",
  "swap_house": "lot_pair",
  "buy_land": "lot",
  "same_fate": "reaction",
  "transfer": "reaction",
  "immune": "reaction",
  "missile": "road",
  "hibernate": "player",
  "rebuild": "lot",
  "close_street": "lot",
  "bulldozer": "lot",
  "dice": "dice",
  "roadblock": "road",
  "mine": "road",
  "audit": "player",
  "equal_pair": "player",
  "equal_all": "none",
  "steal": "player",
  "scheme": "player",
  "raise_rent": "lot",
  "worker": "lot",
  "portal": "road",
  "glory": "none",
  "misery": "none",
  "disaster": "none",
  "turtle": "player",
  "stay": "player",
  "reverse": "player",
  "sleepwalk": "player",
  "motorbike": "none",
  "car": "none",
  "super_dice": "dice",
  "teleport": "player_road",
  "robot": "none",
  "banana": "road",
  "trap": "road",
  "jelly": "road",
  "quantum": "road",
  "rapid_missile": "none",
  "activate": "road",
  "timebomb": "road",
  "explosive": "road"
}
const ALL = {
  "buy_land": {
    "number": 1,
    "name": "购地卡",
    "description": "按市价强购，包含地上房产",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "范围、付款与受款方、大型地产限制",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "市价强购附近对手地产，建筑保留；价格及资格为测试规则。"
  },
  "swap_house": {
    "number": 2,
    "name": "换屋卡",
    "description": "交换房屋",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "两个目标资格、土地所有权是否不变",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "交换当前位置房屋与附近己方至少1级住宅或连锁店，土地所有权不变；交换等级研究为测试规则。"
  },
  "rebuild": {
    "number": 3,
    "name": "改建卡",
    "description": "住宅与连锁店互改；大型地产可换项目",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "等级保留、费用",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选择附近一块地产及新建筑类型，保留等级并清除旧研究。 范围、计时及边界为测试规则。"
  },
  "close_street": {
    "number": 4,
    "name": "停业卡",
    "description": "指定整街停业 5 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "与“查封卡”名称映射、功能建筑是否停工",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "所选地产整街停业5轮。 范围、计时及边界为测试规则。"
  },
  "bulldozer": {
    "number": 5,
    "name": "工程车卡",
    "description": "周围房屋降 1 层",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "单地块选择、空地与大型建筑处理",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选择附近一块地产降低1级。 范围、计时及边界为测试规则。"
  },
  "monster": {
    "number": 6,
    "name": "怪兽卡",
    "description": "指定街道房屋降 1 层",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "街道内不同所有者均受影响与否",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "指定街道建筑降低1级。"
  },
  "dice": {
    "number": 7,
    "name": "遥控骰子卡",
    "description": "可控点数/移动步数",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "多骰时选择方式；绝非固定走 6 格",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选择下一次路线及落点，总步数范围为当前骰数至骰数×6。 范围、计时及边界为测试规则。"
  },
  "turtle": {
    "number": 8,
    "name": "乌龟卡",
    "description": "每次走 1 步，3 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "与车、遥控、梦游的优先级",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "3次移动每次1步；遥控可覆盖。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "reverse": {
    "number": 9,
    "name": "转向卡",
    "description": "周围角色反向",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "岔路前后朝向定义",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "周围角色反向 范围、时序、优先级为测试规则，未实机核验。"
  },
  "stay": {
    "number": 10,
    "name": "停留卡",
    "description": "周围角色原地 1 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "停留是否重新触发当前格",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "下一次行动原地停留，不重放落点。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "sleepwalk": {
    "number": 11,
    "name": "梦游卡",
    "description": "周围对手梦游 2 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "自动骰、路线、收费、反应卡限制",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "2次自动移动，禁出牌、交易、银行及购建；仍付普通租金。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "hibernate": {
    "number": 12,
    "name": "冬眠卡",
    "description": "指定角色冬眠 2 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "不是旧作全体冬眠；状态刷新/叠加",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "指定对手冬眠2次行动；计时及目标资格尚待核验。"
  },
  "roadblock": {
    "number": 13,
    "name": "路障卡",
    "description": "路面放障碍，碰到停步",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "消耗、叠放、停步后地块结算",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "道路放路障；经过者停止剩余移动并结算落点。 范围、计时及边界为测试规则。"
  },
  "mine": {
    "number": 14,
    "name": "地雷卡",
    "description": "传统：住院 2 天、范围建筑降 1 层、连爆；热斗：现金损失并连爆",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "爆炸范围与热斗金额",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "道路放地雷；测试半径1内角色住院2次行动，临街建筑降1层并连爆；载具独立毁坏，暂无热斗。 范围、计时及边界为测试规则。"
  },
  "timebomb": {
    "number": 15,
    "name": "定时炸弹卡",
    "description": "附身后 30 步倒计时，可追上传递；传统爆炸住院 4 天、建筑降 2 层；热斗损失现金",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "传递条件、移动方式扣步、爆炸范围",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "经过附身，30个实际道路步后爆炸；追上无弹角色时传递，住院4次行动、建筑降2层。未实现热斗，计步边界待核验。"
  },
  "missile": {
    "number": 16,
    "name": "飞弹卡",
    "description": "指定地点；传统住院 1 天、范围降 1 层并连爆；热斗扣现金并连爆",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "范围、热斗金额",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选道路爆炸使测试半径1内角色住院1次行动、临街建筑降1层，连爆地雷/炸药；载具独立毁坏，无热斗。"
  },
  "invite_god": {
    "number": 17,
    "name": "请神卡",
    "description": "请离自己最近的神仙",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "最近的图距离定义、平距处理",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "最近地面神仙附身；平距按地图顺序，测试规则。"
  },
  "send_god": {
    "number": 18,
    "name": "送神卡",
    "description": "移除周围角色的神仙或定时炸弹",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "移除后的地图落点",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "移除周围角色或自己的神仙/定时炸弹。"
  },
  "free": {
    "number": 19,
    "name": "免费卡",
    "description": "达到一定损失阈值时，可免除损失",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": false,
    "unknowns": [
      "阈值、费用类别、反应窗口；不能简化成预挂租金盾",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "not_implemented",
    "implementation_note": "尚未实现，不进入活动卡池。"
  },
  "audit": {
    "number": 20,
    "name": "查账卡",
    "description": "获取指定对手现金的 15%",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "取整、存款不在文字目标内",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "获得附近对手现金的15%，向下取整。 范围、计时及边界为测试规则。"
  },
  "equal_pair": {
    "number": 21,
    "name": "均贫卡",
    "description": "与周围指定角色平均现金",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "奇数取整、可选队友",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "与附近指定对手平均现金，奇数余款留给目标。 范围、计时及边界为测试规则。"
  },
  "equal_all": {
    "number": 22,
    "name": "均富卡",
    "description": "场上角色平均现金",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "离场/破产角色参与规则",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "场上未破产且未离场角色平均现金，余款按席位分配。 范围、计时及边界为测试规则。"
  },
  "steal": {
    "number": 23,
    "name": "拾取卡",
    "description": "从周围指定对手随机取 1 卡",
    "source": "https://gl.ali213.net/html/2022-10/934689_19.html",
    "implemented": true,
    "unknowns": [
      "空手、满手、队友资格",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "从附近对手随机取1张牌；自己满8张时不能使用。 范围、计时及边界为测试规则。"
  },
  "scheme": {
    "number": 24,
    "name": "谋划卡",
    "description": "周围指定对手入狱 2 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "与无懈/转移的响应顺序",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "附近指定对手入狱2次行动。 范围、计时及边界为测试规则。"
  },
  "same_fate": {
    "number": 25,
    "name": "同命卡",
    "description": "反击梦游、冬眠、谋划，使施卡者同受效果",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "是否要主动选择、状态消耗顺序",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "反应谋划/冬眠/梦游时自己仍受效果，施卡者同受；无递归反击，规则待核验。"
  },
  "transfer": {
    "number": 26,
    "name": "转移卡",
    "description": "入狱、住院或达到阈值的金钱损失可转嫁",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "金额阈值、目标选择、同次多类损失处理",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "反应时将住院/入狱转给另一个未命中且无状态角色；无金钱转嫁，规则待核验。"
  },
  "immune": {
    "number": 27,
    "name": "无懈卡",
    "description": "免除一次入狱或住院",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "同一爆炸中的建筑损害仍否发生",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "反应时可拒用或免除一次住院/入狱；建筑损伤独立结算，规则待核验。"
  },
  "banana": {
    "number": 28,
    "name": "香蕉皮卡",
    "description": "踩到前滑 1 步",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "滑动后的连续触发与炸弹步数",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "踩到前滑 1 步 范围、时序、优先级为测试规则，未实机核验。"
  },
  "trap": {
    "number": 29,
    "name": "陷阱卡",
    "description": "路过停止且麻痹不能移动",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "麻痹时长、是否允许出牌",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "触碰停止，并在下一次行动原地停留1次。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "raise_rent": {
    "number": 30,
    "name": "涨价卡",
    "description": "指定街道租金 ×2，6 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "与辉煌、物价、天赋叠加",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "所选地产整街租金翻倍6轮。 范围、计时及边界为测试规则。"
  },
  "robot": {
    "number": 31,
    "name": "机器娃娃卡",
    "description": "清前方 10 步障碍",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "岔路、神仙、地图机关是否在清除集合",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选择前方10步路径，清沿途道路物件。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "worker": {
    "number": 32,
    "name": "机器工人卡",
    "description": "周围己方地块加 1 层",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "队友、上限、特殊建筑",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "选择附近己方一块地产增加1级。 范围、计时及边界为测试规则。"
  },
  "quantum": {
    "number": 33,
    "name": "量子飞弹卡",
    "description": "传统：范围建筑清空、住院 5 天、连爆；热斗：范围巨额现金损失并连爆",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "范围、所有权是否保留、金额",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "测试图距离半径1内建筑夷平、角色住院5次行动，并引爆地雷及炸药；保留地权，未实现热斗，范围与时序待核验。"
  },
  "explosive": {
    "number": 34,
    "name": "炸药卡",
    "description": "碰到引爆；传统住院 8 天；热斗扣现金",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "建筑/连爆行为、金额",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "触碰或被连爆引爆，测试半径1内住院8次行动，毁车；当前不损坏建筑，也不继续传播。未实现热斗，范围与时序待核验。"
  },
  "super_dice": {
    "number": 35,
    "name": "超级骰子卡",
    "description": "向前或向后选目的地",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "C 补证为 1–6 步，向后会转向；需实机",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "向前或向后选目的地 范围、时序、优先级为测试规则，未实机核验。"
  },
  "jelly": {
    "number": 36,
    "name": "果冻墙卡",
    "description": "碰到后弹回 2 步",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "是否改变朝向、连锁触发",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "触碰转向后移动2步替代剩余步数。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "portal": {
    "number": 37,
    "name": "随意门卡",
    "description": "放门，踩到移往别处",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "C 名“传送门卡”：随机任一路格；需核名称",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "放置一次性传送门；踩中随机转移至另一道路并结束移动。 范围、计时及边界为测试规则。"
  },
  "teleport": {
    "number": 38,
    "name": "传送卡",
    "description": "指定角色移至指定地点",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "目标范围、终点结算、状态保留",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "指定附近角色到指定道路，不立即触发事件，继续原行动。 范围、时序、优先级为测试规则，未实机核验。"
  },
  "motorbike": {
    "number": 39,
    "name": "机车卡",
    "description": "可用骰子数上限 2",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "可选 1/2 骰、与汽车替换、失去条件",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "可用骰子数上限 2 范围、时序、优先级为测试规则，未实机核验。"
  },
  "car": {
    "number": 40,
    "name": "汽车卡",
    "description": "可用骰子数上限 3",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "可选骰数、与异常状态的优先级",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "可用骰子数上限 3 范围、时序、优先级为测试规则，未实机核验。"
  },
  "magic": {
    "number": 41,
    "name": "魔术卡",
    "description": "与周围指定角色平均手牌",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "奇数、随机分配、合成触发时机",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "与附近角色平均剩余手牌，随机分配，奇数留目标；时序为测试规则。"
  },
  "rapid_missile": {
    "number": 42,
    "name": "急速弹卡",
    "description": "向每位对手处发弹；传统住院 3 天、降 1 层、连爆；热斗大量扣现",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "“极速弹/急速飞弹”名称、重叠爆炸",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "向道路上的对手位置发弹，同格共用爆点；测试半径1、住院3次行动、建筑降1层并连爆。未实现热斗，叠加规则待核验。"
  },
  "glory": {
    "number": 43,
    "name": "辉煌卡",
    "description": "己方全部地产租金 ×2，12 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "己方是否包含队友",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "自己全部地产租金翻倍12轮。 范围、计时及边界为测试规则。"
  },
  "misery": {
    "number": 44,
    "name": "窘困卡",
    "description": "所有对手地产停业 6 天",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "功能型建筑影响",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "其他玩家全部地产停业6轮。 范围、计时及边界为测试规则。"
  },
  "green": {
    "number": 45,
    "name": "绿化卡",
    "description": "清全场道具与神仙",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "附身神仙/炸弹与地图机关是否清除",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "清全场道具、神仙，包括附身神仙与炸弹（11代社区证据）。"
  },
  "disaster": {
    "number": 46,
    "name": "灾祸卡",
    "description": "对手全部房屋降 4 层",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "等级下限、连锁与大型建筑",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "其他玩家全部建筑降低4级，最低0级。 范围、计时及边界为测试规则。"
  },
  "god_bless": {
    "number": 47,
    "name": "神眷卡",
    "description": "在场神仙随你邀请（定向请神）",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "附身神仙是否参与、分配目标集合",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "指定场上地面神仙附身；附身他人的神仙目标尚未接入。"
  },
  "activate": {
    "number": 48,
    "name": "启动卡",
    "description": "触发范围内附身炸弹与机关",
    "source": "https://gl.ali213.net/html/2022-10/934689_20.html",
    "implemented": true,
    "unknowns": [
      "选择地格后作用半径、执行顺序",
      "范围、计时、叠加和目标资格未实机核验"
    ],
    "status": "implemented_provisional",
    "implementation_note": "引爆测试半径1内已建模的地面炸物和附身炸弹；没有对象时不耗牌。地图机关尚未实现，范围和时序待核验。"
  }
}
