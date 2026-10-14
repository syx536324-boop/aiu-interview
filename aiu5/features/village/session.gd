# Owns selection, proximity interactions and the prototype's water and pen state.
extends Node

signal pause_requested
signal state_changed(snapshot: Dictionary)
signal names_result(ok: bool, message: String)

const NameProfile := preload("res://features/identity/name_profile.gd")

var tribes: Node
var wildlife: Node
var world: Node2D
var interiors: Node2D
var inventory: Node
var editor: Node
var resources: Node
var harvesting: Node
var vitals: Node
var homestead: Node
var persistence: Node
var grounds: Node2D
var livestock: Node
var mining: Node
var landscape: Node
var simulation: Node
var offerings: Node
var construction: Node
var production: Node
var combat: Node
var day_night: Node
var gifts: Node
var magic: Node
var attributes_id := ""
var awakening_open := false
var profile := NameProfile.new()
var selected := 0
var water_full := false
var watered := false
var gate_open := false
var overview := false
var menu_paused := false
var torches: Node
var achievements: Node
var foraging: Node
var forest: Node
var nearest := ""
var notice := "沿沙路探索村落；靠近设施按 E 互动。"
var notice_time := 6.0
var refresh_time := 0.0
var roster_open := false

func start(village: Node2D, house_interiors: Node2D, belongings: Node, furniture_editor: Node, gathering: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = village
	interiors = house_interiors
	inventory = belongings
	editor = furniture_editor
	harvesting = gathering
	var names := profile.load_names()
	if not names.is_empty():
		world.apply_founder_names(names["male"], names["female"])
	_install_inputs()
	world.set_active(selected)
	_sync_view()

func _sync_view() -> void:
	if is_instance_valid(day_night): day_night._refresh()
	var outside: bool = world.active_resident.room_id == ""
	world.visible = outside or world.home_data(world.active_resident.room_id).get("tower",false)
	world.camera.enabled = outside
	interiors.focus(world.active_resident)
	if is_instance_valid(world.streamer): world.streamer.ensure_actor(world.active_resident)
	if outside:
		world.camera.position = world.active_resident.position
		world.camera.make_current()
	# The carried light must follow the newly controlled character within the same call,
	# so switching residents never leaves the previous character's torch burning on screen.
	if is_instance_valid(torches): torches.refresh_light()
	_refresh_nearest()

func _refresh_nearest() -> void:
	if world.active_resident.room_id == "":
		if is_instance_valid(landscape): landscape.water_target(world.active_resident.position)
		nearest = world.nearest_point(world.active_resident.position)
	else:
		nearest = str(interiors.context(world.active_resident).get("id", ""))

func rename_founders(male: String, female: String) -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	var error_message := profile.validation_error(male, female)
	if error_message != "":
		names_result.emit(false, error_message)
		return
	var error := profile.save_names(male, female)
	if error != OK:
		names_result.emit(false, "姓名未能保存，请稍后再试。")
		return
	world.apply_founder_names(male.strip_edges(), female.strip_edges())
	if is_instance_valid(persistence): persistence.save_now()
	_set_notice("两位村民的姓名已保存。")
	names_result.emit(true, "两位村民的姓名已保存。")

func _install_inputs() -> void:
	var bindings := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E], "switch_resident": [KEY_TAB],
		"overview": [KEY_M], "roster": [KEY_C], "close_roster": [KEY_ESCAPE],
		"till": [KEY_Q], "plant": [KEY_G], "inventory": [KEY_B], "furnishing": [KEY_F], "rotate_furniture": [KEY_R], "remove_furniture": [KEY_DELETE], "awaken": [KEY_R]
	}
	for i in range(mini(9, world.controllable.size())):
		bindings["resident_" + str(i + 1)] = [KEY_1 + i]
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	if overview or menu_paused or (is_instance_valid(gifts) and gifts.opened): return
	notice_time = maxf(0.0, notice_time - delta)
	refresh_time -= delta
	if refresh_time <= 0:
		refresh_time = 0.1
		_refresh_nearest()
		state_changed.emit(snapshot())

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(tribes) and not tribes.romance.ceremony.is_empty(): get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if is_instance_valid(combat) and combat.ready_for_action():
			if is_instance_valid(simulation): simulation.flush()
			combat.attack_clicked(world.active_resident.get_global_mouse_position())
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(tribes) and not tribes.romance.ceremony.is_empty(): get_viewport().set_input_as_handled(); return
	if not is_instance_valid(world) or event.is_echo() or menu_paused:
		return
	if is_instance_valid(gifts) and gifts.opened:
		if event.is_action_pressed("close_roster"): gifts.close()
		get_viewport().set_input_as_handled()
		return
	if overview:
		if event.is_action_pressed("overview") or event.is_action_pressed("close_roster"):
			overview = false
			world.set_overview(false)
			refresh_interface()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(simulation): simulation.flush()
	if is_instance_valid(production) and production.opened:
		if event.is_action_pressed("close_roster") or (event is InputEventKey and event.keycode==KEY_T and event.pressed): production.close()
		get_viewport().set_input_as_handled()
		return
	if awakening_open or attributes_id != "":
		if event.is_action_pressed("close_roster") or event.is_action_pressed("roster"):
			if awakening_open: close_awakening()
			else: close_attributes()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_T,KEY_V,KEY_J,KEY_X,KEY_Z,KEY_H,KEY_K,KEY_L,KEY_P,KEY_U] and not roster_open and not inventory.opened and not editor.opened:
		match event.keycode:
			KEY_P: magic.branches.cast(str(magic.ensure(world.active_resident.resident_id).branch_selected),world.active_resident.get_global_mouse_position())
			KEY_U: production.open_upgrade()
			KEY_T: production.open_near()
			KEY_V: production.gather_sand()
			KEY_J: combat.fire(world.active_resident.get_global_mouse_position())
			KEY_X: combat.demolish()
			KEY_Z: magic.skills.cast(2,world.active_resident.get_global_mouse_position())
			KEY_H: magic.skills.cast(3,world.active_resident.get_global_mouse_position())
			KEY_K: magic.skills.cast(4,world.active_resident.get_global_mouse_position())
			KEY_L: magic.skills.cast(5,world.active_resident.get_global_mouse_position())
	elif event.is_action_pressed("till") or event.is_action_pressed("plant"):
		if not inventory.opened and not editor.opened and not roster_open:
			if event.is_action_pressed("till"): homestead.till(world.active_resident, grounds)
			else: homestead.cultivate(world.active_resident)
			persistence.save_now()
	elif event.is_action_pressed("switch_resident"):
		var step := -1 if event is InputEventKey and event.shift_pressed else 1
		for offset in range(1, world.controllable.size() + 1):
			var target := posmod(selected + step * offset, world.controllable.size())
			if not world.controllable[target].dead:
				select_resident(target)
				break
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event.is_action_pressed("furnishing"):
		toggle_furnishing()
	elif event.is_action_pressed("roster"):
		set_roster_open(not roster_open)
	elif event.is_action_pressed("close_roster"):
		if inventory.opened:
			close_inventory()
		elif editor.opened:
			if is_instance_valid(editor.ghost):
				editor.cancel_selection()
			else:
				close_furnishing()
		elif roster_open:
			close_roster()
		else:
			pause_requested.emit()
	elif editor.opened and event.is_action_pressed("rotate_furniture"):
		editor.rotate_selected()
	elif editor.opened and event.is_action_pressed("remove_furniture"):
		editor.remove_selected()
	elif event.is_action_pressed("awaken") and not editor.opened and not roster_open and not inventory.opened:
		open_awakening()
	elif event.is_action_pressed("interact"):
		if not roster_open and not inventory.opened and not editor.opened:
			interact()
	elif event.is_action_pressed("overview"):
		if inventory.opened or editor.opened or roster_open:
			return
		elif world.active_resident.room_id != "":
			_set_notice("走到门口按 E，即可回到村落。")
		else:
			overview = not overview
			world.set_overview(overview)
			refresh_interface()
	else:
		for i in range(mini(9, world.controllable.size())):
			if event.is_action_pressed("resident_" + str(i + 1)):
				select_resident(i)
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()

func select_resident(index: int) -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	if world.controllable[clampi(index, 0, world.controllable.size() - 1)].dead:
		_set_notice("该角色已经阵亡。")
		return
	if is_instance_valid(production): production.close()
	editor.close()
	inventory.close()
	attributes_id = ""
	awakening_open = false
	selected = clampi(index, 0, world.controllable.size() - 1)
	world.set_active(selected)
	roster_open = false
	world.set_player_input_enabled(true)
	_sync_view()
	_set_notice("正在操控 " + world.active_resident.resident_name + " · " + world.active_resident.role_label)

func set_roster_open(value: bool) -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	if value:
		editor.close()
		inventory.close()
	roster_open = value
	if not value:
		attributes_id = ""
		awakening_open = false
	refresh_interface()

func close_roster() -> void:
	set_roster_open(false)

func refresh_interface() -> void:
	if not is_instance_valid(world):
		return
	world.set_player_input_enabled((not is_instance_valid(tribes) or tribes.romance.ceremony.is_empty()) and not overview and not menu_paused and not (is_instance_valid(gifts) and gifts.opened) and not roster_open and not inventory.opened and not editor.opened and attributes_id == "" and not awakening_open and (not is_instance_valid(production) or not production.opened))
	state_changed.emit(snapshot())

func toggle_inventory() -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	if inventory.opened:
		close_inventory()
	else:
		roster_open = false
		attributes_id = ""
		awakening_open = false
		editor.close()
		inventory.open_bag(world.active_resident.resident_id, world.active_resident.resident_name)
		refresh_interface()

func close_inventory() -> void:
	inventory.close()
	refresh_interface()

func toggle_furnishing() -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	if editor.opened:
		close_furnishing()
	else:
		roster_open = false
		attributes_id = ""
		awakening_open = false
		inventory.close()
		editor.open()
		refresh_interface()

func close_furnishing() -> void:
	editor.close()
	refresh_interface()

func interact() -> void:
	if overview or menu_paused: return
	if attributes_id != "" or awakening_open or (is_instance_valid(production) and production.opened): return
	if is_instance_valid(simulation): simulation.flush()
	if world.active_resident.dead: return
	_interact_impl()
	if is_instance_valid(persistence): persistence.save_now()

func _interact_impl() -> void:
	if is_instance_valid(tribes) and tribes.interact(): return
	if world.active_resident.room_id != "":
		var context: Dictionary = interiors.context(world.active_resident)
		if context.get("id", "") == "exit":
			var return_position: Vector2 = world.safe_return_position(interiors.outdoor_position(world.active_resident), world.active_resident.room_id)
			interiors.leave(world.active_resident, world.objects, return_position)
			_sync_view()
			_set_notice("已回到村落。")
		elif context.get("id", "") == "ore":
			mining.strike(world.active_resident, context.ore)
		elif context.get("id", "") == "campfire":
			magic.skills.interact_camp()
		elif context.get("id", "") == "workbench":
			production.open_near()
		elif context.get("id", "") == "stove":
			if production.is_smith(): production.open_near()
			else:
				var before: Dictionary = inventory.export_data()
				if homestead.stove(world.active_resident): production.commit(before,"灶台操作已保存。")
		elif context.get("id", "") == "storage":
			var fixture: Node2D = context["fixture"]
			inventory.open_container(world.active_resident.resident_id, world.active_resident.resident_name, fixture.fixture_id, str(world.home_data(world.active_resident.room_id)["name"]) + " · " + fixture.display_name())
			refresh_interface()
		else:
			_set_notice(str(context.get("description", "走到家具、草席或门口，按 E 互动。")))
		return
	_refresh_nearest()
	if nearest.begins_with("branch:"):
		magic.branches.interact(nearest.trim_prefix("branch:"))
		return
	if nearest.begins_with("forage:"):
		foraging.gather(nearest.trim_prefix("forage:"))
		return
	if nearest.begins_with("herb:"):
		forest.gather(nearest.trim_prefix("herb:"))
		return
	if nearest.begins_with("wood:"):
		harvesting.chop(nearest.trim_prefix("wood:"), world.active_resident)
		_refresh_nearest()
		state_changed.emit(snapshot())
		return
	if nearest.begins_with("animal:"):
		livestock.feed_animal(world.active_resident, nearest.trim_prefix("animal:"))
		return
	if nearest.begins_with("ore:"):
		mining.mine_near(world.active_resident)
		return
	var bench: Dictionary = grounds.nearby(world.active_resident)
	if not bench.is_empty() and (nearest == "" or nearest.begins_with("npc:")):
		if bench.id=="campfire": magic.skills.interact_camp()
		else: production.open_near()
		return
	var home: Dictionary = world.home_data(nearest)
	if not home.is_empty():
		if home.get("building",false): _set_notice("房屋正在施工，完成后才能进入。"); return
		if home.get("skill_hut",false) and home.get("owner","")!=world.active_resident.resident_id:
			_set_notice("这间土屋只允许施法者进入。")
			return
		overview = false
		world.set_overview(false)
		interiors.enter(world.active_resident, home)
		_sync_view()
		_set_notice("进入" + str(home["name"]) + "，回到门口按 E 出门。")
		return
	match nearest:
		"well", "lake", "river":
			homestead.fill_bucket(world.active_resident)
		"gate":
			if gate_open and not world.gate_is_clear():
				_set_notice("先离开门口，再把木门关好。")
				return
			gate_open = not gate_open
			world.set_gate_open(gate_open)
			_set_notice("木门已打开，进圈后靠近食槽按 E 喂猪。" if gate_open else "木门已关好。")
		"trough":
			livestock.feed_species(world.active_resident, "pig")
		"cow_trough":
			livestock.feed_species(world.active_resident, "cow")
		"altar_display":
			inventory.open_container(world.active_resident.resident_id, world.active_resident.resident_name, "altar:display", "祭坛")
			refresh_interface()
		"forest_altar":
			if is_instance_valid(world.forest_altar): world.forest_altar.perform()
			gifts.open_menu()
		"altar":
			# The chief priest conducts the village offering; the ritual menu opens on top of it.
			if world.active_resident.resident_id == "chief_priest" and is_instance_valid(world.altar): world.altar.perform()
			gifts.open_menu()
		_:
			if not homestead.nearby(world.active_resident).is_empty():
				homestead.water(world.active_resident)
				return
			var description: String = world.describe_point(nearest)
			_set_notice(description if description != "" else "靠近设施或村民，再按 E。")

func _set_notice(message: String) -> void:
	notice = message
	notice_time = 4.5
	state_changed.emit(snapshot())

func snapshot() -> Dictionary:
	var prompt := "自由行走 · 沙地与石堆之间有通路"
	if world.active_resident.room_id == "" and world.active_resident.position.x < 0:
		prompt = "西岸森林 · 沿林间小径探索，草药旁 E 采集"
	var crop_detail := ""
	var interaction_detail := ""
	var inside: bool = world.active_resident.room_id != ""
	if inside:
		var context: Dictionary = interiors.context(world.active_resident)
		prompt = "屋内行走 · 门口按 E 出门"
		if not context.is_empty():
			prompt = "E  " + str(context["label"]) + " · " + str(context["action"])
			interaction_detail = str(context.get("description", ""))
			if tribes.romance.clinic(world.home_data(world.active_resident.room_id)) and context.get("id", "") == "workbench":
				prompt = "E / T 草药屋 · 合成汤剂"
				interaction_detail = "大补汤：生命健康回满 · 补气汤：健康+5、生命+3"
	elif nearest != "":
		var point: Dictionary = world.point_info(nearest)
		if not point.is_empty():
			prompt = "E  " + str(point["label"]) + " · " + str(point["action"])
			if nearest.begins_with("animal:") or nearest.begins_with("ore:") or nearest.begins_with("built:"): interaction_detail = str(point.get("description", ""))
			if nearest in ["altar", "forest_altar"]:
				prompt = "E 祭台 · 存档 / 觉醒 / 赐予"
	if is_instance_valid(homestead) and not inside and (nearest == "" or nearest.begins_with("npc:")):
		var farm_context: Dictionary = homestead.nearby(world.active_resident)
		if not farm_context.is_empty():
			prompt = farm_context.label + " · " + farm_context.action
			crop_detail = farm_context.description
	if is_instance_valid(homestead) and inside and interiors.context(world.active_resident).get("id", "") == "stove":
		prompt = "E 灶台 · " + ("剩余 %d 秒" % ceili(homestead.cooking.remaining) if homestead.cooking.remaining > 0 else ("领取熟肉" if homestead.cooking.ready > 0 else "放入生猪肉"))
		prompt += " / T 冶炼铁矿"
		if production.is_smith(): prompt = "E / T 铁匠铺 · 冶炼铁矿 / 领取粗铁"
	if inside and world.home_data(world.active_resident.room_id).get("tower",false) and interiors.context(world.active_resident).get("id","")!="exit":
		prompt="箭楼顶部 · 鼠标瞄准 / J 射箭"
	if not inside and is_instance_valid(grounds) and (nearest == "" or nearest.begins_with("npc:")):
		var bench: Dictionary = grounds.nearby(world.active_resident)
		if not bench.is_empty():
			prompt = "E 建筑台 · 建造房屋 / 箭楼" if bench.id=="building_bench" else ("E 篝火 · 点亮 / 熄灭" if bench.id=="campfire" else "E 工作台 · 分类合成")
			interaction_detail = bench.description
	if is_instance_valid(vitals):
		water_full = inventory.has_item(world.active_resident.resident_id, "water_bucket")
		watered = not homestead.plots.is_empty() and not homestead.plots[0].dry
	var roster: Array = world.get_roster()
	for entry: Dictionary in roster:
		var stats: Dictionary = vitals.ensure(str(entry.id)) if is_instance_valid(vitals) else {}
		entry["vitals"] = {}
		for stat in ["life", "hunger", "thirst", "health", "mana"]:
			entry.vitals[stat] = stats.get(stat, 10)
		entry.vitals["max_life"]=vitals.max_life(str(entry.id))
		entry.vitals["max_mana"]=vitals.max_mana(str(entry.id))
		entry["frozen"] = int(entry.index) != selected
	return {
		"torch":torches.snapshot(world.active_resident.resident_id) if is_instance_valid(torches) else {},
		"gift_attributes_available":gifts.attributes_available(world.active_resident.resident_id) if is_instance_valid(gifts) else false,
		"weapon": magic.weapon_snapshot(world.active_resident.resident_id) if is_instance_valid(magic) else {},
		"day_night":day_night.snapshot() if is_instance_valid(day_night) else {},
		"menu_paused": menu_paused,
		"workshop": production.snapshot() if is_instance_valid(production) else {"open":false},
		"attributes": magic.snapshot(attributes_id) if is_instance_valid(magic) and attributes_id != "" else {"open": false},
		"awakening": {"open": awakening_open, "name": world.active_resident.resident_name,
			"available": magic.awakening_error(world.active_resident.resident_id) == "" if is_instance_valid(magic) else false},
		"offering": offerings.preview() if is_instance_valid(offerings) else {},
		"vitals": vitals.ensure(world.active_resident.resident_id).duplicate(true) if is_instance_valid(vitals) else {},
		"max_life":vitals.max_life(world.active_resident.resident_id),
		"max_mana":vitals.max_mana(world.active_resident.resident_id),
		"skill_status":magic.skills.snapshot(world.active_resident.resident_id),
		"branch_status":magic.branch_hud(world.active_resident.resident_id),
		"inventory": inventory.snapshot(), "furnishing": editor.snapshot(),
		"resident": world.active_resident.resident_name, "selected": selected,
		"inside": inside, "room_name": str(world.home_data(world.active_resident.room_id).get("name", "")), "founder_names": world.founder_names(),
		"role": world.active_resident.role_label, "roster": roster, "roster_open": roster_open,
		"population": world.residents.filter(func(a: Node)->bool:return not a.dead).size()+tribes.population.members.keys().filter(func(id: String)->bool:return tribes.population.friendly(id) and tribes.population.node(id).hp>0).size(), "npc_count": tribes.population.members.keys().filter(func(id: String)->bool:return tribes.population.friendly(id) and tribes.population.node(id).hp>0).size(), "homes": world.houses.size(),
		"biome": "西岸森林" if world.active_resident.position.x < 0 and not inside else "干旱地带",
		"water": water_full, "water_text": inventory.Catalog.Water.summary(inventory.ensure_bag(world.active_resident.resident_id)), "watered": watered, "gate_open": gate_open,
		"pregnancy":tribes.romance.hud_status(world.active_resident.resident_id) if is_instance_valid(tribes) else "", "overview": overview, "prompt": prompt, "crop_detail": crop_detail, "detail": interaction_detail if interaction_detail != "" else crop_detail, "underground": world.active_resident.room_id == "mine",
		"notice": notice if notice_time > 0 else ""
	}

func weapon_slot_clicked() -> void:
	if overview or menu_paused or roster_open or inventory.opened or editor.opened or attributes_id != "" or awakening_open or production.opened: return
	var id: String = world.active_resident.resident_id
	if not magic.weapon_snapshot(id).editable: return
	if magic.ensure(id).equipment.weapon == "": toggle_inventory()
	else: magic.equip_weapon(id, "")
	refresh_interface()

func use_selected() -> void:
	if overview or menu_paused: return
	if is_instance_valid(simulation): simulation.flush()
	var selection: Dictionary = inventory.selection.duplicate()
	if selection.get("side", "") != "bag":
		inventory._report("请先选中背包中的物品。")
		return
	var slot: Dictionary = inventory.ensure_bag(world.active_resident.resident_id)[selection.index]
	if slot.is_empty(): return
	var item: String = slot.item
	if item=="scissors":
		close_inventory(); production.open_scissors()
	elif item=="torch":
		if torches.equip(world.active_resident.resident_id,int(selection.index)): close_inventory()
	elif item in magic.Catalog.WEAPONS:
		if magic.equip_weapon(world.active_resident.resident_id,item,int(selection.index)): close_inventory()
	elif magic.Catalog.Armor.contains(item):
		show_attributes(world.active_resident.resident_id)
	elif item in ["restorative_soup", "qi_soup"]:
		forest.drink_soup(item)
		inventory.selection.clear()
		inventory.status = notice
	elif item == "bed":
		if world.active_resident.room_id == "":
			inventory._report("请先进入房屋，再部署赐予的床。")
		else:
			close_inventory()
			toggle_furnishing()
			editor.choose_gift_bed(int(selection.index))
	elif item in ["campfire","workbench", "fence", "fence_gate", "building_bench", "cabinet", "table", "chair", "chest"]:
		close_inventory()
		toggle_furnishing()
		editor.choose(item)
	elif homestead.Meat.RAW.has(item) and world.active_resident.room_id != "" and interiors.context(world.active_resident).get("id","")=="stove" and not production.is_smith():
		var before: Dictionary = inventory.export_data()
		if homestead.stove(world.active_resident,item): production.commit(before,"已提交灶台烹饪操作。")
		inventory.selection.clear()
	elif item in ["bread", "pork", "cooked_pork", "apple", "carrot", "beef", "mutton", "cooked_beef", "cooked_mutton"] or inventory.Catalog.Water.drinkable(item):
		vitals.use_food(world.active_resident.resident_id, item, int(selection.index))
		inventory.selection.clear()
		inventory.status = notice
		persistence.save_now()
	elif item in ["wheat", "rice"]:
		close_inventory()
		livestock.feed_near(world.active_resident, item)
		persistence.save_now()
	elif item == "iron_bucket":
		close_inventory()
		production.gather_sand()
	elif item == "hoe":
		close_inventory()
		homestead.till(world.active_resident, grounds)
		persistence.save_now()
	elif homestead.Crops.SEEDS.has(item):
		close_inventory()
		homestead.select_seed(world.active_resident, item)
		persistence.save_now()
	else:
		inventory._report("" + inventory.Catalog.ITEMS[item].description)
	refresh_interface()

func sacrifice_selected(target_id: String) -> void:
	if overview or menu_paused or not is_instance_valid(offerings): return
	var result: Dictionary = offerings.sacrifice(target_id)
	inventory.status = str(result.message)
	_set_notice(str(result.message))

func show_attributes(id: String) -> void:
	if overview or menu_paused or not is_instance_valid(magic) or not is_instance_valid(magic._actor(id)): return
	if is_instance_valid(simulation): simulation.flush()
	editor.close()
	inventory.close()
	roster_open = true
	attributes_id = id
	awakening_open = false
	refresh_interface()

func close_attributes() -> void:
	attributes_id = ""
	awakening_open = false
	refresh_interface()

func open_awakening() -> void:
	if overview or menu_paused or not is_instance_valid(magic): return
	if is_instance_valid(simulation): simulation.flush()
	var error: String = magic.awakening_error(world.active_resident.resident_id)
	if error != "":
		_set_notice(error)
		return
	editor.close()
	inventory.close()
	awakening_open = true
	refresh_interface()

func close_awakening() -> void:
	awakening_open = false
	refresh_interface()

func awaken_selected(element: String) -> void:
	if not awakening_open: return
	var id: String = world.active_resident.resident_id
	if magic.awaken(id, element):
		awakening_open = false
		attributes_id = id
		roster_open = true
	refresh_interface()

func equip_attribute(slot: String, item: String, bag_index := -1) -> void:
	if attributes_id != "" and not awakening_open:
		magic.equip(attributes_id, slot, item, bag_index)
		refresh_interface()

func unlock_attribute(skill: String) -> void:
	if attributes_id != "" and not awakening_open:
		magic.unlock(attributes_id, skill)
		refresh_interface()

func claim_attribute_gear() -> void:
	if attributes_id != "" and not awakening_open:
		magic.claim_gear(attributes_id)
		refresh_interface()

func select_branch(skill: String) -> void:
	if attributes_id!="": magic.select_branch(attributes_id,skill)
	refresh_interface()
func claim_crystals() -> void:
	if attributes_id!="": magic.claim_crystals(attributes_id)
	refresh_interface()
