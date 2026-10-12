# Validates and persists only the two player-named founders, independently of game state.
extends RefCounted

var path := "user://founder_names.cfg"

func _init() -> void:
	var override_path := OS.get_environment("AIU5_PROFILE_PATH")
	if override_path != "":
		path = override_path

func load_names() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	var male := str(config.get_value("founders", "male", "")).strip_edges()
	var female := str(config.get_value("founders", "female", "")).strip_edges()
	return {"male": male, "female": female} if validation_error(male, female) == "" else {}

func validation_error(male: String, female: String) -> String:
	for value in [male.strip_edges(), female.strip_edges()]:
		if value.is_empty():
			return "请分别填写男、女村民的姓名。"
		if value.length() > 12 or value.contains("\n") or value.contains("\r") or value.contains("\t"):
			return "姓名请使用 1—12 个字符，不含换行或制表符。"
	return ""

func save_names(male: String, female: String) -> Error:
	if validation_error(male, female) != "":
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if error != OK:
		return error
	var config := ConfigFile.new()
	config.set_value("founders", "male", male.strip_edges())
	config.set_value("founders", "female", female.strip_edges())
	return config.save(path)
