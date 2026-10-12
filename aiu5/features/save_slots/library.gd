# Owns independent save folders, metadata, legacy import and validation for the start screen.
extends RefCounted

var root_path := "user://save_slots"
var error := ""

func _init() -> void:
	var override_path := OS.get_environment("AIU5_SAVES_DIR")
	if override_path != "": root_path = override_path
	root_path = ProjectSettings.globalize_path(root_path).replace("\\", "/").trim_suffix("/")

func _folder(id: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]+$")
	return root_path + "/" + id if pattern.search(id) != null else ""

func _write(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return result
	return DirAccess.rename_absolute(path + ".tmp", path)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func import_legacy() -> void:
	error = ""
	var source := OS.get_environment("AIU5_LEGACY_PATH")
	if source == "": source = "user://village_inventory.json"
	source = ProjectSettings.globalize_path(source)
	if not FileAccess.file_exists(source): return
	var folder := _folder("legacy")
	if FileAccess.file_exists(folder + "/slot.json"): return
	var old := _read(source)
	if not _valid_state(old):
		error = "旧存档无法读取，原文件仍保留。"
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		error = "无法建立旧存档目录。"
		return
	var profile_source := OS.get_environment("AIU5_LEGACY_PROFILE_PATH")
	if profile_source == "": profile_source = "user://founder_names.cfg"
	profile_source = ProjectSettings.globalize_path(profile_source)
	for pair in [[source, folder + "/state.json"], [source + ".altar", folder + "/state.json.altar"], [profile_source, folder + "/names.cfg"]]:
		if FileAccess.file_exists(pair[0]) and not FileAccess.file_exists(pair[1]):
			if DirAccess.copy_absolute(pair[0], pair[1]) != OK:
				error = "旧存档导入失败，原文件仍保留。"
				return
	var metadata := {"id": "legacy", "title": "旧村落", "profile": "expanded", "seed": _new_seed(), "created_at": int(Time.get_unix_time_from_system())}
	if _write(folder + "/slot.json", metadata) != OK: error = "旧存档资料写入失败，原文件仍保留。"

func _new_seed() -> int:
	var random := RandomNumberGenerator.new()
	random.randomize()
	return random.randi_range(1, 2147483647)

func create_slot(title: String) -> Dictionary:
	error = ""
	title = title.strip_edges()
	if title.is_empty() or title.length() > 24 or title.contains("\n") or title.contains("\r") or title.contains("\t"):
		return {"ok": false, "error": "请填写1—24个字符的存档名称。"}
	var id := "village-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var folder := _folder(id)
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "error": "无法建立新存档，请检查磁盘空间。"}
	var metadata := {"id": id, "title": title, "profile": "starter", "seed": _new_seed(), "created_at": int(Time.get_unix_time_from_system())}
	if _write(folder + "/slot.json", metadata) != OK:
		return {"ok": false, "error": "存档资料写入失败，已有存档未被覆盖。"}
	return {"ok": true, "slot": _decorate(metadata)}

func _valid_state(data: Dictionary) -> bool:
	if int(data.get("version", 0)) not in [1, 2]: return false
	var session: Variant = data.get("session")
	if not session is Dictionary or not session.get("actors") is Dictionary: return false
	for section in ["vitals", "homestead", "livestock", "mining", "names"]:
		if session.has(section) and not session[section] is Dictionary: return false
	if session.has("resource_world"):
		var resources: Variant = session.resource_world
		if not resources is Dictionary or int(resources.get("version", 0)) != 1: return false
		if not (resources.get("seed") is int or resources.get("seed") is float): return false
		if int(resources.seed) <= 0 or int(resources.seed) > 2147483647: return false
		if not resources.get("suppressed", []) is Array: return false
	for id in ["ali", "heya", "chief_priest"]:
		# Older snapshots can lack later characters; current ones must contain the founders.
		if not session.actors.has(id):
			if id == "chief_priest": continue
			return false
		var actor: Variant = session.actors[id]
		if not actor is Dictionary or not actor.get("position") is Array or actor.position.size() != 2: return false
		for value in actor.position:
			if not (value is int or value is float): return false
	return data.get("bags") is Dictionary and data.get("rooms", {}) is Dictionary

func _decorate(metadata: Dictionary) -> Dictionary:
	var result := metadata.duplicate(true)
	var folder := _folder(str(result.get("id", "")))
	if folder == "": return {}
	result.path = folder + "/state.json"
	result.names_path = folder + "/names.cfg"
	var state := _read(result.path)
	result.valid = _valid_state(state)
	var session: Dictionary = state.get("session", {}) if state.get("session") is Dictionary else {}
	result.saved_at = FileAccess.get_modified_time(result.path) if result.valid else 0
	result.population = session.get("actors", {}).size() if result.valid else 3
	var resources: Dictionary = session.get("resource_world", {}) if session.get("resource_world", {}) is Dictionary else {}
	result.seed = maxi(1, int(resources.get("seed", result.get("seed", str(result.id).hash() & 0x7fffffff))))
	result.profile = str(session.get("settlement", result.get("profile", "expanded")))
	result.homes = 3 if result.profile == "starter" else 8
	return result

func slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root_path)
	if directory == null: return result
	for id: String in directory.get_directories():
		var folder := _folder(id)
		if folder == "": continue
		var metadata := _read(folder + "/slot.json")
		if str(metadata.get("id", "")) != id: continue
		var slot := _decorate(metadata)
		if not slot.is_empty(): result.append(slot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.saved_at) > int(b.saved_at))
	return result

func resolve(id: String) -> Dictionary:
	for slot in slots():
		if slot.id == id:
			if slot.valid:
				var path := _folder(id) + "/slot.json"
				var metadata := _read(path)
				var resource_state: Dictionary = _read(slot.path).get("session", {}).get("resource_world", {})
				if int(metadata.get("seed", 0)) <= 0 and resource_state.is_empty(): slot.seed = _new_seed()
				if int(metadata.get("seed", 0)) != int(slot.seed):
					metadata.seed = slot.seed
					if _write(path, metadata) != OK:
						error = "无法保存村落的随机种子，请检查磁盘。"
						return {}
			return slot
	return {}
