# Stores paid sixty-second workshop jobs by stable fixture ID, including held outputs.
extends RefCounted
const DURATION := 60.0
var jobs: Dictionary = {}
func start(production: Node, station: String, id: String, recipe: Dictionary) -> bool:
	if jobs.has(station):
		production.message.emit("这张工作台正在制作或有成品待领。")
		return false
	var s: Node = production.session
	var before: Dictionary = s.inventory.export_data()
	var actor_id: String = s.world.active_resident.resident_id
	# Check eventual output capacity before reserving materials, without mutating the bag.
	if not s.inventory.exchange(actor_id,recipe.cost,recipe.gain,false):
		production.message.emit("材料不足或背包空间不足，尚未扣除。")
		return false
	if not s.inventory.exchange(actor_id,recipe.cost,{}): return false
	jobs[station] = {"recipe":id,"name":recipe.name,"actor":actor_id,"remaining":DURATION,"gain":recipe.gain.duplicate(true)}
	return production.commit(before,"开始制作%s，需要60秒在线时间；完成后放入制作角色背包。" % recipe.name)
func collect(production: Node, station: String, actor_id: String) -> bool:
	if not jobs.has(station) or float(jobs[station].remaining)>0: return false
	var s: Node = production.session
	var before: Dictionary = s.inventory.export_data()
	var job: Dictionary = jobs[station]
	if not s.inventory.exchange(actor_id,{},job.gain):
		production.message.emit("背包已满，成品保留在工作台，腾出空间后领取。")
		return false
	jobs.erase(station)
	return production.commit(before,"已获得%s。" % job.name)
func elapse(production: Node, delta: float) -> void:
	if delta<=0: return
	for station: String in jobs.keys():
		var job: Dictionary = jobs[station]
		if float(job.remaining)<=0: continue
		job.remaining = maxf(0,float(job.remaining)-delta)
		if job.remaining>0: continue
		# Finished output is retained even when its owner's bag no longer has room.
		if not collect(production,station,str(job.actor)) and jobs.has(station):
			production.session.persistence.save_now()
func restore(data: Dictionary, recipes: Dictionary) -> void:
	jobs.clear()
	for station: String in data:
		var saved: Variant = data[station]
		if not saved is Dictionary or not recipes.has(str(saved.get("recipe",""))): continue
		var recipe: Dictionary = recipes[str(saved.recipe)]
		jobs[station] = {"recipe":str(saved.recipe),"name":recipe.name,"actor":str(saved.get("actor","ali")),"remaining":clampf(float(saved.get("remaining",DURATION)),0,DURATION),"gain":recipe.gain.duplicate(true)}
