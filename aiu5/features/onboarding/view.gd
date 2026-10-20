# Presents the onboarding service as a compact HUD card and a projected world-direction cue.
extends CanvasLayer
const InputHints := preload("res://features/interface/input_hints.gd")
var service: Node
var session: Node
var panel: PanelContainer
var title: Label
var detail: Label
var marker: Control
var marker_text: Label
var learn_button: Button
var fold_button: Button
var folded := false
var latest: Dictionary={}
var font := SystemFont.new()
class DirectionCue extends Control:
	var heading := Vector2.DOWN
	var offscreen := false
	func _draw() -> void:
		var center := Vector2(9,9)
		draw_circle(center,9,Color(0.14,0.11,0.06,0.92))
		if offscreen:
			var direction := heading.normalized()
			var side := Vector2(-direction.y,direction.x)
			draw_colored_polygon(PackedVector2Array([center+direction*6,center-direction*4+side*4,center-direction*4-side*4]),Color("ffdf82"))
		else:
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,5),center+Vector2(-5,-3),center+Vector2(5,-3)]),Color("ffdf82"))

func _ready() -> void:
	layer=2
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	panel=PanelContainer.new()
	panel.name="GuideCard"
	panel.position=Vector2(12,158)
	panel.size=Vector2(230,66)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.17,0.14,0.1,0.91)
	style.border_color=Color("bba36a")
	style.set_border_width_all(1)
	style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=5; style.content_margin_bottom=5
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",2)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	title=_label(heading,11,Color("ffe3a0"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fold_button=Button.new()
	fold_button.text="收起"
	fold_button.focus_mode=Control.FOCUS_NONE
	fold_button.add_theme_font_override("font",font)
	fold_button.add_theme_font_size_override("font_size",9)
	fold_button.add_theme_color_override("font_color",Color("ffe3a0"))
	fold_button.pressed.connect(_fold)
	heading.add_child(fold_button)
	detail=_label(column,10,Color("f2dfb8"))
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x=214
	learn_button=Button.new();learn_button.text="已了解";learn_button.focus_mode=Control.FOCUS_NONE
	learn_button.add_theme_font_override("font",font);learn_button.add_theme_font_size_override("font_size",10)
	learn_button.pressed.connect(func() -> void:service.acknowledge())
	column.add_child(learn_button)
	marker=DirectionCue.new()
	marker.name="GuideDirection"
	marker.size=Vector2(18,18)
	marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(marker)
	marker_text=_label(marker,9,Color("ffe3a0"))
	marker_text.position=Vector2(-22,19)
	marker_text.add_theme_constant_override("outline_size",3)
	marker_text.add_theme_color_override("font_outline_color",Color("31271d"))
	panel.visible=false; marker.visible=false

func _label(parent: Node, size: int, color: Color) -> Label:
	var text := Label.new()
	text.add_theme_font_override("font",font)
	text.add_theme_font_size_override("font_size",size)
	text.add_theme_color_override("font_color",color)
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(text)
	return text

func bind(domain: Node, controller: Node) -> void:
	service=domain; session=controller
	service.changed.connect(_refresh)
	session.state_changed.connect(_present)
	_present(session.snapshot())

func _refresh() -> void:
	if is_instance_valid(session): _present(session.snapshot())

func _fold() -> void:
	folded=not folded
	detail.visible=not folded
	fold_button.text="展开" if folded else "收起"
	panel.size=Vector2(230,28 if folded else 66)
	_refresh()

func _present(state: Dictionary) -> void:
	latest=service.presentation()
	var obscured: bool=state.overview or state.roster_open or state.inventory.open or state.furnishing.open or state.get("attributes",{}).get("open",false) or state.get("awakening",{}).get("open",false) or state.get("workshop",{}).get("open",false) or state.get("menu_paused",false) or (is_instance_valid(session.gifts) and session.gifts.opened) or (is_instance_valid(session.tribes) and not session.tribes.romance.ceremony.is_empty())
	panel.visible=bool(latest.visible) and not obscured
	learn_button.visible=not folded and int(latest.stage) in [4,5,6]
	detail.visible=not folded
	panel.custom_minimum_size=Vector2(230,28 if folded else (110 if int(latest.stage)>=4 else 66))
	panel.size=panel.custom_minimum_size
	title.text=str(latest.title)
	detail.text=InputHints.text(str(latest.text))
	if InputHints.mobile(): detail.text=detail.text.replace("B 背包","背包")
	marker.visible=panel.visible and not folded and not latest.target.is_empty()
	if not marker.visible: return
	var target: Vector2=latest.target.at
	var projected: Vector2=session.world.get_global_transform_with_canvas()*(target-Vector2(0,22))
	# Keep the cue beneath the top HUD and away from the controls/footer.
	var bounded := Vector2(clampf(projected.x,20,610),clampf(projected.y,156,290))
	if Rect2(8,154,242,75).has_point(bounded): bounded.y=240
	marker.position=bounded-Vector2(9,9)
	marker.offscreen=projected.distance_to(bounded)>2
	marker.heading=projected-bounded
	marker_text.text="%s %d像素" % [latest.target.label,int(latest.distance)]
	marker_text.position.x=clampf(24-bounded.x,-22,490-bounded.x)
	marker.queue_redraw()
