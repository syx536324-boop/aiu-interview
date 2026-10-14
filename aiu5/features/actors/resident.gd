# Moves and animates one resident; control and patrol routes are assigned externally.
extends CharacterBody2D

const SPEED := 56.0
const RUN_SPEED := 88.0
var dead := false
var run_multiplier := 1.0
var magic_branches: Node
var resident_name := ""
var resident_id := ""
var room_id := ""
var role_label := "村民"
var dialogue := ""
var can_control := true
var input_enabled := true
var patrol_speed := 15.0
var blocked_time := 0.0
var controlled := false
var patrol: Array[Vector2] = []
var patrol_index := 0
var idle_time := 1.0
var facing := 0
var elapsed := 0.0
var sheet: Texture2D
var sprite: Sprite2D
var pathfinder: Callable
var navigation := PackedVector2Array()

func configure(display_name: String, texture: Texture2D, route: Array[Vector2], find_path: Callable) -> void:
	resident_name = display_name
	sheet = texture
	patrol = route
	pathfinder = find_path

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape2D.new()
	var capsule := CircleShape2D.new()
	capsule.radius = 3.5
	shape.shape = capsule
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = maxi(1, int(sheet.get_width() / 16.0))
	sprite.vframes = maxi(1, int(sheet.get_height() / 16.0))
	sprite.position = Vector2(0, -8)
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if dead or (is_instance_valid(magic_branches) and magic_branches.immobile(resident_id)):
		velocity = Vector2.ZERO
		return
	elapsed += delta
	var direction := Vector2.ZERO
	var speed := SPEED
	if not controlled and has_meta("tribal_escort"): return
	if controlled:
		if input_enabled:
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if Input.is_action_pressed("run"):
				speed = RUN_SPEED * run_multiplier
	elif room_id == "" and not patrol.is_empty():
		idle_time -= delta
		if idle_time <= 0.0:
			var destination := patrol[patrol_index]
			if position.distance_to(destination) < 5.0:
				patrol_index = (patrol_index + 1) % patrol.size()
				idle_time = 2.5
				navigation = PackedVector2Array()
			else:
				if navigation.is_empty():
					navigation = pathfinder.call(position, destination)
				while not navigation.is_empty() and position.distance_to(navigation[0]) < 2.0:
					navigation.remove_at(0)
				if navigation.is_empty():
					idle_time = 1.0
				else:
					direction = position.direction_to(navigation[0])
					speed = patrol_speed
	velocity = direction * speed
	var previous := position
	move_and_slide()
	if not controlled and direction.length_squared() > 0.01:
		blocked_time = blocked_time + delta if position.distance_to(previous) < speed * delta * 0.2 else 0.0
		if blocked_time > 1.5:
			patrol_index = (patrol_index + 1) % patrol.size()
			navigation = PackedVector2Array()
			idle_time = 1.0
			blocked_time = 0.0
	if direction.length_squared() > 0.01:
		if absf(direction.x) > absf(direction.y):
			facing = 3 if direction.x > 0.0 else 2
		else:
			facing = 0 if direction.y > 0.0 else 1
		var walking_row: int = [mini(1, sprite.vframes - 1), 0, mini(3, sprite.vframes - 1), 0][int(elapsed * 9.0) % 4]
		sprite.frame = walking_row * sprite.hframes + mini(facing, sprite.hframes - 1)
	else:
		sprite.frame = mini(facing, sprite.hframes - 1)
	if controlled: queue_redraw()

func set_controlled(value: bool) -> void:
	controlled = value and can_control
	velocity = Vector2.ZERO
	navigation = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 6.0, Color(0.23, 0.18, 0.12, 0.24))
	if controlled:
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 20, Color("c6e2b5"), 1.0)
	draw_set_transform(Vector2.ZERO)
	if controlled:
		var lift := floorf(sin(elapsed * 3.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -22 + lift), Vector2(3, -22 + lift), Vector2(0, -19 + lift)]), Color("ebf3be"))
