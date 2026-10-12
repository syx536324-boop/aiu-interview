# Coordinates full-session autosaves, separate altar checkpoints and all-party death recovery.
extends Node

signal message(text: String)
var session: Node
var inventory: Node
var world: Node2D
var interiors: Node2D
var vitals: Node
var homestead: Node
var grounds: Node2D
var harvesting: Node
var livestock: Node
var mining: Node
var checkpoint: Dictionary = {}
var restoring := false
var ready_to_save := false
var elapsed := 0.0
var restore_queued := false

func start(controller: Node, survival: Node, farming: Node, outdoor: Node2D) -> void:
	session = controller
	inventory = session.inventory
	world = session.world
	interiors = session.interiors
	harvesting = session.harvesting
	livestock = session.livestock
	mining = session.mining
	vitals = survival
	homestead = farming
	grounds = outdoor
	if not inventory.saved_session.is_empty(): restore_session(inventory.saved_session)
	inventory.session_provider = capture_session
	var path: String = inventory.path + ".altar"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("session") is Dictionary:
			checkpoint = data
	ready_to_save = true
	get_tree().auto_accept_quit = false
	if checkpoint.is_empty(): save_checkpoint(false)
	vitals.deaths_changed.connect(_on_deaths)
	_on_deaths()

func capture_session() -> Dictionary:
	if is_instance_valid(session.simulation): session.simulation.flush()
	var actors: Dictionary = {}
	for actor in world.residents:
		var outside: Vector2 = interiors.outdoor_position(actor)
		actors[actor.resident_id] = {"position": [actor.position.x, actor.position.y], "room": actor.room_id,
			"outside": [outside.x, outside.y], "facing": actor.facing, "patrol": actor.patrol_index, "idle": actor.idle_time}
	var pigs: Array = []
	for pig in world.pigs:
		pigs.append({"position": [pig.position.x, pig.position.y], "target": [pig.target.x, pig.target.y],
			"feeding": pig.feeding_time, "pause": pig.pause_time})
	for id: String in interiors.rooms:
		inventory.layouts[id] = interiors.rooms[id].export_layout()
	inventory.layouts["outdoors"] = grounds.export_layout()
	return {"achievements":session.achievements.export_state(),"foraging":session.foraging.export_state(),"day_night":session.day_night.export_state() if is_instance_valid(session.day_night) else {}, "resource_world": session.resources.export_state(), "settlement": world.settlement, "actors": actors, "pigs": pigs, "selected": session.selected, "selected_id": world.active_resident.resident_id, "gate": session.gate_open,
		"names": world.founder_names(), "vitals": vitals.export_state(), "magic": session.magic.export_state(), "construction":session.construction.export_state(), "production":session.production.export_state(), "combat":session.combat.export_state(), "forest":session.forest.export_state(), "homestead": homestead.export_state(), "livestock": livestock.export_state(), "mining": mining.export_state()}

func restore_session(data: Dictionary) -> void:
	restoring = true
	session.overview = false
	world.set_overview(false)
	if is_instance_valid(session.simulation): session.simulation.reset()
	session.editor.close()
	inventory.close()
	session.roster_open = false
	session.attributes_id = ""
	session.awakening_open = false
	# Detach residents before clearing cached rooms, so references remain stable.
	for actor in world.residents:
		if actor.room_id != "":
			interiors.leave(actor, world.objects, interiors.outdoor_position(actor))
	for room: Node2D in interiors.rooms.values():
		if room.get_parent() == interiors: interiors.remove_child(room)
		room.queue_free()
	interiors.rooms.clear()
	interiors.layout_overrides = inventory.layouts
	mining.restore(data.get("mining", {}),int(data.get("resource_world",{}).get("seed",world.resource_seed)))
	grounds.restore(inventory.layouts.get("outdoors", []))
	session.achievements.restore(data.get("achievements",{}))
	session.foraging.restore(data.get("foraging",{}))
	session.construction.restore(data.get("construction",{}))
	session.production.restore(data.get("production",{}))
	session.combat.restore(data.get("combat",{}))
	session.forest.restore(data.get("forest",{}))
	session.magic.restore(data.get("magic", {}))
	for actor in world.residents:
		var saved: Dictionary = data.get("actors", {}).get(actor.resident_id, {})
		if saved.is_empty(): continue
		var room_id := str(saved.get("room", ""))
		if not world.home_data(room_id).is_empty():
			interiors.enter(actor, world.home_data(room_id))
		actor.position = _vector(saved.position)
		actor.facing = int(saved.get("facing", 0))
		actor.patrol_index = int(saved.get("patrol", 0))
		actor.idle_time = float(saved.get("idle", 1))
		actor.velocity = Vector2.ZERO
		actor.navigation = PackedVector2Array()
		interiors.outside_positions[actor.resident_id] = _vector(saved.get("outside", [322, 224]))
	livestock.restore(data.get("livestock", {}), data.get("pigs", []))
	var names: Dictionary = data.get("names", {})
	if names.has("male") and names.has("female"): world.apply_founder_names(names.male, names.female)
	vitals.restore(data.get("vitals", {}))
	if is_instance_valid(session.day_night): session.day_night.restore(data.get("day_night",{}))
	homestead.restore(data.get("homestead", {}))
	session.gate_open = bool(data.get("gate", false))
	world.set_gate_open(session.gate_open)
	harvesting.restore()
	session.resources.restore(data.get("resource_world", {}))
	session.selected = clampi(int(data.get("selected", 0)), 0, world.controllable.size() - 1)
	for i in range(world.controllable.size()):
		if world.controllable[i].resident_id == data.get("selected_id", ""):
			session.selected = i
	world.set_active(session.selected)
	session.overview = false
	world.set_overview(false)
	session._sync_view()
	session.refresh_interface()
	restoring = false

func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func save_checkpoint(announce := true) -> bool:
	var alive := false
	for actor in world.controllable:
		if vitals.ensure(actor.resident_id).life > 0: alive = true
	if not alive: return false
	var data: Dictionary = inventory.export_data()
	if inventory.write_file(inventory.path + ".altar", data) != OK:
		message.emit("祭台存档写入失败，原来的祭台存档仍保留。")
		return false
	checkpoint = data.duplicate(true)
	if announce: message.emit("祭台存档已保存。全员阵亡时将回到这一刻。")
	return true

func save_now() -> bool:
	if not ready_to_save or restoring or restore_queued: return false
	if inventory.save_state() != OK:
		message.emit("自动存档写入失败，请检查磁盘空间后重试。")
		return false
	elapsed = 0.0
	return true

func _process(delta: float) -> void:
	if not ready_to_save: return
	elapsed += delta
	if elapsed >= 15:
		elapsed = 0
		save_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ready_to_save:
		if save_now(): get_tree().quit()
		else: message.emit("退出前存档尚未成功，窗口暂时保留；稍后再次关闭重试。")

func _on_deaths() -> void:
	if restoring or restore_queued: return
	var alive: Array[int] = []
	for i in range(world.controllable.size()):
		if vitals.ensure(world.controllable[i].resident_id).life > 0: alive.append(i)
	if alive.is_empty():
		restore_queued = true
		call_deferred("restore_checkpoint")
	elif world.active_resident.dead:
		session.select_resident(alive[0])
		message.emit("该角色已阵亡，已切换到仍存活的村民。")

func restore_checkpoint() -> bool:
	restore_queued = false
	if checkpoint.is_empty():
		message.emit("没有可用的祭台存档。")
		return false
	inventory.apply_data(checkpoint)
	restore_session(checkpoint.session)
	# Expansion supplies also remain available when rolling back to a pre-expansion altar save.
	for actor in world.controllable: inventory.grant_supplies(actor.resident_id)
	save_now()
	message.emit("所有可操控角色已阵亡，已回到祭台存档。")
	return true
