extends Node2D
class_name CorePiece

signal step_requested(target_cell: Vector2i)
signal turn_finished()
signal drag_canceled()
var core_id: int = 0
var is_docked := false

@export_group("Visuals")
@export var core_radius: float = 32.0
@export var core_color: Color = Color(0.2, 0.90, 1.0, 1.0)
@export var glow_color: Color = Color(0.2, 0.90, 1.0, 0.40)
@export var inner_color: Color = Color(1.0, 1.0, 1.0, 0.95)

@export_group("Movement")
@export var move_duration: float = 0.07

var grid_pos: Vector2i = Vector2i.ZERO
var is_dragging: bool = false
var input_enabled: bool = true
var board = null

var _pulse_timer: float = 0.0
var _move_tween: Tween = null

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	queue_redraw()

func _draw() -> void:
	var tint := core_color if input_enabled or is_docked else core_color.darkened(0.3)
	if input_enabled:
		var radius := core_radius + 12 + sin(_pulse_timer) * 3
		draw_arc(Vector2.ZERO,radius,0,TAU,48,core_color,3,true)
	draw_circle(Vector2.ZERO,core_radius,tint)
	draw_string(ThemeDB.fallback_font,Vector2(-12,12),"A" if core_id == 0 else "B",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("ffffff"))
	if is_docked:
		draw_circle(Vector2(25,-27),12,Color("e7f7ff"))

func set_grid_pos(pos: Vector2i, instant: bool = false) -> void:
	grid_pos = pos
	if board != null and board.has_method("cell_to_local_pos"):
		var target_world: Vector2 = board.cell_to_local_pos(grid_pos)
		if instant:
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			position = target_world
		else:
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_move_tween.tween_property(self, "position", target_world, move_duration)

# スクリーン座標（event.position）をボードのローカル座標に変換する
# get_canvas_transform() はキャンバス→スクリーンの変換なので、逆変換でスクリーン→ワールド、
# さらに board.to_local() でボードローカルに変換する
func _to_board_pos(screen_pos: Vector2) -> Vector2:
	if board == null:
		return Vector2.ZERO
	var canvas_inv: Transform2D = board.get_canvas_transform().affine_inverse()
	var global_canvas_pos: Vector2 = canvas_inv * screen_pos
	return board.to_local(global_canvas_pos)

# Capture the active pointer even when it is released over a UI control.
var _pointer_id: int = -2
var _last_pointer_pos: Vector2

func _input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not is_dragging:
			_start_drag(event.position, event.index)
		elif event.index == _pointer_id and not event.pressed:
			if event.canceled:
				cancel_drag()
				drag_canceled.emit()
			else:
				_process_drag(event.position)
				_end_drag()
	elif event is InputEventScreenDrag and is_dragging and event.index == _pointer_id:
		_process_drag(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not is_dragging:
				_start_drag(event.position, -1)
			elif not event.pressed and _pointer_id == -1:
				_process_drag(event.position)
				_end_drag()
	elif event is InputEventMouseMotion and is_dragging and _pointer_id == -1:
		_process_drag(event.position)

func _start_drag(screen_pos: Vector2, pointer: int = -1) -> void:
	if not input_enabled or board == null or board.local_pos_to_cell(_to_board_pos(screen_pos)) != grid_pos:
		return
	is_dragging = true
	_pointer_id = pointer
	_last_pointer_pos = _to_board_pos(screen_pos)

func _process_drag(screen_pos: Vector2) -> void:
	if not is_dragging or board == null:
		return
	var destination := _to_board_pos(screen_pos)
	var origin := _last_pointer_pos
	var samples := maxi(1, int(ceil(origin.distance_to(destination) / (board.cell_size * 0.15))))
	for i in range(1, samples + 1):
		var cell: Vector2i = board.local_pos_to_cell(origin.lerp(destination, float(i) / samples))
		if cell == grid_pos:
			continue
		var diff: Vector2i = cell - grid_pos
		if absi(diff.x) == 1 and absi(diff.y) == 1:
			# Resolve a crossed corner one orthogonal cell at a time.
			step_requested.emit(grid_pos + Vector2i(diff.x, 0))
		step_requested.emit(cell)
	_last_pointer_pos = destination

func _end_drag() -> void:
	if is_dragging:
		is_dragging = false
		_pointer_id = -2
		turn_finished.emit()

func cancel_drag() -> void:
	is_dragging = false
	_pointer_id = -2

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_dragging:
		cancel_drag()
		drag_canceled.emit()
