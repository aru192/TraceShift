extends Control
class_name GameController

@export var board: Node2D
@export var core: Node2D
@export var stage_label: Label
@export var moves_label: Label
@export var target_info_label: Label
@export var rule_badge_label: Label
@export var hint_label: Label
@export var retry_button: Button
@export var select_button: Button
@export var board_container: Control
@export var clear_dialog: Control

var cores: Array[CorePiece] = []
var current_stage_data: Dictionary = {}
var is_game_over := false
var is_cleared := false
var hint_visible := false
var undo_button: Button
var hint_button: Button

func _ready() -> void:
	cores.append(core)
	var second := CorePiece.new()
	second.name = "CoreB"
	board.add_child(second)
	cores.append(second)
	for who in range(2):
		cores[who].board = board
		cores[who].core_id = who
		cores[who].core_color = PuzzleBoard.CORE_COLORS[who]
		cores[who].glow_color = Color(PuzzleBoard.CORE_COLORS[who],0.3)
		cores[who].step_requested.connect(_on_core_step_requested.bind(who))
		cores[who].turn_finished.connect(_on_core_turn_finished.bind(who))
		cores[who].drag_canceled.connect(_cancel_drag)
	board.path_updated.connect(_on_path_updated)
	board.turn_committed.connect(_on_turn_committed)
	board_container.resized.connect(_adjust_board_scale)
	retry_button.pressed.connect(load_current_stage)
	select_button.pressed.connect(_on_select_pressed)
	undo_button = find_child("UndoButton",true,false)
	hint_button = find_child("HintButton",true,false)
	undo_button.pressed.connect(_on_undo_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	clear_dialog.next_pressed.connect(_on_next_stage_pressed)
	clear_dialog.retry_pressed.connect(load_current_stage)
	clear_dialog.select_pressed.connect(_on_select_pressed)
	load_current_stage()

func load_current_stage() -> void:
	current_stage_data = get_node("/root/StageManager").get_current_stage_data()
	if current_stage_data.is_empty():
		return
	for piece in cores:
		piece.cancel_drag()
	board.initialize_stage(current_stage_data)
	is_game_over = false
	is_cleared = false
	hint_visible = false
	clear_dialog.hide()
	_sync_cores(true)
	_adjust_board_scale()
	_update_ui()

func _adjust_board_scale() -> void:
	if board.rules.width <= 0:
		return
	var available := board_container.size - Vector2(64,64)
	var raw: Vector2 = board.get_board_pixel_size()
	var factor := minf(available.x / raw.x,available.y / raw.y)
	board.scale = Vector2.ONE * maxf(0.1,factor)
	board.position = board_container.size * 0.5

func _sync_cores(instant: bool = false) -> void:
	var rules: DuetRules = board.rules
	for who in range(2):
		cores[who].set_grid_pos(rules.positions[who],instant)
		cores[who].input_enabled = who == rules.active and not is_game_over and not is_cleared
		cores[who].is_docked = rules.docked(who)
		cores[who].queue_redraw()
	board.queue_redraw()

func _update_ui() -> void:
	var rules: DuetRules = board.rules
	var who: String = "A" if rules.active == 0 else "B"
	stage_label.text = "%02d  %s" % [current_stage_data.stage_id,current_stage_data.name]
	moves_label.text = "%d手  /  目標 %d手" % [rules.moves,current_stage_data.par_moves]
	target_info_label.visible = true
	target_info_label.text = "ゴール %d / 2" % [int(rules.docked(0))+int(rules.docked(1))]
	rule_badge_label.add_theme_color_override("font_color", PuzzleBoard.CORE_COLORS[rules.active])
	var used := rules.path.size()-1
	rule_badge_label.text = "%s の番   %d / %d マス" % [who,used,rules.step_limit]
	if rules.path.back() == rules.goals[rules.active] and used > 0:
		rule_badge_label.text = "%s 到着！ 指を離して確定" % who
	elif used > 0 and rules.stops.has(rules.path.back()):
		rule_badge_label.text = "一時停止 · 指を離して交代"
	elif used == rules.step_limit:
		rule_badge_label.text = "上限です · 指を離して交代"
	undo_button.disabled = rules.history.is_empty() and used == 0
	hint_button.text = "ヒントを閉じる" if hint_visible else "考えるヒント"
	hint_label.modulate = Color("ffffff")
	if is_game_over:
		var blocked := rules.blocked_core()
		hint_label.text = "%s の道が塞がりました。\n「1手戻す」で、相手の道を残すルートへ。" % ("A" if blocked == 0 else "B")
		hint_label.modulate = Color("b96332")
	elif hint_visible:
		hint_label.text = str(current_stage_data.hint)
	elif used > 0:
		hint_label.text = "指を離すと、この軌跡が2人を阻む壁に。\n直前のマスへなぞり戻すと取り消せます。"
	else:
		hint_label.text = str(current_stage_data.brief)

func _on_path_updated(_length: int) -> void:
	_update_ui()

func _on_core_step_requested(cell: Vector2i, who: int = -1) -> void:
	var rules: DuetRules = board.rules
	if is_game_over or is_cleared or (who != -1 and who != rules.active):
		return
	if board.add_step_to_path(cell):
		cores[rules.active].set_grid_pos(rules.path.back())

func _on_core_turn_finished(who: int = -1) -> void:
	if is_game_over or is_cleared or (who != -1 and who != board.rules.active):
		return
	board.commit_turn()

func _on_turn_committed(_length: int) -> void:
	var rules: DuetRules = board.rules
	is_cleared = rules.won()
	is_game_over = not is_cleared and rules.blocked_core() != -1
	_sync_cores()
	_update_ui()
	if is_cleared:
		var save = get_node_or_null("/root/SaveManager")
		if save:
			save.complete_stage(int(current_stage_data.stage_id),rules.moves)
		clear_dialog.show_clear(int(current_stage_data.stage_id),rules.moves,int(current_stage_data.par_moves))

func _on_undo_pressed() -> void:
	for piece in cores:
		piece.cancel_drag()
	if board.rules.undo():
		is_game_over = false
		is_cleared = false
		clear_dialog.hide()
		_sync_cores(true)
		_update_ui()

func _cancel_drag() -> void:
	board.rules.cancel_path()
	_sync_cores(true)
	_update_ui()

func _on_hint_pressed() -> void:
	hint_visible = not hint_visible
	_update_ui()

func _on_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")

func _on_next_stage_pressed() -> void:
	var manager = get_node("/root/StageManager")
	if manager.go_to_next_stage():
		load_current_stage()
	else:
		_on_select_pressed()
