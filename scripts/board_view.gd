extends Control

signal tile_clicked(id: int)
var game: RefCounted
var selected: int = -1
var colors = [Color("e76f51"), Color("2a9d8f"), Color("5b7cfa"), Color("a66dd4")]
var player_colors: Array = [0, 1, 2, 3]
var points: Array[Vector2] = []
var cell: float = 48.0
var textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	for level in range(4):
		var path := "res://assets/buildings/level_%d.svg" % level
		if ResourceLoader.exists(path): textures["level_%d" % level] = load(path)
	for kind in ["metro", "event", "start"]:
		var path := "res://assets/icons/%s.svg" % kind
		if ResourceLoader.exists(path): textures[kind] = load(path)

func _draw() -> void:
	if game == null or game.nodes.is_empty(): return
	var step: float = minf((size.x - 100) / 12.0, (size.y - 100) / 8.0)
	cell = minf(step * 0.80, 54.0)
	var origin := (size - Vector2(step * 12, step * 8)) / 2
	points.clear()
	for n in game.nodes: points.append(origin + n.pos * step)
	for n in game.nodes:
		for neighbor in n.neighbors:
			if neighbor > n.id:
				draw_line(points[n.id], points[neighbor], Color("243d4d"), 12.0, true)
	var font = get_theme_default_font()
	var moves: Array = game.available_moves()
	for n in game.nodes:
		var pos := points[n.id]
		var box := Rect2(pos - Vector2.ONE * cell / 2, Vector2.ONE * cell)
		var fill := Color("d5dfe3")
		if n.owner >= 0: fill = colors[player_colors[n.owner]].lightened(0.20)
		elif n.kind == "metro": fill = Color("81c7df")
		elif n.kind == "start": fill = Color("ecd18b")
		elif n.kind == "event": fill = Color("b9a2d6")
		elif n.kind == "signal": fill = Color("bad9bd")
		draw_style_box(_tile_style(fill), box)
		if selected == n.id: draw_rect(box.grow(3), Color("ffffff"), false, 2)
		if moves.has(n.id): draw_rect(box.grow(5), Color("f4c663"), false, 3)
		var caption: String = str(n.id)
		if n.kind == "property": caption += " · " + str(n.level) + "级"
		elif n.kind == "metro": caption += " 地铁"
		elif n.kind == "start": caption += " 起点"
		elif n.kind == "signal": caption += " 信号"
		elif n.kind == "event": caption += " 事件"
		else: caption += " 路口"
		draw_string(font, pos + Vector2(-cell / 2 + 3, cell / 2 - 5), caption, HORIZONTAL_ALIGNMENT_LEFT, cell - 4, 10, Color("183342"))
		var texture_key: String = "level_%d" % n.level if n.kind == "property" else n.kind
		if textures.has(texture_key):
			draw_texture_rect(textures[texture_key], Rect2(pos + Vector2(-17,-23), Vector2(34,34)), false)
		elif n.kind == "property":
			for level in range(maxi(1, n.level)):
				draw_rect(Rect2(pos + Vector2(-15 + level * 10, -14), Vector2(8, 17)), Color("385365") if n.owner < 0 else colors[player_colors[n.owner]].darkened(0.3))
		elif n.kind == "metro": draw_string(font, pos + Vector2(-9, 3), "M", HORIZONTAL_ALIGNMENT_LEFT, 30, 23, Color("184759"))
		elif n.kind == "signal":
			draw_line(pos + Vector2(-15, -5), pos + Vector2(15, -5), Color("27885d") if game.traffic_phase == 0 else Color("d96253"), 5)
			draw_line(pos + Vector2(0, -17), pos + Vector2(0, 6), Color("d96253") if game.traffic_phase == 0 else Color("27885d"), 5)
		else: draw_string(font, pos + Vector2(-9, 3), "+" if n.kind == "start" else "?" if n.kind == "event" else "+", HORIZONTAL_ALIGNMENT_LEFT, 30, 22, Color("385365"))
	for i in range(game.players.size()):
		var p: Dictionary = game.players[i]
		if p.bankrupt: continue
		var pos: Vector2 = points[p.pos] + Vector2(-cell / 2 + 7 + (i % 2) * 18, -cell / 2 + 5 + (i / 2) * 16)
		draw_circle(pos, 10.0 if i == game.current else 8.0, Color.WHITE)
		draw_circle(pos, 8.0 if i == game.current else 6.0, colors[player_colors[i]])
		draw_string(font, pos + Vector2(-4, 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 14, 11, Color.WHITE)

func _tile_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(5)
	return s

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(points.size()):
			if Rect2(points[i] - Vector2.ONE * cell / 2, Vector2.ONE * cell).has_point(event.position):
				tile_clicked.emit(i)
				accept_event()
				return
