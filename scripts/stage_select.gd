extends Control
class_name StageSelectController

const PAGE_SIZE := 10
var page := 0
var page_label: Label
var previous_button: Button
var next_button: Button

@export var back_button: Button
@export var grid_container: GridContainer
@export var scroll_container: ScrollContainer

func _get_stage_manager() -> Node:
	return get_node_or_null("/root/StageManager")

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	page = int((_get_stage_manager().current_stage_id-1) / PAGE_SIZE)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	previous_button = Button.new()
	previous_button.text = "前の10面"
	previous_button.custom_minimum_size = Vector2(240,120)
	previous_button.pressed.connect(_change_page.bind(-1))
	row.add_child(previous_button)
	page_label = Label.new()
	page_label.custom_minimum_size.x = 450
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(page_label)
	next_button = Button.new()
	next_button.text = "次の10面"
	next_button.custom_minimum_size = Vector2(240,120)
	next_button.pressed.connect(_change_page.bind(1))
	row.add_child(next_button)
	var layout = scroll_container.get_parent()
	layout.add_child(row)
	layout.move_child(row,scroll_container.get_index())
	_populate_stages()

func _populate_stages() -> void:
	if not grid_container:
		return
	
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	var sm := _get_stage_manager()
	var sav := _get_save_manager()
	
	var total_stages: int = 100
	if sm != null and sm.has_method("get_total_stages"):
		total_stages = sm.call("get_total_stages")
	if total_stages <= 0:
		total_stages = 100
	
	var first := page * PAGE_SIZE + 1
	var last := mini(first + PAGE_SIZE - 1, total_stages)
	page_label.text = "%d〜%d / %d面\n%s" % [first,last,total_stages,sm.get_stage_data(first).get("chapter", "")]
	previous_button.disabled = page == 0
	next_button.disabled = last >= total_stages
	scroll_container.scroll_vertical = 0
	for i in range(first, last + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(465, 230)
		btn.add_theme_font_size_override("font_size", 30)
		btn.text = str(i)
		
		var is_unlocked: bool = (i == 1)
		var is_completed: bool = false
		
		if sav != null:
			if sav.has_method("is_stage_unlocked"):
				is_unlocked = sav.call("is_stage_unlocked", i)
			if sav.has_method("is_stage_completed"):
				is_completed = sav.call("is_stage_completed", i)
		
		if is_completed:
			btn.text = "%d\n★" % i
			btn.modulate = Color(0.84, 0.94, 0.89)
		elif is_unlocked:
			btn.text = str(i)
			btn.modulate = Color.WHITE
		else:
			btn.text = "%d\nLOCK" % i
			btn.disabled = true
			btn.modulate = Color(0.35, 0.35, 0.45, 0.6)
		
		var data: Dictionary = sm.get_stage_data(i)
		btn.text = "%02d  %s\n%s" % [i, data.name, ("✓ %d手でクリア" % sav.get_best_moves(i)) if is_completed else ("最大%dマス · 目標%d手" % [data.step_limit,data.par_moves])]
		btn.pressed.connect(_on_stage_selected.bind(i))
		grid_container.add_child(btn)

func _on_stage_selected(stage_id: int) -> void:
	var sm := _get_stage_manager()
	if sm != null and sm.has_method("set_current_stage"):
		sm.call("set_current_stage", stage_id)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _change_page(delta: int) -> void:
	var total: int = _get_stage_manager().get_total_stages()
	page = clampi(page + delta, 0, int((total-1) / PAGE_SIZE))
	_populate_stages()
