# Moves a short-lived arrow and checks swept collisions so fast shots cannot tunnel through targets or walls.
extends Node2D
var combat: Node
var actor_id := ""
var damage := 10.0
var record: Dictionary={}
var direction := Vector2.RIGHT
var distance_left := 200.0
var excluded: Array[RID] = []
func _ready() -> void:
	add_to_group("arrows")
func _physics_process(delta: float) -> void:
	var length := minf(distance_left,360*delta)
	var end := global_position+direction*length
	if combat.session.magic.branches.barrier_blocks(global_position,end): queue_free(); return
	var query := PhysicsRayQueryParameters2D.create(global_position,end,1|8|4,excluded)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.is_in_group("hostile_targets"): combat.hit_enemy(hit.collider,damage,actor_id,record)
		elif hit.collider.is_in_group("creature_targets"): combat.hit_animal(hit.collider,damage,actor_id,record)
		queue_free()
		return
	global_position = end
	distance_left -= length
	if distance_left <= 0: queue_free()
func _draw() -> void:
	draw_line(-direction*7,direction*3,Color("e2c78f"),1)
	draw_line(direction*3,direction.rotated(2.5)*3,Color("dce0d4"),1)
	draw_line(direction*3,direction.rotated(-2.5)*3,Color("dce0d4"),1)
