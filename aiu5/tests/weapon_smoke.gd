# Checks real HUD actions, per-character weapon ownership, combat gating and durable transfers.
extends SceneTree
var game: Node
var s: Node
var failures: Array[String] = []
var path := ""
func _initialize() -> void:
	path="res://.runtime/weapon-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
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
func click(button: Button) -> void:
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=button.get_global_rect().get_center()
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		Input.parse_input_event(e)
		await frames(2)
func run() -> void:
	await load_game()
	var hud: CanvasLayer=game.get_node("HUD")
	check(hud.weapon_button.visible and hud.weapon_button.size==Vector2(44,44),"weapon frame visible at requested lower location")
	await click(hud.weapon_button)
	check(s.inventory.opened and not hud.weapon_button.visible,"empty slot opens inventory")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"bow","count":1}])
	s.refresh_interface()
	await click(game.get_node("Belongings").bag_buttons[0])
	await click(game.get_node("Belongings").use_button)
	check(s.magic.ensure("ali").equipment.weapon=="bow" and not s.inventory.has_item("ali","bow"),"equip transfers exactly one bow from bag")
	check(not s.inventory.opened and hud.weapon_icon.item=="bow","HUD displays bow after equip")
	s.select_resident(1)
	check(hud.weapon_icon.item=="" and s.magic.ensure("ali").equipment.weapon=="bow","switch shows other character empty weapon")
	s.inventory.bags.heya=s.inventory._sanitize_slots([{"item":"bow","count":1}])
	check(not s.combat.fire(s.world.active_resident.position+Vector2(60,0)),"bag bow cannot fire without equipping")
	s.select_resident(0)
	s.inventory.exchange("ali",{}, {"arrow":1})
	check(s.combat.fire(s.world.active_resident.position+Vector2(60,0)),"equipped bow fires without bag duplicate")
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({"item":"stone","count":99})
	await click(hud.weapon_button)
	check(s.magic.ensure("ali").equipment.weapon=="bow","full bag prevents unequip loss")
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	var original: String=s.inventory.path
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path=blocked
	check(not s.magic.equip_weapon("ali",""),"failed save rejects weapon change")
	s.inventory.path=original
	check(s.magic.ensure("ali").equipment.weapon=="bow" and not s.inventory.has_item("ali","bow"),"failed save restores weapon and bag")
	await click(hud.weapon_button)
	check(s.magic.ensure("ali").equipment.weapon=="" and s.inventory.has_item("ali","bow"),"unequip returns bow to bag")
	check(not s.magic.equip_weapon("ali","stone"),"nonweapon rejected")
	check(s.magic.equip_weapon("ali","bow"),"re-equip for restart")
	s.overview=true
	s.world.set_overview(true)
	s.refresh_interface()
	check(not hud.weapon_button.visible,"map hides interactive slot")
	s.overview=false
	s.world.set_overview(false)
	s.refresh_interface()
	check(s.persistence.save_now(),"weapon state saved")
	game.queue_free()
	await frames()
	await load_game()
	check(s.magic.ensure("ali").equipment.weapon=="bow" and not s.inventory.has_item("ali","bow"),"equipped weapon survives restart without duplication")
	check(game.get_node("HUD").weapon_icon.item=="bow","HUD restored with saved weapon")
	var old: Dictionary=s.magic.Catalog.restore_state({})
	check(old.equipment.weapon=="","old saves default to empty weapon")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("WEAPON_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
