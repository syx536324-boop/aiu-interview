# Starts one local Python camera process and asynchronously polls its private JSON preview contract.
extends Node
signal updated(data: Dictionary)
var request: HTTPRequest
var cleanup: HTTPRequest
var pid := -1
var retiring: Array = []
var token := ""
var session_id := ""
var base_url := ""
var busy := false
var poll_left := 0.0
var started_at := 0

# Exported games use physical sidecar assets beside AIU5.exe, never paths inside the PCK.
func asset_path(path: String) -> String:
	if path.begins_with("res://") and not OS.has_feature("editor"):
		return OS.get_executable_path().get_base_dir().path_join(path.trim_prefix("res://"))
	return ProjectSettings.globalize_path(path)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	request = HTTPRequest.new()
	request.timeout = 2
	request.body_size_limit = 1500000
	add_child(request)
	request.request_completed.connect(_completed)
	cleanup = HTTPRequest.new()
	cleanup.timeout = 1
	add_child(cleanup)

func open(id: String) -> void:
	close()
	session_id = id
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(asset_path("res://services/gift_camera/config.json")))
	if not config is Dictionary: return _error("摄像头配置无法读取。")
	var python := OS.get_environment("AIU5_CAMERA_PYTHON")
	if python == "": python = asset_path(str(config.get("python", "res://runtime/pythonw.exe")))
	var model := asset_path(str(config.get("model", "res://models/gifts18-prototype-v1.pt")))
	if not FileAccess.file_exists(python): return _error("未找到随应用安装的摄像头运行环境，请重新安装应用或设置AIU5_CAMERA_PYTHON。")
	if not FileAccess.file_exists(model): return _error("未找到首版模型文件。")
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	var port := randi_range(18000, 48000)
	base_url = "http://127.0.0.1:%d" % port
	var log_path := ProjectSettings.globalize_path("user://camera-gifts.log")
	if OS.get_environment("AIU5_CAMERA_LOG") != "": log_path = OS.get_environment("AIU5_CAMERA_LOG")
	var arguments := PackedStringArray([asset_path("res://services/gift_camera/server.py"), "--port",str(port),"--token",token,"--session",id,"--model",model,"--parent",str(OS.get_process_id()),"--camera",str(int(config.get("camera",0))),"--log",log_path])
	pid = OS.create_process(python, arguments, false)
	if pid <= 0: return _error("摄像头服务启动失败，请关闭后重试。")
	started_at = Time.get_ticks_msec()
	poll_left = 0.2

func _error(text: String) -> void:
	updated.emit({"session_id":session_id,"status":"error","message":text})

func _process(delta: float) -> void:
	for retiring_process: Dictionary in retiring.duplicate():
		if not OS.is_process_running(int(retiring_process.pid)):
			retiring.erase(retiring_process)
		elif Time.get_ticks_msec() > int(retiring_process.deadline):
			OS.kill(int(retiring_process.pid))
			retiring.erase(retiring_process)
	if pid <= 0 or busy: return
	if not OS.is_process_running(pid):
		pid = -1
		_error("摄像头服务已退出，请关闭后重试。")
		return
	poll_left -= delta
	if poll_left > 0: return
	poll_left = 0.25
	busy = true
	var error := request.request(base_url+"/snapshot", PackedStringArray(["X-AIU5-Token: "+token]))
	if error != OK: busy = false

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if pid <= 0: return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if Time.get_ticks_msec()-started_at > 20000: _error("摄像头服务连接超时，请关闭后重试。")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary: updated.emit(data)

func close() -> void:
	if is_instance_valid(request): request.cancel_request()
	busy = false
	if pid > 0:
		if is_instance_valid(cleanup):
			cleanup.cancel_request()
			cleanup.request(base_url+"/stop",PackedStringArray(["X-AIU5-Token: "+token]),HTTPClient.METHOD_POST)
		retiring.append({"pid":pid,"deadline":Time.get_ticks_msec()+3000})
	pid = -1
	session_id = ""

func _exit_tree() -> void:
	if pid > 0: OS.kill(pid)
	for retiring_process: Dictionary in retiring:
		if OS.is_process_running(int(retiring_process.pid)): OS.kill(int(retiring_process.pid))
