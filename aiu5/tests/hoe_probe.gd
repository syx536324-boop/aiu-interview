# Exercises actual inventory/equip and Q-only cultivation inputs, foot-cell farming, wear, combat and transactional persistence.
extends Node
const Categories := preload("res://features/inventory/categories.gd")
var game: Node
var s: Node
var directory: String
var checks:=0
var failures: Array[String]=[]
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label); push_error(label)
		if is_instance_valid(s):
			var debug:=FileAccess.open(directory+"/diagnostics.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists(directory+"/diagnostics.jsonl") else FileAccess.WRITE)
			debug.seek_end(); debug.store_line(JSON.stringify({"label":label,"at":[s.world.active_resident.position.x,s.world.active_resident.position.y],"room":s.world.active_resident.room_id,"nearest":s.nearest,"notice":s.notice,"inventory_open":s.inventory.opened,"production_open":s.production.opened,"mode":s.production.mode,"dialog":s.tribes.dialog_kind,"weapon":s.magic.ensure(s.world.active_resident.resident_id).equipment.weapon})); debug.close()
func frames(n:=3) -> void:
	for i in range(n): await get_tree().process_frame
func key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		Input.parse_input_event(event); await frames(5 if pressed else 2)
func click(button: Button) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=get_viewport().get_final_transform()*button.get_global_rect().get_center(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event); await frames(5 if pressed else 2)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames(5)
	s=game.get_node("Session"); s.persistence.set_process(false); s.simulation.set_process(false); s.world.streamer.set_process(false); s.resources.set_process(false)
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,Vector2(600,500))
	s._sync_view(); s.refresh_interface()
func move(at: Vector2) -> void:
	s.world.active_resident.position=at; s._sync_view(); s.refresh_interface()
func spot(negative:=false) -> Vector2:
	var actor: Node=s.world.active_resident
	for y in range(400,1600,32):
		for x in (range(-900,-300,32) if negative else range(520,1800,32)):
			actor.position=Vector2(x+5,y+7); s._refresh_nearest()
			if s.nearest!="" or not s.grounds.nearby(actor).is_empty(): continue
			if s.world.residents.any(func(other: Node)->bool:return other!=actor and other.room_id=="" and other.position.distance_to(actor.position)<64): continue
			var near_npc:=false
			for npc_id: String in s.tribes.population.members:
				var other: Node=s.tribes.population.node(npc_id)
				if is_instance_valid(other) and other.room_id=="" and other.position.distance_to(actor.position)<64: near_npc=true; break
			if near_npc: continue
			if s.homestead.standing_plot(actor): continue
			if s.grounds.land_error(s.homestead.till_bounds(actor),actor,false)=="": return actor.position
	return Vector2.INF
func wear() -> Dictionary: return s.magic.ensure(s.world.active_resident.resident_id).weapon_wear
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(); get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="": get_tree().quit(2); return
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json"); OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg"); OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	await load_game()
	var actor: Node=s.world.active_resident; var id: String=actor.resident_id
	var bag: Array=[]
	bag.append({"item":"hoe","count":1})
	for i in range(20): bag.append({})
	s.inventory.bags[id]=s.inventory._sanitize_slots(bag)
	check(s.inventory.bags[id][0].durability==40 and s.inventory.bags[id][0].uses==0,"legacy hoe gains full weapon wear without duplicating the item")
	check(s.inventory.Gear.WEAPONS.has("hoe") and Categories.group("hoe")=="weapon","hoe is a weapon in equipment and inventory categories")
	var at:=spot(); check(at.is_finite(),"valid isolated farmland location exists")
	if not at.is_finite(): get_tree().quit(1); return
	move(at); await frames()
	var total: int=s.homestead.plots.size()
	await key(KEY_Q)
	check(s.homestead.plots.size()==total,"carrying an unequipped hoe does not cultivate with Q")
	await key(KEY_B)
	var ui: Node=game.get_node("Belongings")
	check(s.inventory.opened,"B opens the real inventory")
	await click(ui.bag_buttons[0])
	check(ui.use_button.text=="装备武器" and not ui.use_button.disabled,"selected hoe offers an explicit equip weapon button")
	await screenshot("hoe-inventory")
	await click(ui.use_button)
	check(not s.inventory.opened and s.magic.ensure(id).equipment.weapon=="hoe" and not s.inventory.ensure_bag(id).any(func(slot: Dictionary)->bool:return slot.get("item","")=="hoe"),"actual UI equips the selected hoe rather than tilling or cloning it")
	check(game.get_node("HUD").weapon_icon.item=="hoe","weapon HUD displays equipped hoe")
	check(game.get_node("HUD").weapon_button.tooltip_text.contains("Q开垦脚下土地") and not game.get_node("HUD").weapon_button.tooltip_text.contains("E采集"),"equipped hoe tooltip uses Q rather than E gathering")
	check(s.snapshot().prompt.begins_with("Q 开垦脚下"),"empty-land interaction hint explains foot-cell cultivation")
	total=s.homestead.plots.size(); var idle_wear:=wear().duplicate(true)
	await key(KEY_E)
	check(s.homestead.plots.size()==total and wear()==idle_wear,"E on empty land preserves ordinary interaction and never cultivates")
	for facing in range(4):
		at=spot(); move(at); actor.facing=facing; total=s.homestead.plots.size(); var before: int=wear().uses
		await key(KEY_Q)
		check(s.homestead.plots.size()==total+1,"real Q cultivates once for facing "+str(facing))
		var plot: Dictionary=s.homestead.plots.back(); var rect: Rect2=s.homestead.Land.bounds(plot)
		check(rect.has_point(at) and rect.size==Vector2(16,16),"tilled cell contains the feet rather than following facing")
		check(wear().uses==before+1,"one successful cultivation costs exactly one wear use")
	# Adjacent existing fields must not divert the hoe to watering a different cell.
	at=spot(); move(at); await key(KEY_Q)
	var neighbor:=at+Vector2(16,0); move(neighbor); total=s.homestead.plots.size()
	check(s.grounds.land_error(s.homestead.till_bounds(actor),actor,false)=="","adjacent free soil is valid")
	await key(KEY_Q)
	check(s.homestead.plots.size()==total+1 and s.homestead.Land.bounds(s.homestead.plots.back()).has_point(neighbor),"Q expands a field beneath the feet even beside an existing field")
	var index: int=s.homestead.plots.size()-1; total=s.homestead.plots.size(); var previous: Dictionary=wear().duplicate(true)
	await key(KEY_Q)
	check(s.homestead.plots.size()==total and wear()==previous,"Q on existing soil neither duplicates it nor consumes hoe wear")
	s.inventory.exchange(id,{}, {"water_bucket":1}); await key(KEY_E)
	check(s.homestead.plots.size()==total and not s.homestead.plots[index].dry,"E on an existing field still irrigates instead of duplicating it")
	check(wear()==previous,"watering does not consume hoe durability")
	at=spot(); move(at); total=s.homestead.plots.size(); await key(KEY_Q)
	check(s.homestead.plots.size()==total+1 and s.homestead.Land.bounds(s.homestead.plots.back()).has_point(at),"Q tills another foot cell with the equipped hoe")
	at=spot(true); check(at.is_finite(),"negative forest coordinate farm location exists")
	move(at); await key(KEY_Q)
	check(s.homestead.Land.bounds(s.homestead.plots.back()).has_point(at),"negative forest coordinates use floor rather than rounding into a neighbor")
	# An invalid target never consumes the tool.
	move(s.homestead.Land.LAKE.get_center()); total=s.homestead.plots.size(); previous=wear().duplicate(true)
	check(not s.homestead.till(actor,s.grounds) and s.homestead.plots.size()==total and wear()==previous,"lake and protected land cannot be tilled and do not wear the hoe")
	at=spot(); move(at); total=s.homestead.plots.size(); s.overview=true; await key(KEY_Q); s.overview=false
	check(s.homestead.plots.size()==total,"Q cannot cultivate while overview is open")
	s.menu_paused=true; await key(KEY_Q); s.menu_paused=false
	check(s.homestead.plots.size()==total,"Q cannot cultivate while game is paused")
	await key(KEY_B); await key(KEY_Q)
	check(s.inventory.opened and s.homestead.plots.size()==total,"Q cannot cultivate while inventory is open")
	s.close_inventory()
	# Door and workbench interactions still work while the hoe is equipped.
	s.interiors.enter(actor,s.world.home_data("kitchen")); s._sync_view(); total=s.homestead.plots.size()
	check(not s.homestead.till(actor,s.grounds) and s.homestead.plots.size()==total,"indoor tilling is rejected")
	actor.position=s.interiors.rooms.kitchen.exit_point(); s._sync_view(); await key(KEY_E)
	check(actor.room_id=="" and s.homestead.plots.size()==total,"E exits a house normally while holding the hoe")
	var bench: Node
	for fixture: Node in s.grounds.fixtures:
		if fixture.kind=="workbench": bench=fixture; break
	var bounds: Rect2=bench.collision_bounds(); move(Vector2(bounds.get_center().x,bounds.end.y+11)); await key(KEY_E)
	check(s.production.opened and s.production.fixture==bench,"nearby workbench retains E interaction priority")
	s.production.close()
	# Last-use and failed-save rules share the weapon transaction, rather than silently losing plots or wear.
	move(spot()); wear().durability=1; wear().uses=14; total=s.homestead.plots.size()
	check(s.homestead.till(actor,s.grounds) and wear().durability==0 and s.homestead.plots.size()==total+1,"final durability use still cultivates successfully")
	move(spot()); total=s.homestead.plots.size()
	check(not s.homestead.till(actor,s.grounds) and s.homestead.plots.size()==total,"broken hoe cannot cultivate")
	# Broken hoes follow the smith's exact-instance repair transaction.
	wear().merge(s.inventory.Origin.gifted("hoe-repair-origin")); previous=wear().duplicate(true)
	s.inventory.exchange(id,{}, {"stone":1})
	s.interiors.enter(actor,s.world.home_data("blacksmith")); s._sync_view()
	for fixture: Node in s.interiors.rooms.blacksmith.fixtures:
		if fixture.kind=="stove":
			var smith_bounds: Rect2=fixture.collision_bounds(); actor.position=Vector2(smith_bounds.get_center().x,smith_bounds.end.y+8); break
	s.production.open_near()
	check(s.production.Repairs.options(s).any(func(option: Dictionary)->bool:return option.id=="repair:equipped" and option.enabled),"smith offers repair for the equipped broken hoe")
	check(s.production.perform("repair:equipped") and wear().durability==40 and wear().uses==0 and not s.inventory.has_item(id,"stone"),"smith restores the hoe using exactly one stone")
	check(s.inventory.Origin.fields(wear())==s.inventory.Origin.fields(previous),"smith repair preserves the hoe magical provenance")
	s.production.close(); s.interiors.leave(actor,s.world.objects,Vector2(600,500)); s._sync_view()
	for field: String in s.inventory.Origin.fields(wear()): wear().erase(field)
	wear().durability=12; wear().uses=7; move(spot()); previous=wear().duplicate(true); total=s.homestead.plots.size()
	var blocker:=FileAccess.open(directory+"/save-blocker",FileAccess.WRITE); blocker.store_string("isolated save failure fixture"); blocker.close()
	var path: String=s.inventory.path; s.inventory.path=directory+"/save-blocker/state.json"
	check(not s.homestead.till(actor,s.grounds),"save failure rejects cultivation")
	s.inventory.path=path
	check(s.homestead.plots.size()==total and wear()==previous,"save failure restores both soil and exact tool counters")
	await frames()
	# Actual combat uses the same equipped hoe and interval, without treating it as an axe or pick.
	move(spot()); var enemy: Node
	for unit: Node in s.combat.enemies.values():
		if not unit.has_meta("goblin") and not unit.friendly: enemy=unit; break
	check(is_instance_valid(enemy),"isolated hostile combat target exists")
	if is_instance_valid(enemy):
		if enemy.get_parent()==null: s.world.objects.add_child(enemy)
		enemy.room_id=""; enemy.position=actor.position+Vector2(24,0); enemy.hp=30; enemy.refresh(); enemy.set_physics_process(false)
		await frames(5); var hp: float=enemy.hp; s.combat.cooldown=0
		check(s.combat.attack_clicked(enemy.global_position) and is_equal_approx(hp-enemy.hp,1),"equipped hoe right-click attack deals one actual damage")
		check(s.combat.cooldown>0.9 and not s.combat.attack_clicked(enemy.global_position),"hoe combat enforces a one-second attack interval")
		enemy.position=Vector2(2000,2000)
	check(s.combat.Gear.attack_range("hoe")==30 and "hoe" not in s.combat.Gear.AXES and "hoe" not in s.combat.Gear.PICKS,"hoe has its defined reach without acquiring axe or pick mining powers")
	# Preserve per-instance magical origin and partial wear across unequip, equip, save and restart.
	wear().merge(s.inventory.Origin.gifted("hoe-probe-origin")); wear().durability=11; wear().uses=9
	previous=wear().duplicate(true)
	check(s.magic.equip_weapon(id,"") and not s.homestead.hoe_equipped(actor),"hoe can be unequipped through ordinary weapon transactions")
	check(s.magic.equip_weapon(id,"hoe") and wear()==previous,"re-equipping preserves provenance and partial durability")
	move(spot()); total=s.homestead.plots.size(); check(s.persistence.save_now(),"equipped hoe and cultivated plots save atomically")
	await screenshot("hoe-equipped")
	game.queue_free(); await frames(5); await load_game()
	check(s.magic.ensure(id).equipment.weapon=="hoe" and wear()==previous,"actual restart restores equipped hoe and provenance")
	check(s.homestead.plots.size()==total,"actual restart restores cultivated plots without duplication")
	game.queue_free(); await frames(5)
	var result: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  "))
	print("HOE_OK" if failures.is_empty() else "HOE_FAILED"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
