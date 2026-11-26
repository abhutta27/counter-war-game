extends SceneTree
## Automated diagnostic test verifying Terrain Collision vs Current Stage08 Spawns.

const PROTO_SCENE := "res://scenes/prototypes/Stage08_SnowyAlpinePrototype.tscn"
const OUT_DIR := "res://verification_screenshots/stage08_terrain_integration/"

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================")
	print("STAGE 08 TERRAIN COLLISION & SPAWN COMPATIBILITY TEST")
	print("==================================================")

	var packed := load(PROTO_SCENE) as PackedScene
	assert(packed != null, "Failed to load prototype scene.")
	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	for _i in range(15):
		await process_frame

	var terrain := stage.get_node_or_null("SnowyAlpineTerrain") as MeshInstance3D
	assert(terrain != null, "SnowyAlpineTerrain must exist.")

	var col_child := terrain.get_node_or_null("SnowyAlpineTerrain_col")
	# In Godot, create_trimesh_collision() creates a StaticBody3D child
	var has_col := false
	for child in terrain.get_children():
		if child is StaticBody3D:
			has_col = true
			break
	assert(has_col, "Terrain must have StaticBody3D collision shape.")
	print("[PASS] Terrain Trimesh Collision verified.")

	# Current Stage08 coordinates
	var current_spawns := {
		"Player3D": Vector3(0.0, 0.2, 48.0),
		"Enemy3D_1": Vector3(10.0, 0.0, 38.0),
		"Enemy3D_2": Vector3(-11.0, 0.0, 35.0),
		"Enemy3D_3": Vector3(8.0, 0.0, 28.0),
		"Enemy3D_4": Vector3(-10.0, 0.0, 24.0),
		"Enemy3D_5": Vector3(-10.0, 6.0, -10.0),
		"Enemy3D_6": Vector3(12.0, 6.0, -14.0),
		"Enemy3D_7": Vector3(8.0, 6.0, -20.0),
		"Enemy3D_8": Vector3(-8.0, 6.0, -28.0),
		"Enemy3D_9": Vector3(-8.0, 14.0, -67.0),
		"Enemy3D_10": Vector3(8.0, 14.0, -69.0),
		"Enemy3D_11": Vector3(-9.0, 14.0, -78.0),
		"Enemy3D_12": Vector3(12.0, 14.0, -76.0)
	}

	print("\n[DIAGNOSTIC] Checking collision height vs current Stage08 spawns:")
	var space := stage.get_world_3d().direct_space_state
	var total_buried := 0

	for name in current_spawns.keys():
		var pos: Vector3 = current_spawns[name]
		# Raycast downwards from 50m above the position to find physical surface
		var ray_from := Vector3(pos.x, 50.0, pos.z)
		var ray_to := Vector3(pos.x, -20.0, pos.z)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var hit := space.intersect_ray(query)

		if hit:
			var surface_y: float = hit.position.y
			var diff := surface_y - pos.y
			var status := "BURIED UNDERGROUND" if diff > 0.3 else ("FLOATING IN AIR" if diff < -0.3 else "GROUNDED")
			if diff > 0.3:
				total_buried += 1
			print(" -> %s: Pos Y=%.2f | Surface Y=%.2f | Gap=%+.2f m [%s]" % [name, pos.y, surface_y, diff, status])
		else:
			print(" -> %s: Pos=(%.1f, %.1f) NO SURFACE HIT!" % [name, pos.x, pos.z])

	print("\n[RESULT] Spawns buried under new terrain collision: %d of %d" % [total_buried, current_spawns.size()])

	# Capture Screenshot 1: Overview
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 25.0, 80.0)
	cam.look_at(Vector3(0.0, 10.0, -10.0), Vector3.UP)
	stage.add_child(cam)
	cam.make_current()

	for _i in range(10):
		await process_frame

	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		img.save_png(OUT_DIR + "01_terrain_overview_collision.png")
		print("[PASS] Saved screenshot: " + OUT_DIR + "01_terrain_overview_collision.png")

	# Capture Screenshot 2: Spawn Valley
	cam.position = Vector3(0.0, 8.0, 60.0)
	cam.look_at(Vector3(0.0, 5.0, 30.0), Vector3.UP)
	for _i in range(10):
		await process_frame

	var img2 := vp.get_texture().get_image()
	if img2:
		img2.save_png(OUT_DIR + "02_valley_spawn_collision_area.png")
		print("[PASS] Saved screenshot: " + OUT_DIR + "02_valley_spawn_collision_area.png")

	quit(0)
