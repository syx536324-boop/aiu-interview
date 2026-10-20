# Adapts the Android on-device camera plugin to the unchanged gift snapshot contract.
extends Node
signal updated(data: Dictionary)
var plugin: Object
var session_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("AiuGiftCamera"):
		plugin = Engine.get_singleton("AiuGiftCamera")
		plugin.connect("camera_snapshot",_snapshot)

func open(id: String) -> void:
	close(); session_id = id
	if not is_instance_valid(plugin):
		updated.emit({"session_id":id,"status":"error","message":"未找到安卓摄像头组件，请重新安装完整APK。"})
		return
	plugin.openCamera(id)

func _snapshot(payload: String) -> void:
	var data: Variant = JSON.parse_string(payload)
	if data is Dictionary and str(data.get("session_id","")) == session_id: updated.emit(data)

func close() -> void:
	session_id = ""
	if is_instance_valid(plugin): plugin.closeCamera()

func _exit_tree() -> void: close()
