# Verifies main-scene river/bridge physics and layering; captures actual forest crossings.
extends "res://tests/npc_attitude_probe.gd"
const Frontier := preload("res://features/landscape/frontier.gd")
const Water := preload("res://features/landscape/layout.gd")

func run() -> void:
	await fresh_game()
	var player: CharacterBody2D=s.world.active_resident
	for npc: Node in s.combat.enemies.values(): npc.collision_layer=0
	for resident: Node in s.world.residents:
		if resident!=player: resident.collision_layer=0
	# Body masks still include the actual static channels, river junctions and terrain.
	for y: float in Water.BRIDGES:
		var bounds: Rect2=Water.bridge_bounds(y)
		player.position=Vector2(bounds.position.x-10,y+3)
		s._sync_view(); await get_tree().physics_frame
		player.move_and_collide(Vector2(bounds.size.x+20,0))
		check(player.position.x>bounds.end.x,"main river bridge allows surface passage at "+str(y))
		player.position=Vector2(bounds.position.x-10,y+40)
		await get_tree().physics_frame
		player.move_and_collide(Vector2(bounds.size.x+20,0))
		check(player.position.x<bounds.end.x,"water alongside main bridge cannot be crossed at "+str(y))
	var index := 0
	for segment: Dictionary in Frontier.river_segments():
		var normal: Vector2=segment.direction.orthogonal()
		player.position=segment.mid-normal*32+Vector2(0,3)
		s._sync_view(); await get_tree().physics_frame
		player.move_and_collide(normal*64)
		check((player.position-segment.mid).dot(normal)>18,"forest bridge has a real open crossing "+str(index))
		var beside: Vector2=segment.mid+segment.direction*54
		player.position=beside-normal*32+Vector2(0,3)
		await get_tree().physics_frame
		player.move_and_collide(normal*64)
		check((player.position-beside).dot(normal)<0,"forest river blocks traversal beside its bridge "+str(index))
		if index==0 and DisplayServer.get_name()!="headless":
			player.position=segment.mid+Vector2(0,3)
			s._sync_view(); await frames(6)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory+"/forest-bridge.png")
		index+=1
	var landscape: Node=game.get_node("Landscape")
	check(landscape.view.get_index()<s.world.objects.get_index(),"main river is rendered before the y-sorted characters")
	var frontier: Node
	for child: Node in s.world.get_children():
		if child.get_script()==Frontier: frontier=child
	check(is_instance_valid(frontier) and frontier.get_index()<s.world.objects.get_index(),"forest bridge surface is rendered below characters")
	if failures.is_empty(): print("WORLD_COMPLETION_OK checks=",checks)
	finish()
