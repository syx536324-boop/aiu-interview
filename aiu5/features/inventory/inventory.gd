# Owns per-character bags, 21-slot containers, atomic transfers and saved room layouts.
extends Node

signal changed
signal message(text: String)
const Catalog := preload("res://features/inventory/catalog.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Wear := preload("res://features/combat/durability.gd")
const Origin := preload("res://features/gifts/provenance.gd")
const Torch := preload("res://features/lighting/torch_record.gd")
var defeated := false
var save_hook: Callable
const CAPACITY := 21
var gift_events: Dictionary = {}
var bags: Dictionary = {}
var containers: Dictionary = {}
var layouts: Dictionary = {}
var resource_hits: Dictionary = {}
var grants: Dictionary = {}
var saved_session: Dictionary = {}
var session_provider: Callable
var opened := false
var actor_id := ""
var actor_name := ""
var container_id := ""
var container_name := ""
var selection: Dictionary = {}
var status := ""
var path := "user://village_inventory.json"

func start() -> void:
	var override_path := OS.get_environment("AIU5_STATE_PATH")
	if override_path != "":
		path = override_path
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version", 0)) not in [1, 2]:
		message.emit("未能读取物品与家具存档。")
		return
	gift_events = data.get("gift_events", {}).duplicate(true)
	grants = data.get("grants", {}).duplicate(true)
	saved_session = data.get("session", {}).duplicate(true)
	for key: String in ["bags", "containers"]:
		var source: Variant = data.get(key, {})
		if source is Dictionary:
			for id: String in source:
				var slots: Array = _sanitize_slots(source[id],9 if id.begins_with("npc:") else CAPACITY)
				if key == "bags":
					bags[id] = slots
				else:
					containers[id] = slots
	var saved_layouts: Variant = data.get("rooms", {})
	if saved_layouts is Dictionary:
		layouts = saved_layouts.duplicate(true)
	var resources: Variant = data.get("harvesting", {})
	if resources is Dictionary:
		for id: String in resources:
			if resources[id] is int or resources[id] is float:
				resource_hits[id] = clampi(int(resources[id]), 0, 4)

func has_item(id: String, item: String) -> bool:
	for slot: Dictionary in ensure_bag(id):
		if slot.get("item", "") == item and int(slot.get("count", 0)) > 0:
			return true
	return false

func commit_resource_reward(actor: String, resource: String, progress: int, item: String, quantity: int) -> Dictionary:
	var bag := ensure_bag(actor)
	var previous_bag := bag.duplicate(true)
	var remaining := quantity
	for empty_pass in [false, true]:
		for i in range(bag.size()):
			if remaining == 0:
				break
			var slot: Dictionary = bag[i]
			if empty_pass and slot.is_empty():
				var count := mini(remaining, int(Catalog.ITEMS[item]["limit"]))
				bag[i] = {"item": item, "count": count}
				if item in Gear.WEAPONS: bag[i].merge(Wear.normalize())
				if item=="torch": bag[i].merge(Torch.normalize())
				remaining -= count
			elif not empty_pass and slot.get("item", "") == item and not Origin.magical(slot):
				var count := mini(remaining, int(Catalog.ITEMS[item]["limit"]) - int(slot["count"]))
				slot["count"] += count
				remaining -= count
	if remaining > 0:
		bags[actor] = previous_bag
		return {"ok": false, "reason": "full"}
	var previous_progress := int(resource_hits.get(resource, 0))
	resource_hits[resource] = progress
	if save_state() != OK:
		bags[actor] = previous_bag
		resource_hits[resource] = previous_progress
		return {"ok": false, "reason": "save"}
	changed.emit()
	return {"ok": true}

func _sanitize_slots(data: Variant, capacity := CAPACITY) -> Array:
	var result: Array = []
	for i in range(capacity):
		var slot: Variant = data[i] if data is Array and i < data.size() else {}
		if slot is Dictionary and slot.get("item", "") == "wood_axe":
			slot = slot.duplicate()
			slot.item = "stone_axe"
		if slot is Dictionary:
			slot = slot.duplicate(true)
			if slot.get("item","")=="scissors" and Origin.magical(slot): slot.item="magic_scissors"
			slot.item = Catalog.canonical(str(slot.get("item","")))
		if slot is Dictionary and Catalog.ITEMS.has(str(slot.get("item", ""))) and int(slot.get("count", 0)) > 0:
			var id := str(slot["item"])
			var clean := {"item": id, "count": mini(int(slot["count"]), int(Catalog.ITEMS[id]["limit"]))}
			clean.merge(Origin.fields(slot))
			if Origin.magical(clean): clean.count = 1
			if id in Gear.WEAPONS: clean.merge(Wear.normalize(slot))
			if id=="torch": clean.merge(Torch.normalize(slot))
			result.append(clean)
		else:
			result.append({})
	return result

func ensure_bag(id: String) -> Array:
	if not bags.has(id):
		bags[id] = _sanitize_slots([] if id.begins_with("npc:") else Catalog.starter_slots(),9 if id.begins_with("npc:") else CAPACITY)
	return bags[id]

func ensure_container(id: String) -> Array:
	if id.begins_with("npc:"): return ensure_bag(id)
	if not containers.has(id):
		containers[id] = _sanitize_slots([])
	return containers[id]

func open_bag(id: String, display_name: String) -> void:
	status = ""
	actor_id = id
	actor_name = display_name
	ensure_bag(id)
	container_id = ""
	selection.clear()
	opened = true
	changed.emit()

func open_container(id: String, display_name: String, storage_id: String, storage_name: String) -> void:
	open_bag(id, display_name)
	container_id = storage_id
	container_name = storage_name
	ensure_container(storage_id)
	changed.emit()

func close() -> void:
	opened = false
	container_id = ""
	selection.clear()
	changed.emit()

func slots_for(side: String) -> Array:
	if side == "bag":
		return ensure_bag(actor_id)
	if side == "storage" and container_id != "":
		return ensure_container(container_id)
	return []

func slot_clicked(side: String, index: int, quick := false) -> void:
	if not opened or index < 0 or index >= CAPACITY:
		return
	status = ""
	var slots := slots_for(side)
	if slots.is_empty() or index>=slots.size():
		return
	if quick and container_id != "":
		quick_transfer(side, index)
		return
	if selection.is_empty():
		if not slots[index].is_empty():
			selection = {"side": side, "index": index}
	else:
		var source := slots_for(selection["side"])
		var source_index := int(selection["index"])
		if side != selection["side"] or index != source_index:
			transfer_slots(source, source_index, slots, index)
			_save_and_notify()
		selection.clear()
	changed.emit()

func transfer_slots(source: Array, source_index: int, target: Array, target_index: int) -> void:
	var from: Dictionary = source[source_index]
	var to: Dictionary = target[target_index]
	if from.is_empty():
		return
	if not to.is_empty() and from["item"] == to["item"] and from.item not in Gear.WEAPONS and from.item!="torch" and not Origin.magical(from) and not Origin.magical(to):
		var room := int(Catalog.ITEMS[from["item"]]["limit"]) - int(to["count"])
		var count := mini(room, int(from["count"]))
		to["count"] += count
		from["count"] -= count
		if from["count"] == 0:
			source[source_index] = {}
	else:
		target[target_index] = from
		source[source_index] = to

func quick_transfer(side: String, index: int) -> void:
	status = ""
	var source := slots_for(side)
	var target := slots_for("storage" if side == "bag" else "bag")
	if target.is_empty() or index<0 or index>=source.size() or source[index].is_empty():
		return
	var original := int(source[index]["count"])
	var remaining := original
	var id := str(source[index]["item"])
	if id in Gear.WEAPONS or id=="torch" or Origin.magical(source[index]):
		for i in range(target.size()):
			if target[i].is_empty():
				target[i] = source[index]
				source[index] = {}
				selection.clear()
				_save_and_notify()
				return
		_report("目标的21格已满，武器仍保留在原处。")
		return
	# Merge matching stacks first, then use empty slots; never overwrite another item.
	for empty_pass in [false, true]:
		for i in range(target.size()):
			if remaining == 0:
				break
			var slot: Dictionary = target[i]
			if empty_pass and slot.is_empty():
				var count := mini(remaining, int(Catalog.ITEMS[id]["limit"]))
				target[i] = {"item": id, "count": count}
				remaining -= count
			elif not empty_pass and slot.get("item", "") == id and not Origin.magical(slot):
				var count := mini(remaining, int(Catalog.ITEMS[id]["limit"]) - int(slot["count"]))
				slot["count"] += count
				remaining -= count
	if remaining == 0:
		source[index] = {}
	else:
		source[index]["count"] = remaining
	selection.clear()
	if remaining == original:
		_report("目标的 21 格已满，物品仍保留在原处。")
	else:
		_save_and_notify()
		if remaining > 0:
			_report("目标空间不足，剩余物品仍保留在原处。")
	changed.emit()

func container_empty(id: String) -> bool:
	for slot: Dictionary in ensure_container(id):
		if not slot.is_empty():
			return false
	return true

func store_layout(room_id: String, records: Array) -> void:
	layouts[room_id] = records.duplicate(true)
	_save_and_notify()

func _save_and_notify() -> void:
	if save_state() != OK:
		_report("本次修改尚未写入存档，请检查磁盘后重试。")
	changed.emit()

func _report(text: String) -> void:
	status = text
	message.emit(text)

func save_state() -> Error:
	if defeated: return ERR_UNAVAILABLE
	if save_hook.is_valid(): return save_hook.call(path)
	return write_file(path, export_data())

func write_file(target: String, data: Dictionary) -> Error:
	var full_path := ProjectSettings.globalize_path(target)
	var error := DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	if error != OK:
		return error
	var file := FileAccess.open(full_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(full_path + ".tmp", full_path)

func snapshot() -> Dictionary:
	return {"open": opened, "actor": actor_name, "container_id": container_id, "container_name": container_name,
		"bag": ensure_bag(actor_id).duplicate(true) if actor_id != "" else [],
		"storage": ensure_container(container_id).duplicate(true) if container_id != "" else [], "selection": selection.duplicate(), "status": status}

func exchange(id: String, costs: Dictionary, rewards: Dictionary, apply := true, ordinary_costs_only := false) -> bool:
	# Apply to a copy so missing ingredients or insufficient space never lose items.
	var bag: Array = ensure_bag(id).duplicate(true)
	for item: String in costs:
		var remaining := int(costs[item])
		for i in range(bag.size()):
			if bag[i].get("item", "") != item: continue
			if ordinary_costs_only and Origin.magical(bag[i]): continue
			var used := mini(remaining, int(bag[i].count))
			bag[i].count -= used
			remaining -= used
			if bag[i].count <= 0: bag[i] = {}
		if remaining > 0: return false
	for item: String in rewards:
		var remaining := int(rewards[item])
		for empty_pass in [false, true]:
			for i in range(bag.size()):
				if remaining <= 0: break
				var slot: Dictionary = bag[i]
				if empty_pass and slot.is_empty():
					var count := mini(remaining, int(Catalog.ITEMS[item].limit))
					bag[i] = {"item": item, "count": count}
					if item in Gear.WEAPONS: bag[i].merge(Wear.normalize())
					if item=="torch": bag[i].merge(Torch.normalize())
					remaining -= count
				elif not empty_pass and slot.get("item", "") == item and not Origin.magical(slot):
					var count := mini(remaining, int(Catalog.ITEMS[item].limit) - int(slot.count))
					slot.count += count
					remaining -= count
		if remaining > 0: return false
	if apply:
		bags[id] = bag
		changed.emit()
	return true

func swap_weapon(id: String, incoming: String, outgoing: String, wear: Dictionary, selected := -1) -> Dictionary:
	# Move the actual unstackable record, never recreate a used weapon from its item ID.
	var bag := ensure_bag(id).duplicate(true)
	var result := {"ok":false}
	var next_wear := Wear.normalize()
	if incoming != "":
		var index := selected
		if index < 0:
			for i in range(bag.size()):
				if bag[i].get("item","")==incoming: index=i; break
		if index < 0 or index >= bag.size() or bag[index].get("item","") != incoming: return result
		if incoming=="magic_scissors" and not Origin.magical(bag[index]): return result
		next_wear = Wear.normalize(bag[index])
		bag[index] = {}
	if outgoing != "":
		var index := -1
		for i in range(bag.size()):
			if bag[i].is_empty(): index=i; break
		if index < 0: return result
		bag[index] = {"item":outgoing,"count":1}
		bag[index].merge(Wear.normalize(wear))
	bags[id] = bag
	changed.emit()
	return {"ok":true,"wear":next_wear}

func grant_supplies(id: String) -> void:
	var supplied: Dictionary = grants.get(id, {})
	var supplies: Dictionary = Catalog.STARTING
	for item: String in supplies:
		if supplied.has(item): continue
		var amount: int = supplies[item]
		if exchange(id, {}, {item: amount}): supplied[item] = true
	grants[id] = supplied

func export_data() -> Dictionary:
	var session: Dictionary = session_provider.call() if session_provider.is_valid() else saved_session
	return {"version": 2, "gift_events":gift_events.duplicate(true), "bags": bags.duplicate(true), "containers": containers.duplicate(true), "rooms": layouts.duplicate(true),
		"harvesting": resource_hits.duplicate(), "grants": grants.duplicate(true), "session": session}

func apply_data(data: Dictionary) -> void:
	bags.clear()
	containers.clear()
	for id: String in data.get("bags", {}): bags[id] = _sanitize_slots(data.bags[id],9 if id.begins_with("npc:") else CAPACITY)
	for id: String in data.get("containers", {}): containers[id] = _sanitize_slots(data.containers[id])
	layouts = data.get("rooms", {}).duplicate(true)
	resource_hits = data.get("harvesting", {}).duplicate()
	gift_events = data.get("gift_events", {}).duplicate(true)
	grants = data.get("grants", {}).duplicate(true)
	saved_session = data.get("session", {}).duplicate(true)
	selection.clear()

func insert_record(id: String, data: Dictionary) -> bool:
	var bag := ensure_bag(id)
	var record: Dictionary = _sanitize_slots([data])[0]
	if record.is_empty(): return false
	for i in range(bag.size()):
		if bag[i].is_empty():
			bag[i] = record
			return true
	return false

func transform_record(id: String, index: int, incoming: String) -> bool:
	var bag := ensure_bag(id)
	if index < 0 or index >= bag.size() or bag[index].is_empty() or not Catalog.ITEMS.has(incoming): return false
	bag[index].item = incoming
	return true

func swap_armor(id: String, incoming: String, outgoing: Dictionary, selected := -1) -> Dictionary:
	var bag: Array = ensure_bag(id).duplicate(true)
	var record: Dictionary = {}
	if incoming != "":
		var index := selected
		if index < 0:
			for i in range(bag.size()):
				if bag[i].get("item", "") == incoming: index = i; break
		if index < 0 or index >= bag.size() or bag[index].get("item", "") != incoming: return {"ok":false}
		record = bag[index].duplicate(true)
		bag[index] = {}
	if not outgoing.is_empty():
		var index := -1
		for i in range(bag.size()):
			if bag[i].is_empty(): index = i; break
		if index < 0: return {"ok":false}
		bag[index] = outgoing.duplicate(true)
	bags[id] = bag
	return {"ok":true,"record":record}
