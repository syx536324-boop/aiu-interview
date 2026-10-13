# Advances online domain time in coarse ticks; flushing preserves fractional seconds at actions/saves.
extends Node

var session: Node
var pending := 0.0
var flushing := false
const TICK := 0.5

func start(controller: Node) -> void:
	session = controller
	for domain in [session.homestead, session.livestock, session.vitals]: domain.clock_driven = true

func _process(delta: float) -> void:
	pending += delta
	if pending >= TICK: flush()

func flush() -> void:
	if flushing or not is_instance_valid(session) or pending <= 0: return
	flushing = true
	var delta := pending
	pending = 0
	if session.homestead.is_processing(): session.homestead.elapse(delta)
	if session.livestock.is_processing(): session.livestock.elapse(delta)
	if session.production.is_processing(): session.production.elapse(delta)
	if is_instance_valid(session.forest) and session.forest.is_processing(): session.forest.elapse(delta)
	if is_instance_valid(session.foraging) and session.foraging.is_processing(): session.foraging.elapse(delta)
	if session.vitals.is_processing():
		var left := delta
		while left>0.00001:
			var step := minf(0.5,left)
			left-=step
			session.vitals.advance(step)
			session.magic.skills.advance(step)
			session.magic.branches.advance(step)
			session.magic.enchants.advance(step)
			session.construction.advance(step)
			if is_instance_valid(session.torches): session.torches.advance(step)
	if is_instance_valid(session.day_night): session.day_night.advance(delta)
	flushing = false

func reset() -> void:
	pending = 0
