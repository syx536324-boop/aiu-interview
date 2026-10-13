# Exercises real discovery rewards, elemental gift choices, torches, click targets and persisted state.
extends Node
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Origin := preload("res://features/gifts/provenance.gd")
const Torch := preload("res://features/lighting/torch_record.gd")
var game: Node
var s: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
var capture := false
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	capture = OS.get_environment("AIU5_CAPTURE")=="true"
	get_tree().create_timer(90,true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
func physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	await frames()
func image(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"image "+name)
func gift(item: String, class_id: int, element := "") -> bool:
	var actor: CharacterBody2D = s.world.active_resident
	actor.position = s.world.point_info("altar").position
	s._sync_view()
	if not s.gifts.open_menu(): return false
	s.gifts.mode="camera"
	s.gifts.session_id="probe-"+str(Time.get_ticks_usec())
	s.gifts.frozen=true
	s.gifts.received=true
	s.gifts.received_at=Time.get_ticks_msec()
	s.gifts.candidates=[{"id":"one","item":item,"class_id":class_id,"name":item,"kind":"animal" if item in ["bird","dog"] else "inventory","confidence":0.99}]
	s.gifts.select_candidate("one")
	s.gifts.select_element(element)
	return s.gifts.confirm()
func run() -> void:
	await load_game()
	check(s.achievements.snapshot("ali").reward==25,"twenty-five discovery reward")
	# The starting loadout is a grant, not a discovery: three seeds of each kind award nothing.
	check(s.achievements.snapshot("ali").completed==0 and s.magic.ensure("ali").pending_points==0,"starting seeds are not achievements")
	check(s.persistence.save_now() and s.magic.ensure("ali").pending_points==0,"saving the starting loadout still awards nothing")
	# Holding more than the starting amount is a genuine acquisition and does count.
	s.inventory.exchange("ali",{}, {"seeds":1})
	check(s.persistence.save_now() and s.achievements.completed.ali.has("item:seeds"),"a fourth seed is a real discovery")
	check(s.magic.ensure("ali").pending_points==25,"real seed discovery adds twenty-five")
	var pending: int = s.magic.ensure("ali").pending_points
	check(s.inventory.commit_resource_reward("ali","probe-stone",1,"stone",1).ok,"real resource reward saves")
	check(s.magic.ensure("ali").pending_points==pending+25,"resource discovery adds twenty-five")
	s.inventory.commit_resource_reward("ali","probe-stone",2,"stone",1)
	check(s.magic.ensure("ali").pending_points==pending+25,"repeat resource is not a new achievement")
	s.inventory.exchange("ali",{}, {"wood":1,"coal":1})
	check(s.persistence.save_now(),"materials committed")
	check(s.production.crafts.start(s.production,"probe-bench","torch",s.production.RECIPES.torch),"real torch recipe reserves materials")
	check(not s.inventory.has_item("ali","torch"),"craft not instantaneous")
	s.production.crafts.elapse(s.production,60)
	check(s.inventory.has_item("ali","torch") and s.achievements.completed.ali.has("item:torch"),"craft completion awards torch discovery")
	check(s.production.RECIPES.torch.cost=={"wood":1,"coal":1},"exact torch ingredients")
	var blocked := directory+"/blocked"
	DirAccess.make_dir_recursive_absolute(blocked)
	var original: String = s.inventory.path
	var before: Dictionary = s.inventory.export_data()
	s.inventory.exchange("ali",{}, {"book":1})
	s.inventory.path=blocked
	check(not s.production.commit(before,"probe"),"failed acquisition save rejected")
	s.inventory.path=original
	check(not s.achievements.completed.ali.has("item:book") and not s.inventory.has_item("ali","book"),"failed save rolls back item and discovery")
	check(s.magic.ensure("ali").pending_points==before.session.magic.residents.ali.pending_points,"failed discovery restores points")
	var torch_index := -1
	for i in range(21):
		if s.inventory.ensure_bag("ali")[i].get("item","")=="torch": torch_index=i; break
	check(s.torches.equip("ali",torch_index),"real torch equips independent slot")
	check(s.magic.ensure("ali").equipment.weapon=="" and not s.inventory.has_item("ali","torch"),"equipping torch does not replace weapon or duplicate")
	check(not s.torches.equipped("ali").lit,"crafted torch begins extinguished")
	check(s.torches.ignite("ali"),"first lighting succeeds")
	s.torches.advance(299.5)
	check(s.torches.equipped("ali").lit and s.torches.equipped("ali").fuel_left==300.5,"five-minute boundary before expiry")
	s.torches.advance(0.5)
	check(not s.torches.equipped("ali").lit and s.torches.equipped("ali").fuel_left==300,"five minutes extinguishes without restoring durability")
	s.torches.advance(1000)
	check(s.torches.equipped("ali").fuel_left==300,"extinguished torch freezes fuel")
	check(s.torches.ignite("ali"),"relight keeps remaining fuel")
	s.torches.advance(12.5)
	s.menu_paused=true; s.torches.advance(200); s.menu_paused=false
	check(s.torches.equipped("ali").fuel_left==287.5,"pause freezes burning")
	s.select_resident(1); s.torches.advance(100)
	check(s.torches.equipped("ali").fuel_left==287.5 and not s.torches.lamp.enabled,"inactive character torch frozen and no light")
	s.select_resident(0)
	check(s.torches.lamp.texture.get_width()==80 and s.torches.lamp.texture.get_height()==80 and s.torches.lamp.texture_scale==1,"exact eighty-world-pixel light")
	check(s.torches.lamp.get_parent()==s.world.active_resident,"light follows currently controlled character")
	s.vitals.ensure("ali").life=0; s.world.active_resident.dead=true; s.torches.advance(100)
	check(s.torches.equipped("ali").fuel_left==287.5,"death freezes burning")
	s.vitals.ensure("ali").life=10; s.world.active_resident.dead=false
	check(s.persistence.save_now(),"lit torch saved")
	var stored: Dictionary = s.inventory.export_data()
	s.torches.advance(20)
	s.inventory.apply_data(stored); s.persistence.restore_session(stored.session)
	check(s.torches.equipped("ali").lit and s.torches.equipped("ali").fuel_left==287.5 and s.torches.equipped("ali").burn_left==287.5,"restore preserves both fuel and session timer")
	check(s.torches.equip("ali"),"unequip returns existing torch")
	var bag: Array = s.inventory.ensure_bag("ali")
	for i in range(21):
		if bag[i].get("item","")=="torch": torch_index=i; break
	check(bag[torch_index].fuel_left==287.5 and not bag[torch_index].lit,"unequipping extinguishes and preserves used fuel")
	s.inventory.open_container("ali","阿力","probe-box","箱子")
	s.inventory.quick_transfer("bag",torch_index)
	check(s.inventory.ensure_container("probe-box")[0].fuel_left==287.5,"container keeps per-instance fuel")
	s.inventory.quick_transfer("storage",0); s.close_inventory()
	bag=s.inventory.ensure_bag("ali")
	for i in range(21):
		if bag[i].get("item","")=="torch": torch_index=i; break
	check(s.torches.equip("ali",torch_index),"torch retrieved and equipped")
	s.magic.ensure("ali").element="fire"
	s.magic.ensure("ali").level=20
	s.magic.ensure("ali").unlocked=["trunk_1","trunk_2","trunk_3"]
	s.magic.ensure("ali").skill_points=65
	s.vitals.ensure("ali").mana=10
	check(s.magic.skills.cast(3,s.world.active_resident.position),"fire rank three ignites equipped torch without camp")
	check(s.vitals.ensure("ali").mana==5 and s.torches.equipped("ali").lit,"torch ignition costs five mana")
	s.torches.advance(287.5)
	check(s.torches.equipped("ali").is_empty() and not s.torches.lamp.enabled,"ten-minute cumulative lifetime scraps torch")
	# Actual altar granting and its twelve-level attribute gate.
	s.magic.ensure("ali").level=11
	check(gift("bowl",2,"water"),"below-twelve camera grant still works")
	var found := -1
	bag=s.inventory.ensure_bag("ali")
	for i in range(21):
		if Origin.magical(bag[i]) and bag[i].get("item","")=="bowl": found=i; break
	check(found>=0 and bag[found].magic_attribute==null,"below twelve cannot force gift attribute")
	s.inventory.open_bag("ali","阿力"); s.inventory.selection={"side":"bag","index":found}
	check(not s.gifts.assign_selected_attribute("water"),"existing gift attribute also gated below twelve")
	s.magic.ensure("ali").level=12
	for element: String in Origin.ELEMENTS:
		check(s.gifts.assign_selected_attribute(element),"choose existing gift "+element)
		check(Origin.fields(s.inventory.ensure_bag("ali")[found]).magic_attribute==element,"provenance preserves "+element)
	s.inventory.path=blocked
	check(not s.gifts.assign_selected_attribute("wood"),"attribute save failure rejected")
	s.inventory.path=original
	check(s.inventory.ensure_bag("ali")[found].magic_attribute=="earth","failed attribute save keeps old choice")
	s.close_inventory()
	check(gift("knife",1,"water"),"twelve-level camera gift with choice")
	bag=s.inventory.ensure_bag("ali")
	for i in range(21):
		if Origin.magical(bag[i]) and bag[i].get("item","")=="knife": found=i; break
	check(bag[found].magic_attribute=="water","camera selection applied to real gift")
	check(s.magic.equip_weapon("ali","knife",found),"elemental gift weapon equips")
	check(s.magic.ensure("ali").weapon_wear.magic_attribute=="water","equipment retains chosen attribute")
	check(gift("bird",6,"wood"),"animal gift accepts attribute")
	check(s.achievements.completed.ali.has("item:bird"),"new gifted animal completes achievement")
	var bird_attribute := false
	for animal in s.livestock.animals:
		if animal.species=="bird" and animal.get_meta("gift_origin",{}).get("magic_attribute","")=="wood": bird_attribute=true
	check(bird_attribute,"gifted animal retains element")
	# Place real actors in an open region and exercise precise boundary/cooldown/click targeting.
	s.world.active_resident.position=Vector2(1100,850)
	var enemy: CharacterBody2D=s.combat.enemies["tribe:1"]
	var other: CharacterBody2D=s.combat.enemies["tribe:2"]
	# The shipped camera must reach the whole bow range, so no test-only zoom override is used here.
	var view_half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / s.world.camera.zoom
	check(minf(view_half.x,view_half.y) >= Gear.attack_range("bow"),"default view reaches the full bow range")
	s._sync_view()
	# Camera2D applies the canvas transform on its own process callback and skips it while the tree
	# is paused, so wait (bounded) until the shipped outdoor camera is really the one in effect
	# before any range is measured. Without this the viewport transform can still be stale.
	for i in range(60):
		if is_equal_approx(s.world.active_resident.get_canvas_transform().get_scale().x,s.world.camera.zoom.x): break
		await frames()
	await physics()
	check(is_equal_approx(s.world.active_resident.get_canvas_transform().get_scale().x,s.world.camera.zoom.x),"outdoor camera is active before range measurement")
	# Let the saved-seed resource streamer finish attaching nearby nodes before choosing a firing
	# line; otherwise a rock can still pop into the corridor after it was measured as clear.
	await frames(40)
	await physics()
	# The world can put a rock on any given line and the bow's ray is long, so fire along a direction
	# that is actually clear; otherwise the range is never the reason an attack is refused.
	var aim := Vector2.ZERO
	for candidate: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
		var clear_query := PhysicsRayQueryParameters2D.create(s.world.active_resident.global_position,s.world.active_resident.global_position+candidate*Gear.attack_range("bow"),1|8|4,[s.world.active_resident.get_rid()])
		if s.world.active_resident.get_world_2d().direct_space_state.intersect_ray(clear_query).is_empty(): aim=candidate; break
	check(aim!=Vector2.ZERO,"a clear 200-pixel firing line exists")
	# Keep the second enemy clear of the line so it can never be picked instead of the clicked one.
	other.position=s.world.active_resident.position+Vector2(-aim.y,aim.x)*30.0
	for weapon: String in Gear.WEAPONS:
		# Gift-only flying scissors is exercised by weapons_plan_probe with real provenance.
		if weapon=="magic_scissors": continue
		s.magic.ensure("ali").equipment.weapon=weapon
		s.magic.ensure("ali").weapon_wear=s.magic.Catalog.Wear.normalize()
		s.inventory.exchange("ali",{}, {"arrow":1})
		s.combat.cooldown=0
		enemy.hp=30; enemy.refresh(); enemy.set_physics_process(false)
		var distance := Gear.attack_range(weapon)
		enemy.position=s.world.active_resident.position+aim*(distance+1)
		await physics()
		check(not s.combat.attack_clicked(enemy.global_position+Vector2(0,-8)),"out-of-range rejected "+weapon)
		enemy.position=s.world.active_resident.position+aim*distance
		await physics()
		var other_hp: float=other.hp
		check(s.combat.attack_clicked(enemy.global_position+Vector2(0,-8)),"inclusive range boundary "+weapon)
		if weapon=="bow":
			# A refused bow shot must not be blamed on the range when the line is really blocked.
			var line_query := PhysicsRayQueryParameters2D.create(s.world.active_resident.global_position,enemy.global_position,1|8|4,[s.world.active_resident.get_rid()])
			check(s.world.active_resident.get_world_2d().direct_space_state.intersect_ray(line_query).get("collider")==enemy,"bow firing line stays clear")
		check(is_equal_approx(s.combat.cooldown,Gear.interval(weapon)),"configured interval "+weapon)
		check(not s.combat.attack_clicked(enemy.global_position+Vector2(0,-8)),"cooldown rejects repeat "+weapon)
		check(other.hp==other_hp,"clicked target never substitutes nearby enemy "+weapon)
		if weapon!="bow": check(enemy.hp==30-Gear.damage(weapon),"clicked melee damage "+weapon)
		for arrow in get_tree().get_nodes_in_group("arrows"): arrow.queue_free()
	# An in-range target is always on screen now, so the only remaining refusals are empty ground
	# and an open panel.
	check(not s.combat.attack_clicked(Vector2(1100,820)),"empty ground click does not consume attack")
	s.combat.cooldown=0
	s.inventory.open_bag("ali","阿力")
	check(not s.combat.attack_clicked(enemy.global_position),"inventory blocks right-click combat")
	s.close_inventory()
	# UI evidence: torch beside weapon, a readable achievement list, and the unlocked attribute choice.
	s.inventory.exchange("ali",{}, {"torch":1})
	bag=s.inventory.ensure_bag("ali")
	for i in range(21):
		if bag[i].get("item","")=="torch": torch_index=i; break
	s.torches.equip("ali",torch_index); s.torches.ignite("ali")
	s.day_night.elapsed=800
	s.refresh_interface(); await frames()
	var hud: CanvasLayer=game.get_node("HUD")
	check(hud.torch_button.visible and hud.torch_button.position.x<hud.weapon_button.position.x,"torch HUD placed at circled left side")
	await image("torch-hud.png")
	s.show_attributes("ali"); game.get_node("Attributes").achievement_tab.pressed.emit()
	s.refresh_interface(); await frames()
	check("25魔法点" in game.get_node("Attributes").achievement_text.text and "100魔法点" not in game.get_node("Attributes").achievement_text.text,"achievement UI shows actual twenty-five reward")
	await image("item-achievements.png")
	s.close_attributes()
	# The bag side of the twenty-level attribute choice must be reachable, not only the backend.
	s.inventory.open_bag("ali","阿力")
	bag=s.inventory.ensure_bag("ali")
	found=-1
	for i in range(21):
		if Origin.magical(bag[i]): found=i; break
	check(found>=0,"a magical gift stays in the bag for the attribute UI")
	s.inventory.selection={"side":"bag","index":found}
	s.refresh_interface(); await frames()
	var bag_view: CanvasLayer=game.get_node("Belongings")
	check(bag_view.attribute_choice.visible and bag_view.attribute_button.visible,"bag shows the attribute selector for a gift item")
	check(not bag_view.attribute_button.disabled and not bag_view.attribute_choice.disabled,"twenty-level bag attribute choice is enabled")
	await image("bag-attribute.png")
	s.close_inventory()
	s.world.active_resident.position=s.world.point_info("altar").position; s._sync_view()
	s.gifts.open_menu(); s.gifts.mode="camera"; s.gifts._emit(); await frames()
	check(not game.get_node("GiftView").attribute_choice.disabled,"camera UI exposes twenty-level element options")
	await image("gift-elements.png")
	s.gifts.close()
	check(s.persistence.save_now(),"final full-session save")
	var completed_before: int=s.achievements.snapshot("ali").completed
	var torch_before: Dictionary = s.torches.equipped("ali").duplicate(true)
	game.queue_free(); await frames()
	await load_game()
	check(s.achievements.snapshot("ali").completed==completed_before,"actual restart never repeats discoveries")
	check(s.torches.equipped("ali").fuel_left==torch_before.fuel_left and s.torches.equipped("ali").lit==torch_before.lit,"actual restart preserves torch state without offline consumption")
	var pending_before: int=s.magic.ensure("heya").pending_points
	s.inventory.exchange("heya",{}, {"stone":1}); s.persistence.save_now()
	check(s.magic.ensure("heya").pending_points==pending_before+25,"separate character receives its own first-item achievement")
	game.queue_free(); await frames()
	if failures.is_empty(): print("ITEM_UPDATE_OK checks=",checks); get_tree().quit(0)
	else: print(failures); get_tree().quit(1)
