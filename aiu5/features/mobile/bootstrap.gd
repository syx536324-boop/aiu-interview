# Boots the Android presentation and saves/pauses when the application leaves the foreground.
extends Node
const Menu := preload("res://features/start_menu/controller.gd")
var menu: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("android_qa") and OS.get_environment("AIU5_QA_RUNNING") != "1":
		OS.set_environment("AIU5_QA_RUNNING","1")
		var probe: Node = load("res://tests/mobile_probe.tscn").instantiate(); add_child(probe); return
	get_tree().quit_on_go_back = false
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		ThemeDB.fallback_font = load("res://assets/fonts/NotoSansSC.ttf")
	menu = Menu.new(); menu.name = "Menu"; add_child(menu)
	get_tree().node_added.connect(_font_added)
	_apply_fonts(menu)

func _font_added(node: Node) -> void: _apply_fonts.call_deferred(node)

func _apply_fonts(node: Node) -> void:
	if not is_instance_valid(node): return
	if "font" in node and node.get("font") is SystemFont:
		node.get("font").fallbacks = [ThemeDB.fallback_font]
	for child: Node in node.get_children(): _apply_fonts(child)

func _notification(what: int) -> void:
	if not is_instance_valid(menu): return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(menu.game):
			var session: Node = menu.game.get_node("Session")
			if is_instance_valid(session.gifts) and session.gifts.opened: session.gifts.close()
			menu.game.get_node("MobileControls").release_all()
			session.simulation.flush(); session.persistence.save_now()
			if not session.menu_paused: menu.pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(menu.game):
			if menu.view.visible: menu.resume_game()
			else: menu.game.get_node("MobileControls").back()
		elif menu.view.screen != "home": menu.show_home()
		else: menu.quit_game()
