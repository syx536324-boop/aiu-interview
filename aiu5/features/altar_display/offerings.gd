# Coordinates one altar item for one resurrection, committing both in a single autosave.
extends Node

const STORAGE_ID := "altar:display"
var session: Node

func start(controller: Node) -> void:
	session = controller

func preview() -> Dictionary:
	var targets: Array[Dictionary] = []
	for actor in session.world.controllable:
		if session.vitals.ensure(actor.resident_id).life <= 0:
			targets.append({"id": actor.resident_id, "name": actor.resident_name})
	return {"targets": targets, "ready": not targets.is_empty() and _error() == ""}

func _error() -> String:
	var actor: CharacterBody2D = session.world.active_resident
	var items: Node = session.inventory
	if session.overview or session.menu_paused or actor.dead:
		return "需要由存活角色在祭坛旁献祭。"
	if actor.room_id != "" or actor.position.distance_to(Vector2(548, 244)) > 18:
		return "请靠近祭坛北侧再献祭。"
	if not items.opened or items.container_id != STORAGE_ID:
		return "请先按 E 打开祭坛。"
	if not session.persistence.ready_to_save or session.persistence.restoring or session.persistence.restore_queued:
		return "正在恢复存档，请稍后再试。"
	var selected: Dictionary = items.selection
	var index := int(selected.get("index", -1))
	if selected.get("side", "") != "storage" or index < 0 or index >= 21:
		return "先选中祭坛右侧的一格物品作为祭品。"
	var slot: Dictionary = items.ensure_container(STORAGE_ID)[index]
	if slot.is_empty() or int(slot.get("count", 0)) <= 0:
		return "这一格没有可献祭的物品。"
	return ""

func sacrifice(target_id: String) -> Dictionary:
	# Flush before checking eligibility: the operator may die or switch at this boundary.
	if is_instance_valid(session.simulation): session.simulation.flush()
	var error := _error()
	if error != "": return {"ok": false, "message": error}
	var target: CharacterBody2D
	for actor in session.world.controllable:
		if actor.resident_id == target_id: target = actor
	if not is_instance_valid(target) or session.vitals.ensure(target_id).life > 0:
		return {"ok": false, "message": "请选择一名阵亡角色；存活角色不需要献祭。"}
	var spawn: Variant = _spawn_position()
	if spawn == null:
		return {"ok": false, "message": "祭台前没有安全的复活位置，请先移开人物或物件。"}
	var items: Node = session.inventory
	var index := int(items.selection.index)
	var slots: Array = items.ensure_container(STORAGE_ID)
	var previous_slot: Dictionary = slots[index].duplicate(true)
	var previous_state: Dictionary = session.vitals.ensure(target_id).duplicate(true)
	var previous_room: String = target.room_id
	var previous_position: Vector2 = target.position
	var previous_outside: Vector2 = session.interiors.outdoor_position(target)
	var previous_velocity: Vector2 = target.velocity
	var previous_navigation: PackedVector2Array = target.navigation.duplicate()
	if int(previous_slot.count) == 1: slots[index] = {}
	else: slots[index].count -= 1
	session.vitals.revive(target_id)
	session.interiors.leave(target, session.world.objects, spawn)
	# Leaving another resident's room must not change the operator's current camera.
	session._sync_view()
	if not session.persistence.save_now():
		slots[index] = previous_slot
		session.vitals.states[target_id] = previous_state
		session.vitals._sync_actors()
		if previous_room != "": session.interiors.enter(target, session.world.home_data(previous_room))
		target.position = previous_position
		target.velocity = previous_velocity
		target.navigation = previous_navigation
		session.interiors.outside_positions[target_id] = previous_outside
		session._sync_view()
		items.changed.emit()
		return {"ok": false, "message": "存档失败，献祭已撤销；祭品和角色原状态均保留。"}
	# Require a fresh item selection for the next ritual, even when a stack remains.
	items.selection.clear()
	items.changed.emit()
	return {"ok": true, "message": "献祭%s ×1，%s已在祭台前复活；五项状态恢复至10。" % [items.Catalog.ITEMS[previous_slot.item].name, target.resident_name]}

func _spawn_position() -> Variant:
	var world: Node2D = session.world
	var obstacles: Array[Rect2] = world.logical_obstacles(session.gate_open)
	for y in range(344, 393, 12):
		for x in range(500, 597, 12):
			var point := Vector2(x, y)
			var blocked := false
			for rect: Rect2 in obstacles:
				if rect.grow(6).has_point(point):
					blocked = true
					break
			if blocked: continue
			for actor in world.residents:
				if actor.room_id == "" and not actor.dead and actor.position.distance_to(point) < 14:
					blocked = true
			for animal in session.livestock.animals:
				if animal.position.distance_to(point) < 16: blocked = true
			if not blocked: return point
	return null
