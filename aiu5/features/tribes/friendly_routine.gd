# Owns peaceful local walks for idle allied NPCs; war invokes it only after higher-priority actions.
extends RefCounted

const RADIUS := 56.0
const SPEED := 16.0
const WAIT_MIN := 1.0
const WAIT_MAX := 3.0
var runtime: Node
var states: Dictionary = {}

func advance_actor(id: String, actor: Node, delta: float) -> void:
	if not _eligible(id,actor) or delta<=0.0: return
	var state := _state(id,actor)
	if float(state.wait)>0.0:
		state.wait=maxf(0.0,float(state.wait)-delta)
		actor.velocity=Vector2.ZERO
		return
	var home := Vector2(state.home[0],state.home[1])
	if not bool(state.walking):
		var goal := _destination(id,actor,home,int(state.cycle))
		state.cycle=int(state.cycle)+1
		if not goal.is_finite():
			state.wait=WAIT_MAX
			return
		state.target=[goal.x,goal.y]
		state.walking=true
		state.travel=0.0
	var target := Vector2(state.target[0],state.target[1])
	state.travel=float(state.travel)+delta
	if runtime.workers.move(actor,target,delta,SPEED,"routine") or float(state.travel)>=12.0:
		# Failed routes are retried with a different nearby point; never snap or teleport.
		state.walking=false
		state.wait=WAIT_MIN+float(posmod(id.hash()+int(state.cycle),9))*0.25
		actor.navigation=PackedVector2Array()
		actor.velocity=Vector2.ZERO

func _eligible(id: String, actor: Node) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.hp<=0: return false
	var record: Dictionary=runtime.population.members.get(id,{})
	if record.is_empty() or not runtime.population.friendly(id) or float(record.child_left)>0: return false
	if str(record.career) not in ["civilian","archer","charger"] or actor.room_id!="": return false
	if runtime.war.orders.has(id) or runtime.romance.busy(actor.resident_id) or runtime.encounters.in_combat(actor): return false
	if runtime.session.get_tree().paused or runtime.relics.failed: return false
	if runtime.session.magic.skills.rooted(id) or runtime.session.magic.branches.immobile(id): return false
	if runtime.session.magic.branches.immobile(actor.resident_id): return false
	if runtime.session.production.opened and runtime.session.production.mode=="tribes" and runtime.dialog_kind=="npc" and runtime.dialog_id==id: return false
	return actor.global_position.distance_to(runtime.session.world.active_resident.global_position)<=600.0

func _state(id: String, actor: Node) -> Dictionary:
	if not states.has(id):
		var home: Vector2=actor.home_point()
		states[id]={"home":[home.x,home.y],"target":[home.x,home.y],"walking":false,
			"wait":WAIT_MIN+float(posmod(id.hash(),6))*0.25,"cycle":0,"travel":0.0}
	return states[id]

func _destination(id: String, actor: Node, home: Vector2, cycle: int) -> Vector2:
	var nav=runtime.session.world.navigation
	for attempt in range(12):
		var angle := TAU*float(posmod(id.hash()+cycle*5+attempt,12))/12.0
		var radius := 32.0+float(posmod(id.hash()+cycle*7+attempt*3,25))
		var target := home+Vector2.from_angle(angle)*radius
		if not runtime.session.world.BOUNDS.grow(-12).has_point(target): continue
		var path: PackedVector2Array=nav.find_path(actor.position,target)
		if path.is_empty() or path[-1].distance_to(target)>8.0: continue
		target=path[-1]
		if actor.position.distance_to(target)<22.0: continue
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new(); circle.radius=5.0
		query.shape=circle; query.transform=Transform2D(0,target)
		query.collision_mask=1|2|8|16; query.exclude=[actor.get_rid()]
		if actor.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return target
	return Vector2.INF

func export_state() -> Dictionary:
	return states.duplicate(true)

func restore(data: Dictionary) -> void:
	states.clear()
	for id: String in data:
		if not runtime.population.members.has(id) or not data[id] is Dictionary: continue
		var saved: Dictionary=data[id]
		var home: Variant=saved.get("home",[])
		var target: Variant=saved.get("target",[])
		if not home is Array or not target is Array or home.size()!=2 or target.size()!=2: continue
		var at := Vector2(float(home[0]),float(home[1]))
		var goal := Vector2(float(target[0]),float(target[1]))
		if not at.is_finite() or not goal.is_finite() or not runtime.session.world.BOUNDS.has_point(at): continue
		if not runtime.session.world.BOUNDS.has_point(goal): continue
		states[id]={"home":[at.x,at.y],"target":[goal.x,goal.y],"walking":bool(saved.get("walking",false)),
			"wait":clampf(float(saved.get("wait",0)),0.0,WAIT_MAX),"cycle":maxi(0,int(saved.get("cycle",0))),
			"travel":clampf(float(saved.get("travel",0)),0.0,12.0)}
