# Simulates one nearby hostile from another tribe; defeated state is persistent and never respawns on a timer.
extends CharacterBody2D
var combat: Node
var enemy_id := ""
var hp := 30.0
var cooldown := 0.0
var pursuit := 0.0
var sprite: Sprite2D
func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5
	shape.shape = circle
	add_child(shape)
	sprite=Sprite2D.new()
	sprite.texture=preload("res://assets/ninja_adventure/Actor/Character/Caveman2/SpriteSheet.png")
	sprite.hframes=maxi(1,int(sprite.texture.get_width()/16.0))
	sprite.vframes=maxi(1,int(sprite.texture.get_height()/16.0))
	sprite.position=Vector2(0,-8)
	sprite.modulate=Color("d4a29d")
	add_child(sprite)
	add_to_group("hostile_targets")
	refresh()
func refresh() -> void:
	visible = hp > 0
	collision_layer = 8 if hp > 0 else 0
	set_physics_process(hp > 0)
	queue_redraw()
func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	pursuit = maxf(0,pursuit-delta)
	var session: Node = combat.session
	var actor: CharacterBody2D = session.world.active_resident
	var home: Dictionary = session.world.home_data(actor.room_id)
	var occupied_building: bool = home.get("built",false) and not home.get("ruined",false)
	if actor.dead or (actor.room_id != "" and not occupied_building): return
	var target: Vector2 = home.door if occupied_building else actor.global_position
	var gap := global_position.distance_to(target)
	if gap > 110 and pursuit <= 0: return
	if gap > 13:
		velocity = global_position.direction_to(target) * 32
		move_and_slide()
	elif cooldown <= 0:
		cooldown = 2.0
		if occupied_building: session.construction.hit(actor.room_id,10)
		else:
			var stats: Dictionary = session.vitals.ensure(actor.resident_id)
			stats.life = maxf(0,float(stats.life)-1)
			session.vitals._sync_actors()
			session.vitals.deaths_changed.emit()
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-28),Vector2(3,-28),Vector2(0,-25)]),Color("e37657"))
	draw_rect(Rect2(-10,-22,20,3),Color("392d27"))
	draw_rect(Rect2(-10,-22,20*hp/30.0,3),Color("bf7060"))
