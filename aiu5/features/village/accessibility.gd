# Answers reachability on compressed horizontal free runs without searching paths or mutating live navigation.
extends RefCounted

var region: Rect2i
var solid_rows: Dictionary = {}
var runs: Dictionary = {}
var parents := PackedInt32Array()

func build(bounds: Rect2i, coverage: Dictionary) -> void:
	region = bounds
	for cell: Vector2i in coverage:
		if not solid_rows.has(cell.y): solid_rows[cell.y] = []
		solid_rows[cell.y].append(cell.x)
	for row: Array in solid_rows.values(): row.sort()
	_connect()

func with_changes(coverage: Dictionary, changes: Dictionary) -> RefCounted:
	var result = get_script().new()
	result.region = region
	result.solid_rows = solid_rows.duplicate()
	var copied: Dictionary = {}
	for cell: Vector2i in changes:
		var was_solid := coverage.has(cell)
		var is_solid := int(coverage.get(cell, 0)) + int(changes[cell]) > 0
		if was_solid == is_solid: continue
		if not copied.has(cell.y):
			result.solid_rows[cell.y] = solid_rows.get(cell.y, []).duplicate()
			copied[cell.y] = true
		var row: Array = result.solid_rows[cell.y]
		var index := row.bsearch(cell.x)
		if is_solid: row.insert(index, cell.x)
		else: row.remove_at(index)
	result._connect()
	return result

func _connect() -> void:
	# Four-neighbour connectivity equals no-corner-cutting diagonal reachability.
	var previous: Array[Vector3i] = []
	for y in range(region.position.y, region.end.y):
		var current: Array[Vector3i] = []
		var x := region.position.x
		for solid: int in solid_rows.get(y, []):
			if x < solid: current.append(Vector3i(x, solid, parents.size())); parents.append(parents.size())
			x = solid + 1
		if x < region.end.x: current.append(Vector3i(x, region.end.x, parents.size())); parents.append(parents.size())
		var left := 0
		for run: Vector3i in current:
			while left < previous.size() and previous[left].y <= run.x: left += 1
			var index := left
			while index < previous.size() and previous[index].x < run.y:
				_join(run.z, previous[index].z)
				index += 1
		runs[y] = current
		previous = current
	# Flatten once; queries never walk a union tree.
	for id in range(parents.size()): parents[id] = _root(id)

func _root(id: int) -> int:
	while parents[id] != id:
		parents[id] = parents[parents[id]]
		id = parents[id]
	return id

func _join(a: int, b: int) -> void:
	a = _root(a); b = _root(b)
	if a != b: parents[maxi(a,b)] = mini(a,b)

func _component(cell: Vector2i) -> int:
	if not region.has_point(cell): return -1
	for run: Vector3i in runs.get(cell.y, []):
		if cell.x < run.x: return -1
		if cell.x < run.y: return parents[run.z]
	return -1

func component_at(at: Vector2) -> int:
	# Match Navigation._free_cell's nearest free endpoint, including its tie order.
	var center := Vector2i(floori(at.x / 8), floori(at.y / 8))
	var distance := INF
	var component := -1
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			var candidate := at.distance_squared_to(Vector2(x * 8 + 4, y * 8 + 4))
			if candidate >= distance: continue
			var id := _component(Vector2i(x,y))
			if id >= 0: distance = candidate; component = id
	return component
