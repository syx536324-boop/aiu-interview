# Carries a tribal arrow through swept physical collision with a fixed range and one impact.
extends Node2D
var runtime: Node
var attacker := ""
var tribe := ""
var damage := 1.0
var slow := 0.0
var direction := Vector2.RIGHT
var left := 150.0
var excluded: Array[RID]=[]
func _ready() -> void:
 add_to_group("tribal_arrows"); add_to_group("arrows")
func _physics_process(delta: float) -> void:
 var step := minf(left,360*delta); var to := global_position+direction*step
 if runtime.session.magic.branches.barrier_blocks(global_position,to): queue_free(); return
 var query := PhysicsRayQueryParameters2D.create(global_position,to,1|2|4|8|16,excluded)
 var hit: Dictionary=get_world_2d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  var target: Node=hit.collider
  runtime.war.damage_target(target,damage,tribe,attacker)
  if slow>0:
   if "enemy_id" in target and runtime.relics.owner(target.tribe)!=runtime.relics.owner(tribe):
    runtime.session.magic.branches._status(target,attacker,"suppress",2.0,{"slow":slow})
   elif "resident_id" in target and runtime.relics.owner(tribe)!="player":
    runtime.session.magic.branches.player_status(target.resident_id,"slowed",2.0)
  queue_free(); return
 global_position=to; left-=step
 if left<=0: queue_free()
func _draw() -> void:
 draw_line(-direction*7,direction*3,Color("e1c795"),1)
 draw_line(direction*3,direction.rotated(2.5)*3,Color("dbe0d1"),1)
 draw_line(direction*3,direction.rotated(-2.5)*3,Color("dbe0d1"),1)
