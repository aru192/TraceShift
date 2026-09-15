extends Node

const SAVE_PATH := "user://duet_save_v4.json"
const LEGACY_PATH := "user://duet_save_v3.json"

var max_unlocked_stage: int = 1
var completed_stages: Dictionary = {} # stage_id (int) -> { "moves": int, "completed": bool }

func _ready() -> void:
	load_from_disk()

func is_stage_unlocked(stage_id: int) -> bool:
	var manager = get_node_or_null("/root/StageManager")
	return manager != null and manager.stage_map.has(stage_id) and stage_id <= max_unlocked_stage

func is_stage_completed(stage_id: int) -> bool:
	return completed_stages.has(stage_id) and completed_stages[stage_id].get("completed", false)

func get_best_moves(stage_id: int) -> int:
	if completed_stages.has(stage_id):
		return completed_stages[stage_id].get("moves", 0)
	return 0

func complete_stage(stage_id: int, moves_used: int) -> void:
	if not is_stage_unlocked(stage_id):
		return
	if not completed_stages.has(stage_id):
		completed_stages[stage_id] = {
			"completed": true,
			"moves": moves_used
		}
	else:
		completed_stages[stage_id]["completed"] = true
		var prev_moves: int = completed_stages[stage_id].get("moves", 9999)
		if moves_used < prev_moves:
			completed_stages[stage_id]["moves"] = moves_used
	
	_recompute_unlocks()
	
	save_to_disk()

func save_to_disk() -> void:
	var stringified_completed := {}
	for k in completed_stages.keys():
		stringified_completed[str(k)] = completed_stages[k]
		
	var data := {
		"max_unlocked_stage": max_unlocked_stage,
		"completed_stages": stringified_completed
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str := JSON.stringify(data, "\t")
		file.store_string(json_str)
		file.close()

func load_from_disk() -> void:
	var path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else LEGACY_PATH
	if not FileAccess.file_exists(path):
		path = "user://duet_save_v2.json"
	if not FileAccess.file_exists(path):
		max_unlocked_stage = 1
		completed_stages = {}
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str := file.get_as_text()
		file.close()
		var json := JSON.new()
		var parse_result := json.parse(json_str)
		if parse_result == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			apply_progress(data, path != SAVE_PATH)

func apply_progress(data: Dictionary, legacy: bool = false) -> void:
	completed_stages.clear()
	var raw: Dictionary = data.get("completed_stages", {})
	for k in raw:
		var id := int(k)
		if id >= 1 and id <= 100 and (not legacy or id <= 5) and raw[k] is Dictionary:
			completed_stages[id] = raw[k]
	_recompute_unlocks()

func _recompute_unlocks() -> void:
	max_unlocked_stage = 1
	while max_unlocked_stage < 100 and is_stage_completed(max_unlocked_stage):
		max_unlocked_stage += 1

func reset_save() -> void:
	max_unlocked_stage = 1
	completed_stages.clear()
	save_to_disk()
