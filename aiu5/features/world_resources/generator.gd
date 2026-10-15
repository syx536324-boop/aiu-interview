# Generates bounded, stable resource records per chunk using a versioned integer PRNG and static exclusion masks.
extends RefCounted

const Layout := preload("res://features/village/layout.gd")
const Geography := preload("res://features/landscape/layout.gd")
const Land := preload("res://features/homestead/land.gd")
const Shed := preload("res://features/livestock/shed.gd")
const Harvesting := preload("res://features/harvesting/harvesting.gd")
const Mining := preload("res://features/mining/mining.gd")
const Density := preload("res://features/world_resources/density.gd")
const VERSION := 1
const CHUNK_SIZE := Vector2(320, 200)
const MAX_PER_CHUNK := 7
var seed := 1
var blocked: Array[Rect2] = []
var state := 1

func configure(world_seed: int, fixed_obstacles: Array[Rect2]) -> void:
	seed = maxi(1, world_seed)
	blocked = fixed_obstacles.duplicate()
	# Density must never make a previously rejected location reassign stable IDs.
	for at: Vector2 in Density.DECORATIVE_DEADWOOD: blocked.append(Density.decorative_bounds(at))
	# Depleted legacy anchors still reserve the same area, so progress never shifts generated IDs.
	for record: Dictionary in Harvesting.TREES:
		blocked.append(Rect2(record.at - Vector2(18, 54), Vector2(36, 62)))
	for record: Dictionary in Mining.SURFACE:
		blocked.append(Rect2(record.at - Vector2(20, 24), Vector2(40, 32)))
	# Keep the whole village footprint and entrances free, not only building colliders.
	for home: Dictionary in Layout.HOMES:
		blocked.append(Rect2(home.at, home.region.size).grow(22))
		blocked.append(Rect2(home.door - Vector2(28, 28), Vector2(56, 56)))
	for founder: Dictionary in Layout.PLAYERS:
		blocked.append(Rect2(founder.at - Vector2(56, 56), Vector2(112, 112)))
	for npc: Dictionary in Layout.NPCS:
		blocked.append(Rect2(npc.at - Vector2(28, 28), Vector2(56, 56)))
	blocked.append(Rect2(208, 220, 100, 68))
	blocked.append(Rect2(377, 202, 112, 90))
	blocked.append(Shed.BOUNDS.grow(20))
	blocked.append(Geography.PLAZA.grow(22))
	blocked.append(Rect2(2030, 380, 80, 100))

func _next() -> int:
	state = (state * 1664525 + 1013904223) & 0xffffffff
	return state

func biome(at: Vector2) -> String:
	if at.x >= 1780: return "foothill"
	if at.x >= 640 and at.x < 1780: return "arid"
	return "oasis_edge"

func allowed(at: Vector2, kind := "tree") -> bool:
	var footprint := Rect2(at - Vector2(28, 54 if kind == "tree" else 24), Vector2(56, 62 if kind == "tree" else 32))
	if not Rect2(Vector2(24, 24), Layout.SIZE - Vector2(48, 48)).encloses(footprint): return false
	if footprint.intersects(Land.LAKE.grow(16)): return false
	if footprint.intersects(Rect2(8, 0, 48, 600)) or footprint.intersects(Rect2(8, 600, 112, 1000)): return false
	if footprint.intersects(Geography.MOUNTAINS.grow(10)): return false
	for rectangle in blocked:
		if footprint.intersects(rectangle.grow(5)): return false
	for route: Array in Layout.ROADS:
		for i in range(route.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(at, route[i], route[i + 1])
			if at.distance_to(nearest) < 46: return false
	return true

func chunk(cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if cell.x < 0 or cell.y < 0 or cell.x > 7 or cell.y > 23: return result
	# Explicit integer mixing avoids global RNG, load order and wall-clock dependencies.
	state = (seed ^ ((cell.x + 1) * 73856093) ^ ((cell.y + 1) * 19349663) ^ (VERSION * 83492791)) & 0xffffffff
	var region := biome(Vector2(cell) * CHUNK_SIZE + CHUNK_SIZE / 2)
	var stone_goal := 4 + _next() % 3 if region == "foothill" else _next() % 3
	var tree_goal := 3 + _next() % 2 if region == "arid" else 1 + _next() % 2
	var candidates: Array[Vector2] = []
	for y in [48, 112, 176]:
		for x in [40, 100, 160, 220, 280]:
			candidates.append(Vector2(cell) * CHUNK_SIZE + Vector2(x + int(_next() % 13) - 6, y + int(_next() % 9) - 4))
	for i in range(candidates.size() - 1, 0, -1):
		var j := int(_next() % (i + 1))
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var counts := {"tree": 0, "stone": 0}
	for at in candidates:
		var kind := "stone" if counts.stone < stone_goal else "tree"
		if kind == "tree" and counts.tree >= tree_goal: continue
		if not allowed(at, kind): continue
		# Fixed lattice spacing plus chunk insets also prevent cross-chunk overlaps.
		var ordinal: int = counts[kind]
		result.append({"id": "gen1:%d:%d:%s:%d" % [cell.x, cell.y, kind, ordinal], "at": at, "kind": kind, "variant": int(_next() % 3)})
		counts[kind] += 1
		if result.size() >= MAX_PER_CHUNK: break
	# Build every old descriptor first: filtering never changes the integer RNG stream.
	return Density.filter_records(result,seed,Density.DEADWOOD_PERCENT)
