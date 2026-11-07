extends Control

const Gods = preload("res://scripts/model/god_rules.gd")

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
var zoom_factor: float = 1.0
var pan_offset := Vector2.ZERO
var dragging: bool = false

func reset_view() -> void:
	zoom_factor = 1.0
	pan_offset = Vector2.ZERO
	queue_redraw()

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next: float = clampf(zoom_factor * factor, 1.0, 4.0)
	pan_offset = (pan_offset + size / 2 - anchor) * (next / zoom_factor) + anchor - size / 2
	zoom_factor = next
	if is_equal_approx(zoom_factor, 1.0): pan_offset = Vector2.ZERO
	queue_redraw()

func focus_player() -> void:
	if game == null or game.players.is_empty(): return
	_layout()
	pan_offset += size / 2 - points[game.players[game.current].pos]
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
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
	step = maxf(1, minf((size.x - 44) / extent.x, (size.y - 44) / extent.y)) * zoom_factor
	cell = step * 0.82
	origin = (size - extent * step) / 2 - low * step + pan_offset
	points.clear()
	for n in game.nodes: points.append(origin + n.pos * step)
	lot_rects.clear()
	for lot in game.lots.values():
		var f: Rect2i = lot.footprint
		lot_rects[lot.id] = Rect2(origin + (Vector2(f.position) - Vector2.ONE * 0.5) * step, Vector2(f.size) * step).grow(-step * 0.12)

func _draw() -> void:
	if game == null or game.nodes.is_empty() or size.x <= 44 or size.y <= 44: return
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
		elif n.kind == "lottery": fill = Color("f1ce72")
		elif n.kind == "magic": fill = Color("b99be3")
		elif n.kind == "metro": fill = Color("91d3dc")
		elif n.kind == "cash": fill = Color("a7d2a0") if n.get("cash_amount", 0) > 0 else Color("e1a39a")
		elif n.kind == "unresolved": fill = Color("ddc486")
		elif n.kind == "news": fill = Color("dda3ad")
		elif n.kind == "minigame": fill = Color("a6b4de")
		draw_style_box(_tile_style(fill, 3), box)
		if active_roads.has(n.id): draw_rect(box.grow(1), Color("73e6d0"), false, 2)
		if selected == n.id: draw_rect(box.grow(2), Color.WHITE, false, 2)
		if moves.has(n.id): draw_rect(box.grow(3), Color("ffce62"), false, 3)
		var caption: String = str(n.id)
		if n.kind == "start": caption = "起"
		elif n.kind == "event": caption = "?"
		elif n.kind == "lottery": caption = "彩"
		elif n.kind == "magic": caption = "魔"
		elif n.kind == "metro": caption = "M"
		elif n.kind == "cash": caption = "+" if n.get("cash_amount", 0) > 0 else "−"
		elif n.kind == "unresolved": caption = "?"
		elif n.kind == "news": caption = "!"
		elif n.kind == "minigame": caption = "游"
		var font_size: int = clampi(int(cell * 0.43), 9, 14)
		if cell >= 13 or n.kind != "road":
			draw_string(font, pos + Vector2(-cell / 2, font_size * 0.35), caption, HORIZONTAL_ALIGNMENT_CENTER, cell, maxi(1, mini(font_size, int(cell))), Color("27434a"))
		if n.get("signal", false):
			draw_circle(pos + Vector2(cell * 0.24, -cell * 0.24), 3, Color("f06560") if game.traffic_phase else Color("35b982"))
		if game.road_objects.has(n.id):
			var mine_centre := pos + Vector2(cell * 0.22, -cell * 0.24)
			var radius := maxf(4, cell * 0.19)
			draw_circle(mine_centre, radius + 1, Color("ffdb9f"))
			var object_kind: String = game.road_objects[n.id].kind
			var object_colors := {"roadblock":"bc8136", "portal":"7757be", "banana":"ba8b18", "jelly":"3c7bb8", "trap":"575a63", "timebomb":"c46824", "explosive":"a12e38", "mine":"a12e38"}
			draw_circle(mine_centre, radius, Color(object_colors.get(object_kind, "a12e38")))
			var glyph: String = {"roadblock":"−", "portal":"门", "banana":"滑", "jelly":"返", "trap":"锁", "timebomb":"时", "explosive":"炸", "mine":"+"}.get(object_kind, "+")
			draw_string(font, mine_centre + Vector2(-radius-2, radius*0.7), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius*2+4, maxi(8, int(radius*1.8)), Color("fff2d8"))
		if game.road_gods.has(n.id):
			var god_id: String = game.road_gods[n.id]
			var center := pos + Vector2(-cell*0.23, cell*0.23)
			var radius := maxf(5, cell*0.25)
			var diamond := PackedVector2Array([center+Vector2(0,-radius), center+Vector2(radius,0), center+Vector2(0,radius), center+Vector2(-radius,0)])
			draw_colored_polygon(diamond, god_color(god_id))
			draw_string(font, center+Vector2(-radius,radius*0.6), god_glyph(god_id), HORIZONTAL_ALIGNMENT_CENTER, radius*2, maxi(9,int(radius*1.7)), Color("142532"))
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
	if lot.get("closed_until", 0) > game.round_number: draw_rect(box.grow(-3), Color("de7d73"), false, 3)
	if box.size.x < 54 or box.size.y < 54:
		_draw_compact_lot(lot, box, accent)
	elif lot.kind == "small":
		_draw_small_lot(lot, box, accent)
	else:
		var font := get_theme_default_font()
		var name_size: int = clampi(int(step * 0.48), 10, 17)
		var title: String = str(lot.name)
		if not facility and lot.owner >= 0: title = game.building_name(lot.building_type)
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > box.size.x - 8:
			name_size = maxi(9, int((box.size.x - 8) / maxf(1, title.length())))
		draw_string(font, box.position + Vector2(4, name_size + 4), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 8, name_size, Color("eaf3ed"))
		var centre: Vector2 = box.get_center() + Vector2(0, 3)
		var icon_size: float = maxf(10, minf(box.size.x - 12, box.size.y - 40))
		icon_size = minf(icon_size, step * 2.1)
		if facility:
			_draw_facility(str(lot.building_type), centre, icon_size, accent)
		elif lot.owner >= 0 and lot.building_type in ["mall", "hotel", "estate", "bookstore", "energy", "lab", "park"]:
			draw_rect(Rect2(centre - Vector2.ONE * icon_size * 0.4, Vector2.ONE * icon_size * 0.8), accent.darkened(0.35))
			var glyph: String = {"mall":"商", "hotel":"宿", "estate":"产", "bookstore":"书", "energy":"能", "lab":"研", "park":"园"}[lot.building_type]
			draw_string(font, centre + Vector2(-icon_size / 2, icon_size * 0.22), glyph, HORIZONTAL_ALIGNMENT_CENTER, icon_size, int(icon_size * 0.6), accent.lightened(0.4))
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

func _draw_compact_lot(lot: Dictionary, box: Rect2, accent: Color) -> void:
	var width: float = minf(box.size.x, box.size.y) * 0.55
	if lot.kind == "facility":
		_draw_facility(lot.building_type, box.get_center(), width, accent)
	else:
		var centre: Vector2 = box.get_center()
		draw_rect(Rect2(centre - Vector2.ONE * width / 2, Vector2.ONE * width), accent.darkened(0.15))
		if width >= 13:
			var caption: String = str(lot.level) if lot.owner >= 0 else "地"
			draw_string(get_theme_default_font(), centre + Vector2(-width / 2, 4), caption, HORIZONTAL_ALIGNMENT_CENTER, width, 11, Color("eaf3ed"))

func _draw_small_lot(lot: Dictionary, box: Rect2, accent: Color) -> void:
	# Short coordinate labels match the full name in the sidebar. Never truncate prices.
	var font := get_theme_default_font()
	var title: String = str(lot.name).trim_prefix("住宅 ")
	var font_size: int = clampi(int(box.size.x * 0.23), 10, 14)
	draw_string(font, box.position + Vector2(2, font_size + 2), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 4, font_size, Color("eaf3ed"))
	var icon_centre: Vector2 = box.get_center() + Vector2(0, 2)
	var unit: float = minf(box.size.x * 0.16, box.size.y * 0.14)
	var roof := PackedVector2Array([icon_centre + Vector2(-unit * 1.5, 0), icon_centre + Vector2(0, -unit * 1.25), icon_centre + Vector2(unit * 1.5, 0)])
	if lot.building_type == "chain":
		draw_rect(Rect2(icon_centre + Vector2(-unit * 1.5, -unit), Vector2(unit * 3, unit)), accent.lightened(0.35))
		for stripe in range(3): draw_rect(Rect2(icon_centre + Vector2(-unit * 1.5 + stripe * unit, -unit), Vector2(unit * 0.5, unit)), Color("f0d9aa"))
	else: draw_colored_polygon(roof, accent.lightened(0.25))
	draw_rect(Rect2(icon_centre + Vector2(-unit, 0), Vector2(unit * 2, unit)), accent)
	draw_rect(Rect2(icon_centre + Vector2(-unit * 0.22, unit * 0.3), Vector2(unit * 0.44, unit * 0.7)), Color("27453d"))
	var subtitle: String = "待购" if lot.owner < 0 else "%d级" % int(lot.level)
	draw_string(font, Vector2(box.position.x + 2, box.end.y - 3), subtitle, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 4, maxi(10, font_size - 1), accent.lightened(0.3))

func _draw_facility(kind: String, centre: Vector2, width: float, accent: Color) -> void:
	var unit: float = width / 6
	if kind == "shop":
		draw_rect(Rect2(centre - Vector2(width * 0.4, width * 0.2), Vector2(width * 0.8, width * 0.65)), accent)
		for stripe in range(4): draw_rect(Rect2(centre + Vector2(-width * 0.5 + stripe * width * 0.25, -width * 0.4), Vector2(width * 0.25, width * 0.25)), accent if stripe % 2 == 0 else Color("f1d6a0"))
	elif kind == "hospital":
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
			if p.status.kind == "vacation" and lot_rects.has(p.status.get("lot_id", "")):
				pos = lot_rects[p.status.lot_id].get_center() + Vector2(0, step * 0.8)
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
		if p.get("vehicle", "foot") != "foot":
			var chassis := Rect2(pos + Vector2(-badge_radius-3, badge_radius-2), Vector2(badge_radius*2+6, 5))
			draw_rect(chassis, _player_color(i).lightened(0.3))
			draw_circle(chassis.position + Vector2(3, 5), 3, Color("182733"))
			draw_circle(chassis.end + Vector2(-3, 0), 3, Color("182733"))
			if p.vehicle == "car": draw_rect(Rect2(pos + Vector2(-badge_radius-2, -badge_radius-4), Vector2(badge_radius*2+4, 3)), _player_color(i).lightened(0.3))
		if p.get("status", {}).get("kind", "") in ["hibernate", "sleepwalk"]:
			draw_string(get_theme_default_font(), pos + Vector2(-badge_radius, -badge_radius - 4), "Zz", HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2 + 8, 14, Color("c6dcff"))
		if not p.get("bomb", {}).is_empty():
			draw_string(get_theme_default_font(), pos + Vector2(-badge_radius-4, badge_radius+16), str(p.bomb.remaining), HORIZONTAL_ALIGNMENT_CENTER, badge_radius*2+8, 12, Color("ffb57a"))
		if not p.get("god", {}).is_empty():
			draw_arc(pos, badge_radius + 4, 0, TAU, 24, god_color(p.god.id), 2, true)
			draw_string(get_theme_default_font(), pos + Vector2(-badge_radius, badge_radius+16), god_glyph(p.god.id), HORIZONTAL_ALIGNMENT_CENTER, badge_radius*2, 12, god_color(p.god.id))
		if game.phase == "reaction" and game.reaction_player() == i:
			draw_arc(pos, badge_radius + 6, 0, TAU, 24, Color("f28a79"), 3, true)

func _tile_style(color: Color, radius: int = 5) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	return result

func god_glyph(id: String) -> String:
	return {"wealth":"财", "poor":"穷", "fortune":"福", "misfortune":"衰", "angel":"天", "devil":"魔", "earth":"土", "confused":"糊", "martial":"武", "fierce":"凶"}.get(id,"神")

func god_color(id: String) -> Color:
	return Color("ef9c9c") if id in ["poor", "misfortune", "devil", "confused", "fierce"] else Color("e9d383")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
			accept_event()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, event.position)
			accept_event()
			return
	if event is InputEventMouseMotion:
		if dragging and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			pan_offset += event.relative
			queue_redraw()
			accept_event()
			return
		dragging = false
		tooltip_text = ""
		for id in lot_rects:
			if lot_rects[id].has_point(event.position):
				var lot: Dictionary = game.lots[id]
				tooltip_text = "%s · %s" % [lot.name, "公共设施" if lot.kind == "facility" else ("待购 %d" % lot.price if lot.owner < 0 else "%s · %d级" % [game.players[lot.owner].name, lot.level])]
				return
		for n in game.nodes:
			if event.position.distance_to(points[n.id]) < maxf(6, cell / 2):
				tooltip_text = "%02d · %s" % [n.id, n.name]
				return
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
