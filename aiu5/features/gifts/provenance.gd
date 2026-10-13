# Preserves the immutable origin of camera gifts across inventory and equipment records.
extends RefCounted
const ELEMENTS := {"wood":"木", "water":"水", "fire":"火", "earth":"土"}
static func fields(data: Dictionary) -> Dictionary:
	if not bool(data.get("is_magical", false)) or str(data.get("gift_event_id", "")) == "": return {}
	var element := str(data.get("magic_attribute",""))
	return {"origin":"player_gift", "is_magical":true, "magic_attribute":element if ELEMENTS.has(element) else null, "gift_event_id":str(data.gift_event_id),"gift_level":clampi(int(data.get("gift_level",1)),1,100)}
static func gifted(event_id: String, element := "", gift_level := 1) -> Dictionary:
	return fields({"is_magical":true,"gift_event_id":event_id,"magic_attribute":element,"gift_level":gift_level})
static func magical(data: Dictionary) -> bool:
	return not fields(data).is_empty()
static func describe(data: Dictionary) -> String:
	if not magical(data): return ""
	return " · 赐予等级%d" % int(fields(data).gift_level)+" · 魔法赐予（%s）" % ELEMENTS[str(data.magic_attribute)] if ELEMENTS.has(str(data.get("magic_attribute",""))) else " · 赐予等级%d · 魔法赐予（属性未选择）" % int(fields(data).gift_level)
