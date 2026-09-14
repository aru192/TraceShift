extends Node

const STAGES_FILE_PATH := "res://data/stages.json"

var stages: Array = []
var stage_map: Dictionary = {} # stage_id (int) -> stage_data (Dictionary)
var current_stage_id: int = 1

func _ready() -> void:
	load_stages()

func load_stages() -> void:
	stages.clear()
	stage_map.clear()
	
	if not FileAccess.file_exists(STAGES_FILE_PATH):
		push_warning("Stages file not found at " + STAGES_FILE_PATH)
		return
	
	var file := FileAccess.open(STAGES_FILE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		var res := json.parse(content)
		if res == OK and json.data is Array:
			stages = json.data
			for s in stages:
				if s is Dictionary and s.has("stage_id"):
					stage_map[int(s["stage_id"])] = s
		else:
			push_error("Failed to parse stages.json: " + json.get_error_message())

func get_total_stages() -> int:
	return stages.size()

func get_stage_data(stage_id: int) -> Dictionary:
	if stage_map.has(stage_id):
		return stage_map[stage_id]
	return {}

func get_current_stage_data() -> Dictionary:
	return get_stage_data(current_stage_id)

func set_current_stage(stage_id: int) -> void:
	current_stage_id = stage_id

func has_next_stage() -> bool:
	return stage_map.has(current_stage_id + 1)

func go_to_next_stage() -> bool:
	if has_next_stage():
		current_stage_id += 1
		return true
	return false
