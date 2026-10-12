# Defines crop species and the four two-minute online growth stages.
extends RefCounted

const STAGE_SECONDS := 120.0
const MATURE_AFTER := STAGE_SECONDS * 4
const STAGE_NAMES := ["萌芽", "幼苗", "拔节", "结穗"]
const SEEDS := {"seeds": "wheat", "rice_seeds": "rice"}
const CROPS := {
	"wheat": {"name": "小麦", "seed": "seeds", "harvest": "wheat"},
	"rice": {"name": "水稻", "seed": "rice_seeds", "harvest": "rice"}
}

static func stage(growth: float) -> int:
	return clampi(floori(growth / STAGE_SECONDS) + 1, 1, 4)

static func mature(growth: float) -> bool:
	return growth >= MATURE_AFTER

static func detail(plot: Dictionary) -> String:
	var crop := str(plot.get("crop", ""))
	if crop == "dead": return "庄稼已枯死 · 灌溉后可重新播种"
	if not CROPS.has(crop): return ""
	var growth := float(plot.get("growth", 0))
	var name: String = CROPS[crop].name
	if mature(growth): return name + " · 4/4 已成熟 · 按 G 收获"
	var remaining := ceili(MATURE_AFTER - growth)
	return "%s · %s %d/4 · 剩余 %d:%02d" % [name, STAGE_NAMES[stage(growth) - 1], stage(growth), floori(remaining / 60.0), remaining % 60]
