# Defines vessel water states and conversions shared by inventory, survival and rendering.
extends RefCounted

const BUCKETS := ["bucket", "water_bucket_1", "water_bucket_2", "water_bucket_3", "water_bucket"]
const CUPS := ["wooden_cup", "water_cup"]
const THIRST_PER_DRINK := 4

static func is_vessel(item: String) -> bool:
	return item in BUCKETS or item in CUPS

static func units(item: String) -> int:
	return 1 if item == "water_cup" else maxi(0, BUCKETS.find(item))

static func drinkable(item: String) -> bool:
	return units(item) > 0

static func after_drink(item: String) -> String:
	if item == "water_cup": return "wooden_cup"
	var level := BUCKETS.find(item)
	return str(BUCKETS[level - 1]) if level > 0 else ""

static func filled(item: String) -> String:
	if item in BUCKETS: return "water_bucket"
	return "water_cup" if item in CUPS else ""

static func summary(slots: Array) -> String:
	var bucket_level := -1
	var full_cups := 0
	var has_cup := false
	for slot: Dictionary in slots:
		var item := str(slot.get("item", ""))
		if item in BUCKETS: bucket_level = maxi(bucket_level, units(item))
		if item in CUPS: has_cup = true
		if item == "water_cup": full_cups += int(slot.get("count", 0))
	var parts: PackedStringArray = []
	if bucket_level >= 0: parts.append("桶%d/4" % bucket_level)
	if has_cup: parts.append("杯%d" % full_cups)
	return " ".join(parts) if not parts.is_empty() else "无"
