extends Control

signal tile_clicked(id: int)
signal lot_clicked(id: String)
var game: RefCounted
var selected: int = -1
var selected_lot: String = ""
var colors = [Color("e76f51"), Color("2a9d8f"), Color("5b7cfa"), Color("a66dd4")]
var player_colors: Array = [0, 1, 2, 3]
var points: Array[Vector2] = []
var lot_rects: Dictionary = {}
var cell: float = 28.0
var step: float = 34.0
var origin := Vector2.ZERO
var textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	for level in range(4):
		var path := "res://assets/buildings/level_%d.svg" % level
		if ResourceLoader.exists(path): textures["level_%d" % level] = load(path)

func _player_color(index: int) -> Color:
	return colors[int(player_colors[index % player_colors.size()]) % colors.size()]

func _layout() -> void:
	var low: Vector2 = game.nodes[0].pos - Vector2.ONE * 0.5
	var high: Vector2 = low + Vector2.ONE
	for n in game.nodes:
		low = low.min(n.pos - Vector2.ONE * 0.5)
		high = high.max(n.pos + Vector2.ONE * 0.5)
	for lot in game.lots.values():
		var f: Rect2i = lot.footprint
		low = low.min(Vector2(f.position) - Vector2.ONE * 0.5)
		high = high.max(Vector2(f.end) - Vector2.ONE * 0.5)
	var extent: Vector2 = high - low
	step = maxf(1, minf((size.x - 44) / extent.x, (size.y - 44) / extent.y))
	cell = step * 0.82
	origin = (size - extent * step) / 2 - low * step
	points.clear()
	for n in game.nodes: points.append(origin + n.pos * step)
	lot_rects.clear()
	for lot in game.lots.values():
		var f: Rect2i = lot.footprint
		lot_rects[lot.id] = Rect2(origin + (Vector2(f.position) - Vector2.ONE * 0.5) * step, Vector2(f.size) * step).grow(-step * 0.12)

func _draw() -> void:
	if game == null or game.nodes.is_empty(): return
	_layout()
	draw_style_box(_tile_style(Color("112c32"), 16), Rect2(Vector2.ZERO, size))
	var active_lots: Array = []
	if selected_lot != "" and game.lots.has(selected_lot): active_lots.append(selected_lot)
	elif selected >= 0 and selected < game.nodes.size(): active_lots = game.lots_at_node(selected)
	var active_roads: Array = []
	for id in active_lots:
		for road_id in game.lots[id].frontage_nodes:
			if game.board_model.roads.has(road_id):
				var road_cell: Vector2i = game.board_model.roads[road_id].cell
				for n in game.nodes:
					if Vector2i(n.pos) == road_cell and not active_roads.has(n.id): active_roads.append(n.id)
	# Road corridors connect cell centres. Ownership is drawn only on separate plots.
	for n in game.nodes:
		for neighbor in n.neighbors:
			if neighbor > n.id:
				draw_line(points[n.id], points[neighbor], Color("52646a"), cell + 3, true)
	for lot in game.lots.values(): _draw_lot(lot, active_lots.has(lot.id))
	var moves: Array = game.available_moves()
	var font := get_theme_default_font()
	for n in game.nodes:
		var pos: Vector2 = points[n.id]
		var box := Rect2(pos - Vector2.ONE * cell / 2, Vector2.ONE * cell)
		var fill := Color("c3d0cf")
		if n.kind == "start": fill = Color("efd18b")
		elif n.kind == "event": fill = Color("c5b6dd")
		elif n.kind == "metro": fill = Color("91d3dc")
		draw_style_box(_tile_style(fill, 3), box)
		if active_roads.has(n.id): draw_rect(box.grow(1), Color("73e6d0"), false, 2)
		if selected == n.id: draw_rect(box.grow(2), Color.WHITE, false, 2)
		if moves.has(n.id): draw_rect(box.grow(3), Color("ffce62"), false, 3)
		var caption: String = str(n.id)
		if n.kind == "start": caption = "起"
		elif n.kind == "event": caption = "?"
		elif n.kind == "metro": caption = "M"
		var font_size: int = clampi(int(cell * 0.43), 9, 14)
		draw_string(font, pos + Vector2(-cell / 2, font_size * 0.35), caption, HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, Color("27434a"))
		if n.get("signal", false):
			draw_circle(pos + Vector2(cell * 0.24, -cell * 0.24), 3, Color("f06560") if game.traffic_phase else Color("35b982"))
		if game.road_objects.has(n.id):
			var mine_centre := pos + Vector2(cell * 0.22, -cell * 0.24)
			var radius := maxf(4, cell * 0.19)
			draw_circle(mine_centre, radius + 1, Color("ffdb9f"))
			draw_circle(mine_centre, radius, Color("a12e38"))
			draw_line(mine_centre - Vector2(radius * 0.55, 0), mine_centre + Vector2(radius * 0.55, 0), Color("ffead2"), 2)
			draw_line(mine_centre - Vector2(0, radius * 0.55), mine_centre + Vector2(0, radius * 0.55), Color("ffead2"), 2)
	_draw_players()

func _draw_lot(lot: Dictionary, highlighted: bool) -> void:
	var box: Rect2 = lot_rects[lot.id]
	var facility: bool = lot.kind == "facility"
	var fill := Color("355148") if not facility else Color("274956")
	var accent := Color("8abfa7") if not facility else Color("8bbbc9")
	if lot.owner >= 0:
		accent = _player_color(lot.owner)
		fill = accent.darkened(0.62)
	if lot.building_type == "hospital": accent = Color("f1a69c")
	elif lot.building_type == "prison": accent = Color("adb5c9")
	elif lot.building_type == "bank": accent = Color("e6c874")
	draw_style_box(_tile_style(Color(0,0,0,0.20), 6), Rect2(box.position + Vector2(3,4), box.size))
	draw_style_box(_tile_style(fill, 6), box)
	draw_rect(box.grow(-1), accent.darkened(0.25), false, 1)
	if highlighted: draw_rect(box.grow(2), Color("73e6d0"), false, 3)
	if lot.kind == "small":
		_draw_small_lot(lot, box, accent)
	else:
		var font := get_theme_default_font()
		var name_size: int = clampi(int(step * 0.48), 10, 17)
		var title: String = str(lot.name)
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > box.size.x - 8:
			name_size = maxi(9, int((box.size.x - 8) / maxf(1, title.length())))
		draw_string(font, box.position + Vector2(4, name_size + 4), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 8, name_size, Color("eaf3ed"))
		var centre: Vector2 = box.get_center() + Vector2(0, 3)
		var icon_size: float = maxf(10, minf(box.size.x - 12, box.size.y - 40))
		icon_size = minf(icon_size, step * 2.1)
		if facility:
			_draw_facility(str(lot.building_type), centre, icon_size, accent)
		else:
			var texture_key := "level_%d" % clampi(int(lot.level), 0, 3)
			if textures.has(texture_key):
				draw_texture_rect(textures[texture_key], Rect2(centre - Vector2.ONE * icon_size / 2, Vector2.ONE * icon_size), false)
			else:
				draw_rect(Rect2(centre - Vector2(icon_size * 0.3, icon_size * 0.35), Vector2(icon_size * 0.6, icon_size * 0.7)), accent)
		var subtitle: String = "公共设施" if facility else ("待购 · %d" % int(lot.price) if lot.owner < 0 else "%dP · %d级" % [int(lot.owner) + 1, int(lot.level)])
		draw_string(font, Vector2(box.position.x + 3, box.end.y - 5), subtitle, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 6, clampi(int(step * 0.4), 9, 13), accent.lightened(0.2))
	# Small gate marks convey the explicit frontage without painting buildings on roads.
	for road_id in lot.frontage_nodes:
		if not game.board_model.roads.has(road_id): continue
		var p: Vector2 = origin + Vector2(game.board_model.roads[road_id].cell) * step
		var gate := p.clamp(box.position, box.end)
		draw_line(gate, gate.move_toward(p, step * 0.17), Color("73e6d0") if highlighted else accent, 3, true)

func _draw_small_lot(lot: Dictionary, box: Rect2, accent: Color) -> void:
	# Short coordinate labels match the full name in the sidebar. Never truncate prices.
	var font := get_theme_default_font()
	var title: String = str(lot.name).trim_prefix("住宅 ")
	var font_size: int = clampi(int(box.size.x * 0.23), 10, 14)
	draw_string(font, box.position + Vector2(2, font_size + 2), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 4, font_size, Color("eaf3ed"))
	var icon_centre: Vector2 = box.get_center() + Vector2(0, 2)
	var unit: float = minf(box.size.x * 0.16, box.size.y * 0.14)
	var roof := PackedVector2Array([icon_centre + Vector2(-unit * 1.5, 0), icon_centre + Vector2(0, -unit * 1.25), icon_centre + Vector2(unit * 1.5, 0)])
	draw_colored_polygon(roof, accent.lightened(0.25))
	draw_rect(Rect2(icon_centre + Vector2(-unit, 0), Vector2(unit * 2, unit)), accent)
	draw_rect(Rect2(icon_centre + Vector2(-unit * 0.22, unit * 0.3), Vector2(unit * 0.44, unit * 0.7)), Color("27453d"))
	var subtitle: String = "待购" if lot.owner < 0 else "%d级" % int(lot.level)
	draw_string(font, Vector2(box.position.x + 2, box.end.y - 3), subtitle, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 4, maxi(10, font_size - 1), accent.lightened(0.3))

func _draw_facility(kind: String, centre: Vector2, width: float, accent: Color) -> void:
	var unit: float = width / 6
	if kind == "hospital":
		draw_rect(Rect2(centre - Vector2(unit, 3 * unit), Vector2(2 * unit, 6 * unit)), accent)
		draw_rect(Rect2(centre - Vector2(3 * unit, unit), Vector2(6 * unit, 2 * unit)), accent)
	elif kind == "prison":
		var cell_box := Rect2(centre - Vector2.ONE * width / 2, Vector2.ONE * width)
		draw_rect(cell_box, accent, false, 3)
		for column in range(1, 4):
			var x: float = cell_box.position.x + width * column / 4
			draw_line(Vector2(x, cell_box.position.y), Vector2(x, cell_box.end.y), accent, 3)
	else:
		var roof := PackedVector2Array([centre + Vector2(-3 * unit, -unit), centre + Vector2(0, -3 * unit), centre + Vector2(3 * unit, -unit)])
		draw_colored_polygon(roof, accent)
		for column in [-2, 0, 2]: draw_rect(Rect2(centre + Vector2(column * unit - unit * 0.4, -unit * 0.5), Vector2(unit * 0.8, unit * 2.5)), accent)
		draw_rect(Rect2(centre + Vector2(-3 * unit, 2.5 * unit), Vector2(6 * unit, unit * 0.5)), accent)

func _draw_players() -> void:
	for i in range(game.players.size()):
		var p: Dictionary = game.players[i]
		if p.bankrupt: continue
		var pos: Vector2 = points[p.pos]
		var badge_radius: float = clampf(cell * 0.24, 5, 10)
		if not p.get("status", {}).is_empty():
			for lot in game.lots.values():
				if lot.building_type == p.status.kind and lot.kind == "facility":
					var box: Rect2 = lot_rects[lot.id]
					pos = box.get_center() + Vector2(0, box.size.y * 0.20)
					badge_radius = minf(10, step * 0.3)
					break
		pos += Vector2((i % 2 - 0.5) * badge_radius * 1.7, (floori(i / 2.0) - 0.5) * badge_radius * 1.7)
		if i == game.current: draw_arc(pos, badge_radius + 3, 0, TAU, 24, Color("ffd37c"), 2, true)
		draw_circle(pos, badge_radius + 1, Color.WHITE)
		draw_circle(pos, badge_radius, _player_color(i))
		draw_string(get_theme_default_font(), pos + Vector2(-badge_radius, badge_radius * 0.5), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2, clampi(int(badge_radius * 1.5), 9, 14), Color.WHITE)

func _tile_style(color: Color, radius: int = 5) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	return result

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(points.size()):
			if Rect2(points[i] - Vector2.ONE * cell / 2, Vector2.ONE * cell).has_point(event.position):
				tile_clicked.emit(i)
				accept_event()
				return
		for id in lot_rects:
			if lot_rects[id].has_point(event.position):
				lot_clicked.emit(id)
				accept_event()
				return
