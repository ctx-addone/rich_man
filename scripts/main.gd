extends Control

const Game = preload("res://scripts/game_state.gd")
const Board = preload("res://scripts/board_view.gd")
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
var forced_dice: int = 0
var gm_used: bool = false
var generation: int = 0

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
	v.add_child(label("v0.1  ·  2D 玩法验证  /  四个角色数值完全相同  /  F1 打开测试工具", 14, Color("7f9aab")))

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
	v.add_child(label("市民街区", 26, Color("e9c46a")))
	v.add_child(label("57 个节点  ·  环路与中央十字  ·  3 座地铁站  ·  2 组信号灯"))
	var preview = Board.new()
	var sample = Game.new()
	sample.setup(player_names)
	preview.game = sample
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(preview)
	v.add_child(label("唯一地图已选中。地铁落点付费换乘；信号灯每轮切换通行方向。", 16, Color("a7bac8")))
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
	forced_dice = 0
	gm_used = false
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
	board_col.add_child(board)
	board_col.add_child(label("金框：可选下一步   ·   彩色圆点：玩家   ·   地产色：持有人   ·   点击格子查看详情", 13, Color("9cb4c4")))
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
		col.add_child(label("现金 %s   /   资产 %s" % [p.cash, game.net_worth(i)], 14))
	top_title.text = "市民街区   /   第 %d / %d 轮%s" % [game.round_number, game.round_limit, "  ·  GM测试局" if gm_used else ""]
	board.selected = selected
	board.queue_redraw()
	clear_children(sidebar)
	var p: Dictionary = game.players[game.current]
	sidebar.add_child(label("当前操作  /  " + p.name, 22, COLORS[portraits[game.current]]))
	sidebar.add_child(paragraph("全城信号：" + game.signal_state(6), 14))
	if handoff:
		sidebar.add_child(paragraph("请将操作交给 %s。确认后查看手牌并开始本回合。" % p.name, 20))
		sidebar.add_child(button("我已就位 · 开始回合", func(): handoff = false; refresh()))
	else:
		sidebar.add_child(label("骰子  %s    剩余步数  %d" % ["—" if game.last_roll == 0 else str(game.last_roll), game.steps_left], 20))
		match game.phase:
			"roll": sidebar.add_child(button("掷骰子" + ("  [GM: %d]" % forced_dice if forced_dice > 0 else ""), roll))
			"move":
				sidebar.add_child(paragraph("选择金框出口继续前进。" if game.available_moves().size() > 1 else "正在移动…"))
				for id in game.available_moves():
					sidebar.add_child(button("→ %02d · %s" % [id, game.nodes[id].name], func(): act_move(id)))
			"land":
				var n: Dictionary = game.nodes[p.pos]
				if n.kind == "property":
					if n.owner < 0: sidebar.add_child(button("购买地产  ·  %d" % n.price, func(): game.buy_property(); refresh(), p.cash < n.price))
					elif n.owner == game.current and n.level < 3:
						sidebar.add_child(button("升级建筑  ·  %d" % 600, func(): game.upgrade_property(); refresh(), p.cash < 600))
			"metro":
				sidebar.add_child(paragraph("可支付 200 换乘另一地铁站，换乘后结束移动。"))
				for n in game.nodes:
					if n.kind == "metro" and n.id != p.pos: sidebar.add_child(button("换乘 → " + n.name, func(): game.take_metro(n.id); refresh(), p.cash < 200))
		if game.phase in ["land", "end", "metro"]: sidebar.add_child(button("结束回合 →", next_turn))
		var hand := panel(sidebar)
		hand.add_child(label("手牌  ·  掷骰前每回合最多一张", 15))
		if p.cards.is_empty(): hand.add_child(label("暂无卡牌", 14))
		for card in p.cards:
			var b := button(Game.CARD_NAMES[card], func(): game.use_card(card); refresh(), game.phase != "roll" or game.card_used or (card == "rent_free" and p.rent_shield))
			b.tooltip_text = Game.CARD_DESCRIPTIONS[card]
			hand.add_child(b)
	var id: int = selected if selected >= 0 else p.pos
	var n: Dictionary = game.nodes[id]
	var detail := panel(sidebar)
	detail.add_child(label("%02d  /  %s" % [id, n.name], 18))
	if n.kind == "property":
		detail.add_child(paragraph("持有：%s\n等级：%d / 3\n地价：%d   租金：%d" % ["无主" if n.owner < 0 else game.players[n.owner].name, n.level, n.price, n.rent * n.level * n.level], 14))
	else: detail.add_child(paragraph({"metro":"落在此处可付费换乘。", "start":"每次正常移动进入，领取1000。", "event":"停留触发奖金、费用或抽卡。", "signal":game.signal_state(id), "junction":"移动至此可选择出口，不可立即回头。"}.get(n.kind, ""), 14))
	var log_panel := panel(sidebar)
	log_panel.add_child(label("最近动态", 16))
	for j in range(maxi(0, game.logs.size() - 5), game.logs.size()): log_panel.add_child(paragraph(game.logs[j], 13))
	if not handoff and game.phase == "move" and game.available_moves().size() == 1 and not advancing:
		auto_step()

func roll() -> void:
	game.roll_dice(forced_dice)
	forced_dice = 0
	selected = -1
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
	if not handoff and game.available_moves().has(id): act_move(id)
	else:
		selected = id
		refresh()

func next_turn() -> void:
	if game.end_turn():
		handoff = true
		selected = -1
	refresh()

func results() -> void:
	screen = "results"
	var v := clear_page()
	v.add_child(label("比赛结束", 42))
	var winner_names: Array = []
	for id in game.winners: winner_names.append(game.players[id].name)
	v.add_child(label("获胜：" + " / ".join(winner_names), 28, Color("e9c46a")))
	v.add_child(label("净资产 = 现金 + 地价 + 建筑投资成本" + ("  ·  本局使用了GM" if gm_used else ""), 16))
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
	v.add_child(paragraph("1. 四个席位由真人轮流操作，确认交接后开始回合。\n2. 掷骰前可使用一张卡牌。掷骰后沿路移动，路口选择方向。\n3. 无主地产可购买；再次停在自己的地产可升级，最高3级。\n4. 停在别人地产支付租金，租金随建筑等级平方增长。\n5. 停在地铁站可付200换乘；红灯限制路口出口，无法前进时停止。\n6. 现金不足会自动按半价变卖地产；仍不足则破产退出。\n7. 最后存活者获胜，或达到设定轮数后比较净资产。\n8. 点击地图格子查看详情；F1打开GM测试工具。", 18))
	v.add_child(button("知道了", dismiss))

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
	var cards := HBoxContainer.new()
	v.add_child(cards)
	for card in Game.CARD_NAMES: cards.add_child(button("+ " + Game.CARD_NAMES[card], func(): gm_used = true; game.gm_give_card(who.selected, card); dismiss()))
	v.add_child(button("立即结算整局", func(): gm_used = true; game.finish_game(); dismiss()))
	v.add_child(button("关闭  /  Esc", dismiss))
