# Executes tribal movement intents on physical frames; domain decisions and timers stay on the online clock.
extends RefCounted

var runtime: Node
var commands: Dictionary = {}

func begin_step() -> void:
	for key: int in commands:
		var actor: Node=commands[key].actor.get_ref()
		if is_instance_valid(actor):
			actor.set_meta("motion_last_distance",float(actor.get_meta("motion_distance",0.0)))
			actor.set_meta("motion_distance",0.0)
	commands.clear()

func submit(actor: Node, at: Vector2, speed: float, purpose: String) -> void:
	actor.set_meta("tribal_movement",self)
	commands[actor.get_instance_id()]={"actor":weakref(actor),"target":at,"speed":speed,
		"left":0.6,"room":str(actor.room_id),"purpose":purpose}

func stop(actor: Node) -> void:
	commands.erase(actor.get_instance_id())
	actor.velocity=Vector2.ZERO
	actor.set_meta("motion_distance",0.0)
	actor.set_meta("motion_last_distance",0.0)

func advance_actor(actor: Node, delta: float) -> void:
	var key := actor.get_instance_id()
	if not commands.has(key):
		actor.velocity=Vector2.ZERO
		return
	var command: Dictionary=commands[key]
	var id := str(actor.enemy_id) if "enemy_id" in actor else str(actor.resident_id)
	if actor.dead or runtime.relics.failed or str(actor.room_id)!=str(command.room) or float(command.left)<=0:
		stop(actor); return
	if runtime.session.magic.skills.rooted(id) or runtime.session.magic.branches.immobile(id) or runtime.session.magic.branches.immobile(actor.resident_id):
		stop(actor); return
	if command.purpose=="routine" and not runtime.routine._eligible(id,actor):
		stop(actor); return
	command.left=float(command.left)-delta
	var before: Vector2=actor.position
	if runtime.workers.move_step(actor,command.target,delta,float(command.speed),true): stop(actor)
	actor.set_meta("motion_distance",float(actor.get_meta("motion_distance",0.0))+actor.position.distance_to(before))
