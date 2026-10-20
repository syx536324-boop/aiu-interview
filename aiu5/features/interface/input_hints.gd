# Translates keyboard interaction hints for touch presentation without changing gameplay input rules.
extends RefCounted
static var interaction_regex: RegEx

static func mobile() -> bool:
	return OS.has_feature("android") or OS.get_environment("AIU5_MOBILE_PREVIEW") == "1"

static func text(value: String) -> String:
	if not mobile(): return value
	if "e" not in value.to_lower(): return value
	if interaction_regex == null:
		interaction_regex = RegEx.new()
		interaction_regex.compile("(?i)(按\\s*)?(?<![a-z0-9_])e(?![a-z0-9_])")
	var result := value
	var matches := interaction_regex.search_all(value)
	for index in range(matches.size()-1,-1,-1):
		var found: RegExMatch = matches[index]
		var caption := "按交互" if found.get_string(1) != "" else "交互"
		result = result.left(found.get_start()) + caption + result.substr(found.get_end())
	return result
