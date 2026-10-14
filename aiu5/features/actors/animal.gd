# Moves and displays sex/age for livestock; the livestock module owns growth and reproduction.
extends CharacterBody2D

var animal_id := ""
var hp := 10.0
var max_hp := 10.0
var species := "pig"
var sex := "female"
var growth := 300.0
var growth_preview := 300.0
var cooldown := 0.0
var fed := false
var pen_bounds := Rect2(398, 230, 65, 30)
var feeding_point := Vector2(452, 235)
var target := Vector2.ZERO
var feeding_time := 0.0
var pause_time := 0.0
var animation_time := 0.0
var rng := RandomNumberGenerator.new()
var sprite: Sprite2D
var sheet: Texture2D
var pig_seed := 1

func _ready() -> void:
	rng.seed = pig_seed
	collision_layer = 4
	collision_mask = 1 | 2
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	collision.position = Vector2(0, -3)
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = 2
	sprite.position = Vector2(0, -7)
	add_child(sprite)
	_choose_target()
	sync_visual()
	add_to_group("creature_targets")
	if species == "cow": add_to_group("cow_targets")
	if species=="sheep": sprite.visible=false

func adult() -> bool:
	return growth >= 300.0

func sync_visual() -> void:
	growth_preview = growth
	if is_instance_valid(sprite): sprite.scale = Vector2.ONE if adult() else Vector2(0.65, 0.65)
	queue_redraw()

func feed() -> void:
	feeding_time = 7.0
	pause_time = 0.0
	target = (feeding_point + Vector2(rng.randf_range(-5, 3), rng.randf_range(-2, 5))).clamp(pen_bounds.position, pen_bounds.end)

func _choose_target() -> void:
	target = pen_bounds.position + Vector2(rng.randf_range(0, pen_bounds.size.x), rng.randf_range(0, pen_bounds.size.y))
	pause_time = rng.randf_range(0.7, 2.2)

func _physics_process(delta: float) -> void:
	animation_time += delta
	feeding_time = maxf(0.0, feeding_time - delta)
	pause_time -= delta
	velocity = Vector2.ZERO
	if has_meta("tether_target"):
		var owner_at: Vector2=get_meta("tether_target")
		if position.distance_to(owner_at)>2: velocity=position.direction_to(owner_at)*96*float(get_meta("magic_slow_rate",1.0))
	elif pause_time <= 0:
		if position.distance_to(target) > 3.0:
			velocity = position.direction_to(target) * (11.0 if adult() else 8.0)*float(get_meta("magic_slow_rate",1.0))
		elif feeding_time <= 0:
			_choose_target()
	move_and_slide()
	if not has_meta("tether_target"): position = position.clamp(pen_bounds.position, pen_bounds.end)
	if absf(velocity.x) > 0.1: sprite.flip_h = velocity.x < 0.0
	sprite.frame = int(animation_time * 5) % 2 if velocity.length_squared() > 1 or feeding_time > 0 else 0
	if species=="sheep" and (velocity.length_squared()>1 or feeding_time>0): queue_redraw()
	# The shadow and sex marker are static; domain growth ticks redraw the juvenile bar.

func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 6, Color(0.22, 0.16, 0.12, 0.2))
	draw_set_transform(Vector2.ZERO)
	if species in ["pig","cow","sheep"]: draw_rect(Rect2(-2, -20 if adult() else -15, 4, 2), Color("81b9d3") if sex == "male" else Color("dc9aab"))
	if not adult():
		draw_rect(Rect2(-7, 3, 14, 2), Color("514c35"))
		draw_rect(Rect2(-7, 3, 14 * minf(growth_preview, 300) / 300.0, 2), Color("b8c579"))
	if species=="sheep": _draw_sheep()
	if hp<10:
		draw_rect(Rect2(-8,-25,16,2),Color("584033"))
		draw_rect(Rect2(-8,-25,16*hp/10.0,2),Color("c97b62"))

func _draw_sheep() -> void:
	var scale_factor := 1.0 if adult() else 0.65
	draw_set_transform(Vector2(0,-2),0,Vector2.ONE*scale_factor)
	var left: bool=velocity.x<0 if absf(velocity.x)>0.1 else sprite.flip_h
	var step := int(animation_time*5)%2 if velocity.length_squared()>1 else 0
	for x in [-5,3]: draw_rect(Rect2(x,-2+step,3,5-step),Color("63584b"))
	for at in [Vector2(-5,-7),Vector2(0,-10),Vector2(5,-7),Vector2(0,-5)]: draw_circle(at,3 if get_meta("sheared",false) else 5,Color("c9bfa4") if get_meta("sheared",false) else Color("e9e7d6"))
	draw_rect(Rect2(-11 if left else 5,-11,6,8),Color("796e5c"))
	draw_rect(Rect2(-10 if left else 8,-9,2,2),Color("292923"))
	draw_set_transform(Vector2.ZERO)
