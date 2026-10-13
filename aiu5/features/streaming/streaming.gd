# Parks distant state-bearing objects outside the scene tree and activates only nearby simulation.
extends Node

const Overview := preload("res://features/streaming/overview.gd")
const CHUNK_SIZE := Vector2(320, 200)
var world: Node2D
var session: Node
var overview: CanvasLayer
var entries: Dictionary = {}
var center := Vector2i(-100, -100)
var refresh_left := 0.0
var active_count := 0
var activation_queue: Array = []
var attached_last_frame := 0

func start(controller: Node) -> void:
	session = controller
	world = session.world
	world.streamer = self
	overview = Overview.new()
	add_child(overview)
	overview.start(world, session.grounds, session.homestead)
	_register_new()
	focus(true)

func _register_new() -> void:
	for node in world.objects.get_children(): _track(node, world.objects)
	for node in world.get_children():
		if node is Label: _track(node, world)

func _track(node: CanvasItem, parent: Node2D) -> void:
	if node.get_meta("procedural_resource", false): return
	var id := node.get_instance_id()
	if not entries.has(id): entries[id] = {"node": node, "parent": parent, "active": true}

func focus(immediate := false) -> void:
	var home: Dictionary = world.home_data(world.active_resident.room_id)
	var roof: bool = home.get("tower",false)
	var occupied_building: bool = home.get("built",false) and not home.get("ruined",false)
	var indoors: bool = world.active_resident.room_id != "" and not roof
	var inside: bool = world.active_resident.room_id != "" and not occupied_building
	world.terrain.set_process(not indoors)
	var at: Vector2 = world.active_resident.global_position if roof else (home.door if occupied_building else world.active_resident.position)
	var next: Vector2i = world.terrain.cell(at)
	if not inside and (next != center or immediate):
		center = next
		session.homestead.settle()
		world.terrain.focus(at, true)
		# Static landscape and farm drawings reject geometry outside this working area.
		var region := Rect2(Vector2(center - Vector2i.ONE) * CHUNK_SIZE, CHUNK_SIZE * 3).grow(64)
		session.homestead.land.render_region = region
		session.homestead.land.queue_redraw()
		if is_instance_valid(session.landscape.view):
			session.landscape.view.render_region = region
			session.landscape.view.queue_redraw()
	session.resources.focus(at, indoors)
	if is_instance_valid(session.forest): session.forest.focus(at, indoors)
	if is_instance_valid(overview): overview.mark_loaded()
	_register_new()
	session.livestock.active_animals.clear()
	active_count = 0
	for id in entries.keys():
		var record: Dictionary = entries[id]
		var node: Variant = record.node
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			entries.erase(id)
			continue
		# Indoor actors belong to interiors, never to the outdoor streaming container.
		if node is CharacterBody2D and "room_id" in node and node.room_id != "": continue
		var target: Vector2i = world.terrain.cell(node.position)
		var gap: int = world.terrain.distance(target, center)
		var active: bool = not inside and (gap <= 1 or node == world.active_resident)
		# Half-chunk activation hysteresis prevents thrashing at screen boundaries.
		if not inside and record.active and gap == 2:
			active = Rect2(Vector2(center - Vector2i.ONE) * CHUNK_SIZE, CHUNK_SIZE * 3).grow(60).has_point(node.position)
		if active:
			active_count += 1
			if "animal_id" in node: session.livestock.active_animals.append(node)
			if node.get_parent() == null:
				# Attach immediately whatever the camera actually shows, instead of one fixed chunk.
				var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / maxf(0.01, world.camera.zoom.x)
				var viewport_area := Rect2(at - half, half * 2.0).grow(64)
				if node == world.active_resident or viewport_area.has_point(node.position):
					record.parent.add_child(node)
				elif not activation_queue.has(id): activation_queue.append(id)
		elif node.get_parent() == record.parent:
			record.parent.remove_child(node)
		record.active = active

func ensure_actor(actor: CharacterBody2D) -> void:
	if actor.room_id == "" and actor.get_parent() == null: world.objects.add_child(actor)
	focus(true)

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	refresh_left -= delta
	if (world.active_resident.room_id == "" and world.terrain.cell(world.active_resident.position) != center) or refresh_left <= 0:
		refresh_left = 0.2
		focus()
	var started := Time.get_ticks_usec()
	attached_last_frame = 0
	while not activation_queue.is_empty() and attached_last_frame < 4:
		var id: int = activation_queue.pop_front()
		if not entries.has(id): continue
		var record: Dictionary = entries[id]
		var node: Variant = record.node
		if not is_instance_valid(node) or not record.active or node.get_parent() != null: continue
		record.parent.add_child(node)
		attached_last_frame += 1
		if Time.get_ticks_usec() - started >= 2000: break

func set_overview(value: bool) -> void:
	if value:
		session.simulation.flush()
		session.homestead.settle()
		session.livestock.settle()
		overview.present()
		world.visible = false
		get_tree().paused = true
	else:
		overview.visible = false
		get_tree().paused = false
		world.visible = world.active_resident.room_id == ""
		focus(true)

func _exit_tree() -> void:
	# Parked Nodes are deliberately owned here, since SceneTree cannot free detached objects.
	for record: Dictionary in entries.values():
		var node: Variant = record.node
		if is_instance_valid(node) and node.get_parent() == null: node.free()
	entries.clear()
