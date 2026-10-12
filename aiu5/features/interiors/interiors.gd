# Keeps separate rooms and safely reparents residents across their exterior and interior spaces.
extends Node2D

const Room := preload("res://features/interiors/room.gd")
const Layout := preload("res://features/interiors/layout.gd")
var rooms: Dictionary = {}
var special_rooms: Dictionary = {}
var outside_positions: Dictionary = {}
var layout_overrides: Dictionary = {}

func enter(resident: CharacterBody2D, home: Dictionary) -> void:
	var room_id: String = home["id"]
	if not rooms.has(room_id):
		var room: Node2D
		if special_rooms.has(room_id):
			room = special_rooms[room_id].call()
		else:
			room = Room.new()
			var saved: Variant = layout_overrides.get(room_id, [{"missing": true}])
			room.configure(home, Layout.ROOMS[room_id], saved if saved is Array else [{"missing": true}])
		room.name = room_id
		room.position = Vector2(2048 + (rooms.size() % 4) * 512, 2048 + floori(rooms.size() / 4.0) * 512)
		add_child(room)
		rooms[room_id] = room
	var target: Node2D = rooms[room_id]
	if target.get_meta("outdoor_roof",false): target.position = home.at + Vector2(0,-32)
	outside_positions[resident.resident_id] = resident.global_position
	var spawn: Vector2 = target.safe_spawn()
	if target.get_parent() == null: add_child(target)
	if resident.get_parent() == null:
		target.objects.add_child(resident)
	else:
		resident.reparent(target.objects)
	resident.position = spawn
	resident.room_id = room_id
	resident.velocity = Vector2.ZERO
	resident.navigation = PackedVector2Array()
	focus(resident)

func leave(resident: CharacterBody2D, outside_parent: Node2D, return_position: Vector2) -> void:
	if resident.get_parent() == null: outside_parent.add_child(resident)
	else: resident.reparent(outside_parent)
	resident.global_position = return_position
	resident.room_id = ""
	resident.velocity = Vector2.ZERO
	resident.navigation = PackedVector2Array()
	focus(resident)

func outdoor_position(resident: CharacterBody2D) -> Vector2:
	return outside_positions.get(resident.resident_id, Vector2(322, 224))

func focus(resident: CharacterBody2D) -> void:
	for room_id: String in rooms.keys():
		var room: Node2D = rooms[room_id]
		var occupied: bool = room.objects.get_children().any(func(node: Node) -> bool: return node is CharacterBody2D)
		if not occupied:
			layout_overrides[room_id] = room.export_layout()
			if room.get_parent() == self: remove_child(room)
			room.free()
			rooms.erase(room_id)
			continue
		var selected: bool = resident.room_id == room_id
		room.visible = selected
		room.camera.enabled = selected
		if selected:
			if room.get_parent() == null: add_child(room)
			room.camera.make_current()
		elif room.get_parent() == self:
			remove_child(room)

func context(resident: CharacterBody2D) -> Dictionary:
	if resident.room_id == "":
		return {}
	return rooms[resident.room_id].nearby(resident.position)

func _exit_tree() -> void:
	for room in rooms.values():
		if is_instance_valid(room) and room.get_parent() == null: room.free()
