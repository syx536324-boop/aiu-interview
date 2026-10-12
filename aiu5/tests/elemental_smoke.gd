# Launches the shared skill probe in the editor runtime; the Node probe also runs from installed releases.
extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.add_child(load("res://tests/elemental_probe.gd").new())
