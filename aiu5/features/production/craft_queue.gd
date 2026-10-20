# Owns paid per-station parallel jobs, retained outputs and legacy single-job save migration.
extends RefCounted
const DURATION := 60.0
var jobs: Dictionary = {}
var next_id := 0

func queue(station: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if jobs.has(station):
		result.append(jobs[station])
		for job: Dictionary in jobs[station].get("parallel",[]): result.append(job)
	return result

func start(production: Node, station: String, id: String, recipe: Dictionary) -> bool:
	if queue(station).size()>=production.craft_capacity():
		production.message.emit("这张工作台的制作位已满，请等待完成或先领取暂存成品。")
		return false
	var s: Node=production.session
	var before: Dictionary=s.inventory.export_data()
	var actor_id: String=s.world.active_resident.resident_id
	if not s.inventory.exchange(actor_id,recipe.cost,recipe.gain,false):
		production.message.emit("材料不足或背包空间不足，尚未扣除。")
		return false
	if not s.inventory.exchange(actor_id,recipe.cost,{}): return false
	var duration: float=production.craft_duration()
	var job := {"id":next_id,"recipe":id,"name":recipe.name,"actor":actor_id,"remaining":duration,"duration":duration,"gain":recipe.gain.duplicate(true)}
	next_id+=1
	if not jobs.has(station): jobs[station]=job
	else:
		if not jobs[station].has("parallel"): jobs[station].parallel=[]
		jobs[station].parallel.append(job)
	return production.commit(before,"开始制作%s，需要%.0f秒在线时间；本台%d/%d制作位。" % [recipe.name,duration,queue(station).size(),production.craft_capacity()])

func _remove(station: String, id: int) -> void:
	var remaining: Array[Dictionary]=[]
	for entry: Dictionary in queue(station):
		if int(entry.id)==id: continue
		var copy: Dictionary=entry.duplicate(true);copy.erase("parallel");remaining.append(copy)
	if remaining.is_empty(): jobs.erase(station);return
	var first: Dictionary=remaining.pop_front()
	if not remaining.is_empty(): first.parallel=remaining
	jobs[station]=first

func collect(production: Node, station: String, actor_id: String, job_id := -1) -> bool:
	var job: Dictionary={}
	for candidate: Dictionary in queue(station):
		if float(candidate.remaining)<=0 and (job_id<0 or int(candidate.id)==job_id):job=candidate;break
	if job.is_empty(): return false
	var s: Node=production.session
	var before: Dictionary=s.inventory.export_data()
	if not s.inventory.exchange(actor_id,{},job.gain):
		production.message.emit("背包已满，成品保留在工作台，腾出空间后领取。")
		return false
	_remove(station,int(job.id))
	production.craft_completed.emit(str(job.recipe),actor_id)
	return production.commit(before,"已获得%s。" % job.name)

func elapse(production: Node, delta: float) -> void:
	if delta<=0: return
	for station: String in jobs.keys():
		# Advance every slot before delivery can promote a parallel job or restore a failed transaction.
		var ready: Array[int]=[]
		for job: Dictionary in queue(station):
			if float(job.remaining)<=0: continue
			job.remaining=maxf(0,float(job.remaining)-delta)
			if float(job.remaining)==0: ready.append(int(job.id))
		for id: int in ready:
			var owner := ""
			for current: Dictionary in queue(station):
				if int(current.id)==id:owner=str(current.actor);break
			if owner!="" and not collect(production,station,owner,id): production.session.persistence.save_now()

func restore(data: Dictionary, recipes: Dictionary, serial := 0) -> void:
	jobs.clear();next_id=maxi(0,serial)
	var used: Dictionary={}
	for station: String in data:
		var saved: Variant=data[station]
		if not saved is Dictionary: continue
		var source: Array=[saved]
		if saved.get("parallel",[]) is Array: source.append_array(saved.get("parallel",[]))
		var valid: Array[Dictionary]=[]
		for entry: Variant in source:
			if not entry is Dictionary or not recipes.has(str(entry.get("recipe",""))) or valid.size()>=3: continue
			var recipe: Dictionary=recipes[str(entry.recipe)]
			var duration: float=clampf(float(entry.get("duration",DURATION)),30,DURATION)
			var id: int=int(entry.get("id",-1))
			if id<0 or used.has(id):id=next_id
			used[id]=true;next_id=maxi(next_id,id+1)
			valid.append({"id":id,"recipe":str(entry.recipe),"name":recipe.name,"actor":str(entry.get("actor","ali")),"remaining":clampf(float(entry.get("remaining",duration)),0,duration),"duration":duration,"gain":recipe.gain.duplicate(true)})
		if valid.is_empty(): continue
		var first: Dictionary=valid.pop_front()
		if not valid.is_empty():first.parallel=valid
		jobs[station]=first
