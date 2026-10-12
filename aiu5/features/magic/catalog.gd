# Defines four exclusive elements, level costs, equipment slots and the five elemental trunk skills.
extends RefCounted

const Torch := preload("res://features/lighting/torch_record.gd")
const MAX_LEVEL := 100
const POINTS_PER_LEVEL := 5
const BASE_MANA := 10
const MANA_PER_LEVEL := 5
const SKILL_COST := 10
const ELEMENTS := {
	"wood": {"name": "木", "color": "8ebc75"}, "water": {"name": "水", "color": "72b8ce"},
	"fire": {"name": "火", "color": "dc9566"}, "earth": {"name": "土", "color": "c6ad70"}}
const Items := preload("res://features/inventory/catalog.gd")
const Armor := preload("res://features/magic/equipment_catalog.gd")
const EQUIPMENT := {
	"armor": {"name": "盔甲", "item": "leather_armor"}, "legs": {"name": "护腿", "item": "leather_leggings"},
	"head": {"name": "头盔", "item": "leather_helmet"}, "feet": {"name": "靴子", "item": "leather_boots"}}
const Wear := preload("res://features/combat/durability.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const WEAPONS := Gear.WEAPONS
const TRUNK := ["trunk_1", "trunk_2", "trunk_3", "trunk_4", "trunk_5"]

static func mana_limit(level: int) -> int:
	return BASE_MANA + (clampi(level, 1, MAX_LEVEL) - 1) * MANA_PER_LEVEL

static func required(level: int) -> int:
	return 0 if level >= MAX_LEVEL else 100 * (floori(float(maxi(1, level)) / 10.0) + 1)

static func fresh() -> Dictionary:
	return {"element": "", "level": 1, "xp": 0,"pending_points":0, "skill_points": 0, "unlocked": [],
		"torch":{}, "equipment_records":{"armor":{},"legs":{},"head":{},"feet":{}}, "equipment": {"armor": "", "legs": "", "head": "", "feet": "", "weapon": ""}, "gear_claimed": false, "weapon_wear": Wear.normalize()}

static func add_points(state: Dictionary, amount: int) -> void:
	state.xp += amount
	while state.level < MAX_LEVEL and state.xp >= required(int(state.level)):
		state.xp -= required(int(state.level))
		state.level += 1
		state.skill_points += POINTS_PER_LEVEL
	if state.level >= MAX_LEVEL: state.xp = 0

static func restore_state(source: Dictionary) -> Dictionary:
	var state := fresh()
	state.pending_points=maxi(0,int(source.get("pending_points",0)))
	if ELEMENTS.has(str(source.get("element", ""))):
		state.element = str(source.element)
		state.level = clampi(int(source.get("level", 1)), 1, MAX_LEVEL)
		state.xp = clampi(int(source.get("xp", 0)), 0, maxi(0, required(state.level) - 1))
		var earned := (int(state.level) - 1) * POINTS_PER_LEVEL
		var saved: Variant = source.get("unlocked", [])
		if saved is Array:
			for id: String in TRUNK:
				if not saved.has(id) or (state.unlocked.size() + 1) * SKILL_COST > earned: break
				state.unlocked.append(id)
		# Version-1 six-node saves refund the removed sixth node exactly once.
		var refund := SKILL_COST if saved is Array and saved.has("trunk_6") and state.unlocked.size()==5 and earned>=60 else 0
		state.skill_points = clampi(int(source.get("skill_points", 0))+refund, 0, earned - state.unlocked.size() * SKILL_COST)
	var gear: Variant = source.get("equipment", {})
	if gear is Dictionary:
		for slot: String in EQUIPMENT:
			var item := Items.canonical(str(gear.get(slot,"")))
			if Armor.fits(slot,item): state.equipment[slot] = item
		var weapon := str(gear.get("weapon", ""))
		if weapon == "wood_axe": weapon = "stone_axe"
		if weapon in WEAPONS: state.equipment.weapon = weapon
	state.weapon_wear = Wear.normalize(source.get("weapon_wear",{}) if source.get("weapon_wear",{}) is Dictionary else {})
	for slot: String in EQUIPMENT:
		if state.equipment[slot] == "": continue
		var record: Variant = source.get("equipment_records", {}).get(slot, {})
		var clean := {"item":state.equipment[slot],"count":1}
		if record is Dictionary: clean.merge(Wear.Origin.fields(record))
		state.equipment_records[slot] = clean
	var torch: Variant = source.get("torch",{})
	if torch is Dictionary and torch.get("item","")=="torch" and float(torch.get("fuel_left",Torch.LIFETIME))>0:
		state.torch = {"item":"torch","count":1}
		state.torch.merge(Torch.normalize(torch))
	state.gear_claimed = bool(source.get("gear_claimed", false))
	return state
