# Simulates one nearby hostile from another tribe; defeated state is persistent and never respawns on a timer.
extends CharacterBody2D
var combat: Node
var enemy_id := ""
var hp := 30.0
var max_hp := 30.0
var thirst := 10.0
var cooldown := 0.0
var pursuit := 0.0
var sprite: Sprite2D
# Tribe membership: raider (the three fixed outlanders), forest or barbarian.
var tribe := "raider"
var role := "charger"
var territory := Rect2()
var chief_id := ""
var shot_cooldown := 0.0
var mana := 0
const ROLE_NAMES := {"civilian": "平民", "archer": "弓箭手", "charger": "冲锋手", "chief": "村长"}
const TRIBE_NAMES := {"raider": "外部落", "forest": "森林部落", "barbarian": "野蛮部落", "yunye": "云野部落"}

func configure_tribe(tribe_name: String, npc_role: String, area: Rect2, max_hp := 20.0) -> void:
	tribe = tribe_name
	role = npc_role
	territory = area
	self.max_hp=max_hp
	hp = max_hp
func label() -> String:
	return str(TRIBE_NAMES.get(tribe, tribe)) + " · " + str(ROLE_NAMES.get(role, role))
func aggro_range() -> float:
	if role == "civilian": return 60.0
	if tribe == "barbarian" or tribe == "yunye": return 210.0   # hostile: attacks whatever enters its sight
	if tribe == "forest": return 80.0       # unknown: only reacts at close range
	return 110.0
func attack_reach() -> float:
	if role == "archer": return 160.0
	if role == "chief": return 200.0
	return 13.0
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
	shot_cooldown = maxf(0,shot_cooldown-delta)
	var session: Node = combat.session
	if session.magic.skills.rooted(enemy_id): velocity=Vector2.ZERO; return
	var actor: CharacterBody2D = session.world.active_resident
	var home: Dictionary = session.world.home_data(actor.room_id)
	var occupied_building: bool = home.get("built",false) and not home.get("ruined",false)
	if actor.dead or home.get("skill_hut",false) or (actor.room_id != "" and not occupied_building): return
	var target: Vector2 = home.door if occupied_building else actor.global_position
	var gap := global_position.distance_to(target)
	if gap > aggro_range() and pursuit <= 0: return
	# Tribe members never chase beyond their own territory, so they cannot raid the village.
	if territory.has_area() and not territory.grow(8).has_point(target):
		if not territory.grow(-4).has_point(global_position):
			velocity = global_position.direction_to(territory.get_center()) * 32
			move_and_slide()
		return
	var reach := attack_reach()
	if gap > reach:
		var step: Vector2= global_position.direction_to(target) * 32 * session.magic.branches.speed_rate(enemy_id)
		if territory.has_area():
			var next := global_position + step * delta
			if not territory.grow(-4).has_point(next): velocity = Vector2.ZERO; return
		velocity = step
		move_and_slide()
	elif cooldown <= 0:
		cooldown = 2.0
		if occupied_building:
			var element: String=str(combat.CHIEF_ELEMENT.get(tribe,"")) if role=="chief" else ""
			session.magic.branches.note_combat(actor.resident_id)
			session.construction.hit(actor.room_id,10,false,element)
		else:
			if role == "archer" or role == "chief":
				# Ranged tribe members shoot from cover; the chief spends mana like a player would.
				if role == "chief" and chief_id != "":
					if mana < 5:
						mana = mini(session.magic.max_mana(chief_id), mana + 1)
						return
					mana -= 5
				shot_cooldown = 2.0
			var ranged := role in ["archer","chief"]
			if ranged and session.magic.branches.barrier_blocks(global_position,actor.global_position): return
			session.vitals.hurt(actor.resident_id,1,{"kind":"ranged" if ranged else "melee","enemy":enemy_id,"element":str(combat.CHIEF_ELEMENT.get(tribe,"")) if role=="chief" else ""})
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-28),Vector2(3,-28),Vector2(0,-25)]),Color("e37657"))
	draw_rect(Rect2(-10,-22,20,3),Color("392d27"))
	draw_rect(Rect2(-10,-22,20*hp/max_hp,3),Color("bf7060"))

	if thirst<10: draw_rect(Rect2(-10,-18,20*thirst/10.0,2),Color("72b8ce"))
