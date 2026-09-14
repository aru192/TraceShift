extends Control
class_name TitleController

@export var play_button: Button
@export var select_button: Button
@export var progress_label: Label
@export var reset_button: Button

func _get_stage_manager() -> Node:
	return get_node_or_null("/root/StageManager")

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	
	_update_progress()

func _update_progress() -> void:
	if progress_label:
		var sm := _get_stage_manager()
		var sav := _get_save_manager()
		var total: int = 100
		if sm != null and sm.has_method("get_total_stages"):
			total = sm.call("get_total_stages")
		var completed_count: int = 0
		if sav != null:
			var completed_stages = sav.get("completed_stages")
			if completed_stages is Dictionary:
				completed_count = completed_stages.size()
		progress_label.text = "クリア %d / %d  ·  DUET EDITION" % [completed_count, total]

func _on_play_pressed() -> void:
	var sav := _get_save_manager()
	var sm := _get_stage_manager()
	var target_stage: int = 1
	if sav != null and sav.get("max_unlocked_stage") != null:
		target_stage = int(sav.get("max_unlocked_stage"))
	
	var total: int = 100
	if sm != null and sm.has_method("get_total_stages"):
		total = sm.call("get_total_stages")
	if target_stage > total and total > 0:
		target_stage = total
	
	if sm != null and sm.has_method("set_current_stage"):
		sm.call("set_current_stage", target_stage)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stage_select.tscn")

func _on_reset_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "進行状況のリセット"
	dialog.dialog_text = "クリア記録をすべて消して、最初から始めますか？"
	dialog.ok_button_text = "リセット"
	dialog.cancel_button_text = "キャンセル"
	dialog.confirmed.connect(_confirm_reset)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 280))

func _confirm_reset() -> void:
	var sav := _get_save_manager()
	if sav != null and sav.has_method("reset_save"):
		sav.call("reset_save")
	_update_progress()
