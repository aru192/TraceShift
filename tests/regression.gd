extends SceneTree

class MemorySave:
	extends "res://scripts/save_manager.gd"
	func save_to_disk() -> void:
		pass

var failures := 0
var checks := 0
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func play_turn(game: GameController, turn: Dictionary) -> void:
	check(game.board.rules.active == int(turn.core), "correct active core")
	for i in range(1,turn.path.size()):
		var cell := Vector2i(turn.path[i][0],turn.path[i][1])
		game._on_core_step_requested(cell,int(turn.core))
		check(game.board.rules.path.back() == cell,"accepted legal solution step")
	game._on_core_turn_finished(int(turn.core))

func run() -> void:
	var save = root.get_node_or_null("SaveManager")
	if save:
		root.remove_child(save)
		save.queue_free()
	var manager = root.get_node("StageManager")
	check(manager.get_total_stages() == 100,"exactly 100 dual-core stages")
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://tests/duet_solutions.json"))
	var game: GameController = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for row in report:
		manager.set_current_stage(int(row.stage_id))
		game.load_current_stage()
		var rules: DuetRules = game.board.rules
		for turn in row.solution:
			play_turn(game,turn)
		check(game.is_cleared and not game.is_game_over,"stage %d both cores reach goals" % row.stage_id)
		check(rules.moves == int(row.optimal_turns),"certified par count")
		check(rules.history.size() == rules.moves,"one undo snapshot per committed turn")
		var expected_positions := rules.positions.duplicate()
		var expected_traces := rules.traces.duplicate()
		var expected_opened := rules.opened
		game._on_undo_pressed()
		check(not game.is_cleared and not game.clear_dialog.visible,"undo dismisses victory and restores input")
		play_turn(game,row.solution[-1])
		check(rules.positions == expected_positions and rules.traces == expected_traces and rules.opened == expected_opened,"undo and replay restore exact board")
		game.load_current_stage()
		if row.blocking_first_turn != null:
			play_turn(game,row.blocking_first_turn)
			check(game.is_game_over and rules.blocked_core() == 1,"stage %d tempting A path blocks B" % row.stage_id)
			game._on_undo_pressed()
			check(not game.is_game_over and rules.traces.is_empty() and rules.moves == 0 and rules.active == 0,"undo recovers blocked B")
		# A failed route does not poison retry or the correct solution.
		for turn in row.solution:
			play_turn(game,turn)
		check(game.is_cleared,"recover and solve")
	# Sparse drag must stop at the per-turn movement limit, with undo still legal.
	manager.set_current_stage(1)
	game.load_current_stage()
	var r: DuetRules = game.board.rules
	r.setup({"width":5,"height":3,"starts":[[0,0],[0,2]],"goals":[[4,0],[4,2]],"walls":[],"step_limit":2})
	game._sync_cores(true)
	await process_frame
	var board: PuzzleBoard = game.board
	var a: CorePiece = game.cores[0]
	var origin: Vector2 = board.get_global_transform_with_canvas()*board.cell_to_local_pos(Vector2i(0,0))
	a._start_drag(Vector2(-100,-100),2)
	check(not a.is_dragging,"drag must start on active core")
	game.cores[1]._start_drag(board.get_global_transform_with_canvas()*board.cell_to_local_pos(Vector2i(0,2)),3)
	check(not game.cores[1].is_dragging,"inactive core cannot be dragged")
	a._start_drag(origin,2)
	var other := InputEventScreenTouch.new()
	other.index=3; other.pressed=false
	a._input(other)
	check(a.is_dragging,"secondary finger release ignored")
	a._process_drag(board.get_global_transform_with_canvas()*board.cell_to_local_pos(Vector2i(4,0)))
	check(r.path.size()==3 and a.grid_pos==Vector2i(2,0),"fast drag cannot exceed two cells")
	check(not r.step(Vector2i(3,0)),"rules reject extra step at cap")
	check(r.step(Vector2i(1,0)),"backtracking allowed at cap")
	check(r.step(Vector2i(0,0)),"return to start")
	check(not r.commit() and r.moves==0,"empty drag consumes no turn")
	a.cancel_drag()
	r.step(Vector2i(1,0)); r.step(Vector2i(2,0)); r.commit()
	check(r.active==1 and r.traces.has(Vector2i(1,0)),"commit alternates and creates shared walls")
	r.step(Vector2i(1,2)); r.step(Vector2i(1,1))
	check(not r.step(Vector2i(1,0)),"opponent cannot cross A trace")
	r.cancel_path(); r.undo()
	check(r.active==0 and r.traces.is_empty(),"undo restores turn and shared walls")
	# OS cancellation discards unfinished path rather than silently committing.
	a._start_drag(origin,2)
	a._process_drag(board.get_global_transform_with_canvas()*board.cell_to_local_pos(Vector2i(1,0)))
	a._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(r.path.size()==1 and r.moves==0 and not a.is_dragging,"backgrounding cancels pending drag")
	game.load_current_stage()
	await create_timer(0.12).timeout
	check(a.position.is_equal_approx(board.cell_to_local_pos(r.positions[0])),"retry kills stale tween")
	# Both target rings and occupied cells are exclusive; ending at own goal locks only on commit.
	r.setup({"width":3,"height":3,"starts":[[0,0],[2,2]],"goals":[[1,0],[1,2]],"walls":[],"step_limit":3})
	r.step(Vector2i(1,0))
	check(not r.won() and not r.docked(0),"touching ring is pending until release")
	check(not r.step(Vector2i(2,0)),"cannot move through own goal")
	check(r.step(Vector2i(0,0)),"can undo arrival before release")
	r.step(Vector2i(1,0));r.commit()
	check(r.docked(0) and r.active==1,"docked A remains parked")
	r.step(Vector2i(2,1));r.commit()
	check(r.active==1,"skip docked core on subsequent turns")
	# Arrow exits, forced stops, backtracking and undo must agree with touch rules.
	r.setup({"width":4,"height":3,"starts":[[0,0],[0,2]],"goals":[[3,0],[3,2]],"walls":[],"step_limit":3,"arrows":[[1,0,1,0]],"stops":[[2,0]]})
	check(r.step(Vector2i(1,0)),"enter arrow from any direction")
	check(not r.step(Vector2i(1,1)),"arrow rejects wrong exit")
	check(r.step(Vector2i(0,0)),"arrow allows cancel by backtracking")
	r.step(Vector2i(1,0));r.step(Vector2i(2,0))
	check(not r.step(Vector2i(3,0)),"rest tile stops a drag before the cap")
	check(r.step(Vector2i(1,0)),"rest tile allows backtracking")
	r.step(Vector2i(2,0));r.commit()
	r.step(Vector2i(1,2));r.commit()
	check(r.step(Vector2i(3,0)),"rest tile can be left on next turn")
	r.cancel_path();r.undo()
	check(r.stops.has(Vector2i(2,0)) and r.arrows.has(Vector2i(1,0)),"undo preserves static mechanics")
	# Bridges only become usable after the builder leaves and commits.
	r.setup({"width":5,"height":3,"starts":[[0,1],[2,2]],"goals":[[4,1],[2,0]],"walls":[],"step_limit":3,"bridges":[[2,1,0]]})
	check(r.terrain_blocks(Vector2i(2,1),1),"B cannot enter unbuilt A bridge")
	check(r.route_exists(1),"future bridge is not a false dead end")
	r.step(Vector2i(1,1));r.step(Vector2i(2,1))
	check(r.traces.is_empty(),"bridge is not built during drag")
	r.step(Vector2i(3,1));r.commit()
	check(r.traces.get(Vector2i(2,1))==0,"A departure builds bridge")
	check(not r.terrain_blocks(Vector2i(2,1),1) and r.terrain_blocks(Vector2i(2,1),0),"only partner can reuse bridge")
	check(r.blocked_core()==-1,"partner can cross future route")
	r.step(Vector2i(2,1));r.step(Vector2i(2,0));r.commit()
	check(r.traces.get(Vector2i(2,1))==2,"bridge collapses after partner departs")
	check(r.terrain_blocks(Vector2i(2,1),0) and r.terrain_blocks(Vector2i(2,1),1),"collapsed bridge blocks both")
	r.undo()
	check(r.traces.get(Vector2i(2,1))==0 and r.active==1,"undo rebuilds bridge")
	r.undo()
	check(r.traces.is_empty(),"undo restores scaffold")
	# Keys open numbered gates on commit, not mid-drag; undo restores each channel.
	r.setup({"width":5,"height":3,"starts":[[0,0],[0,2]],"goals":[[4,0],[4,2]],"walls":[],"step_limit":3,"keys":[[1,0,0],[1,2,1]],"gates":[[2,0,0],[2,2,1]]})
	r.step(Vector2i(1,0))
	check(not r.step(Vector2i(2,0)),"key pickup waits for commit")
	r.cancel_path()
	check(r.opened==0,"cancel does not collect key")
	r.step(Vector2i(1,0));r.commit()
	check(r.gate_open(Vector2i(2,0)) and not r.gate_open(Vector2i(2,2)),"key opens only matching gate")
	r.step(Vector2i(1,2));r.commit()
	check(r.opened==3,"both key channels collected")
	r.undo()
	check(r.opened==1,"undo preserves earlier key and restores second gate")
	r.undo()
	check(r.opened==0,"undo restores all keys")
	# Use an in-memory saver so regression cannot alter player records.
	var memory := MemorySave.new()
	memory.name = "SaveManager"
	root.add_child(memory)
	memory.apply_progress({})
	check(memory.is_stage_unlocked(1) and not memory.is_stage_unlocked(2),"new game unlocks exactly stage one")
	memory.complete_stage(5,2)
	check(memory.completed_stages.is_empty(),"cannot award locked stage")
	memory.complete_stage(1,5)
	check(memory.is_stage_unlocked(2) and not memory.is_stage_unlocked(3),"clear unlocks exactly one stage")
	memory.complete_stage(1,4)
	check(memory.max_unlocked_stage==2 and memory.get_best_moves(1)==4,"replay cannot unlock extra stages")
	memory.apply_progress({"completed_stages":{"1":{"completed":true,"moves":5},"3":{"completed":true,"moves":5}},"max_unlocked_stage":100})
	check(memory.max_unlocked_stage==2,"saved unlock count cannot skip gaps")
	memory.apply_progress({"completed_stages":{"1":{"completed":true},"6":{"completed":true}}},true)
	check(memory.is_stage_completed(1) and not memory.is_stage_completed(6),"migration preserves unchanged levels only")
	var complete := {}
	for i in range(1,101):complete[str(i)]={"completed":true,"moves":12}
	memory.apply_progress({"completed_stages":complete})
	check(memory.max_unlocked_stage==100 and not memory.is_stage_unlocked(101),"final stage unlock stays in bounds")
	memory.apply_progress({})
	manager.set_current_stage(20)
	game.load_current_stage()
	check(game.current_stage_data.stage_id==1,"loading a locked stage returns to unlocked frontier")
	manager.set_current_stage(1)
	var locked_selection = load("res://scenes/stage_select.tscn").instantiate()
	root.add_child(locked_selection)
	await process_frame
	check(not locked_selection.grid_container.get_child(0).disabled and locked_selection.grid_container.get_child(1).disabled,"locked stage button disabled")
	locked_selection._on_stage_selected(5)
	check(manager.current_stage_id==1,"direct selection callback cannot bypass lock")
	locked_selection.queue_free()
	root.remove_child(memory)
	memory.queue_free()
	manager.set_current_stage(100)
	var selection = load("res://scenes/stage_select.tscn").instantiate()
	root.add_child(selection)
	await process_frame
	check(selection.grid_container.get_child_count()==10,"only ten buttons per page")
	check(selection.grid_container.get_child(0).text.begins_with("91"),"current stage opens final page")
	check(selection.next_button.disabled,"no page after stage 100")
	selection._change_page(-9)
	check(selection.grid_container.get_child(0).text.begins_with("01"),"page one remains reachable")
	check(selection.previous_button.disabled,"no negative page")
	game.clear_dialog.show_clear(10,6,6)
	check(game.clear_dialog.next_button.text=="次の面へ","stage ten is no longer the finale")
	game.clear_dialog.show_clear(100,6,6)
	check(game.clear_dialog.title_label.text=="最終面クリア！","stage 100 finale")
	selection.queue_free()
	print("DUET regression: ",checks," checks; failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
