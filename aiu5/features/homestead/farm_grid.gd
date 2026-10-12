# Splits legacy farmland into independent cells and selects connected irrigation areas.
extends RefCounted

const CELL := 16.0
const WATER_CELLS := 15

static func split(records: Array) -> Array:
	var cells: Array = []
	for record: Dictionary in records:
		for y in range(ceili(float(record.h) / CELL)):
			for x in range(ceili(float(record.w) / CELL)):
				var cell := record.duplicate(true)
				cell.x = float(record.x) + x * CELL
				cell.y = float(record.y) + y * CELL
				cell.w = minf(CELL, float(record.w) - x * CELL)
				cell.h = minf(CELL, float(record.h) - y * CELL)
				# An old plot represented one seed/crop, regardless of its rendered area.
				if x != 0 or y != 0:
					cell.crop = ""
					cell.growth = 0.0
					cell.stage = 0
					cell.mature = false
				cells.append(cell)
	return cells

static func irrigation(cells: Array, origin: int) -> Array[int]:
	var positions: Dictionary = {}
	for i in range(cells.size()): positions[Vector2(cells[i].x, cells[i].y)] = i
	var chosen: Array[int] = [origin]
	var seen := {origin: true}
	var cursor := 0
	while cursor < chosen.size() and chosen.size() < WATER_CELLS:
		var cell: Dictionary = cells[chosen[cursor]]
		cursor += 1
		for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var index: int = positions.get(Vector2(cell.x, cell.y) + offset * CELL, -1)
			if index < 0 or seen.has(index): continue
			seen[index] = true
			chosen.append(index)
			if chosen.size() == WATER_CELLS: break
	return chosen
