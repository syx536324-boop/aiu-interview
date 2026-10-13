# Checks rendered opacity on all four sides and corners, preventing reversed or overlapping haze bands.
extends SceneTree
const Haze := preload("res://features/weather/haze.gd")
class BlankWorld extends Node2D:
	var camera: Camera2D
	var active_resident: Node2D
var directory := ""
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	create_timer(30,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var background := CanvasLayer.new()
	background.layer=-1
	var black := ColorRect.new()
	black.color=Color.BLACK
	black.size=Vector2(640,400)
	background.add_child(black); root.add_child(background)
	var world := BlankWorld.new()
	world.active_resident=Node2D.new()
	world.active_resident.position=Vector2(1100,-800)
	world.add_child(world.active_resident)
	world.camera=Camera2D.new()
	world.camera.position=world.active_resident.position
	world.camera.zoom=Vector2(1.3,1.3)
	world.add_child(world.camera)
	root.add_child(world); world.camera.make_current()
	var haze := Haze.new()
	world.add_child(haze); haze.start(world)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var width := float(image.get_width())
	var height := float(image.get_height())
	var outer_values: Array[float]=[]
	for i in range(3):
		var alpha: float=[0.9,0.7,0.4][i]
		var x := width*0.15*(float(i)+0.5)/3.0
		var y := height*0.15*(float(i)+0.5)/3.0
		var spots: Array[Vector2]=[Vector2(x,height/2),Vector2(width-1-x,height/2),Vector2(width/2,y),Vector2(width/2,height-1-y),Vector2(x,y),Vector2(width-1-x,height-1-y)]
		for point: Vector2 in spots:
			var pixel := image.get_pixel(int(point.x),int(point.y))
			var observed: float=pixel.r/Haze.HAZE_COLOUR.r
			check(absf(observed-alpha)<0.025,"actual band opacity %s at %s (observed %.3f)" % [alpha,point,observed])
		outer_values.append(image.get_pixel(int(x),int(height/2)).r)
	check(outer_values[0]>outer_values[1] and outer_values[1]>outer_values[2],"rendered haze gets less dense towards the center")
	check(image.get_pixel(int(width/2),int(height/2)).r<0.01,"center remains clear")
	check(image.save_png(directory+"/haze-opacity-grid.png")==OK,"rendered gradient saved")
	if failures.is_empty(): print("HAZE_PIXELS_OK checks=",checks); quit(0)
	else: print(failures); quit(1)
