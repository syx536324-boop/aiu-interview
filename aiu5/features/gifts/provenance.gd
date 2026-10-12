# Preserves the immutable origin of camera gifts across inventory and equipment records.
extends RefCounted
static func fields(data: Dictionary) -> Dictionary:
	if not bool(data.get("is_magical", false)) or str(data.get("gift_event_id", "")) == "": return {}
	return {"origin":"player_gift", "is_magical":true, "magic_attribute":null, "gift_event_id":str(data.gift_event_id)}
static func gifted(event_id: String) -> Dictionary:
	return fields({"is_magical":true,"gift_event_id":event_id})
static func magical(data: Dictionary) -> bool:
	return not fields(data).is_empty()
static func describe(data: Dictionary) -> String:
	return " · 魔法赐予（属性待定）" if magical(data) else ""
