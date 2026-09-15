extends RefCounted
class_name DuetRules

# One source of truth for drawing, input, undo, and tests.
const DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var width: int
var height: int
var step_limit: int
var positions: Array[Vector2i] = []
var goals: Array[Vector2i] = []
var fixed_walls: Dictionary = {}
var arrows: Dictionary = {}
var stops: Dictionary = {}
var bridges: Dictionary = {} # cell -> first builder (0=A, 1=B)
var keys: Dictionary = {} # cell -> channel
var gates: Dictionary = {}
var opened: int = 0
var traces: Dictionary = {} # normal: owner, bridge: builder then 2=collapsed
var active: int = 0
var path: Array[Vector2i] = []
var history: Array[Dictionary] = []
var moves: int = 0

func setup(stage: Dictionary) -> void:
	width = int(stage.width)
	height = int(stage.height)
	step_limit = int(stage.step_limit)
	positions.clear()
	goals.clear()
	fixed_walls.clear()
	traces.clear()
	arrows.clear()
	stops.clear()
	bridges.clear()
	keys.clear()
	gates.clear()
	opened = 0
	for tile in stage.get("bridges", []):
		bridges[Vector2i(tile[0],tile[1])] = int(tile[2])
	for tile in stage.get("keys", []):
		keys[Vector2i(tile[0],tile[1])] = int(tile[2])
	for tile in stage.get("gates", []):
		gates[Vector2i(tile[0],tile[1])] = int(tile[2])
	for tile in stage.get("arrows", []):
		arrows[Vector2i(tile[0],tile[1])] = Vector2i(tile[2],tile[3])
	for tile in stage.get("stops", []):
		stops[Vector2i(tile[0],tile[1])] = true
	history.clear()
	moves = 0
	active = 0
	for cell in stage.starts:
		positions.append(Vector2i(cell[0], cell[1]))
	for cell in stage.goals:
		goals.append(Vector2i(cell[0], cell[1]))
	for cell in stage.walls:
		fixed_walls[Vector2i(cell[0], cell[1])] = true
	path = [positions[active]]

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func docked(who: int) -> bool:
	return positions[who] == goals[who]

func won() -> bool:
	return docked(0) and docked(1)

func can_step(cell: Vector2i) -> bool:
	if not inside(cell) or won():
		return false
	if path.size() >= 2 and cell == path[-2]:
		return true
	var delta: Vector2i = cell - path.back()
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	if path.size() - 1 >= step_limit or path.back() == goals[active]:
		return false
	if path.size() > 1 and stops.has(path.back()):
		return false
	if arrows.has(path.back()) and delta != arrows[path.back()]:
		return false
	return not (cell in path or terrain_blocks(cell, active) or cell == positions[1-active] or cell == goals[1-active])

func step(cell: Vector2i) -> bool:
	if not can_step(cell):
		return false
	if path.size() >= 2 and cell == path[-2]:
		path.pop_back()
	else:
		path.append(cell)
	return true

func commit() -> bool:
	if path.size() < 2:
		return false
	history.append({"positions": positions.duplicate(), "traces": traces.duplicate(), "active": active, "moves": moves, "opened": opened})
	for i in range(path.size()-1):
		var cell := path[i]
		traces[cell] = 2 if bridges.has(cell) and traces.has(cell) else active
	for cell in path:
		if keys.has(cell):
			opened |= 1 << keys[cell]
	positions[active] = path.back()
	moves += 1
	if not docked(1-active):
		active = 1-active
	path = [positions[active]]
	return true

func cancel_path() -> void:
	path = [positions[active]]

func undo() -> bool:
	if path.size() > 1:
		cancel_path()
		return true
	if history.is_empty():
		return false
	var old: Dictionary = history.pop_back()
	positions.assign(old.positions)
	traces = old.traces.duplicate()
	active = old.active
	moves = old.moves
	opened = old.opened
	path = [positions[active]]
	return true

# Conservative reachability: future bridges and opened gates may restore a route.
func route_exists(who: int) -> bool:
	if docked(who):
		return true
	var visited: Dictionary = {positions[who]: true}
	var frontier: Array[Vector2i] = [positions[who]]
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		for direction in DIRECTIONS:
			if arrows.has(cell) and direction != arrows[cell]:
				continue
			var next: Vector2i = cell + direction
			if not inside(next) or visited.has(next) or terrain_blocks(next, who, true):
				continue
			if (next == positions[1-who] and not bridges.has(next)) or next == goals[1-who]:
				continue
			if next == goals[who]:
				return true
			visited[next] = true
			frontier.append(next)
	return false

func gate_open(cell: Vector2i) -> bool:
	return not gates.has(cell) or (opened & (1 << gates[cell])) != 0

func terrain_blocks(cell: Vector2i, who: int, optimistic: bool = false) -> bool:
	if fixed_walls.has(cell):
		return true
	# A partner can still collect a key or build a bridge later. Reachability
	# must overestimate these future options to avoid declaring a false loss.
	if not optimistic and not gate_open(cell):
		return true
	if bridges.has(cell):
		if traces.has(cell):
			return traces[cell] == 2 or traces[cell] == who
		return who != bridges[cell] and not optimistic
	return traces.has(cell)

func blocked_core() -> int:
	if not bridges.is_empty() or not gates.is_empty():
		var can_move := false
		for direction in DIRECTIONS:
			if can_step(positions[active] + direction):
				can_move = true
		if not can_move and not won():
			return active
	for who in range(2):
		if not route_exists(who):
			return who
	return -1
