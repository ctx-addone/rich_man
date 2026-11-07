extends Control

const Game = preload("res://scripts/game_state.gd")
const Board = preload("res://scripts/board_view.gd")
const Cards = preload("res://scripts/model/cards_catalog.gd")
const Traits = preload("res://scripts/model/character_traits.gd")
const Gods = preload("res://scripts/model/god_rules.gd")
const DebugTools = preload("res://scripts/model/debug_tools.gd")
const AI = preload("res://scripts/model/ai_controller.gd")
const Saves = preload("res://scripts/model/save_game.gd")
const COLORS = [Color("e76f51"), Color("2a9d8f"), Color("5b7cfa"), Color("a66dd4")]
const NAMES = ["赤橙", "青竹", "蓝星", "紫菀"]
var game = Game.new()
var map_id: String = Game.Maps.DEFAULT_MAP_ID
var page: Control
var board: Control
var sidebar: VBoxContainer
var sidebar_state_key: String = ""
var top_title: Label
var score_row: HBoxContainer
var popup: Control
var portraits: Array = [0, 1, 2, 3]
var name_inputs: Array[LineEdit] = []
var player_names: Array = ["玩家 1", "玩家 2", "玩家 3", "玩家 4"]
var character_ids: Array[String] = []
var talents_enabled: bool = true
var gods_enabled: bool = true
var specials_enabled: bool = true
var teams: Array[int] = [0, 1, 2, 3]
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
var controllers: Array[String] = ["human", "ai", "ai", "ai"]
var ai_paused := false
var ai_delay := 0.25
var ai_elapsed := 0.0
var ai_notice := ""
var save_directory := "user://saves"

func automated_seat() -> int:
	if screen != "game" or game.players.is_empty(): return -1
	return game.reaction_player() if game.phase == "reaction" else game.current

func is_automated() -> bool:
	var seat := automated_seat()
	return seat >= 0 and seat < controllers.size() and controllers[seat] == "ai"

func _process(delta: float) -> void:
	if screen != "game" or popup != null or advancing or ai_paused or not is_automated():
		ai_elapsed = 0.0
		return
	ai_elapsed += delta
	if ai_elapsed < ai_delay: return
	ai_elapsed = 0.0
	var success: bool
	if game.phase == "roll" and forced_dice > 0:
		success = game.roll_dice(forced_dice)
		forced_dice = 0
	else: success = AI.step(game)
	if not success:
		ai_paused = true
		ai_notice = "电脑未找到可执行动作，已暂停。可接管当前席位继续操作。"
	reaction_ack = -1
	handoff = not is_automated()
	refresh()

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
	v.add_child(label("单机对战 · 电脑托管 / 同机热座 · 可保存与继续", 18))
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
	var resume := button("读取存档", show_saves)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(resume)
	var help := button("玩法说明", show_help)
	help.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(help)
	spacer(v)
	v.add_child(label("v0.8 开发版  ·  单机托管与存读档  /  F1 测试工具", 14, Color("7f9aab")))

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
	var choices := OptionButton.new()
	choices.name = "MapChoice"
	var maps: Array[Dictionary] = Game.Maps.entries(true)
	for entry in maps:
		choices.add_item(entry.name)
		var index := choices.item_count - 1
		choices.set_item_metadata(index, entry.id)
		choices.set_item_disabled(index, not entry.playable)
		choices.set_item_tooltip(index, entry.description)
		if entry.id == map_id: choices.select(index)
	choices.item_selected.connect(func(index): map_id = str(choices.get_item_metadata(index)); map_select())
	v.add_child(choices)
	v.add_child(label("独立道路与多格建筑  ·  银行  ·  医院  ·  监狱  ·  商店"))
	var preview = Board.new()
	var sample = Game.new()
	sample.setup(player_names, 0, turns, {"map_id":map_id, "specials_enabled":specials_enabled})
	preview.game = sample
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(preview)
	v.add_child(paragraph("本图用于验证多入口建筑、银行与特殊场所，不是原版地图。骑士庄园仍在逐格核对，暂不可选。当前经济参数及部分状态规则仍在核验。", 16))
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(button("← 返回", menu))
	row.add_child(button("选择角色 →", character_select))

func character_select() -> void:
	screen = "characters"
	ensure_characters()
	var v := clear_page()
	v.add_child(label("02  /  选择角色", 32))
	v.add_child(label("选择人类或电脑席位 · 角色规则和占位外观独立 · 天赋可关闭", 18, Color("a7bac8")))
	spacer(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	name_inputs.clear()
	for i in range(4):
		var col := panel(row)
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(label("席位 %d" % (i + 1), 18, COLORS[portraits[i]]))
		col.add_child(portrait(portraits[i], Vector2(140, 140)))
		col.add_child(label(NAMES[portraits[i]] + " · 占位外观", 16))
		var input := LineEdit.new()
		input.text = player_names[i]
		input.max_length = 12
		col.add_child(input)
		name_inputs.append(input)
		var controller := OptionButton.new()
		controller.name = "ControllerChoice%d" % i
		controller.add_item("人类 · 手动操作")
		controller.add_item("电脑 · 自动操作")
		controller.select(1 if controllers[i] == "ai" else 0)
		controller.item_selected.connect(func(index): controllers[i] = "ai" if index == 1 else "human")
		col.add_child(controller)
		var team := OptionButton.new()
		team.name = "TeamChoice%d" % i
		for team_id in range(4): team.add_item("队伍 %d" % (team_id + 1), team_id)
		team.select(teams[i])
		team.item_selected.connect(func(index):
			capture_names()
			teams[i] = index
			character_select())
		col.add_child(team)
		var characters := OptionButton.new()
		characters.name = "CharacterChoice%d" % i
		var choices: Array = Traits.ids()
		for id in choices: characters.add_item(Traits.display_name(id))
		characters.select(choices.find(character_ids[i]))
		col.add_child(characters)
		var talent := paragraph(Traits.description(character_ids[i]), 13)
		talent.custom_minimum_size.y = 100
		col.add_child(talent)
		characters.item_selected.connect(func(index):
			character_ids[i] = choices[index]
			talent.text = Traits.description(character_ids[i]))
		col.add_child(button("更换外观 ↻", func():
			capture_names()
			var next: int = (portraits[i] + 1) % 4
			var other: int = portraits.find(next)
			portraits[other] = portraits[i]
			portraits[i] = next
			character_select()))
	spacer(v)
	v.add_child(label("每人现金 10,000 · 同队免租并可协助升级 · 按存活队伍或队伍总资产判胜"))
	if not Game.Teams.valid_assignment(teams, 4): v.add_child(label("至少需要两支队伍才能开始比赛。", 16, Color("f28a79")))
	var controls := HBoxContainer.new()
	v.add_child(controls)
	controls.add_child(button("← 地图", func(): capture_names(); map_select()))
	controls.add_child(label("对局轮数"))
	var rounds := OptionButton.new()
	for n in [10, 20, 30]: rounds.add_item(str(n) + " 轮", n)
	rounds.select([10,20,30].find(turns))
	rounds.item_selected.connect(func(index): turns = rounds.get_item_id(index))
	controls.add_child(rounds)
	controls.add_child(button("四人混战", func(): capture_names(); teams.assign([0, 1, 2, 3]); character_select()))
	controls.add_child(button("2 对 2", func(): capture_names(); teams.assign([0, 1, 0, 1]); character_select()))
	var talents := CheckButton.new()
	talents.name = "TalentsToggle"
	talents.text = "角色天赋"
	talents.button_pressed = talents_enabled
	talents.toggled.connect(func(enabled): talents_enabled = enabled)
	controls.add_child(talents)
	var gods := CheckButton.new()
	gods.name = "GodsToggle"
	gods.text = "道路神仙"
	gods.button_pressed = gods_enabled
	gods.toggled.connect(func(enabled): gods_enabled = enabled)
	controls.add_child(gods)
	var specials := CheckButton.new()
	specials.name = "SpecialsToggle"
	specials.text = "特殊设施"
	specials.button_pressed = specials_enabled
	specials.toggled.connect(func(enabled): specials_enabled = enabled)
	controls.add_child(specials)
	controls.add_child(button("开始对局 →", func(): capture_names(); start_game(), not Game.Teams.valid_assignment(teams, 4)))

func ensure_characters() -> void:
	if character_ids.size() != 4:
		character_ids.assign(["sun_xiaomei", "atu", "qian", "shalong"])

func capture_names() -> void:
	for i in range(name_inputs.size()):
		if is_instance_valid(name_inputs[i]):
			var n := name_inputs[i].text.strip_edges()
			player_names[i] = n if not n.is_empty() else "玩家 %d" % (i+1)

func start_game() -> void:
	if not Game.Teams.valid_assignment(teams, 4): return
	var next_game = Game.new()
	ensure_characters()
	if not next_game.setup(player_names, 0, turns, {"gods_enabled":gods_enabled, "talents_enabled":talents_enabled, "specials_enabled":specials_enabled, "characters":character_ids, "teams":teams, "map_id":map_id}): return
	game = next_game
	selected = -1
	selected_lot = ""
	forced_dice = 0
	gm_used = false
	ai_paused = false
	ai_notice = ""
	ai_elapsed = 0.0
	reaction_ack = -1
	handoff = true
	build_game()

func build_game() -> void:
	screen = "game"
	var v := clear_page()
	var header := HBoxContainer.new()
	v.add_child(header)
	top_title = label("", 20)
	top_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(top_title)
	header.add_child(button("规则", show_help))
	header.add_child(button("股票", show_stocks))
	header.add_child(button("卡牌图鉴", show_card_catalog))
	header.add_child(button("角色/神仙", show_world_catalog))
	header.add_child(button("存读档", show_saves))
	header.add_child(button("托管", show_control_settings))
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
	var state_key:String="%s:%d:%d"%[game.phase,game.current,game.reaction_player()]
	if is_instance_valid(sidebar) and state_key!=sidebar_state_key:
		(sidebar.get_parent() as ScrollContainer).set_deferred("scroll_vertical",0)
		sidebar_state_key=state_key
	if game.phase == "finished": results(); return
	clear_children(score_row)
	for i in range(4):
		var p: Dictionary = game.players[i]
		var col := panel(score_row, Color("20394b") if i == game.current else Color("102535"))
		col.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(label(("▶ " if i == game.current else "") + p.name + (" · 破产" if p.bankrupt else ""), 18, COLORS[portraits[i]]))
		col.add_child(label("队伍 %d · 团队资产 %d" % [p.team + 1, game.team_scores().get(p.team, 0)], 13))
		col.add_child(label("现金 %s  存款 %s" % [p.cash, p.deposit], 14))
		col.add_child(label(Traits.display_name(p.get("character_id", "original")) + (" · 电脑" if controllers[i] == "ai" else " · 人类") + (" · 天赋关" if not talents_enabled else ""), 13))
		col.add_child(label("资产 %s%s" % [game.net_worth(i), " · " + status_text(p) if not p.status.is_empty() else ""], 13))
	top_title.text = "%s   /   第 %d / %d 轮%s" % [game.map_metadata.name, game.round_number, game.round_limit, "  ·  GM测试局" if gm_used else ""]
	board.selected = selected
	board.selected_lot = selected_lot
	board.queue_redraw()
	clear_children(sidebar)
	var p: Dictionary = game.players[game.current]
	if is_automated():
		var seat: int = automated_seat()
		sidebar.add_child(label(("电脑应对 / " if game.phase == "reaction" else "电脑行动 / ") + game.players[seat].name, 22, COLORS[portraits[seat]]))
		sidebar.add_child(paragraph("已暂停电脑行动。" if ai_paused else "正在自动决策，可随时暂停或接管。", 17))
		if not ai_notice.is_empty(): sidebar.add_child(paragraph(ai_notice, 14))
		if game.phase == "reaction": sidebar.add_child(paragraph(game.reaction_description(), 16))
		sidebar.add_child(button("继续电脑行动" if ai_paused else "暂停电脑行动", func(): ai_paused = not ai_paused; ai_notice = ""; refresh()))
		sidebar.add_child(button("接管当前席位", func(): controllers[seat] = "human"; handoff = true; reaction_ack = -1; refresh()))
	elif game.phase == "reaction":
		show_reaction_controls()
	elif handoff:
		sidebar.add_child(label("当前操作  /  " + p.name, 22, COLORS[portraits[game.current]]))
		sidebar.add_child(paragraph("请将操作交给 %s。确认后继续当前行动。" % p.name, 20))
		sidebar.add_child(button("我已就位 · " + ("开始回合" if game.phase == "roll" else "继续行动"), func(): handoff = false; refresh()))
	else:
		sidebar.add_child(label("当前操作  /  " + p.name, 22, COLORS[portraits[game.current]]))
		sidebar.add_child(label("骰子  %s    剩余步数  %d" % ["—" if game.last_roll == 0 else str(game.last_roll), game.steps_left], 20))
		if not game.last_dice.is_empty():
			var faces: Array[String] = []
			for value in game.last_dice: faces.append(str(value))
			sidebar.add_child(label("骰面  " + " + ".join(faces), 14))
		if not p.status.is_empty() and game.phase != "detained":
			sidebar.add_child(paragraph("梦游中：自动掷骰和行走，不能主动出牌或交易。" if game.is_sleepwalking() else "当前%s。本次行程已结束，后续回合按提示推进状态。" % status_text(p), 16))
		sidebar.add_child(label("载具 · " + vehicle_name(p), 15))
		if not p.get("god", {}).is_empty():
			sidebar.add_child(label("附身 · %s · 余%d次行动" % [Gods.CATALOG[p.god.id].name, p.god.remaining], 17, Color("e9c46a")))
			sidebar.add_child(paragraph(Gods.CATALOG[p.god.id].description, 13))
		if p.get("turtle_turns", 0) > 0: sidebar.add_child(label("乌龟 · 余%d次行动，每次1步" % p.turtle_turns, 14))
		if p.get("stay_turns", 0) > 0: sidebar.add_child(label("停留/麻痹 · 下次行动原地结束", 14, Color("f1a69c")))
		if not p.get("bomb", {}).is_empty(): sidebar.add_child(label("附身炸弹 · 剩余 %d 步" % p.bomb.remaining, 17, Color("f28a79")))
		match game.phase:
			"roll":
				if game.max_dice() > 1 and not game.is_sleepwalking():
					var dice_row := HBoxContainer.new()
					sidebar.add_child(dice_row)
					for count in range(1, game.max_dice()+1):
						dice_row.add_child(button("%d颗骰子%s" % [count, " ✓" if game.dice_count == count else ""], func(): game.set_dice_count(count); refresh(), game.controlled_dice != 0))
				sidebar.add_child(button("梦游 · 自动掷骰" if game.is_sleepwalking() else "掷骰子" + ("  [GM: %d]" % forced_dice if forced_dice > 0 else ""), roll, game.is_sleepwalking()))
			"move":
				sidebar.add_child(paragraph("选择金框出口继续前进。" if game.available_moves().size() > 1 else "正在移动…"))
				for id in game.available_moves():
					sidebar.add_child(button("→ %02d · %s" % [id, game.nodes[id].name], func(): act_move(id)))
			"land":
				for lot_id in game.lots_at_node(p.pos):
					if game.is_sleepwalking(): break
					var lot: Dictionary = game.lots[lot_id]
					if lot.kind == "facility": continue
					if lot.owner < 0: sidebar.add_child(button("购买地产 · %s" % lot.name, func(): choose_building(lot_id, false)))
					elif game.same_team(lot.owner, game.current):
						sidebar.add_child(button("升级建筑 · %s · %d" % [game.building_name(lot.building_type), game.upgrade_cost(lot_id)], func(): game.upgrade_property(lot_id); refresh(), not game.can_upgrade_property(lot_id)))
						if lot.owner != game.current: sidebar.add_child(paragraph("协助队友升级：由你支付费用，产权保留给队友。", 14))
						else: sidebar.add_child(button("改建项目 · " + lot.name, func(): choose_building(lot_id, true)))
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
			"lottery":
				sidebar.add_child(label("乐透站", 24, Color("efd18b")))
				sidebar.add_child(paragraph("每注 %d · 第%d轮开奖\n奖池 %d · 剩余移动 %d步" % [game.Specials.TEST_PROFILE.ticket_price, game.lottery_state.draw_round, game.lottery_state.pot, game.steps_left]))
				var numbers := OptionButton.new()
				numbers.name = "LotteryNumber"
				for number in game.lottery_numbers(): numbers.add_item("号码 %02d" % number, number)
				sidebar.add_child(numbers)
				sidebar.add_child(button("购入一注", func(): game.buy_ticket(numbers.get_selected_id()); refresh(), p.cash < game.Specials.TEST_PROFILE.ticket_price or game.pending_service.purchases >= game.Specials.TEST_PROFILE.visit_limit))
				var tickets: Array[String] = []
				for ticket in game.lottery_state.tickets:
					if ticket.player == game.current: tickets.append(str(ticket.number))
				sidebar.add_child(paragraph("本期持有：" + ("无" if tickets.is_empty() else "、".join(tickets)), 15))
				sidebar.add_child(button("离开乐透站 · 继续行程", func(): game.close_lottery(); refresh()))
			"magic":
				sidebar.add_child(label("魔法屋", 24, Color("c5b6dd")))
				sidebar.add_child(paragraph("先选择效果，再随机抽取条件：载具、资产、地产、卡片、性别、神仙或所在位置。在场且符合条件的角色都会受到影响。原创无性别角色不参与男女条件。", 16))
				for option in game.magic_options():
					sidebar.add_child(button("施放 · " + option.name, func(): game.choose_magic(option.id); refresh()))
					sidebar.add_child(paragraph(option.description, 13))
				sidebar.add_child(button("离开魔法屋", func(): game.close_magic(); refresh()))
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
			var b := button(Game.CARD_NAMES[card] + (" · 被动应对" if reactive else ""), func(): play_card(card), game.phase != "roll" or reactive or game.is_sleepwalking())
			b.tooltip_text = Game.CARD_DESCRIPTIONS[card]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
			row.add_child(button("弃", func(): game.discard_card(card_index); refresh(), game.phase not in ["roll", "shop"] or game.is_sleepwalking()))
	var id: int = selected if selected >= 0 else p.pos
	var n: Dictionary = game.nodes[id]
	var detail := panel(sidebar)
	var detail_lots: Array = [selected_lot] if game.lots.has(selected_lot) else game.lots_at_node(id)
	if not p.status.is_empty() and selected < 0 and selected_lot.is_empty():
		detail.add_child(label("当前状态与位置", 18))
		detail.add_child(paragraph("当前仍在道路上，状态结束后继续当前位置。" if p.status.kind == "sleepwalk" else "离开后返回：%s" % game.nodes[p.status.return_pos].name, 14))
		var facility: Dictionary = game.facility_lot(p.status.kind)
		detail_lots = [p.status.lot_id] if p.status.kind == "vacation" else ([facility.id] if not facility.is_empty() else [])
	else:
		detail.add_child(label("%02d  /  %s" % [id, n.name], 18))
		detail.add_child(paragraph({"lottery":"经过时可选号购票，离开继续剩余步数。", "magic":"停留时选择魔法效果，再抽取作用条件。", "metro":"落在此处可付费换乘。", "start":"每次正常移动进入，领取%d。" % game.start_bonus, "event":"停留触发奖金、费用或抽卡。", "signal":game.signal_state(id), "junction":"移动至此可选择出口，不可立即回头。"}.get(n.kind, "道路只负责行走，产权属于路旁建筑。"), 14))
	if n.kind == "lottery":
		detail.add_child(paragraph("第%d轮开奖 · 当前奖池 %d" % [game.lottery_state.draw_round, game.lottery_state.pot], 14))
		if not game.lottery_state.last_draw.is_empty():
			var draw: Dictionary = game.lottery_state.last_draw
			detail.add_child(paragraph("上期开奖：第%d轮，号码%d" % [draw.round, draw.number], 14))
		for ticket in game.lottery_state.tickets:
			detail.add_child(label("%s · 号码%d" % [game.players[ticket.player].name, ticket.number], 13))
	if game.road_objects.has(id):
		var object_kind: String = game.road_objects[id].kind
		detail.add_child(label("道路物件 · " + Game.CARD_NAMES.get(object_kind, object_kind), 16, Color("e9c46a")))
		detail.add_child(paragraph(Game.CARD_DESCRIPTIONS.get(object_kind, "经过时触发。"), 13))
	if game.road_gods.has(id):
		var god: Dictionary = Gods.CATALOG[game.road_gods[id]]
		detail.add_child(label("道路神仙 · " + god.name, 16, Color("e9c46a")))
		detail.add_child(paragraph(god.description, 13))
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
			if lot.owner == game.current and lot.building_type == "lab" and not handoff and not is_automated():
				if lot.research.is_empty(): detail.add_child(button("安排研究", func(): choose_research(lot_id), game.phase not in ["land", "roll"] or lot.level <= 0 or lot.closed_until > game.round_number))
				elif lot.research.remaining == 0: detail.add_child(button("领取研究成果", func(): game.collect_research(lot_id); refresh(), p.cards.size() >= Game.HAND_LIMIT or game.phase not in ["land", "roll", "shop"] or lot.level <= 0 or lot.closed_until > game.round_number))
	var log_panel := panel(sidebar)
	log_panel.add_child(label("最近动态", 16))
	for j in range(maxi(0, game.logs.size() - 5), game.logs.size()): log_panel.add_child(paragraph(game.logs[j], 13))
	if not is_automated() and not handoff and game.phase == "move" and game.available_moves().size() == 1 and not advancing:
		auto_step()
	elif not is_automated() and not handoff and game.phase == "roll" and game.is_sleepwalking() and not advancing:
		auto_sleepwalk()

func vehicle_name(p: Dictionary) -> String:
	return {"foot":"步行 · 最多1颗骰子", "motorbike":"摩托车 · 最多2颗骰子", "car":"汽车 · 最多3颗骰子"}.get(p.get("vehicle", "foot"), "步行")

func auto_sleepwalk() -> void:
	advancing = true
	var ticket := generation
	await get_tree().create_timer(0.22).timeout
	if ticket != generation or screen != "game": return
	advancing = false
	if popup != null or handoff or game.phase != "roll" or not game.is_sleepwalking(): return
	game.roll_dice()
	refresh()

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
	if handoff or is_automated() or game.phase != "move": return
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
	return "%s %d回合" % [{"hospital":"住院", "prison":"入狱", "vacation":"度假", "hibernate":"冬眠", "sleepwalk":"梦游", "stay":"停留", "paralyzed":"麻痹"}.get(p.status.kind, "停留"), p.status.remaining]

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
	if game.pending_attack.get("kind", "") == "money":
		sidebar.add_child(paragraph("费用尚未扣除。免费免除本次付款；转移由选中的角色应对。住宿等后续效果仍按事件继续。", 14))
	else:
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

func show_world_catalog() -> void:
	var v := modal("角色天赋与神仙")
	v.add_child(paragraph("角色能力、神仙规则与当前实现边界。角色外观仍为原创占位素材。", 14))
	var content := scroll_content(v, 480)
	content.add_child(label("角色天赋", 23, Color("e9c46a")))
	for id in Traits.ids():
		var entry: Dictionary = Traits.CATALOG[id]
		var item := panel(content)
		item.add_child(label(entry.name, 18))
		item.add_child(paragraph(entry.description, 14))
		if not entry.get("unknowns", "").is_empty(): item.add_child(paragraph("待核验/待接入：" + str(entry.unknowns), 12))
	content.add_child(label("神仙附身", 23, Color("e9c46a")))
	for id in Gods.CATALOG:
		var entry: Dictionary = Gods.CATALOG[id]
		var item := panel(content)
		item.add_child(label(entry.name, 18))
		item.add_child(paragraph(entry.description, 14))
		if not entry.get("unknowns", "").is_empty(): item.add_child(paragraph("待核验/待接入：" + str(entry.unknowns), 12))
	v.add_child(button("关闭", dismiss))

func play_card(card_id: String) -> void:
	if game.phase != "roll": return
	var v := modal(Game.CARD_NAMES[card_id])
	v.add_child(paragraph(Game.CARD_DESCRIPTIONS[card_id]))
	var target_type: String = Game.CARD_TARGETS.get(card_id, "none")
	var error_label := paragraph("", 14)
	if target_type == "dice" or card_id == "robot":
		var routes: Array = game.controlled_routes(card_id)
		var route_choice := OptionButton.new()
		route_choice.name = "RouteChoice"
		route_choice.custom_minimum_size.x = 610
		route_choice.clip_text = true
		for index in range(routes.size()):
			var route: Dictionary = routes[index]
			route_choice.add_item("%02d · %s · %s%d步 · 路线%d" % [route.destination, game.nodes[route.destination].name, "后退" if route.steps < 0 else "前进", absi(route.steps), index+1])
			route_choice.set_item_metadata(index, route.steps)
		v.add_child(route_choice)
		var route_detail := paragraph("", 14)
		v.add_child(route_detail)
		var preview_route := func():
			if routes.is_empty(): route_detail.text = "当前没有合法路线，卡牌不会消耗。"; return
			var path_labels: Array[String] = []
			for node_id in routes[route_choice.selected].path: path_labels.append("%02d" % node_id)
			route_detail.text = ("清除路径上的道路物件：" if card_id == "robot" else "指定路线，沿途仍会触发银行及道路物件：") + " → ".join(path_labels)
		preview_route.call()
		route_choice.item_selected.connect(func(_index): preview_route.call())
		v.add_child(button("确认路线", func():
			var route: Dictionary = routes[route_choice.selected]
			if game.use_card(card_id, route.path, route.steps): dismiss()
			else: error_label.text = "路线或状态已变化，卡牌未消耗。", routes.is_empty()))
	elif target_type == "player_road":
		var people: Array = game.card_targets(card_id)
		var player_choice := OptionButton.new()
		player_choice.name = "TeleportPlayer"
		for player_id in people: player_choice.add_item(game.players[player_id].name)
		v.add_child(player_choice)
		var road_choice := OptionButton.new()
		road_choice.name = "TeleportRoad"
		v.add_child(road_choice)
		var update_roads := func():
			road_choice.clear()
			if people.is_empty(): return
			for road in game.teleport_destinations(people[player_choice.selected]): road_choice.add_item("%02d · %s" % [road, game.nodes[road].name], road)
		update_roads.call()
		player_choice.item_selected.connect(func(_index): update_roads.call())
		v.add_child(button("确认传送", func():
			if road_choice.selected < 0: return
			if game.use_card(card_id, people[player_choice.selected], road_choice.get_selected_id()): dismiss()
			else: error_label.text = "目标或目的地无效，卡牌未消耗。", people.is_empty() or road_choice.item_count == 0))
	elif target_type == "lot_pair":
		var choices: Array = game.card_targets(card_id)
		var origins: Array = []
		var destinations: Array = []
		var first := OptionButton.new()
		first.name = "PairLotA"
		var second := OptionButton.new()
		second.name = "PairLotB"
		for id in choices:
			var lot: Dictionary = game.lots[id]
			if lot.building_type not in ["house", "chain"]: continue
			var text_value: String = lot.name + " · " + game.players[lot.owner].name
			if game.lots_at_node(game.players[game.current].pos).has(id):
				origins.append(id)
				first.add_item(text_value)
			if lot.owner == game.current and lot.level >= 1:
				destinations.append(id)
				second.add_item(text_value)
		v.add_child(label("当前位置房屋"))
		v.add_child(first)
		v.add_child(label("范围内己方房屋 / 连锁店（至少1级）"))
		v.add_child(second)
		v.add_child(button("确认交换", func():
			if game.use_card(card_id, [origins[first.selected], destinations[second.selected]]): dismiss()
			else: error_label.text = "请选择符合规则的两块不同地产，卡牌未消耗。", origins.is_empty() or destinations.is_empty()))
	elif target_type in ["player", "road", "lot", "god"]:
		var target := OptionButton.new()
		target.name = "CardTarget"
		var options: Array = game.card_targets(card_id)
		for id in options:
			var title_text: String
			if target_type == "god":
				title_text = Gods.bless_target_name(game, str(id))
			else:
				title_text = game.players[id].name if target_type == "player" else (game.lots[id].name if target_type == "lot" else "%02d · %s" % [id, game.nodes[id].name])
			target.add_item(title_text)
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
	var scores: Dictionary = game.team_scores()
	var team_order: Array = scores.keys()
	team_order.sort_custom(func(a,b): return scores[a] > scores[b])
	for team_id in team_order:
		var members: Array[String] = []
		for who in game.team_members(team_id): members.append(game.players[who].name)
		v.add_child(label("队伍 %d · 总资产 %d · %s" % [team_id + 1, scores[team_id], " / ".join(members)], 18))
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
	v.add_child(paragraph("1. 默认一名真人与三名电脑，可在选人页改为同机热座或选择队伍；至少两队。掷骰前选择卡牌；途经岔路随机，停在岔路后可选方向。\n2. 道路与建筑独立，多个入口关联同一产权。停在入口可购买、升级或向对手付租金。\n3. 经过银行时可存取款，离开后继续剩余步数。大额费用可用免费或转移卡应对。\n4. 住院、入狱等状态按提示推进；最后存活队伍获胜，或达到轮数上限后比较队伍净资产。队友免租，可由行动者付费协助加盖；卡牌仍可能误伤队友。\n5. “托管”可调整各席位控制；电脑行动时可暂停或接管，真人防御仍由真人确认。\n6. “存读档”每次新建一份记录，可从主菜单或局内读取。读档后电脑先暂停，确认局势后继续。\n7. 经过乐透站可购票；停在魔法屋先选效果再抽条件。商店货品在本次访问内固定，售出不补货。\n8. 点击建筑查看产权与入口；F1可构造资金、卡牌、地产和特殊状态。\n\n当前是系统验证版本，地图、经济参数与部分状态细则仍待原版核验。完整还原进度见项目策划文档。", 18))
	v.add_child(button("知道了", dismiss))

func show_stocks() -> void:
	if screen != "game": return
	var v := modal("股票市场")
	if handoff or game.phase == "reaction":
		v.add_child(paragraph("请先完成席位交接或当前防御结算，再打开交易界面。"))
		v.add_child(button("返回对局", dismiss))
		return
	var p: Dictionary = game.players[game.current]
	var can_trade: bool = game.can_trade_stocks() and not is_automated()
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
			else: failure.text = "交易未完成，请检查存款、数量和当前阶段。", not can_trade or p.deposit < quote.price)
		row.add_child(buy)
		var sell := button("卖出 · " + quote.name, func():
			if game.trade_stock(stock_id, int(amount.value), false): refresh(); show_stocks()
			else: failure.text = "交易未完成，请检查持仓、数量和当前阶段。", not can_trade or held <= 0)
		row.add_child(sell)
		item.add_child(failure)
		var history: Array[String] = []
		for price in quote.history: history.append(str(price))
		item.add_child(paragraph("近期价格：" + " → ".join(history), 12))
	if not can_trade: content.add_child(paragraph("当前仅可查看行情。电脑席位需要先接管；移动、停留状态与结算期间不能交易。", 14))
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
	v.add_child(label("尚未保存的对局进度不会保留。"))
	v.add_child(button("先保存对局", show_saves))
	v.add_child(button("继续游戏", dismiss))
	v.add_child(button("确认离开", menu))

func show_control_settings() -> void:
	var v := modal("席位控制与托管")
	v.add_child(paragraph("电脑会完成掷骰、用卡、购地、交易与防御。打开窗口时自动暂停行动。", 14))
	for i in range(controllers.size()):
		var row := HBoxContainer.new()
		v.add_child(row)
		row.add_child(label(game.players[i].name if screen == "game" else player_names[i], 18))
		var choice := OptionButton.new()
		choice.name = "LiveController%d" % i
		choice.add_item("人类")
		choice.add_item("电脑")
		choice.select(1 if controllers[i] == "ai" else 0)
		choice.item_selected.connect(func(index):
			controllers[i] = "ai" if index == 1 else "human"
			handoff = true
			reaction_ack = -1)
		row.add_child(choice)
	v.add_child(button("恢复全部电脑行动" if ai_paused else "暂停全部电脑行动", func(): ai_paused = not ai_paused; ai_notice = ""; show_control_settings()))
	v.add_child(button("返回对局", dismiss))

func save_metadata(title_text: String) -> Dictionary:
	return {"title":title_text,"saved_at":Time.get_datetime_string_from_system(),"portraits":portraits.duplicate(),"controllers":controllers.duplicate(),"gm_used":gm_used,"forced_dice":forced_dice,"handoff":handoff,"reaction_ack":reaction_ack,"selected":selected,"selected_lot":selected_lot,"ai_paused":ai_paused}

func save_snapshot(title_text: String) -> Dictionary:
	if screen != "game": return {"ok":false,"error":"当前没有可保存的对局。"}
	var path := save_directory.path_join("match_%d_%d.rms" % [int(Time.get_unix_time_from_system()*1000.0), Time.get_ticks_usec()])
	var result: Dictionary = Saves.save_to_file(game, path, save_metadata(title_text))
	result["path"] = path
	return result

func show_saves() -> void:
	var v := modal("保存与读取对局")
	v.add_child(paragraph("每次保存创建一份新记录。保存包括未完成的移动和防御；读档后电脑先暂停，可查看局势再继续。", 14))
	if screen == "game":
		var title_input := LineEdit.new()
		title_input.name = "SaveTitle"
		title_input.max_length = 40
		title_input.text = "%s · 第%d轮 · %s" % [game.map_metadata.name, game.round_number, game.players[game.current].name]
		v.add_child(title_input)
		var feedback := paragraph("", 14)
		v.add_child(feedback)
		v.add_child(button("新建存档", func():
			var title_text: String = title_input.text.strip_edges()
			var result: Dictionary = save_snapshot(title_text if not title_text.is_empty() else "未命名对局")
			if result.ok: show_saves()
			else: feedback.text = "保存失败：" + str(result.error)))
	var content := scroll_content(v, 310 if screen == "game" else 440)
	var files := PackedStringArray()
	if DirAccess.dir_exists_absolute(save_directory): files = DirAccess.get_files_at(save_directory)
	files.sort()
	files.reverse()
	var count := 0
	for file_name in files:
		if not file_name.ends_with(".rms"): continue
		count += 1
		var path: String = save_directory.path_join(file_name)
		var info: Dictionary = Saves.peek_file(path)
		var item := panel(content)
		if not info.get("ok", false):
			item.add_child(paragraph("无法读取 · " + file_name + "\n" + str(info.get("error", "存档损坏")), 13))
			continue
		var meta: Dictionary = info.get("metadata", {})
		item.add_child(label(str(meta.get("title", "未命名对局")), 18))
		item.add_child(label(str(meta.get("saved_at", "")), 13))
		item.add_child(button("读取 · " + str(meta.get("title", "未命名对局")), func(): confirm_load(path)))
	if count == 0: content.add_child(label("还没有存档。开始对局后可随时保存。", 16))
	v.add_child(button("返回", dismiss))

func confirm_load(path: String) -> void:
	var v := modal("读取这份对局？")
	v.add_child(paragraph("当前未保存的进度将被替换。读取失败时会保留当前对局。", 16))
	var feedback := paragraph("", 14)
	v.add_child(feedback)
	v.add_child(button("确认读取", func():
		var result: Dictionary = load_snapshot(path)
		if not result.ok: feedback.text = "读取失败：" + str(result.error)))
	v.add_child(button("返回存档列表", show_saves))

func load_snapshot(path: String) -> Dictionary:
	var result: Dictionary = Saves.load_from_file(path)
	if not result.get("ok", false): return result
	var loaded = result.game
	var meta: Dictionary = result.get("metadata", {})
	var portrait_data: Variant = meta.get("portraits", [0,1,2,3])
	var controller_data: Variant = meta.get("controllers", ["human","human","human","human"])
	if not portrait_data is Array or not controller_data is Array:
		return {"ok":false,"error":"席位或外观信息类型无效。"}
	var loaded_portraits: Array = portrait_data
	var loaded_controllers: Array = controller_data
	if loaded.players.size() != 4 or loaded_portraits.size() != 4 or loaded_controllers.size() != 4:
		return {"ok":false,"error":"席位或外观信息不完整。"}
	for i in range(4):
		if typeof(loaded_portraits[i]) != TYPE_INT or loaded_portraits[i] < 0 or loaded_portraits[i] > 3 or loaded_controllers[i] not in ["human", "ai"]:
			return {"ok":false,"error":"席位控制或外观数据无效。"}
	if typeof(meta.get("forced_dice", 0)) != TYPE_INT or typeof(meta.get("gm_used", false)) != TYPE_BOOL:
		return {"ok":false,"error":"测试标记或骰子信息无效。"}
	game = loaded
	map_id = game.map_id
	portraits = loaded_portraits.duplicate()
	controllers.assign(loaded_controllers)
	player_names.clear()
	character_ids.clear()
	for p in game.players:
		player_names.append(p.name)
		character_ids.append(p.get("character_id", "original"))
	talents_enabled = game.talents_enabled
	gods_enabled = game.gods_enabled
	specials_enabled = game.specials_enabled
	teams.clear()
	for player in game.players: teams.append(player.team)
	turns = game.round_limit
	gm_used = bool(meta.get("gm_used", false))
	forced_dice = clampi(int(meta.get("forced_dice", 0)), 0, 6)
	selected = -1
	selected_lot = ""
	reaction_ack = -1
	handoff = true
	ai_paused = true
	ai_elapsed = 0.0
	ai_notice = "读档完成，电脑已暂停。"
	build_game()
	return {"ok":true}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and screen == "game": show_gm()
		elif event.keycode == KEY_ESCAPE and popup != null: dismiss()

func show_gm() -> void:
	if screen != "game": return
	var outer := modal("GM 测试工具")
	var v := scroll_content(outer, 480)
	v.add_child(label("测试操作会标记本局；传送当前玩家触发落地，但不领起点奖励。", 14))
	var who := OptionButton.new()
	who.name = "GMPlayer"
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
	destination.name = "GMRoad"
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
	var vehicles := HBoxContainer.new()
	v.add_child(vehicles)
	for kind in ["foot", "motorbike", "car"]:
		vehicles.add_child(button("设置" + {"foot":"步行", "motorbike":"摩托车", "car":"汽车"}[kind], func(): gm_used = true; game.gm_vehicle(who.selected, kind); dismiss(), game.phase == "reaction"))
	var bombs := HBoxContainer.new()
	v.add_child(bombs)
	bombs.add_child(button("附身炸弹 · 剩1步", func(): gm_used = true; game.gm_bomb(who.selected, 1); dismiss(), game.phase == "reaction"))
	bombs.add_child(button("清除附身炸弹", func(): gm_used = true; game.gm_bomb(who.selected, 0); dismiss(), game.phase == "reaction"))
	var god_choice := OptionButton.new()
	god_choice.name = "GMGod"
	var god_ids: Array = Gods.CATALOG.keys()
	for id in god_ids: god_choice.add_item(Gods.CATALOG[id].name)
	v.add_child(god_choice)
	var god_actions := HBoxContainer.new()
	v.add_child(god_actions)
	god_actions.add_child(button("神仙附身", func(): gm_used = true; game.gm_god(who.selected, god_ids[god_choice.selected]); dismiss(), game.phase == "reaction"))
	god_actions.add_child(button("放置道路神仙", func(): gm_used = true; game.gm_spawn_god(destination.get_selected_id(), god_ids[god_choice.selected]); dismiss(), game.phase == "reaction"))
	god_actions.add_child(button("清除附身神仙", func(): gm_used = true; game.gm_god(who.selected, ""); dismiss(), game.phase == "reaction"))
	v.add_child(button("配置地产与租金测试 →", show_gm_property, game.phase in ["reaction", "move"]))
	v.add_child(button("手动选择所有岔路 · " + ("开" if game.gm_choose_route else "关"), func(): gm_used = true; game.gm_choose_route = not game.gm_choose_route; dismiss(), game.phase != "roll"))
	v.add_child(button("立即结算整局", func(): gm_used = true; game.finish_game(); dismiss()))
	outer.add_child(button("关闭  /  Esc", dismiss))

func show_gm_property() -> void:
	var v := modal("GM · 配置地产")
	v.add_child(paragraph("设置产权、建筑与等级；清除该地块的研究、涨价和停业。配置后可回GM传送到任一入口，测试租金与防御。", 14))
	var lot_choice := OptionButton.new()
	lot_choice.name = "GMLot"
	var lot_ids: Array[String] = []
	for lot in game.lots.values():
		if lot.kind == "facility": continue
		lot_ids.append(lot.id)
		lot_choice.add_item(lot.name)
	v.add_child(lot_choice)
	var owner_choice := OptionButton.new()
	owner_choice.name = "GMLotOwner"
	owner_choice.add_item("无主空地", 0)
	for i in range(game.players.size()): owner_choice.add_item(game.players[i].name, i + 1)
	owner_choice.select(game.current + 1)
	v.add_child(owner_choice)
	var kind_choice := OptionButton.new()
	kind_choice.name = "GMLotKind"
	v.add_child(kind_choice)
	var level := SpinBox.new()
	level.name = "GMLotLevel"
	level.min_value = 1
	level.max_value = 5
	level.value = 1
	level.prefix = "等级 "
	v.add_child(level)
	var description := paragraph("", 14)
	v.add_child(description)
	var update_lot := func():
		kind_choice.clear()
		var id: String = lot_ids[lot_choice.selected]
		for kind in game.building_options(id): kind_choice.add_item(game.building_name(kind))
		level.max_value = game.max_level(id)
		description.text = "道路入口：" + "、".join(game.lots[id].frontage_nodes)
	update_lot.call()
	lot_choice.item_selected.connect(func(_index): update_lot.call())
	var error_text := paragraph("", 14)
	v.add_child(error_text)
	v.add_child(button("应用地产配置", func():
		var id: String = lot_ids[lot_choice.selected]
		var kind: String = game.building_options(id)[kind_choice.selected]
		if DebugTools.configure_lot(game, id, owner_choice.get_selected_id()-1, kind, int(level.value)):
			gm_used = true
			dismiss()
		else: error_text.text = "当前阶段或所有者无效，配置未应用。"))
	v.add_child(button("返回GM", show_gm))
