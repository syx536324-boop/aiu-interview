# Verifies smith repair/crafting costs, exact instances, UI selection, rollback and persistence.
extends SceneTree
var failures: Array[String] = []
var game: Node
var s: Node
var path := ""
func _initialize() -> void:
	path="res://.runtime/smith-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	await frames()
func enter(id: String) -> void:
	s.production.close()
	var a: CharacterBody2D=s.world.active_resident
	if a.room_id!="": s.interiors.leave(a,s.world.objects,s.interiors.outdoor_position(a))
	a.position=s.world.home_data(id).door
	s.interact()
	check(a.room_id==id,"enter "+id)
	for f: Node2D in s.interiors.rooms[id].fixtures:
		if f.kind=="stove":
			var bounds: Rect2=f.collision_bounds()
			a.position=Vector2(bounds.get_center().x,bounds.end.y+8)
			break
	s.production.open_near()
func count(item: String) -> int:
	var result:=0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: result+=int(slot.count)
	return result
func click_recipe(id: String) -> void:
	s.refresh_interface()
	var ui: Node=game.get_node("Workshop")
	for i in range(ui.current.recipes.size()):
		if ui.current.recipes[i].id==id:
			check(not ui.buttons[i].disabled,"recipe enabled "+id)
			ui.buttons[i].pressed.emit()
			ui.confirm_button.pressed.emit()
			return
	check(false,"recipe visible "+id)
func run() -> void:
	await load_game()
	s.inventory.bags.ali=s.inventory._sanitize_slots([
		{"item":"pickaxe","count":1,"durability":0},{"item":"stone_axe","count":1,"durability":0},
		{"item":"stone_sword","count":1,"durability":0},{"item":"iron_axe","count":1,"durability":0},
		{"item":"iron_sword","count":1,"durability":0},{"item":"wood_sword","count":1,"durability":0},
		{"item":"bow","count":1,"durability":0},{"item":"stone_sword","count":1,"durability":12,"uses":8},
		{"item":"stone","count":10},{"item":"crude_iron","count":10}])
	check(s.magic.equip_weapon("ali","stone_axe",1),"equip broken axe")
	enter("kitchen")
	check(not s.production.perform("repair:equipped") and not s.production.perform("smith:iron_armor"),"kitchen cannot repair or craft smith armor")
	enter("blacksmith")
	check(s.production.Repairs.options(s).size()==5,"five repairable instances; wood bow and partial wear excluded")
	await click_recipe("repair:equipped")
	check(s.magic.ensure("ali").weapon_wear=={"durability":40,"uses":0} and count("stone")==9,"equipped stone repair costs exactly one stone")
	check(not s.production.perform("repair:equipped") and count("stone")==9,"repeated repair cannot spend material")
	for index in [0,2,3,4]: check(s.production.perform("repair:bag:%d" % index),"repair bag instance %d" % index)
	check(count("stone")==7 and count("crude_iron")==8,"stone/iron recipes each consume one corresponding material")
	check(s.inventory.bags.ali[7].durability==12 and s.inventory.bags.ali[7].uses==8,"same-type partial weapon untouched")
	check(not s.production.perform("repair:bag:7") and not s.production.perform("repair:bag:5") and not s.production.perform("repair:bag:6"),"partial wood and bow not repairable")
	check(not s.production.perform("repair:bag:99") and not s.production.perform("repair:bag:no"),"stale or invalid repair rejected")
	s.magic.ensure("ali").weapon_wear={"durability":0,"uses":0}
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	check(not s.production.perform("repair:equipped") and s.magic.ensure("ali").weapon_wear.durability==0,"missing repair material preserves broken weapon")
	var packed: Array=[]
	for i in range(20): packed.append({"item":"stone_axe","count":1,"durability":0})
	packed.append({"item":"stone","count":5})
	s.inventory.bags.ali=s.inventory._sanitize_slots(packed)
	s.refresh_interface()
	var ui: Node=game.get_node("Workshop")
	check(ui.current.recipes.size()>10 and ui.buttons.size()==ui.current.recipes.size(),"scrolling UI represents all repair/craft rows")
	await click_recipe("repair:bag:19")
	check(s.inventory.bags.ali[19].durability==40 and s.inventory.bags.ali[18].durability==0 and count("stone")==4,"last visible repair row selects exact instance in full bag")
	var original: String=s.inventory.path
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	var before: Array=s.inventory.bags.ali.duplicate(true)
	s.inventory.path=blocked
	check(not s.production.perform("repair:bag:18"),"failed repair save rejected")
	s.inventory.path=original
	check(s.inventory.bags.ali==before,"failed repair restores material and target wear")
	enter("blacksmith")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"leather","count":21},{"item":"crude_iron","count":21}])
	for id: String in s.production.Smith.RECIPES:
		check(s.production.perform(id),"start armor craft "+id)
		s.production.elapse(60)
	check(count("leather")==0 and count("crude_iron")==0,"full sets use 8+5+4+4 of each material")
	check(count("leather_armor")==1 and count("iron_boots")==1,"armor outputs in bag")
	s.production.close()
	s.show_attributes("ali")
	var attributes: Node=game.get_node("Attributes")
	attributes.gear_buttons.armor.button.pressed.emit()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=attributes.gear_choice.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await frames()
	check(attributes.gear_choice.get_popup().visible,"actual mouse opens material dropdown")
	await create_timer(0.25,true).timeout
	check(attributes.gear_choice.get_popup().visible,"periodic snapshots keep material dropdown open")
	attributes.gear_choice.get_popup().index_pressed.emit(1)
	attributes.gear_choice.get_popup().hide()
	check(attributes.gear_choice.selected==1,"popup selection routes iron material through native option button")
	attributes.wear_button.pressed.emit()
	check(s.magic.ensure("ali").equipment.armor=="iron_armor" and count("iron_armor")==0,"actual armor picker selects iron variant")
	attributes.gear_buttons.armor.button.pressed.emit()
	attributes.gear_choice.select(0)
	attributes.gear_choice.item_selected.emit(0)
	attributes.wear_button.pressed.emit()
	check(s.magic.ensure("ali").equipment.armor=="leather_armor" and count("iron_armor")==1,"changing material returns previous armor")
	for slot: String in {"head":"iron_helmet","legs":"leather_leggings","feet":"iron_boots"}:
		check(s.magic.equip("ali",slot,{"head":"iron_helmet","legs":"leather_leggings","feet":"iron_boots"}[slot]),"equip material variant "+slot)
	check(not s.magic.equip("ali","head","iron_armor"),"wrong armor slot rejected")
	s.close_roster()
	enter("blacksmith")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"leather","count":7}])
	check(not s.production.perform("smith:leather_armor") and count("leather")==7,"insufficient armor material retained")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"crude_iron","count":9}])
	for i in range(1,21): s.inventory.bags.ali[i]={"item":"book","count":10}
	check(not s.production.perform("smith:iron_armor") and count("crude_iron")==9,"full output bag retains iron")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"crude_iron","count":8}])
	before=s.inventory.bags.ali.duplicate(true)
	s.inventory.path=blocked
	check(not s.production.perform("smith:iron_armor"),"failed armor save rejected")
	s.inventory.path=original
	check(s.inventory.bags.ali==before,"failed armor craft restores ingredients and removes output")
	enter("blacksmith")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"stone","count":1},{"item":"iron_sword","count":1,"durability":0}])
	check(s.persistence.save_checkpoint(false),"checkpoint before repair")
	check(s.production.perform("repair:equipped"),"repair before reload")
	var equipment: Dictionary=s.magic.ensure("ali").equipment.duplicate()
	check(s.persistence.save_now(),"save armor and repair")
	game.queue_free()
	await frames()
	await load_game()
	check(s.magic.ensure("ali").equipment==equipment and s.magic.ensure("ali").weapon_wear.durability==40,"reload retains armor material and repaired durability")
	check(s.persistence.restore_checkpoint() and s.magic.ensure("ali").weapon_wear.durability==0 and count("stone")==1,"checkpoint restores pre-repair material and wear")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("SMITH_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
