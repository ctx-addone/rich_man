extends Control

const Game = preload("res://scripts/game_state.gd")
const Board = preload("res://scripts/board_view.gd")
const Cards = preload("res://scripts/model/cards_catalog.gd")
const COLORS = [Color("e76f51"), Color("2a9d8f"), Color("5b7cfa"), Color("a66dd4")]
const NAMES = ["赤橙", "青竹", "蓝星", "紫菀"]
var game = Game.new()
var page: Control
var board: Control
var sidebar: VBoxContainer
var top_title: Label
var score_row: HBoxContainer
var popup: Control
var portraits: Array = [0, 1, 2, 3]
var name_inputs: Array[LineEdit] = []
var player_names: Array = ["玩家 1", "玩家 2", "玩家 3", "玩家 4"]
var turns: int = 20
var screen: String = "menu"
var handoff: bool = true
var advancing: bool = false
var selected: int = -1
var selected_lot: String = ""
var forced_dice: int = 0
var gm_used: bool = false
var generation: int = 0
var reaction_ack: int = -1

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color("e6edf2"))
	t.set_color("font_color", "Button", Color("e6edf2"))
	t.set_color("font_disabled_color", "Button", Color("6d8190"))
	t.set_stylebox("normal", "Button", style(Color("1c3446")))
	t.set_stylebox("hover", "Button", style(Color("2c5268")))
	t.set_stylebox("pressed", "Button", style(Color("366477")))
	t.set_stylebox("disabled", "Button", style(Color("142532")))
	t.set_stylebox("focus", "Button", style(Color(0,0,0,0), Color("e9c46a")))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	theme = t
	menu()

func style(color: Color, border := Color(0,0,0,0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func clear_page() -> VBoxContainer:
	generation += 1
	advancing = false
	if is_instance_valid(page): page.queue_free()
	close_popup()
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 26)
	page = margin
	var v := VBoxContainer.new()
	margin.add_child(v)
	return v

func label(text: String, size_font: int = 16, color := Color("e6edf2")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_font)
	l.add_theme_color_override("font_color", color)
	return l

func paragraph(text: String, size_font: int = 16) -> Label:
	var l := label(text, size_font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.disabled = disabled
	b.pressed.connect(callback)
	return b

func panel(parent: Node, color := Color("102535")) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color))
	parent.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	return v

func spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func menu() -> void:
	screen = "menu"
	var v := clear_page()
	v.add_child(label("RICH MAN  /  LOCAL TABLETOP", 16, Color("e9c46a")))
	spacer(v)
	v.add_child(label("街区大亨", 68))
	v.add_child(label("掷骰出发。购置地产。让每一步成为机会。", 24, Color("a7bac8")))
	v.add_child(label("单机热座 · 四人轮流操作 · 经典地产棋盘原型", 18))
	var row := HBoxContainer.new()
	v.add_child(row)
	for i in range(4):
		var p := panel(row)
		p.add_child(portrait(i, Vector2(120, 140)))
		p.add_child(label(NAMES[i], 18, COLORS[i]))
	var start := button("开始游戏  →", map_select)
	start.custom_minimum_size.x = 320
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(start)
	var help := button("玩法说明", show_help)
	help.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(help)
	spacer(v)
	v.add_child(label("v0.4 开发版  ·  股票与攻防结算  /  同机热座  /  F1 测试工具", 14, Color("7f9aab")))

func portrait(index: int, dimensions: Vector2) -> Control:
	var path := "res://assets/characters/player_%d.svg" % (index + 1)
	if ResourceLoader.exists(path):
		var image := TextureRect.new()
		image.texture = load(path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = dimensions
		return image
	var block := ColorRect.new()
	block.color = COLORS[index]
	block.custom_minimum_size = dimensions
	return block

func map_select() -> void:
	screen = "map"
	var v := clear_page()
	v.add_child(label("01  /  选择地图", 32))
	v.add_child(label("市民街区 · 系统验证地图", 26, Color("e9c46a")))
	v.add_child(label("独立道路与多格建筑  ·  银行  ·  医院  ·  监狱  ·  商店"))
	var preview = Board.new()
	var sample = Game.new()
	sample.setup(player_names)
	preview.game = sample
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(preview)
	v.add_child(paragraph("本图用于验证多入口建筑、银行与特殊场所，不是原版地图。当前经济参数及部分状态规则仍在核验。", 16))
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(button("← 返回", menu))
	row.add_child(button("选择角色 →", character_select))

func character_select() -> void:
	screen = "characters"
	var v := clear_page()
	v.add_child(label("02  /  选择角色", 32))
	v.add_child(label("固定四个真人席位 · 可由一人扮演全部角色 · 外观不同，能力相同", 18, Color("a7bac8")))
	spacer(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	name_inputs.clear()
	for i in range(4):
		var col := panel(row)
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(label("席位 %d" % (i + 1), 18, COLORS[portraits[i]]))
		col.add_child(portrait(portraits[i], Vector2(180, 210)))
		col.add_child(label(NAMES[portraits[i]] + " · 无技能", 22))
		var input := LineEdit.new()
		input.text = player_names[i]
		input.max_length = 12
		col.add_child(input)
		name_inputs.append(input)
		col.add_child(button("更换外观 ↻", func():
			capture_names()
			var next: int = (portraits[i] + 1) % 4
			var other: int = portraits.find(next)
			portraits[other] = portraits[i]
			portraits[i] = next
			character_select()))
	spacer(v)
	v.add_child(label("每人初始现金 10,000 · 起点奖励 1,000 · 最后存活或轮数结束时资产最高者获胜"))
	var controls := HBoxContainer.new()
	v.add_child(controls)
	controls.add_child(button("← 地图", func(): capture_names(); map_select()))
	controls.add_child(label("对局轮数"))
	var rounds := OptionButton.new()
	for n in [10, 20, 30]: rounds.add_item(str(n) + " 轮", n)
	rounds.select([10,20,30].find(turns))
	rounds.item_selected.connect(func(index): turns = rounds.get_item_id(index))
	controls.add_child(rounds)
	controls.add_child(button("开始对局 →", func(): capture_names(); start_game()))

func capture_names() -> void:
	for i in range(name_inputs.size()):
		if is_instance_valid(name_inputs[i]):
			var n := name_inputs[i].text.strip_edges()
			player_names[i] = n if not n.is_empty() else "玩家 %d" % (i+1)

func start_game() -> void:
	game = Game.new()
	game.setup(player_names, 0, turns)
	selected = -1
	selected_lot = ""
	forced_dice = 0
	gm_used = false
	reaction_ack = -1
	handoff = true
	build_game()

func build_game() -> void:
	screen = "game"
	var v := clear_page()
	var header := HBoxContainer.new()
	v.add_child(header)
	top_title = label("", 24)
	top_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(top_title)
	header.add_child(button("规则", show_help))
	header.add_child(button("股票", show_stocks))
	header.add_child(button("卡牌图鉴", show_card_catalog))
	header.add_child(button("GM · F1", show_gm))
	header.add_child(button("主菜单", confirm_menu))
	score_row = HBoxContainer.new()
	v.add_child(score_row)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var board_col := VBoxContainer.new()
	board_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(board_col)
	board = Board.new()
	board.game = game
	board.player_colors = portraits
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.tile_clicked.connect(on_tile)
	board.lot_clicked.connect(on_lot)
	board_col.add_child(board)
	board_col.add_child(label("金框：可走出口  ·  圆点：玩家  ·  建筑边色：产权  ·  点击建筑查看入口与详情", 13, Color("9cb4c4")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 355
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)
	refresh()

func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func refresh() -> void:
	if screen != "game": return
	if game.phase == "finished": results(); return
	clear_children(score_row)
	for i in range(4):
		var p: Dictionary = game.players[i]
		var col := panel(score_row, Color("20394b") if i == game.current else Color("102535"))
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(label(("▶ " if i == game.current else "") + p.name + (" · 破产" if p.bankrupt else ""), 18, COLORS[portraits[i]]))
		col.add_child(label("现金 %s  存款 %s" % [p.cash, p.deposit], 14))
		col.add_child(label("资产 %s%s" % [game.net_worth(i), " · " + status_text(p) if not p.status.is_empty() else ""], 13))
	top_title.text = "市民街区   /   第 %d / %d 轮%s" % [game.round_number, game.round_limit, "  ·  GM测试局" if gm_used else ""]
	board.selected = selected
	board.selected_lot = selected_lot
	board.queue_redraw()
	clear_children(sidebar)
	var p: Dictionary = game.players[game.current]
	if game.phase == "reaction":
		show_reaction_controls()
	elif handoff:
		sidebar.add_child(label("当前操作  /  " + p.name, 22, COLORS[portraits[game.current]]))
		sidebar.add_child(paragraph("请将操作交给 %s。确认后继续当前行动。" % p.name, 20))
		sidebar.add_child(button("我已就位 · " + ("开始回合" if game.phase == "roll" else "继续行动"), func(): handoff = false; refresh()))
	else:
		sidebar.add_child(label("当前操作  /  " + p.name, 22, COLORS[portraits[game.current]]))
		sidebar.add_child(label("骰子  %s    剩余步数  %d" % ["—" if game.last_roll == 0 else str(game.last_roll), game.steps_left], 20))
		if not p.status.is_empty() and game.phase != "detained":
			sidebar.add_child(paragraph("当前%s。本次行程已结束，后续回合按提示推进状态。" % status_text(p), 16))
		match game.phase:
			"roll": sidebar.add_child(button("掷骰子" + ("  [GM: %d]" % forced_dice if forced_dice > 0 else ""), roll))
			"move":
				sidebar.add_child(paragraph("选择金框出口继续前进。" if game.available_moves().size() > 1 else "正在移动…"))
				for id in game.available_moves():
					sidebar.add_child(button("→ %02d · %s" % [id, game.nodes[id].name], func(): act_move(id)))
			"land":
				for lot_id in game.lots_at_node(p.pos):
					var lot: Dictionary = game.lots[lot_id]
					if lot.kind == "facility": continue
					if lot.owner < 0: sidebar.add_child(button("购买地产 · %s" % lot.name, func(): choose_building(lot_id, false)))
					elif lot.owner == game.current:
						sidebar.add_child(button("升级建筑 · %s · %d" % [game.building_name(lot.building_type), game.upgrade_cost(lot_id)], func(): game.upgrade_property(lot_id); refresh(), lot.level >= game.max_level(lot_id) or p.cash < game.upgrade_cost(lot_id)))
						sidebar.add_child(button("改建项目 · " + lot.name, func(): choose_building(lot_id, true)))
			"bank":
				sidebar.add_child(paragraph("银行服务\n可存入现金或提取存款。离开后继续剩余移动，不重复结算经过事件。"))
				var amount := SpinBox.new()
				amount.min_value = 0
				amount.max_value = maxi(1000, maxi(p.cash, p.deposit))
				amount.step = 1
				amount.value = 1000
				amount.prefix = "金额 "
				sidebar.add_child(amount)
				var bank_error := paragraph("", 14)
				sidebar.add_child(button("存入现金", func():
					if game.bank_transfer(int(amount.value)): refresh()
					else: bank_error.text = "现金不足，请调整金额。"))
				sidebar.add_child(button("提取存款", func():
					if game.bank_transfer(-int(amount.value)): refresh()
					else: bank_error.text = "存款不足，请调整金额。"))
				sidebar.add_child(bank_error)
				sidebar.add_child(button("离开银行 · 继续行程", func(): game.close_bank(); refresh()))
			"detained":
				sidebar.add_child(paragraph("%s\n本次无法行走或主动使用卡牌。结束回合后推进停留时间。" % status_text(p), 18))
			"shop":
				sidebar.add_child(paragraph("卡牌商店 · 本次还可买%d张\n手牌满时先弃牌；离店时结算书店奖励。" % game.shop_remaining()))
				sidebar.add_child(button("浏览商店", show_shop))
				sidebar.add_child(button("离开商店", func(): game.close_shop(); refresh()))
		if game.phase in ["land", "end", "detained"]: sidebar.add_child(button("结束回合 →", next_turn))
		var hand := panel(sidebar)
		hand.add_child(label("手牌 %d/%d · 掷骰前使用" % [p.cards.size(), Game.HAND_LIMIT], 15))
		if p.cards.is_empty(): hand.add_child(label("暂无卡牌", 14))
		for card_index in range(p.cards.size()):
			var card: String = p.cards[card_index]
			var row := HBoxContainer.new()
			hand.add_child(row)
			var reactive: bool = Game.CARD_TARGETS.get(card, "") == "reaction"
			var b := button(Game.CARD_NAMES[card] + (" · 被动应对" if reactive else ""), func(): play_card(card), game.phase != "roll" or reactive)
			b.tooltip_text = Game.CARD_DESCRIPTIONS[card]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			row.add_child(button("弃", func(): game.discard_card(card_index); refresh(), game.phase not in ["roll", "shop"]))
	var id: int = selected if selected >= 0 else p.pos
	var n: Dictionary = game.nodes[id]
	var detail := panel(sidebar)
	var detail_lots: Array = [selected_lot] if game.lots.has(selected_lot) else game.lots_at_node(id)
	if not p.status.is_empty() and selected < 0 and selected_lot.is_empty():
		detail.add_child(label("当前状态与位置", 18))
		detail.add_child(paragraph("离开后返回：%s" % game.nodes[p.status.return_pos].name, 14))
		var facility: Dictionary = game.facility_lot(p.status.kind)
		detail_lots = [p.status.lot_id] if p.status.kind == "vacation" else ([facility.id] if not facility.is_empty() else [])
	else:
		detail.add_child(label("%02d  /  %s" % [id, n.name], 18))
		detail.add_child(paragraph({"metro":"落在此处可付费换乘。", "start":"每次正常移动进入，领取1000。", "event":"停留触发奖金、费用或抽卡。", "signal":game.signal_state(id), "junction":"移动至此可选择出口，不可立即回头。"}.get(n.kind, "道路只负责行走，产权属于路旁建筑。"), 14))
	for lot_id in detail_lots:
		var lot: Dictionary = game.lots[lot_id]
		detail.add_child(label(lot.name, 18, Color("e9c46a")))
		detail.add_child(paragraph("占地 %d×%d · 临街入口 %s" % [lot.footprint.size.x, lot.footprint.size.y, ", ".join(lot.frontage_nodes)], 13))
		if lot.kind == "facility":
			detail.add_child(paragraph({"bank":"经过时可调整现金与存款。", "hospital":"受伤角色在此停留，状态到期后返回道路。", "prison":"被拘留角色在此停留，状态到期后返回道路。", "shop":"停留可购买卡牌，离店触发书店奖励。"}.get(lot.building_type, "公共设施"), 14))
		else:
			detail.add_child(paragraph("持有：%s\n类型：%s  等级：%d/%d\n资产估值：%d  租金参考：%d" % ["无主" if lot.owner < 0 else game.players[lot.owner].name, game.building_name(lot.building_type), lot.level, game.max_level(lot_id), game.lot_value(lot_id), game.rent_preview(lot_id)], 14))
			detail.add_child(paragraph(game.building_description(lot.building_type), 13))
			if lot.get("closed_until", 0) > game.round_number: detail.add_child(label("停业 · 剩余%d轮" % (lot.closed_until - game.round_number), 14, Color("f1a69c")))
			if lot.get("rent_until", 0) > game.round_number: detail.add_child(label("涨价 · 剩余%d轮" % (lot.rent_until - game.round_number), 14, Color("e9c46a")))
			if lot.owner >= 0 and game.players[lot.owner].get("glory_until", 0) > game.round_number: detail.add_child(label("持有人辉煌效果生效中", 14, Color("e9c46a")))
			if not lot.get("research", {}).is_empty(): detail.add_child(paragraph("研究：%s · %s" % [Game.CARD_NAMES.get(lot.research.card_id, lot.research.card_id), "完成待领，手牌需有空位" if lot.research.remaining == 0 else "剩余%d轮" % lot.research.remaining], 13))
			if lot.owner == game.current and lot.building_type == "lab" and not handoff:
				if lot.research.is_empty(): detail.add_child(button("安排研究", func(): choose_research(lot_id), game.phase not in ["land", "roll"] or lot.level <= 0 or lot.closed_until > game.round_number))
				elif lot.research.remaining == 0: detail.add_child(button("领取研究成果", func(): game.collect_research(lot_id); refresh(), p.cards.size() >= Game.HAND_LIMIT or game.phase not in ["land", "roll", "shop"] or lot.level <= 0 or lot.closed_until > game.round_number))
	var log_panel := panel(sidebar)
	log_panel.add_child(label("最近动态", 16))
	for j in range(maxi(0, game.logs.size() - 5), game.logs.size()): log_panel.add_child(paragraph(game.logs[j], 13))
	if not handoff and game.phase == "move" and game.available_moves().size() == 1 and not advancing:
		auto_step()

func roll() -> void:
	game.roll_dice(forced_dice)
	forced_dice = 0
	selected = -1
	selected_lot = ""
	refresh()

func auto_step() -> void:
	advancing = true
	var ticket := generation
	await get_tree().create_timer(0.22).timeout
	if ticket != generation or screen != "game": return
	advancing = false
	if popup != null: return
	var choices: Array = game.available_moves()
	if choices.size() == 1:
		game.move_to(choices[0])
		refresh()

func act_move(id: int) -> void:
	if handoff or game.phase != "move": return
	game.move_to(id)
	refresh()

func on_tile(id: int) -> void:
	selected_lot = ""
	if not handoff and game.available_moves().has(id): act_move(id)
	else:
		selected = id
		refresh()

func on_lot(id: String) -> void:
	selected_lot = id
	selected = -1
	refresh()

func status_text(p: Dictionary) -> String:
	if p.status.is_empty(): return ""
	return "%s %d回合" % [{"hospital":"住院", "prison":"入狱", "vacation":"度假", "hibernate":"冬眠"}.get(p.status.kind, "停留"), p.status.remaining]

func show_reaction_controls() -> void:
	var responder: int = game.reaction_player()
	if responder < 0: return
	var p: Dictionary = game.players[responder]
	sidebar.add_child(label("防御应对  /  " + p.name, 22, COLORS[portraits[responder]]))
	if reaction_ack != responder:
		sidebar.add_child(paragraph("请把操作交给 %s，确认后选择防御方式。当前行动者仍是 %s。" % [p.name, game.players[game.current].name], 18))
		sidebar.add_child(button("我来应对 · " + p.name, func(): reaction_ack = responder; refresh()))
		return
	sidebar.add_child(paragraph(game.reaction_description(), 17))
	sidebar.add_child(paragraph("只在确认后消耗防御卡。人物免疫或转移不会撤销已发生的建筑损害。", 14))
	for card_id in game.reaction_options():
		if card_id == "transfer":
			var choices: Array = game.reaction_targets(card_id)
			var target := OptionButton.new()
			target.name = "ReactionTarget"
			for player_id in choices: target.add_item(game.players[player_id].name)
			sidebar.add_child(target)
			sidebar.add_child(button("使用 " + Game.CARD_NAMES[card_id], func(): respond(card_id, choices[target.selected]), choices.is_empty()))
		else:
			sidebar.add_child(button("使用 " + Game.CARD_NAMES[card_id], func(): respond(card_id)))
	sidebar.add_child(button("承受效果 · 不使用防御卡", func(): respond()))

func respond(card_id: String = "", target: int = -1) -> void:
	if game.resolve_reaction(card_id, target):
		reaction_ack = -1
		if game.phase != "reaction": handoff = true
	refresh()

func scroll_content(parent: Node, height: int = 440) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	return contents

func choose_building(lot_id: String, rebuilding: bool) -> void:
	var lot: Dictionary = game.lots[lot_id]
	var v := modal(("改建项目 · " if rebuilding else "购买地产 · ") + lot.name)
	v.add_child(paragraph("选择建筑类型。当前价格及效果参数为待核验配置。", 14))
	var content := scroll_content(v)
	for kind in game.building_options(lot_id):
		var cost: int = game.rebuild_cost(lot_id, kind) if rebuilding else game.purchase_cost(lot_id, kind)
		content.add_child(button("选择 " + game.building_name(kind) + " · %d" % cost, func():
			var success: bool = game.rebuild_property(lot_id, kind) if rebuilding else game.buy_property(lot_id, kind)
			if success: dismiss(), game.players[game.current].cash < cost or (rebuilding and lot.building_type == kind)))
		content.add_child(paragraph(game.building_description(kind), 14))
	v.add_child(button("取消", dismiss))

func choose_research(lot_id: String) -> void:
	var v := modal("安排研究")
	v.add_child(paragraph("研究所等级决定可研究项目。具体卡池和研究时长仍需对照原版。", 14))
	for card in game.research_options(lot_id):
		v.add_child(button("研究 " + Game.CARD_NAMES[card] + " · %d" % game.research_cost(lot_id), func():
			if game.start_research(lot_id, card): dismiss(), game.players[game.current].cash < game.research_cost(lot_id) or not game.lots[lot_id].research.is_empty()))
	if game.research_options(lot_id).is_empty(): v.add_child(label("当前没有可启动项目，请检查研究进度。"))
	v.add_child(button("返回", dismiss))

func show_shop() -> void:
	if game.phase != "shop": return
	var v := modal("卡牌商店")
	var p: Dictionary = game.players[game.current]
	v.add_child(label("现金 %d · 手牌 %d/%d · 本次余量 %d" % [p.cash, p.cards.size(), Game.HAND_LIMIT, game.shop_remaining()]))
	if p.cards.size() >= Game.HAND_LIMIT: v.add_child(paragraph("手牌已满，请返回对局弃牌后再购买。", 14))
	var content := scroll_content(v)
	for offer in game.shop_offers():
		content.add_child(button("购买卡牌 · %s · %d" % [offer.name, offer.price], func():
			if game.buy_card(offer.id): show_shop(), p.cash < offer.price or p.cards.size() >= Game.HAND_LIMIT or game.shop_remaining() <= 0))
		content.add_child(paragraph(Game.CARD_DESCRIPTIONS[offer.id], 13))
	v.add_child(button("返回对局", dismiss))

func show_card_catalog() -> void:
	var v := modal("卡牌图鉴 · 首发48项")
	v.add_child(paragraph("收录有来源的规则目录；标记“可用”的卡牌已接入当前版本，其余尚未实现。范围、价格和部分交互仍待核验。", 14))
	var content := scroll_content(v, 480)
	for id in Cards.ALL:
		var entry: Dictionary = Cards.ALL[id]
		var item := panel(content)
		item.add_child(label("%02d  %s · %s" % [entry.number, entry.name, "可用" if entry.implemented else "待实现"], 18, Color("e9c46a") if entry.implemented else Color("9cb4c4")))
		item.add_child(paragraph(entry.description, 14))
		if not str(entry.get("implementation_note", "")).is_empty(): item.add_child(paragraph("当前实现：" + entry.implementation_note, 13))
		if not entry.unknowns.is_empty(): item.add_child(paragraph("待核验：" + "、".join(entry.unknowns), 12))
	v.add_child(button("关闭", dismiss))

func play_card(card_id: String) -> void:
	if game.phase != "roll": return
	var v := modal(Game.CARD_NAMES[card_id])
	v.add_child(paragraph(Game.CARD_DESCRIPTIONS[card_id]))
	var target_type: String = Game.CARD_TARGETS.get(card_id, "none")
	var error_label := paragraph("", 14)
	if target_type == "dice":
		var row := HBoxContainer.new()
		v.add_child(row)
		for number in range(1, 7):
			row.add_child(button(str(number), func():
				if game.use_card(card_id, -1, number): dismiss()
				else: error_label.text = "当前无法使用这张卡。"))
	elif target_type in ["player", "road", "lot"]:
		var target := OptionButton.new()
		var options: Array = game.card_targets(card_id)
		for id in options:
			target.add_item(game.players[id].name if target_type == "player" else (game.lots[id].name if target_type == "lot" else "%02d · %s" % [id, game.nodes[id].name]))
		v.add_child(target)
		var building_choice: OptionButton
		if card_id == "rebuild" and not options.is_empty():
			building_choice = OptionButton.new()
			building_choice.name = "CardBuildingChoice"
			var update_options := func():
				building_choice.clear()
				for kind in game.building_options(options[target.selected]): building_choice.add_item(game.building_name(kind))
			update_options.call()
			target.item_selected.connect(func(_index): update_options.call())
			v.add_child(building_choice)
		v.add_child(button("确认使用", func():
			if game.use_card(card_id, options[target.selected], building_choice.selected if card_id == "rebuild" else 0): dismiss()
			else: error_label.text = "目标状态已改变或不在有效范围内。", options.is_empty()))
		if options.is_empty(): error_label.text = "当前没有可用目标，卡牌不会消耗。"
	else:
		v.add_child(button("确认使用", func():
			if game.use_card(card_id): dismiss()
			else: error_label.text = "当前无法使用这张卡。"))
	v.add_child(error_label)
	v.add_child(button("取消", dismiss))

func next_turn() -> void:
	if game.end_turn():
		handoff = true
		selected = -1
		selected_lot = ""
	refresh()

func results() -> void:
	screen = "results"
	var v := clear_page()
	v.add_child(label("比赛结束", 42))
	var winner_names: Array = []
	for id in game.winners: winner_names.append(game.players[id].name)
	v.add_child(label("获胜：" + " / ".join(winner_names), 28, Color("e9c46a")))
	v.add_child(label("净资产 = 现金 + 存款 + 股票市值 + 地价 + 建筑投资成本" + ("  ·  本局使用了GM" if gm_used else ""), 16))
	var ranking := [0,1,2,3]
	ranking.sort_custom(func(a,b): return game.net_worth(a) > game.net_worth(b))
	for i in ranking:
		var p: Dictionary = game.players[i]
		var col := panel(v)
		col.add_child(label("%s    现金 %d    净资产 %d%s" % [p.name, p.cash, game.net_worth(i), "   已破产" if p.bankrupt else ""], 24, COLORS[portraits[i]]))
	spacer(v)
	v.add_child(button("相同设置 · 再来一局", start_game))
	v.add_child(button("返回主菜单", menu))

func modal(title_text: String) -> VBoxContainer:
	close_popup()
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.025,0.04,0.94)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup = shade
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body := panel(center)
	body.custom_minimum_size.x = 650
	body.add_child(label(title_text, 26, Color("e9c46a")))
	return body

func close_popup() -> void:
	if is_instance_valid(popup): popup.queue_free()
	popup = null

func dismiss() -> void:
	close_popup()
	if screen == "game": refresh()

func show_help() -> void:
	var v := modal("玩法说明")
	v.add_child(paragraph("1. 四个席位轮流操作；掷骰前选择卡牌，路口选择出口。\n2. 道路与建筑独立，多个入口可以关联同一建筑及产权。\n3. 停在临街入口可购买或升级对应地产，对手地产会收租。\n4. 经过银行时可存取款，离开后继续剩余步数。\n5. 住院或入狱时暂不能行走和主动出牌，按提示结束停留回合。\n6. 最后存活者获胜，或达到轮数上限后比较净资产。\n7. 点击建筑看产权与入口；F1可以构造资金、卡牌和特殊状态。\n\n当前是系统验证版本，地图、经济参数与部分状态细则仍待原版核验。完整还原进度见项目策划文档。", 18))
	v.add_child(button("知道了", dismiss))

func show_stocks() -> void:
	if screen != "game": return
	var v := modal("股票市场")
	if handoff or game.phase == "reaction":
		v.add_child(paragraph("请先完成席位交接或当前防御结算，再打开交易界面。"))
		v.add_child(button("返回对局", dismiss))
		return
	var p: Dictionary = game.players[game.current]
	v.add_child(label("%s · 存款 %d · 股票市值 %d" % [p.name, p.deposit, game.stock_value(game.current)], 18))
	v.add_child(paragraph("使用银行存款买入，卖出所得回到存款。每轮全员行动结束后更新行情。公司、价格及波动为测试配置。", 14))
	var content := scroll_content(v, 390)
	for stock_id in game.stock_market.quotes:
		var quote: Dictionary = game.stock_market.quotes[stock_id]
		var item := panel(content)
		var held: int = p.stocks.get(stock_id, 0)
		item.add_child(label("%s · %d / 份 · 变化 %+d" % [quote.name, quote.price, quote.price - quote.previous], 18, Color("e9c46a")))
		item.add_child(label("持仓 %d 份 · 市值 %d" % [held, held * quote.price], 14))
		var row := HBoxContainer.new()
		item.add_child(row)
		var amount := SpinBox.new()
		amount.name = "StockQuantity_" + stock_id
		amount.min_value = 1
		amount.max_value = maxi(1, maxi(held, int(p.deposit / quote.price)))
		amount.step = 1
		amount.value = 1
		amount.prefix = "份数 "
		amount.custom_minimum_size.x = 180
		row.add_child(amount)
		var failure := paragraph("", 13)
		var buy := button("买入 · " + quote.name, func():
			if game.trade_stock(stock_id, int(amount.value), true): refresh(); show_stocks()
			else: failure.text = "交易未完成，请检查存款、数量和当前阶段。", not game.can_trade_stocks() or p.deposit < quote.price)
		row.add_child(buy)
		var sell := button("卖出 · " + quote.name, func():
			if game.trade_stock(stock_id, int(amount.value), false): refresh(); show_stocks()
			else: failure.text = "交易未完成，请检查持仓、数量和当前阶段。", not game.can_trade_stocks() or held <= 0)
		row.add_child(sell)
		item.add_child(failure)
		var history: Array[String] = []
		for price in quote.history: history.append(str(price))
		item.add_child(paragraph("近期价格：" + " → ".join(history), 12))
	if not game.can_trade_stocks(): content.add_child(paragraph("当前阶段仅可查看行情；移动、停留状态与结算期间不能交易。", 14))
	content.add_child(label("最近交易", 18))
	var count := 0
	for index in range(game.stock_market.ledger.size()-1, -1, -1):
		var trade: Dictionary = game.stock_market.ledger[index]
		if trade.get("player_id", -1) != game.current: continue
		var action: String = {"buy":"买入", "sell":"卖出", "liquidate":"偿债卖出"}.get(trade.side, trade.side)
		content.add_child(paragraph("第%d轮 · %s %s %d份 · 单价%d · 合计%d" % [trade.round, action, game.stock_market.quotes[trade.stock_id].name, trade.quantity, trade.price, trade.amount], 12))
		count += 1
		if count >= 5: break
	if count == 0: content.add_child(label("暂无交易", 14))
	v.add_child(button("返回对局", dismiss))

func confirm_menu() -> void:
	var v := modal("返回主菜单？")
	v.add_child(label("当前对局不会保存。"))
	v.add_child(button("继续游戏", dismiss))
	v.add_child(button("确认离开", menu))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and screen == "game": show_gm()
		elif event.keycode == KEY_ESCAPE and popup != null: dismiss()

func show_gm() -> void:
	if screen != "game": return
	var v := modal("GM 测试工具")
	v.add_child(label("测试操作会标记本局；传送当前玩家触发落地，但不领起点奖励。", 14))
	var who := OptionButton.new()
	for i in range(4): who.add_item(game.players[i].name, i)
	who.select(game.current)
	v.add_child(who)
	var cash_row := HBoxContainer.new()
	v.add_child(cash_row)
	for amount in [1000, 10000, -1000, -10000]:
		cash_row.add_child(button("%+d 现金" % amount, func(): gm_used = true; game.gm_cash(who.selected, amount); dismiss()))
	var dice_row := HBoxContainer.new()
	v.add_child(label("当前玩家下一骰（一次有效）"))
	v.add_child(dice_row)
	for n in range(1,7): dice_row.add_child(button(str(n), func(): gm_used = true; forced_dice = n; dismiss(), game.phase != "roll"))
	var destination := OptionButton.new()
	for n in game.nodes: destination.add_item("%02d · %s" % [n.id,n.name], n.id)
	v.add_child(destination)
	v.add_child(button("传送选中玩家至此格", func(): gm_used = true; game.gm_teleport(who.selected, destination.selected); dismiss()))
	var cards := OptionButton.new()
	var card_ids: Array = Game.CARD_NAMES.keys()
	for card in card_ids: cards.add_item(Game.CARD_NAMES[card])
	v.add_child(cards)
	v.add_child(button("发放选中卡牌", func(): gm_used = true; game.gm_give_card(who.selected, card_ids[cards.selected]); dismiss()))
	var state_row := HBoxContainer.new()
	v.add_child(state_row)
	for kind in ["hospital", "prison"]:
		state_row.add_child(button("住院2回合" if kind == "hospital" else "入狱2回合", func(): gm_used = true; game.send_to_facility(who.selected, kind, 2); dismiss()))
	state_row.add_child(button("解除停留", func(): gm_used = true; game.gm_release(who.selected); dismiss()))
	v.add_child(button("立即结算整局", func(): gm_used = true; game.finish_game(); dismiss()))
	v.add_child(button("关闭  /  Esc", dismiss))
