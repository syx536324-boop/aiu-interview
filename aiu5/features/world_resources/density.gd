# Filters existing stable records without consuming generation RNG or rewriting save identities.
extends RefCounted

const DEADWOOD_PERCENT := 60
const WILD_PERCENT := 80
const DECORATIVE_DEADWOOD := [Vector2(46,80),Vector2(78,263),Vector2(547,68),Vector2(864,340),Vector2(680,540)]

static func retained(world_seed: int, resource_id: String, percentage: int) -> bool:
	if percentage >= 100: return true
	if percentage <= 0: return false
	# Explicit 32-bit mixing remains stable across engine runs and is independent of global RNG.
	var value := (world_seed ^ 2166136261) & 0xffffffff
	for byte: int in resource_id.to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xffffffff
	value ^= value >> 16
	value = (value * 1664525 + 1013904223) & 0xffffffff
	value ^= value >> 13
	value = (value * 1664525 + 1013904223) & 0xffffffff
	value ^= value >> 16
	return value % 100 < percentage

static func filter_records(records: Array[Dictionary], world_seed: int, tree_percent := WILD_PERCENT) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		var percentage := tree_percent if record.get("kind","")=="tree" else WILD_PERCENT
		if retained(world_seed,str(record.id),percentage): result.append(record)
	return result

static func decorative_id(index: int) -> String:
	return "decorative:deadwood:%d" % index

static func decorative_bounds(at: Vector2) -> Rect2:
	# The original sprite is 32x48; its foot anchor and 19x10 collider must stay reserved
	# for generated resource placement even when this decorative tree is no longer drawn.
	return Rect2(at+Vector2(6.5,36),Vector2(19,10))
