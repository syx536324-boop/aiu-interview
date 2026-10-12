# Defines compatible armor variants for each character equipment slot, including legacy gear.
extends RefCounted
const SLOTS := {"armor":["leather_armor","iron_armor"], "legs":["leather_leggings","iron_leggings"],
	"head":["leather_helmet","iron_helmet"], "feet":["leather_boots","iron_boots"]}
static func fits(slot: String, item: String) -> bool:
	return SLOTS.has(slot) and item in SLOTS[slot]
static func contains(item: String) -> bool:
	for items: Array in SLOTS.values():
		if item in items: return true
	return false
