extends SceneTree

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
		game._on_undo_pressed()
		check(not game.is_cleared and not game.clear_dialog.visible,"undo dismisses victory and restores input")
		play_turn(game,row.solution[-1])
		check(rules.positions == expected_positions and rules.traces == expected_traces,"undo and replay restore exact board")
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
