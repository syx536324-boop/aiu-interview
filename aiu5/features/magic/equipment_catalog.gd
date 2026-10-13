# Defines compatible armor variants and material-specific incoming injury reduction.
extends RefCounted
const SLOTS := {"armor":["leather_armor","iron_armor"], "legs":["leather_leggings","iron_leggings"],
	"head":["leather_helmet","iron_helmet"], "feet":["leather_boots","iron_boots"]}
static func fits(slot: String, item: String) -> bool:
	return SLOTS.has(slot) and item in SLOTS[slot]
static func contains(item: String) -> bool:
	for items: Array in SLOTS.values():
		if item in items: return true
	return false

const DEFENSE := {"leather_armor":1,"leather_leggings":1,"leather_helmet":1,"leather_boots":1}
const REDUCTION_PER_POINT := 0.05
static func defense(item: String) -> int:
	return int(DEFENSE.get(item,0))
static func total_defense(equipment: Dictionary) -> int:
	var total := 0
	for slot: String in SLOTS:
		var item := str(equipment.get(slot,""))
		if fits(slot,item): total+=defense(item)
	return total
static func damage_rate(equipment: Dictionary) -> float:
	return 1.0-total_defense(equipment)*REDUCTION_PER_POINT
static func describe(item: String) -> String:
	if DEFENSE.has(item): return "防御1 · 免伤5%"
	return "防御数值待设置" if contains(item) else ""
