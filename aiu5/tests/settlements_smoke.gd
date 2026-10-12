# Verifies two furnace queues, forest village access, NPC roles, clearing and altar persistence.
extends SceneTree
var failures: Array[String] = []
var s: Node
var game: Node
var path := ""
func _initialize() -> void:
	path = "res://.runtime/settlements-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await process_frame
func enter(id: String, kind: String) -> void:
	s.production.close()
	var a: CharacterBody2D = s.world.active_resident
	if a.room_id != "": s.interiors.leave(a,s.world.objects,s.interiors.outdoor_position(a))
	a.position = s.world.home_data(id).door
	s.interact()
	check(a.room_id == id,"enter "+id)
	var room: Node2D = s.interiors.rooms[id]
	for fixture: Node2D in room.fixtures:
		if fixture.kind == kind:
			var bounds: Rect2 = fixture.collision_bounds()
			a.position = Vector2(bounds.get_center().x,bounds.end.y+8)
			break
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	await frames()
	check(s.world.controllable.size()==3 and s.world.residents.size()==6,"three founders plus three nonplayable forest residents")
	for actor in s.world.residents:
		if actor.resident_id.begins_with("forest_"): check(not actor.can_control,"forest NPC remains unplayable")
	for x in range(-8,0):
		for y in range(8):
			for record: Dictionary in s.forest.generate(Vector2i(x,y)):
				check(not Rect2(record.at-Vector2(26,54),Vector2(52,60)).intersects(s.world.Layout.FOREST_VILLAGE),"resources avoid village clearing")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"iron_ore","count":3}])
	enter("blacksmith","stove")
	s.interact()
	check(s.production.opened and s.production.mode=="smelt","E at blacksmith furnace opens smelting")
	check(s.production.perform("smelt"),"smith consumes ore and begins smelting")
	s.production.elapse(12)
	check(s.production.smith_smelting.remaining==18 and s.production.smelting.remaining==0,"smith furnace independent of kitchen")
	enter("kitchen","stove")
	s.production.open_near()
	check(s.production.perform("smelt"),"kitchen starts while smith is busy")
	s.production.elapse(18)
	check(s.production.smith_smelting.ready==1 and s.production.smelting.remaining==12,"separate deadlines")
	check(s.persistence.save_now(),"save both furnaces")
	var saved: Dictionary = s.production.export_state()
	s.production.restore(saved)
	check(s.production.smith_smelting.ready==1 and s.production.smelting.remaining==12,"restore both furnaces")
	enter("blacksmith","stove")
	s.production.open_near()
	check(s.production.perform("collect") and s.inventory.has_item("ali","crude_iron"),"collect smith iron")
	check(not s.production.perform("collect"),"cannot collect twice")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"ginseng","count":1},{"item":"reishi","count":1},{"item":"water_cup","count":1}])
	enter("forest_herb_house","workbench")
	s.interact()
	check(s.production.mode=="herbs" and s.production.perform("restorative_soup"),"forest village herbal house crafts soup")
	s.production.close()
	var a: CharacterBody2D=s.world.active_resident
	s.interiors.leave(a,s.world.objects,s.world.Layout.FOREST_ALTAR+Vector2(0,22))
	s._sync_view()
	s.interact()
	s.gifts.save_altar()
	s.gifts.close()
	check(FileAccess.file_exists(path+".altar"),"forest altar writes checkpoint")
	check(s.magic.awakening_error("ali")=="" and s.magic.awaken("ali","wood"),"forest altar allows chosen awakening")
	check(s.landscape.protected(s.world.Layout.FOREST_PLAZA),"altar plaza protected from building")
	s.world.streamer.focus(true)
	await frames(100)
	for data: Dictionary in s.world.Layout.FOREST_NPCS:
		check(not s.world.navigation.find_path(a.position,data.at).is_empty(),"path to "+data.name)
	s.world.set_overview(true)
	var frozen: Dictionary=s.production.export_state()
	await create_timer(0.2,true).timeout
	check(s.production.export_state()==frozen,"overview freezes furnace time")
	s.world.set_overview(false)
	s.production.restore({"remaining":7.0,"ready":0})
	check(s.production.smelting.remaining==7 and s.production.smith_smelting.remaining==0,"old furnace save migration")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("SETTLEMENTS_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
