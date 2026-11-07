extends Control

signal cell_selected(cell: int)
var game: RefCounted
var input_enabled := false
var animation_fraction: float = 0.0
var cells: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	if game == null or game.phase != "minigame" or size.x < 50 or size.y < 100: return
	var state: Dictionary = game.pending_service.game
	var font := get_theme_default_font()
	draw_style_box(_style(Color("112c32"), 16), Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(24, 34), "接金币  /  " + game.players[game.current].name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 24, Color("e8d7a5"))
	if state.status == "result":
		for index in range(state.history.size()):
			var result: Dictionary = state.history[index]
			draw_string(font, Vector2(40, 120 + index * 68), "%s     %d 分     奖励 %d" % [game.players[result.player].name, result.score, result.reward], HORIZONTAL_ALIGNMENT_LEFT, size.x - 80, 23, Color("e8d7a5") if result.player == game.current else Color("c7d8dd"))
		return
	var remaining: float = (game.Minigame.TEST_PROFILE.ticks - state.tick) * game.Minigame.TEST_PROFILE.tick_seconds
	draw_string(font, Vector2(24, 65), "得分 %d    剩余 %.1f 秒" % [state.score, remaining], HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 18, Color("c7d8dd"))
	var unit: float = minf((size.x - 100) / 3.0, (size.y - 145) / 3.0)
	var origin: Vector2 = Vector2((size.x - unit * 3) / 2, 90)
	cells.clear()
	for index in range(9):
		var box := Rect2(origin + Vector2(index % 3, index / 3) * unit, Vector2.ONE * unit).grow(-5)
		cells.append(box)
		draw_style_box(_style(Color("254d53") if state.cell == index else Color("1a3a41"), 8), box)
		if game.Minigame.legal_cells(game).has(index) and state.status == "playing": draw_rect(box.grow(-2), Color("6bbfb9"), false, 2)
		if state.cell == index: draw_rect(box.grow(-2), Color("f1d18a"), false, 3)
		draw_string(font, box.position + Vector2(10, 21), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 24, 14, Color("7b9fa6"))
		if state.cell == index:
			var basket := Rect2(box.get_center() + Vector2(-unit * 0.22, unit * 0.24), Vector2(unit * 0.44, unit * 0.15))
			draw_style_box(_style(Color("e8bd71"), 5), basket)
	for item in state.items:
		var box: Rect2 = cells[item.cell]
		var falling: bool = item.remaining >= item.life
		var center: Vector2 = box.get_center() + Vector2(0, lerpf(-unit * 0.28, unit * 0.20, animation_fraction) if falling else unit * 0.20)
		var radius: float = minf(18, unit * 0.15)
		if item.kind == "coin":
			draw_circle(center, radius, Color("e8bb4d"))
			draw_arc(center, radius * 0.72, 0, TAU, 20, Color("fff0ac"), 2, true)
			draw_string(font, center + Vector2(-radius, 6), "$", HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 18, Color("6b4e20"))
		elif item.kind == "ingot":
			var shape := PackedVector2Array([center+Vector2(-radius,-radius/2),center+Vector2(-radius*0.6,radius/2),center+Vector2(radius*0.6,radius/2),center+Vector2(radius,-radius/2)])
			draw_colored_polygon(shape, Color("efc25a"))
			draw_circle(center, radius * 0.5, Color("fff0ac"))
		else:
			draw_circle(center, radius, Color("d47070"))
			draw_line(center + Vector2(-6,-6), center + Vector2(6,6), Color("fff0dc"), 3, true)
			draw_line(center + Vector2(6,-6), center + Vector2(-6,6), Color("fff0dc"), 3, true)
	draw_string(font, Vector2(20, size.y - 18), "点击相邻发光格移动 · 金币短暂停留 · 避开空中与地面炸弹", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 16, Color("a7c4ca"))

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	return result

func _gui_input(event: InputEvent) -> void:
	if not input_enabled: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for index in range(cells.size()):
			if cells[index].has_point(event.position):
				cell_selected.emit(index)
				accept_event()
				return
