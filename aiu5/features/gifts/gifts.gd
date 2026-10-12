# Owns altar gift sessions and atomic, deduplicated rewards; camera results never mutate saves alone.
extends Node
signal changed(state: Dictionary)
const Mapping := preload("res://features/gifts/mapping.gd")
const Origin := preload("res://features/gifts/provenance.gd")
var session: Node
var camera: Node
var opened := false
var mode := "altar"
var actor_id := ""
var session_id := ""
var feedback := ""
var frozen := false
var candidates: Array = []
var received_at := 0
var received := false
var sequence := 0
var selected := ""
var frame_jpeg := ""
var device := ""
var was_paused := false

func start(controller: Node, bridge: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = controller
	camera = bridge
	camera.updated.connect(accept_snapshot)

func available() -> bool:
	if not is_instance_valid(session) or session.overview or session.menu_paused: return false
	var actor: Node2D = session.world.active_resident
	if actor.dead or actor.room_id != "": return false
	for id: String in ["altar", "forest_altar"]:
		var point: Dictionary = session.world.point_info(id)
		if not point.is_empty() and actor.position.distance_to(point.position) <= float(point.radius): return true
	return false

func open_menu() -> bool:
	if opened: return false
	if not available():
		session._set_notice("请先到祭台正面，再选择赐予。")
		return false
	if not session.persistence.ready_to_save or session.persistence.restoring or session.persistence.restore_queued: return false
	session.simulation.flush()
	session.inventory.close()
	session.editor.close()
	session.roster_open = false
	session.attributes_id = ""
	session.awakening_open = false
	actor_id = session.world.active_resident.resident_id
	opened = true
	mode = "altar"
	feedback = "选择祭台仪式。"
	was_paused = get_tree().paused
	get_tree().paused = true
	session.refresh_interface()
	_emit()
	return true

func begin_camera() -> void:
	if not opened or mode != "altar": return
	mode = "camera"
	session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	feedback = "正在加载首版模型与摄像头…"
	frame_jpeg = ""
	candidates.clear()
	selected = ""
	sequence = 0
	received = false
	frozen = false
	camera.open(session_id)
	_emit()

func save_altar() -> void:
	if opened and mode == "altar":
		feedback = "祭台存档已保存。" if session.persistence.save_checkpoint() else "存档失败，请重试。"
		_emit()

func awaken() -> void:
	if not opened or mode != "altar": return
	close()
	session.open_awakening()

func accept_snapshot(data: Dictionary) -> void:
	if not opened or mode != "camera" or str(data.get("session_id", "")) != session_id: return
	if data.get("status", "") == "error":
		feedback = str(data.get("message", "摄像头连接失败。"))
		candidates.clear()
		selected = ""
		frame_jpeg = ""
		received = false
		_emit()
		return
	if frozen: return
	if data.get("status", "") != "ready": return
	var next_sequence := int(data.get("sequence", 0))
	if next_sequence <= sequence: return
	sequence = next_sequence
	received_at = Time.get_ticks_msec()
	received = true
	frame_jpeg = str(data.get("frame_jpeg", ""))
	device = str(data.get("device", ""))
	candidates.clear()
	for candidate: Dictionary in data.get("candidates", []):
		var index := int(candidate.get("class_id", -1))
		if Mapping.reward(index).is_empty(): continue
		if candidate.get("class_name", "") != Mapping.NAMES[index] or float(candidate.get("confidence", 0)) < 0.45: continue
		if not bool(candidate.get("stable", false)): continue
		var entry := candidate.duplicate(true)
		entry.merge(Mapping.reward(index), true)
		candidates.append(entry)
	feedback = "请保持物品稳定，再点击“定格选择”。" if not candidates.is_empty() else "尚无稳定候选，请调整距离、角度或光线。"
	_emit()

func freeze_frame() -> void:
	if not opened or mode != "camera": return
	if frozen:
		frozen = false
		selected = ""
		feedback = "继续识别，请重新定格选择。"
	elif not received or Time.get_ticks_msec()-received_at > 2000 or candidates.is_empty():
		feedback = "当前没有新鲜的稳定识别结果。"
	else:
		frozen = true
		feedback = "选择一个物品，确认后赐予1件；每次仪式只赐予一次。"
	_emit()

func select_candidate(id: String) -> void:
	if not frozen: return
	for candidate: Dictionary in candidates:
		if str(candidate.id) == id:
			selected = id
			_emit()
			return

func confirm() -> bool:
	if not opened or mode != "camera" or not frozen or selected == "": return false
	if not available() or actor_id != session.world.active_resident.resident_id: return _reject("角色或祭台位置已改变，请重新开启仪式。")
	if not received or Time.get_ticks_msec()-received_at > 30000: return _reject("定格结果超过30秒，请继续识别并重新选择。")
	var chosen: Dictionary = {}
	for candidate: Dictionary in candidates:
		if str(candidate.id) == selected: chosen = candidate; break
	if chosen.is_empty(): return false
	var event_id := session_id + ":" + selected
	if session.inventory.gift_events.has(event_id): return _reject("这次赐予已经完成。")
	var before: Dictionary = session.inventory.export_data()
	var record := {"item":str(chosen.item), "count":1}
	record.merge(Origin.gifted(event_id))
	if chosen.kind == "animal":
		if not session.livestock.gift_animal(str(chosen.item), record): return _reject("村庄动物数量已达上限，请稍后再试。")
	elif not session.inventory.insert_record(actor_id, record): return _reject("背包已满，请腾出1格后重试；尚未赐予。")
	session.inventory.gift_events[event_id] = {"class_id":int(chosen.class_id), "actor":actor_id}
	if not session.persistence.save_now():
		session.inventory.apply_data(before)
		session.persistence.restore_session(before.session)
		get_tree().paused = true
		return _reject("存档失败，赐予已撤销，请重试。")
	var text := "已赐予%s×1，带有魔法标记，属性待定。" % chosen.name
	close()
	session._set_notice(text)
	return true

func _reject(text: String) -> bool:
	feedback = text
	_emit()
	return false

func close() -> void:
	if not opened: return
	camera.close()
	opened = false
	candidates.clear()
	selected = ""
	session_id = ""
	frame_jpeg = ""
	get_tree().paused = was_paused
	session.refresh_interface()
	_emit()

func _emit() -> void:
	changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"open":opened,"mode":mode,"feedback":feedback,"frame_jpeg":frame_jpeg,"frozen":frozen,"selected":selected,"candidates":candidates.duplicate(true),"device":device}

func _process(_delta: float) -> void:
	if opened and mode == "camera" and received and Time.get_ticks_msec()-received_at > (30000 if frozen else 2000):
		received = false
		selected = ""
		candidates.clear()
		feedback = "识别结果已过期，请继续识别或关闭后重试。"
		_emit()

func _exit_tree() -> void:
	if opened:
		camera.close()
		get_tree().paused = was_paused
