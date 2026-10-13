# Defines livestock species, sheep pasture, breeding names and per-kill drops.
extends RefCounted
const NAMES := {"pig":"猪","cow":"牛","sheep":"羊"}
const SHEEP_PASTURE := Rect2(304,416,76,64)
const SHEEP_FEEDING := Vector2(370,444)
static func drops(kind: String, adult: bool) -> Dictionary:
	match kind:
		"pig": return {"pork":1}
		"cow": return {"cowhide":1,"beef":1}
		"sheep": return {"mutton":1,"wool":2} if adult else {}
	return {}
static func initial_sheep() -> Array:
	return [{"id":"sheep:1","species":"sheep","sex":"male","growth":300.0,"position":[324,442]},
		{"id":"sheep:2","species":"sheep","sex":"female","growth":300.0,"position":[350,456]}]
