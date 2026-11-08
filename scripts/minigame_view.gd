extends Control

signal cell_selected(cell: int)
signal bin_selected(bin_id: int)
signal switch_selected(switch_id: int)
signal lane_selected(lane: int)
var game: RefCounted
var input_enabled := false
var animation_fraction: float = 0.0
var cells: Array[Rect2] = []
var bins: Array[Rect2] = []
var switches: Array[Rect2] = []
var lane_buttons: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	if game == null or game.phase != "minigame" or size.x < 50 or size.y < 100: return
	var state: Dictionary = game.pending_service.game
	var font := get_theme_default_font()
	draw_style_box(_style(Color("112c32"), 16), Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(24, 34), game.Minigame.title(game) + "  /  " + game.players[game.current].name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 24, Color("e8d7a5"))
	if state.status == "result":
		for index in range(state.history.size()):
			var result: Dictionary = state.history[index]
			draw_string(font, Vector2(40, 120 + index * 68), "%s     %d 分     奖励 %d" % [game.players[result.player].name, result.score, game.Minigame.cash_reward(game,result)], HORIZONTAL_ALIGNMENT_LEFT, size.x - 80, 23, Color("e8d7a5") if result.player == game.current else Color("c7d8dd"))
		return
	var rules: Dictionary = game.Minigame.profile(game)
	var remaining: float = (rules.ticks - state.tick) * rules.tick_seconds
	draw_string(font, Vector2(24, 65), "得分 %d    剩余 %.1f 秒" % [state.score, remaining], HORIZONTAL_ALIGNMENT_LEFT, size.x - 48, 18, Color("c7d8dd"))
	if state.id == "toss_dolls":
		_draw_dolls(state,font)
		return
	if state.id == "disarm_bomb":
		_draw_switches(state,font)
		return
	if state.id == "shoot_balloons":
		_draw_balloons(state,font)
		return
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

func _draw_dolls(state: Dictionary, font: Font) -> void:
	cells.clear()
	bins.clear()
	var center := Vector2(size.x * 0.5, size.y * 0.43)
	if not state.queue.is_empty():
		_draw_toy(center, str(state.queue[0]), 39, font)
		draw_string(font, center + Vector2(-125,68), "当前物品 · 请选择投掷位置", HORIZONTAL_ALIGNMENT_CENTER, 250, 16, Color("e8d7a5"))
		draw_string(font, Vector2(28,112), "接下来", HORIZONTAL_ALIGNMENT_LEFT, 100, 16, Color("9dbac1"))
		for index in range(1,state.queue.size()):
			_draw_toy(Vector2(155+(index-1)*62,106),str(state.queue[index]),19,font)
	var colors := [Color("376b9b"),Color("42535a"),Color("985b83")]
	var names := ["蓝色篮", "垃圾桶", "粉色篮"]
	var counts := [str(state.baskets.blue)+" 只", "炸弹丢这里", str(state.baskets.pink)+" 只"]
	var width: float = (size.x-100)/3
	for index in range(3):
		var box := Rect2(Vector2(30+index*(width+20),size.y*0.65),Vector2(width,minf(115,size.y*0.23)))
		bins.append(box)
		draw_style_box(_style(colors[index],12),box)
		if state.choice == index: draw_rect(box.grow(-3),Color("f1d18a"),false,4)
		draw_string(font,box.position+Vector2(0,37),names[index],HORIZONTAL_ALIGNMENT_CENTER,box.size.x,22,Color("f3edf0"))
		draw_string(font,box.position+Vector2(0,73),counts[index],HORIZONTAL_ALIGNMENT_CENTER,box.size.x,16,Color("dae5ed"))
	var caption:String = "点击下方目标投掷 · 蓝归蓝，粉归粉，炸弹及时扔掉"
	if state.choice >= 0: caption = "已选择「%s」 · 正在投掷" % names[state.choice]
	draw_string(font,Vector2(20,size.y-18),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-40,16,Color("a7c4ca"))

func _draw_toy(center:Vector2, kind:String, radius:float, font:Font) -> void:
	var color:Color = Color("70b9ed") if kind == "blue" else Color("eea0c7")
	if kind == "bomb":
		draw_circle(center,radius,Color("d47070"))
		draw_line(center+Vector2(-radius*0.35,-radius*0.35),center+Vector2(radius*0.35,radius*0.35),Color("fff0dc"),4,true)
		draw_line(center+Vector2(radius*0.35,-radius*0.35),center+Vector2(-radius*0.35,radius*0.35),Color("fff0dc"),4,true)
	else:
		draw_circle(center+Vector2(-radius*0.65,-radius*0.65),radius*0.43,color)
		draw_circle(center+Vector2(radius*0.65,-radius*0.65),radius*0.43,color)
		draw_circle(center,radius,color)
		for direction in [-1,1]: draw_circle(center+Vector2(direction*radius*0.33,-radius*0.12),radius*0.10,Color("183449"))
		draw_arc(center+Vector2(0,radius*0.12),radius*0.27,0,PI,12,Color("183449"),2,true)

func _draw_switches(state:Dictionary,font:Font) -> void:
	cells.clear();bins.clear();switches.clear()
	var stage_text:String = {"preview":"记住金币与炸弹的位置", "shuffle":"留意开关换位 · 现在不能打开", "choose":"点击开关揭开物品 · 炸弹会结束本轮"}[state.stage]
	draw_string(font,Vector2(30,128),stage_text,HORIZONTAL_ALIGNMENT_CENTER,size.x-60,22,Color("e8d7a5"))
	var unit:float = (size.x-70)/6
	var centers:Array[Vector2]=[]
	for index in range(6):
		var box:=Rect2(Vector2(25+index*unit,size.y*0.42),Vector2(unit-10,130))
		switches.append(box)
		centers.append(box.get_center())
		draw_string(font,Vector2(box.position.x,box.end.y+36),str(index+1),HORIZONTAL_ALIGNMENT_CENTER,box.size.x,20,Color("92b3c0"))
	for index in range(6):
		var point:Vector2 = centers[index]
		if state.stage == "shuffle" and state.last_swap.has(index):
			var other:int = state.last_swap[1] if index == state.last_swap[0] else state.last_swap[0]
			point = centers[other].lerp(centers[index],animation_fraction)
			point.y += sin(animation_fraction*PI)*70*(1 if index == state.last_swap[0] else -1)
		var face:=Rect2(point-Vector2((unit-10)/2,65),Vector2(unit-10,130))
		var revealed:bool = state.stage == "preview" or state.opened.has(index)
		draw_style_box(_style(Color("294956") if revealed else Color("3c4c58"),12),face)
		if state.stage == "choose" and not state.opened.has(index): draw_rect(face.grow(-3),Color("6bbfb9"),false,2)
		if revealed:
			if state.initial[state.order[index]] == "coin":
				draw_circle(point,25,Color("e8bb4d"))
				draw_string(font,point+Vector2(-23,8),"$",HORIZONTAL_ALIGNMENT_CENTER,46,25,Color("6b4e20"))
			else: _draw_toy(point,"bomb",25,font)
		else:
			draw_line(point+Vector2(0,-29),point+Vector2(0,17),Color("d9ab65"),8,true)
			draw_line(point+Vector2(-23,-29),point+Vector2(23,-29),Color("edc68b"),8,true)
			draw_circle(point+Vector2(0,24),21,Color("172f3c"))
	var caption:String="先观察，再记住每次换位。只有选择阶段能打开开关。"
	if state.stage == "choose":caption="已打开 %d / 6 · 已得 %d 分 · 开到炸弹保留已得分"%[state.opened.size(),state.score]
	draw_string(font,Vector2(20,size.y-35),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-40,17,Color("a7c4ca"))

func _draw_balloons(state:Dictionary,font:Font) -> void:
	cells.clear();bins.clear();switches.clear();lane_buttons.clear()
	var area:=Rect2(Vector2(30,95),Vector2(size.x-60,size.y-195))
	var lane_width:float=area.size.x/4
	for lane in range(4):
		var column:=Rect2(area.position+Vector2(lane*lane_width,0),Vector2(lane_width-8,area.size.y))
		draw_style_box(_style(Color("1b3c46") if lane%2==0 else Color("203f48"),8),column)
		var control:=Rect2(Vector2(column.position.x,area.end.y+12),Vector2(column.size.x,50))
		lane_buttons.append(control)
		draw_style_box(_style(Color("466c7c") if state.choice==lane else Color("2b5668"),8),control)
		draw_string(font,control.position+Vector2(0,32),"发射 %d"%(lane+1),HORIZONTAL_ALIGNMENT_CENTER,control.size.x,21,Color("ebdec2"))
		if state.choice==lane:draw_rect(column.grow(-4),Color("f1d18a"),false,3)
	var profile:Dictionary=game.Minigame.profile(game)
	for balloon in state.balloons:
		var visual_height:float=maxi(0,balloon.height-balloon.speed)+animation_fraction*mini(balloon.speed,balloon.height)
		var point:=Vector2(area.position.x+(balloon.lane+0.5)*lane_width-4,area.end.y-30-visual_height/profile.top_height*(area.size.y-60))
		var color:Color=Color("d16f78") if balloon.kind=="bomb" else (Color("e0b660") if balloon.kind=="ingot" else Color("72bcd0"))
		draw_line(point+Vector2(0,20),point+Vector2(0,35),color,2,true)
		draw_circle(point,24,color)
		var glyph:String="×" if balloon.kind=="bomb" else ("◆" if balloon.kind=="ingot" else "$")
		draw_string(font,point+Vector2(-22,8),glyph,HORIZONTAL_ALIGNMENT_CENTER,44,25,Color("122b36"))
	draw_string(font,Vector2(20,size.y-18),"一炮击中该区所有气球 · 红色炸弹飞得更快，可等它飞走",HORIZONTAL_ALIGNMENT_CENTER,size.x-40,16,Color("a7c4ca"))

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	return result

func _gui_input(event: InputEvent) -> void:
	if not input_enabled: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game != null and game.phase == "minigame" and game.pending_service.game.id == "shoot_balloons":
			for lane in range(lane_buttons.size()):
				if lane_buttons[lane].has_point(event.position):
					lane_selected.emit(lane)
					accept_event()
					return
			return
		if game != null and game.phase == "minigame" and game.pending_service.game.id == "disarm_bomb":
			for index in range(switches.size()):
				if switches[index].has_point(event.position):
					switch_selected.emit(index)
					accept_event()
					return
			return
		if game != null and game.phase == "minigame" and game.pending_service.game.id == "toss_dolls":
			for index in range(bins.size()):
				if bins[index].has_point(event.position):
					bin_selected.emit(index)
					accept_event()
					return
			return
		for index in range(cells.size()):
			if cells[index].has_point(event.position):
				cell_selected.emit(index)
				accept_event()
				return
