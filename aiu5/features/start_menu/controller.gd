# Coordinates the menu, save library and game lifetime without owning game simulation or UI layout.
extends Node

const Library := preload("res://features/save_slots/library.gd")
const View := preload("res://features/start_menu/view.gd")
const Game := preload("res://scenes/main.tscn")
var library: RefCounted
var view: CanvasLayer
var game: Node
var active_slot: Dictionary = {}
var busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	library = Library.new()
	library.import_legacy()
	view = View.new()
	add_child(view)
	view.continue_requested.connect(func() -> void: view.show_slots(library.slots()))
	view.new_requested.connect(func() -> void: view.show_new("赤沙村 " + str(library.slots().size() + 1)))
	view.create_requested.connect(create_game)
	view.load_requested.connect(continue_game)
	view.back_requested.connect(show_home)
	view.resume_requested.connect(resume_game)
	view.return_requested.connect(return_home)
	view.quit_requested.connect(quit_game)
	show_home()

func show_home() -> void:
	get_tree().paused = false
	get_tree().auto_accept_quit = true
	view.show_home(library.slots().any(func(s: Dictionary) -> bool: return s.valid), library.error)

func create_game(title: String) -> void:
	if busy or is_instance_valid(game): return
	var result: Dictionary = library.create_slot(title)
	if not result.ok:
		view.show_error(result.error)
		return
	busy = true
	call_deferred("_launch", result.slot, true)

func continue_game(id: String) -> void:
	if busy or is_instance_valid(game): return
	var slot: Dictionary = library.resolve(id)
	if slot.is_empty() or not slot.valid:
		view.show_error("无法读取这个存档，原文件未被修改。")
		return
	busy = true
	call_deferred("_launch", slot, false)

func _launch(slot: Dictionary, is_new: bool) -> void:
	OS.set_environment("AIU5_STATE_PATH", slot.path)
	OS.set_environment("AIU5_PROFILE_PATH", slot.names_path)
	OS.set_environment("AIU5_WORLD_PROFILE", slot.profile)
	OS.set_environment("AIU5_WORLD_SEED", str(slot.seed))
	get_tree().paused = false
	game = Game.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	if is_new and not game.get_node("Persistence").save_now():
		game.queue_free()
		game = null
		busy = false
		get_tree().auto_accept_quit = true
		view.show_error("新存档保存失败，请检查磁盘后重试。")
		return
	active_slot = slot
	game.get_node("Session").pause_requested.connect(pause_game)
	view.visible = false
	busy = false

func pause_game() -> void:
	if not is_instance_valid(game): return
	var session: Node = game.get_node("Session")
	session.simulation.flush()
	session.menu_paused = true
	session.refresh_interface()
	get_tree().paused = true
	view.show_pause(active_slot.title)

func resume_game() -> void:
	if not is_instance_valid(game): return
	view.visible = false
	get_tree().paused = false
	var session: Node = game.get_node("Session")
	session.menu_paused = false
	session.refresh_interface()

func return_home() -> void:
	if busy or not is_instance_valid(game): return
	if not game.get_node("Persistence").save_now():
		view.show_error("保存失败，村落仍保留在游戏中，请重试。")
		return
	busy = true
	game.queue_free()
	await get_tree().process_frame
	game = null
	active_slot = {}
	busy = false
	show_home()

func quit_game() -> void:
	if is_instance_valid(game) and not game.get_node("Persistence").save_now():
		view.show_error("保存失败，请重试后再退出。")
		return
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and view.visible:
		if view.screen == "pause": resume_game()
		elif view.screen != "home": show_home()
		get_viewport().set_input_as_handled()
