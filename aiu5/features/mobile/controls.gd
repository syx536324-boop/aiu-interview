# Presents mobile controls and delegates actions to the existing game domains.
extends CanvasLayer
const TouchButton := preload("res://features/mobile/touch_button.gd")
const Joystick := preload("res://features/mobile/joystick.gd")
var session: Node
var root: Control
var movement: Control
var tools: Control
var navigation: Control
var expanded := false
var buttons: Dictionary = {}
var aim := Vector2.INF
var aim_room := ""
var aim_actor := ""

static func enabled() -> bool:
	return OS.has_feature("android") or OS.get_environment("AIU5_MOBILE_PREVIEW") == "1"

func start(controller: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; layer = 12; session = controller
	root = Control.new(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	movement = Joystick.new(); movement.position = Vector2(8,257); movement.size = Vector2(104,104); root.add_child(movement)
	navigation = Control.new(); navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(navigation)
	tools = Control.new(); tools.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tools)
	_button(root,"back","返回",Rect2(579,58,53,32))
	for row: Array in [["bag","背包"],["roster","角色"],["map","全图"],["switch","切换"],["more","更多"]]:
		var index: int = ["bag","roster","map","switch","more"].find(row[0])
		_button(navigation,row[0],row[1],Rect2(141+index*65,365,61,32))
	_button(root,"interact","交互",Rect2(559,272,70,40))
	# Attack is touch-only: tapping the world fires the shared combat action, so the
	# freed slot below "交互" is used by the run button instead.
	var run := _button(root,"run","奔跑",Rect2(548,318,81,43))
	run.down.connect(func() -> void: Input.action_press("run"))
	run.up.connect(func() -> void: Input.action_release("run"))
	var actions := [["till","耕地"],["plant","种/收"],["craft","制作"],["furnish","布置"],["upgrade","升级"],["empower","赋能"],["skill3","三级"],["skill4","四级"],["skill5","五级"],["branch","分支"],["sand","装沙"],["demolish","拆屋"],["apple","种果树"],["tutorial","教程"]]
	for i in range(actions.size()): _button(tools,actions[i][0],actions[i][1],Rect2(304+(i%4)*63,130+(i/4)*39,60,36))
	session.state_changed.connect(_present)
	_present(session.snapshot())
	var hud: Node = session.get_parent().get_node("HUD")
	for label: String in ["help_label","belongings_hint","skill_hint"]: hud.get(label).visible = false

func _button(parent: Node,id: String,caption: String,bounds: Rect2) -> Control:
	var button := TouchButton.new(); button.name = id; button.caption = caption; button.position = bounds.position; button.size = bounds.size
	parent.add_child(button); buttons[id] = button
	if id not in ["run","attack"]: button.activated.connect(func() -> void: dispatch(id))
	return button

func _present(_state: Dictionary) -> void:
	var modal: bool = session.overview or session.menu_paused or session.roster_open or session.inventory.opened or session.editor.opened or session.production.opened or session.attributes_id!="" or session.awakening_open or (is_instance_valid(session.gifts) and session.gifts.opened)
	var ceremony: bool = not session.tribes.romance.ceremony.is_empty()
	root.visible = not session.menu_paused and not ceremony
	movement.visible = not modal; navigation.visible = not modal
	buttons.interact.visible = not modal; buttons.run.visible = not modal
	tools.visible = expanded and not modal
	buttons.back.visible = not session.menu_paused and not ceremony
	if modal or ceremony:
		movement.release(); Input.action_release("run")
	var hud: Node = session.get_parent().get_node("HUD")
	for label: String in ["help_label","belongings_hint","skill_hint","view_label"]: hud.get(label).visible = false
	if aim_actor != session.world.active_resident.resident_id or aim_room != session.world.active_resident.room_id:
		aim = Vector2.INF

func release_all() -> void:
	if is_instance_valid(movement): movement.release()
	Input.action_release("run")
	for button: Control in buttons.values():
		if is_instance_valid(button): button.release()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or not event.pressed or not session.combat.ready_for_action(): return
	var actor: Node2D = session.world.active_resident
	aim = actor.get_canvas_transform().affine_inverse()*event.position; aim_room = actor.room_id; aim_actor = actor.resident_id
	session.combat.attack_clicked(aim)
	get_viewport().set_input_as_handled()

func target() -> Vector2:
	var actor: Node2D = session.world.active_resident
	if aim.is_finite() and aim_room == actor.room_id and aim_actor == actor.resident_id: return aim
	return actor.global_position+[Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][actor.facing]*65

func dispatch(action: String) -> void:
	if action == "back": back(); return
	if session.menu_paused or not session.tribes.romance.ceremony.is_empty(): return
	if action == "more": expanded = not expanded; _present(session.snapshot()); return
	if not session.combat.ready_for_action(): return
	session.simulation.flush()
	match action:
		"interact": session.interact()
		"attack":
			if aim.is_finite(): session.combat.attack_clicked(target())
			else: session.combat.fire(target())
		"bag": session.toggle_inventory()
		"roster": session.set_roster_open(true)
		"map": session.overview = true; session.world.set_overview(true); session.refresh_interface()
		"switch":
			for offset in range(1,session.world.controllable.size()+1):
				var index: int = posmod(session.selected+offset,session.world.controllable.size())
				if not session.world.controllable[index].dead: session.select_resident(index); break
		"furnish": session.toggle_furnishing()
		"tutorial": expanded=false;session.onboarding.review_features();session.refresh_interface()
		"apple": session.orchard.plant()
		"till": session.homestead.till(session.world.active_resident,session.grounds)
		"plant": session.homestead.cultivate(session.world.active_resident); session.persistence.save_now()
		"craft": session.production.open_near()
		"upgrade": session.production.open_upgrade()
		"empower": session.magic.skills.cast(2,target())
		"skill3": session.magic.skills.cast(3,target())
		"skill4": session.magic.skills.cast(4,target())
		"skill5": session.magic.skills.cast(5,target())
		"branch": session.magic.branches.cast(str(session.magic.ensure(session.world.active_resident.resident_id).branch_selected),target())
		"sand": session.production.gather_sand()
		"demolish": session.combat.demolish()

func back() -> void:
	release_all(); expanded = false
	if is_instance_valid(session.gifts) and session.gifts.opened: session.gifts.close()
	elif session.overview: session.overview = false; session.world.set_overview(false); session.refresh_interface()
	elif session.production.opened: session.production.close()
	elif session.awakening_open: session.close_awakening()
	elif session.attributes_id != "": session.close_attributes()
	elif session.inventory.opened: session.close_inventory()
	elif session.editor.opened:
		if is_instance_valid(session.editor.ghost): session.editor.cancel_selection()
		else: session.close_furnishing()
	elif session.roster_open: session.close_roster()
	else: session.pause_requested.emit()

func _exit_tree() -> void: release_all()
