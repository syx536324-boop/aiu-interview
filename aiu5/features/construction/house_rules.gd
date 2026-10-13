# Calculates house levels, escalating paid upgrades and elemental crystal resistance.
extends RefCounted
const MAX_LEVEL := 10
const HOUSE_LEVELS := {"wood_house":1,"stone_house":2,"iron_house":3}
const ELEMENTS := ["wood","water","fire","earth"]
static func is_house(kind: String) -> bool:
	return HOUSE_LEVELS.has(kind)
static func kind(level: int) -> String:
	return "wood_house" if level==1 else ("stone_house" if level==2 else "iron_house")
static func duration(level: int, initial := false) -> float:
	return 30.0 if initial else 30.0*pow(1.3,maxi(0,level-2))
static func costs(level: int, element: String) -> Dictionary:
	var result := {"wood":50,"stone":50,"iron_ore":10}
	for i in range(maxi(0,level-2)):
		for material: String in result: result[material]=ceili(float(result[material])*1.15)
	if needs_crystal(level) and element in ELEMENTS: result[element+"_crystal"]=1
	return result
static func needs_crystal(level: int) -> bool:
	return level>=4 and level%2==0
static func stats(level: int) -> Dictionary:
	return {"hp":50.0 if level==1 else (100.0 if level==2 else 200.0*pow(1.15,level-3)),"defense":0 if level==1 else (10 if level==2 else 20)}
static func resistance(crystals: Dictionary, element: String) -> float:
	return clampf(float(crystals.get(element,0))*0.02,0,0.5) if element in ELEMENTS else 0.0
