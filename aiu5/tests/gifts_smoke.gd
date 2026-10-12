# Exercises gift confirmation, source-preserving transfers, deduplication and failed-write rollback with deterministic camera observations.
extends SceneTree
const Origin := preload("res://features/gifts/provenance.gd")
const Mapping := preload("res://features/gifts/mapping.gd")
var game: Node
var s: Node
var failures: Array[String] = []
var path := ""
class FakeCamera extends Node:
	signal updated(data: Dictionary)
	var closes := 0
	func open(_id: String) -> void: pass
	func close() -> void: closes += 1
func _initialize() -> void:
	path = "res://.runtime/gifts-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	var fake := FakeCamera.new()
	game.add_child(fake)
	s.gifts.camera = fake
	await frames()
func begin(class_id: int, stable := true) -> void:
	s.world.active_resident.position = s.world.point_info("altar").position
	check(s.gifts.open_menu(),"open altar menu")
	s.gifts.begin_camera()
	s.gifts.accept_snapshot({"session_id":s.gifts.session_id,"status":"ready","sequence":1,"frame_jpeg":"","device":"TEST","candidates":[{"id":"object-1","class_id":class_id,"class_name":Mapping.NAMES[class_id],"confidence":.9,"stable":stable}]})
	s.gifts.freeze_frame()
	s.gifts.select_candidate("object-1")
func run() -> void:
	await load_game()
	for i in range(18): check(not Mapping.reward(i).is_empty(),"mapping class "+str(i))
	check(not s.gifts.open_menu(),"cannot open away from altar")
	s.inventory.bags.ali = s.inventory._sanitize_slots([])
	begin(1,false)
	check(not s.gifts.frozen and not s.gifts.confirm(),"unstable observation cannot grant")
	s.gifts.close()
	check(not paused,"cancel restores world time")
	begin(1)
	check(paused,"camera gift pauses world")
	check(s.gifts.confirm(),"confirmed knife saved")
	check(not s.gifts.confirm() and s.inventory.gift_events.size()==1,"repeated confirm cannot duplicate")
	check(Origin.magical(s.inventory.bags.ali[0]),"knife has immutable magical origin")
	check(s.magic.equip_weapon("ali","knife",0),"equip magical weapon")
	check(Origin.magical(s.magic.ensure("ali").weapon_wear),"equipped weapon retains origin")
	check(s.magic.equip_weapon("ali",""),"unequip weapon")
	s.inventory.open_container("ali","阿砾","gift:chest","箱")
	s.inventory.quick_transfer("bag",0)
	check(Origin.magical(s.inventory.containers["gift:chest"][0]),"storage retains source")
	s.inventory.quick_transfer("storage",0)
	s.inventory.close()
	check(s.persistence.save_now(),"save transferred magical record")
	game.queue_free()
	await frames()
	await load_game()
	check(Origin.magical(s.inventory.bags.ali[0]) and s.inventory.gift_events.size()==1,"restart retains source and event ledger")
	s.inventory.bags.ali = s.inventory._sanitize_slots([{"item":"apple","count":2}])
	begin(8)
	check(s.gifts.confirm(),"grant magical apple alongside ordinary stack")
	check(s.inventory.bags.ali[0].count==2 and Origin.magical(s.inventory.bags.ali[1]),"ordinary and magical apple are separate")
	s.inventory.exchange("ali",{},{"apple":1})
	check(s.inventory.bags.ali[0].count==3 and s.inventory.bags.ali[1].count==1,"world reward cannot join magical apple")
	s.inventory.transfer_slots(s.inventory.bags.ali,1,s.inventory.bags.ali,0)
	check(Origin.magical(s.inventory.bags.ali[0]) and s.inventory.bags.ali[1].count==3,"magical apple swaps instead of merging")
	s.inventory.bags.ali = s.inventory._sanitize_slots([{"item":"armor","count":1}])
	begin(14)
	check(s.gifts.confirm(),"grant magical armor")
	check(s.magic.equip("ali","armor","leather_armor",1),"choose magical same-type armor")
	check(Origin.magical(s.magic.ensure("ali").equipment_records.armor),"armor preserves exact chosen instance")
	check(s.magic.equip("ali","armor","leather_armor",0),"replace with ordinary same-type armor")
	check(not Origin.magical(s.magic.ensure("ali").equipment_records.armor) and Origin.magical(s.inventory.bags.ali[0]),"ordinary worn armor and gifted returned armor stay distinct")
	var count: int = s.livestock.animals.size()
	begin(7)
	check(s.gifts.confirm() and s.livestock.animals.size()==count+1,"dog gift creates one village animal")
	var state: Dictionary = s.livestock.export_state()
	check(Origin.magical(state.animals[-1].gift_origin),"animal snapshot retains magical source")
	s.livestock.restore(state)
	check(Origin.magical(s.livestock.animals[-1].get_meta("gift_origin",{})),"restored dog retains magical source")
	s.inventory.bags.ali = s.inventory._sanitize_slots([])
	begin(3)
	check(s.gifts.confirm() and s.inventory.has_item("ali","bed"),"bed gift becomes deployable record")
	var actor: CharacterBody2D = s.world.active_resident
	s.interiors.enter(actor,s.world.home_data("house"))
	s._sync_view()
	check(actor.room_id != "","enter house for gift bed")
	var room: Node2D = s.interiors.rooms[actor.room_id]
	for fixture: Node2D in room.fixtures.duplicate(): room.remove_fixture(fixture)
	check(s.editor.open(),"open furniture mode")
	s.editor.choose_gift_bed(0)
	s.editor.point_at(Vector2(68,70))
	check(s.editor.place(),"deploy gifted bed")
	check(room.fixtures.size()==1 and Origin.magical(room.fixtures[0].gift_origin),"deployed bed retains source")
	s.editor.pick(room.fixtures[0])
	check(s.editor.remove_selected() and Origin.magical(s.inventory.bags.ali[0]),"recovered bed preserves source")
	s.editor.close()
	s.interiors.leave(actor,s.world.objects,s.world.point_info("altar").position)
	s._sync_view()
	var full: Array = []
	for i in range(21): full.append({"item":"book","count":1})
	s.inventory.bags.ali = s.inventory._sanitize_slots(full)
	var events: int = s.inventory.gift_events.size()
	begin(9)
	check(not s.gifts.confirm() and s.inventory.gift_events.size()==events,"full bag rejects without consuming confirmation")
	s.inventory.bags.ali[0] = {}
	var original: String = s.inventory.path
	var blocked := path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path = blocked
	check(not s.gifts.confirm() and s.inventory.bags.ali[0].is_empty() and s.inventory.gift_events.size()==events,"failed write rolls back gift and ledger")
	check(paused,"failed gift keeps world paused")
	s.inventory.path = original
	check(s.gifts.confirm(),"retry after failed write succeeds once")
	begin(9)
	s.gifts.received_at = Time.get_ticks_msec()-31000
	check(not s.gifts.confirm(),"expired frozen observations cannot grant")
	s.gifts.close()
	s.inventory.bags.ali = s.inventory._sanitize_slots([])
	begin(0)
	check(s.gifts.confirm(),"grant magical cup")
	check(s.homestead.fill_bucket(s.world.active_resident),"fill gifted cup")
	check(s.inventory.bags.ali[0].item=="water_cup" and Origin.magical(s.inventory.bags.ali[0]),"filling cup retains source")
	s.vitals.ensure("ali").thirst = 4
	check(s.vitals.use_food("ali","water_cup",0),"drink from chosen gift cup")
	check(s.inventory.bags.ali[0].item=="wooden_cup" and Origin.magical(s.inventory.bags.ali[0]),"empty gift cup retains source after drinking")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("GIFTS_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
