# Selects the saved settlement profile before any world nodes are constructed.
extends RefCounted

static func configure(world: Node) -> void:
	var selected := OS.get_environment("AIU5_WORLD_PROFILE")
	var path := OS.get_environment("AIU5_STATE_PATH")
	if path == "": path = "user://village_inventory.json"
	var world_seed := int(OS.get_environment("AIU5_WORLD_SEED"))
	if world_seed <= 0: world_seed = maxi(1, path.hash() & 0x7fffffff)
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("session") is Dictionary:
			selected = str(data.session.get("settlement", "expanded"))
			var resources: Variant = data.session.get("resource_world", {})
			if resources is Dictionary: world_seed = int(resources.get("seed", world_seed))
	world.resource_seed = maxi(1, world_seed)
	world.settlement = "starter" if selected == "starter" else "expanded"
