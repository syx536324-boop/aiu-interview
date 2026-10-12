# Defines raw-to-cooked meat conversions and sanitizes the shared persistent stove job.
extends RefCounted
const RAW := {"pork":"cooked_pork","beef":"cooked_beef","mutton":"cooked_mutton"}
const COOKED := ["cooked_pork","cooked_beef","cooked_mutton"]
static func restore_cooking(data: Dictionary) -> Dictionary:
	var item := str(data.get("item","cooked_pork"))
	return {"remaining":clampf(float(data.get("remaining",0)),0,60),"ready":clampi(int(data.get("ready",0)),0,1),"item":item if item in COOKED else "cooked_pork"}
