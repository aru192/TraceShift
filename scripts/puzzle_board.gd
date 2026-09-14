extends Node2D
class_name PuzzleBoard

signal path_updated(length: int)
signal turn_committed(path_length: int)

const CORE_COLORS = [Color("2876ad"), Color("b96332")]
@export var cell_size: float = 120.0
var rules := DuetRules.new()
var _phase := 0.0

func _process(delta: float) -> void:
	_phase += delta * 3.0
	queue_redraw()

func initialize_stage(data: Dictionary) -> void:
	rules.setup(data)
	queue_redraw()

func get_board_pixel_size() -> Vector2:
	return Vector2(rules.width, rules.height) * cell_size

func cell_to_local_pos(cell: Vector2i) -> Vector2:
	return -get_board_pixel_size() * 0.5 + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size

func local_pos_to_cell(local_pos: Vector2) -> Vector2i:
	var point := (local_pos + get_board_pixel_size() * 0.5) / cell_size
	return Vector2i(floor(point.x), floor(point.y))

func add_step_to_path(cell: Vector2i) -> bool:
	if not rules.step(cell):
		return false
	path_updated.emit(rules.path.size()-1)
	queue_redraw()
	return true

func commit_turn() -> bool:
	var length := rules.path.size()-1
	if not rules.commit():
		return false
	turn_committed.emit(length)
	queue_redraw()
	return true

func _draw() -> void:
	if rules.positions.size() != 2:
		return
	var bounds := Rect2(-get_board_pixel_size()*0.5-Vector2(10,10),get_board_pixel_size()+Vector2(20,20))
	draw_style_box(_box(Color("e6eaee"),12),bounds)
	for y in range(rules.height):
		for x in range(rules.width):
			var cell := Vector2i(x,y)
			var center := cell_to_local_pos(cell)
			var rect := Rect2(center-Vector2.ONE*(cell_size/2-4),Vector2.ONE*(cell_size-8))
			var color := Color("ffffff")
			if rules.fixed_walls.has(cell):
				color = Color("d3d9df")
			draw_style_box(_box(color,8),rect)
			if rules.fixed_walls.has(cell):
				draw_line(center-Vector2(12,12),center+Vector2(12,12),Color("87939e"),3)
				draw_line(center+Vector2(-12,12),center+Vector2(12,-12),Color("87939e"),3)
			if rules.arrows.has(cell):
				var direction: Vector2 = Vector2(rules.arrows[cell])
				var side := direction.orthogonal()
				var tip := center + direction * 22
				draw_line(center-direction*22,tip,Color("626e7a"),4,true)
				draw_polyline(PackedVector2Array([tip-direction*12+side*12,tip,tip-direction*12-side*12]),Color("626e7a"),4,true)
			if rules.stops.has(cell):
				draw_rect(Rect2(center-Vector2(16,16),Vector2(32,32)),Color("626e7a"),false,4)
			if rules.traces.has(cell):
				var tint: Color = CORE_COLORS[rules.traces[cell]]
				draw_style_box(_box(tint.lightened(0.82),7),rect.grow(-3))
				draw_line(center-Vector2(20,20),center+Vector2(20,20),tint,5)
				draw_line(center+Vector2(-20,20),center+Vector2(20,-20),tint,5)
	for who in range(2):
		var center := cell_to_local_pos(rules.goals[who])
		var tint: Color = CORE_COLORS[who]
		var radius := cell_size * 0.34
		draw_arc(center,radius,0,TAU,48,tint,5,true)
		draw_arc(center,radius-9,0,TAU,48,Color(tint,0.3),2,true)
		var glyph := "A" if who == 0 else "B"
		draw_string(ThemeDB.fallback_font,center+Vector2(-12,12),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,34,tint)
	if rules.path.size() > 1:
		var pts := PackedVector2Array()
		for cell in rules.path:
			pts.append(cell_to_local_pos(cell))
		var tint: Color = CORE_COLORS[rules.active]
		draw_polyline(pts,Color(tint,0.18),24,true)
		draw_polyline(pts,tint,9,true)
		for i in range(pts.size()-1):
			draw_circle(pts[i],9,tint)
	# Possible next cells make the movement limit and orthogonal rule legible.
	for direction in DuetRules.DIRECTIONS:
		var cell: Vector2i = rules.path.back() + direction
		if rules.can_step(cell):
			draw_circle(cell_to_local_pos(cell),6,Color(CORE_COLORS[rules.active],0.65))

var _boxes: Dictionary = {}
func _box(color: Color, radius: int) -> StyleBoxFlat:
	var key := str(color) + str(radius)
	if not _boxes.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		_boxes[key] = style
	return _boxes[key]
