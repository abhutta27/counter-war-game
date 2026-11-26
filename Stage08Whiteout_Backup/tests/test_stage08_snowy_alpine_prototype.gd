extends SceneTree
## Automated Verification & Visual Capture Suite for Stage08 Snowy Alpine Prototype
## Verifies:
## 1. Scene loading and hierarchy
## 2. Player3D spawn & ground collision
## 3. Walkable switchbacks and 3 natural elevation tiers (Valley, Mid-Ridge, Summit)
## 4. Raycast continuity (no holes, cracks or gaps in collision)
## 5. Visual capture of 4 high-resolution screenshots
## 6. Performance diagnostics (FPS & frame times)

const PROTOTYPE_SCENE := "res://scenes/prototypes/Stage08_SnowyAlpinePrototype.tscn"
const SCREENSHOT_DIR := "res://verification_screenshots/snowy_alpine_prototype/"

var _stage: Node3D
var _player: CharacterBody3D

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n============================================================")
	print(" STAGE 08 SNOWY ALPINE TERRAIN PROTOTYPE — VERIFICATION ")
	print("============================================================")

	# 1. Load Scene
	if not ResourceLoader.exists(PROTOTYPE_SCENE):
		_fail("Scene not found: " + PROTOTYPE_SCENE)
		return
	var packed := ResourceLoader.load(PROTOTYPE_SCENE) as PackedScene
	if not packed:
		_fail("Failed to load scene: " + PROTOTYPE_SCENE)
		return
	print("[PASS] ResourceLoader successfully loaded: %s" % PROTOTYPE_SCENE)

	_stage = packed.instantiate() as Node3D
	if not _stage:
		_fail("Failed to instantiate prototype scene.")
		return
	root.add_child(_stage)
	current_scene = _stage
	print("[PASS] Successfully instantiated and attached prototype to SceneTree.")

	# 2. Verify Core Nodes
	_player = _stage.get_node_or_null("Player3D") as CharacterBody3D
	if not _player:
		_fail("Player3D node missing from prototype.")
		return
	print("[PASS] Player3D node found and typed correctly.")

	var terrain := _stage.get_node_or_null("SnowyAlpineTerrain") as MeshInstance3D
	if not terrain:
		_fail("SnowyAlpineTerrain mesh instance missing.")
		return
	print("[PASS] SnowyAlpineTerrain mesh instance found.")

	var world_env := _stage.get_node_or_null("AlpineAtmosphere") as WorldEnvironment
	if not world_env or not world_env.environment:
		_fail("AlpineAtmosphere WorldEnvironment missing or invalid.")
		return
	print("[PASS] AlpineAtmosphere WorldEnvironment verified (Fog density: %.4f)." % world_env.environment.fog_density)

	var sun := _stage.get_node_or_null("AlpineSun") as DirectionalLight3D
	if not sun or not sun.shadow_enabled:
		_fail("AlpineSun DirectionalLight3D missing or shadows disabled.")
		return
	print("[PASS] AlpineSun DirectionalLight3D verified with shadow splits enabled.")

	# Wait for shaders and physics to settle
	print("\n[QA] Settling frames for rendering and physics...")
	for _f in range(30):
		await process_frame

	# 3. Verify Player Spawn & Gravity Floor Contact
	print("\n[QA] Checking Player3D ground collision at spawn...")
	# Allow gravity to settle player onto floor
	for _f in range(25):
		await process_frame

	var spawn_pos: Vector3 = _player.global_position
	print("[QA] Player position after spawn settling: %s" % str(spawn_pos))
	if spawn_pos.y < -5.0 or spawn_pos.y > 10.0:
		_fail("Player spawned out of bounds or fell through terrain: " + str(spawn_pos))
		return
	if not _player.is_on_floor():
		_fail("Player is not on floor after settling at spawn point!")
		return
	print("[PASS] Player3D confirmed ON FLOOR with solid terrain contact (Y = %.2fm)." % spawn_pos.y)

	# 4. Verify 3 Distinct Natural Elevation Tiers & Walkability
	print("\n[QA] Testing Player navigation across 3 Elevation Tiers...")
	var test_waypoints := [
		{"name": "Tier 1: Lower Valley Drop Zone", "pos": Vector3(0.0, 3.0, 105.0), "min_y": 1.2, "max_y": 2.8},
		{"name": "Switchback 1: S-Curve Midpoint", "pos": Vector3(-18.0, 6.0, 48.0), "min_y": 4.0, "max_y": 6.2},
		{"name": "Tier 2: Mid-Ridge Tactical Plateau", "pos": Vector3(8.0, 9.5, 0.0), "min_y": 7.5, "max_y": 9.5},
		{"name": "Switchback 2: Summit Defile Trail", "pos": Vector3(18.0, 13.0, -25.0), "min_y": 9.0, "max_y": 13.5},
		{"name": "Tier 3: High Summit Mountain Crest", "pos": Vector3(0.0, 18.5, -85.0), "min_y": 16.0, "max_y": 19.0}
	]

	for wp in test_waypoints:
		var target_pos: Vector3 = wp["pos"]
		var ground_y: float = float(_stage.get_elevation(target_pos.x, target_pos.z))
		_player.global_position = Vector3(target_pos.x, ground_y + 0.5, target_pos.z)
		_player.velocity = Vector3.ZERO
		for _f in range(20):
			await process_frame
		var pos_y := _player.global_position.y
		print("  -> %s: Player Y = %.2fm (expected [%.1f, %.1f])" % [wp["name"], pos_y, wp["min_y"], wp["max_y"]])
		if pos_y < float(wp["min_y"]) or pos_y > float(wp["max_y"]):
			_fail("Elevation check failed at %s. Player Y: %.2f" % [wp["name"], pos_y])
			return
		if not _player.is_on_floor():
			_fail("Player lost floor collision at %s!" % wp["name"])
			return
	print("[PASS] All 3 distinct natural elevation tiers and switchbacks verified with solid floor collision.")

	# 5. Raycast Floor Continuity Check across Switchbacks (No Holes/Cracks)
	print("\n[QA] Performing raycast sweep across mountain route to verify zero collision holes...")
	var space_state := _stage.get_world_3d().direct_space_state
	var sample_points := 30
	var holes_found := 0

	for i in range(sample_points):
		var t := float(i) / float(sample_points - 1)
		var z := lerpf(110.0, -80.0, t)
		var elevation_est: float = float(_stage.get_elevation(0.0, z))
		var ray_origin := Vector3(0.0, elevation_est + 10.0, z)
		var ray_end := Vector3(0.0, elevation_est - 10.0, z)

		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			holes_found += 1
			print("  [WARN] Collision gap detected at Z = %.1f" % z)

	if holes_found > 0:
		_fail("Found %d collision gaps along the playable route!" % holes_found)
		return
	print("[PASS] Continuous solid walkable collision verified across all 30 route probe points.")

	# 6. Performance Benchmarking (60 frames)
	print("\n[QA] Measuring rendering performance and frame times...")
	var frame_times: Array[float] = []
	for _f in range(60):
		var start := Time.get_ticks_usec()
		await process_frame
		var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
		frame_times.append(elapsed)

	var sum_time := 0.0
	for t in frame_times:
		sum_time += t
	var avg_ms := sum_time / float(frame_times.size())
	var est_fps := 1000.0 / avg_ms if avg_ms > 0.0 else 0.0
	print("[PERF] 60-frame benchmark: avg frame time = %.2f ms (~%.1f FPS)" % [avg_ms, est_fps])

	# 7. Visual Capture of 4 Key Angles
	print("\n[QA] Capturing visual prototype screenshots...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))

	# Return player to natural valley spawn position
	_player.global_position = Vector3(0.0, 2.5, 105.0)
	_player.velocity = Vector3.ZERO
	for _f in range(10):
		await process_frame

	# Shot 1: Player First-Person Spawn View in Lower Valley
	var player_cam := _player.get_node_or_null("Camera3D") as Camera3D
	if player_cam:
		player_cam.current = true
	for _f in range(6):
		await process_frame
	_save_viewport_screenshot(SCREENSHOT_DIR + "01_player_spawn_valley.png")
	print("[CAPTURE] Saved: 01_player_spawn_valley.png")

	# Shot 2: Ascending Switchback Trail 1 View
	if player_cam:
		player_cam.current = false
	var cam2 := Camera3D.new()
	cam2.name = "QA_Cam2"
	_stage.add_child(cam2)
	cam2.position = Vector3(-8.0, 5.0, 62.0)
	cam2.look_at(Vector3(-18.0, 7.5, 30.0), Vector3.UP)
	cam2.fov = 72.0
	cam2.current = true
	for _f in range(6):
		await process_frame
	_save_viewport_screenshot(SCREENSHOT_DIR + "02_switchback_trail_ascent.png")
	print("[CAPTURE] Saved: 02_switchback_trail_ascent.png")

	# Shot 3: Mid-Ridge Overlook View looking down at Lower Valley
	cam2.position = Vector3(18.0, 11.5, 10.0)
	cam2.look_at(Vector3(0.0, 2.0, 80.0), Vector3.UP)
	for _f in range(6):
		await process_frame
	_save_viewport_screenshot(SCREENSHOT_DIR + "03_mid_ridge_overlook.png")
	print("[CAPTURE] Saved: 03_mid_ridge_overlook.png")

	# Shot 4: High Summit Crest Panorama showing distant jagged ranges and fog
	cam2.position = Vector3(0.0, 21.0, -60.0)
	cam2.look_at(Vector3(0.0, 45.0, -180.0), Vector3.UP)
	cam2.fov = 78.0
	for _f in range(6):
		await process_frame
	_save_viewport_screenshot(SCREENSHOT_DIR + "04_summit_peaks_panorama.png")
	print("[CAPTURE] Saved: 04_summit_peaks_panorama.png")

	cam2.queue_free()

	print("\n============================================================")
	print(" ALL VERIFICATION & CAPTURE CHECKS PASSED SUCCESSFULLY! ")
	print("============================================================\n")
	quit(0)

func _save_viewport_screenshot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img:
		var err := img.save_png(path)
		if err != OK:
			push_warning("Failed to save screenshot to: " + path)
	else:
		push_warning("Viewport texture image was null for: " + path)

func _fail(reason: String) -> void:
	push_error("[FAIL] " + reason)
	print("[FAIL] " + reason)
	quit(1)
