extends Control
class_name ClearDialog

signal next_pressed()
signal retry_pressed()
signal select_pressed()

@export var title_label: Label
@export var stage_label: Label
@export var moves_label: Label
@export var next_button: Button
@export var retry_button: Button
@export var select_button: Button
@export var panel: PanelContainer

func _ready() -> void:
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if retry_button:
		retry_button.pressed.connect(_on_retry_button_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_button_pressed)

func _on_next_button_pressed() -> void:
	next_pressed.emit()

func _on_retry_button_pressed() -> void:
	retry_pressed.emit()

func _on_select_button_pressed() -> void:
	select_pressed.emit()

func show_clear(stage_id: int, moves_used: int, max_moves: int) -> void:
	visible = true
	var last_stage: bool = stage_id == get_node("/root/StageManager").get_total_stages()
	if stage_label:
		stage_label.text = "第 %d 面 クリア" % stage_id
		if not last_stage:
			stage_label.text += " · 次は第 %d 面" % (stage_id+1)
	if moves_label:
		moves_label.text = "%d手で到着 · 目標%d手\n%s" % [moves_used, max_moves, "最短手順です！" if moves_used <= max_moves else "次は、もっと少ない手数で。"]
	if title_label:
		title_label.text = "最終面クリア！" if last_stage else "2人とも、到着。"
	if next_button:
		next_button.text = "ステージを振り返る" if last_stage else "次の面へ"
	
	if panel:
		panel.scale = Vector2(0.8, 0.8)
		panel.pivot_offset = panel.size * 0.5
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.3)
