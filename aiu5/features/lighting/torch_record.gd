# Defines per-instance torch fuel and one-lighting-session timers for bags and equipment.
extends RefCounted
const LIFETIME := 600.0
const BURN_SESSION := 300.0
static func normalize(data: Dictionary = {}) -> Dictionary:
	var fuel := float(data.get("fuel_left", LIFETIME))
	var burning := float(data.get("burn_left", BURN_SESSION))
	fuel = clampf(fuel, 0, LIFETIME) if is_finite(fuel) else LIFETIME
	burning = clampf(burning, 0, BURN_SESSION) if is_finite(burning) else BURN_SESSION
	return {"fuel_left":fuel, "burn_left":burning, "lit":bool(data.get("lit",false)) and fuel>0 and burning>0}
static func describe(data: Dictionary) -> String:
	var value := normalize(data)
	return "%s · 剩余耐久%d秒 / 600秒%s" % ["点燃" if value.lit else "熄灭", ceili(value.fuel_left), " · 本次燃烧还剩%d秒" % ceili(value.burn_left) if value.lit else ""]
