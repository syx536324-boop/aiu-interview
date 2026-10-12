# Builds a small walkability grid from physical obstacles for resident patrol routes.
extends RefCounted

var grid := AStarGrid2D.new()

var obstacle_cells: Dictionary = {}
var coverage: Dictionary = {}
var changed_cells := 0
var full_rebuilds := 0
var revision := 0

func rebuild(obstacles: Array[Rect2], map_size: Vector2, origin := Vector2.ZERO) -> void:
	var region := Rect2i(Vector2i((origin / 8).floor()), Vector2i(((map_size - origin) / 8).ceil()))
	if grid.region != region:
		grid.region = region
		grid.cell_size = Vector2(8, 8)
		grid.offset = Vector2(4, 4)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		obstacle_cells.clear()
		coverage.clear()
		full_rebuilds += 1
	var wanted: Dictionary = {}
	for obstacle in obstacles: wanted[obstacle] = true
	changed_cells = 0
	for obstacle: Rect2 in obstacle_cells.keys():
		if wanted.has(obstacle): continue
		for cell: Vector2i in obstacle_cells[obstacle]:
			coverage[cell] = int(coverage[cell]) - 1
			if coverage[cell] == 0:
				coverage.erase(cell)
				grid.set_point_solid(cell, false)
				changed_cells += 1
		obstacle_cells.erase(obstacle)
	for obstacle: Rect2 in wanted:
		if obstacle_cells.has(obstacle): continue
		var expanded := obstacle.grow(4)
		expanded.position.y += 3
		var first := Vector2i(floori(expanded.position.x / 8), floori(expanded.position.y / 8)).max(region.position)
		var last := Vector2i(ceili(expanded.end.x / 8), ceili(expanded.end.y / 8)).min(region.end - Vector2i.ONE)
		var cells: Array[Vector2i] = []
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not expanded.has_point(grid.get_point_position(cell)): continue
				cells.append(cell)
				if not coverage.has(cell):
					grid.set_point_solid(cell, true)
					changed_cells += 1
				coverage[cell] = int(coverage.get(cell, 0)) + 1
		obstacle_cells[obstacle] = cells
	if changed_cells > 0: revision += 1

func _free_cell(at: Vector2) -> Vector2i:
	var center := Vector2i(floori(at.x / 8), floori(at.y / 8))
	var best := Vector2i(-1, -1)
	var distance := INF
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			var cell := Vector2i(x, y)
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
				var candidate := at.distance_squared_to(grid.get_point_position(cell))
				if candidate < distance:
					distance = candidate
					best = cell
	return best

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _free_cell(from)
	var end := _free_cell(to)
	if start.y < 0 or end.y < 0:
		return PackedVector2Array()
	return grid.get_point_path(start, end)
