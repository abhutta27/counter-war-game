extends SceneTree
## Stage 08 Isolated Spawn, Collision, Patrol, and Line-of-Sight Compatibility Test.
## Strictly runs in an isolated test environment without mutating production scenes.

const PROTO_SCENE := "res://scenes/prototypes/Stage08_SnowyAlpinePrototype.tscn"
const PLAYER_SCENE := preload("res://scenes/entities/Player3D.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/Enemy3D.tscn")
const OUT_DIR := "res://verification_screenshots/stage08_terrain_integration/"

func _init() -> void:
	call_deferred("_run_compatibility_test")

func _run_compatibility_test() -> void:
	print("======================================================================")
	print("STAGE 08 — ISOLATED SPAWN, COLLISION & PATROL COMPATIBILITY TEST")
	print("======================================================================")

	# 1. Instantiate the physical snowy alpine environment
	var packed := load(PROTO_SCENE) as PackedScene
	assert(packed != null, "Could not load " + PROTO_SCENE)
	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	# Remove prototype's default test player to test with clean real instances
	var proto_player = stage.get_node_or_null("Player3D")
	if proto_player:
		proto_player.queue_free()

	for _i in range(10):
		await process_frame

	var space_state := stage.get_world_3d().direct_space_state
	var terrain := stage.get_node_or_null("SnowyAlpineTerrain") as MeshInstance3D
	assert(terrain != null, "SnowyAlpineTerrain not found")

	# 2. Existing Production Spawns from Stage08.tscn
	var enemy_spawns := {
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

	var look_targets := {
		"Enemy3D_1": Vector3(10.0, 0.0, 20.0),
		"Enemy3D_2": Vector3(-11.0, 0.0, 20.0),
		"Enemy3D_3": Vector3(8.0, 0.0, 15.0),
		"Enemy3D_4": Vector3(0.0, 0.0, 20.0),
		"Enemy3D_5": Vector3(0.0, 6.0, -10.0),
		"Enemy3D_6": Vector3(12.0, 6.0, -26.0),
		"Enemy3D_7": Vector3(0.0, 6.0, -20.0),
		"Enemy3D_8": Vector3(-8.0, 6.0, -38.0),
		"Enemy3D_9": Vector3(0.0, 14.0, -67.0),
		"Enemy3D_10": Vector3(8.0, 14.0, -80.0),
		"Enemy3D_11": Vector3(0.0, 14.0, -78.0),
		"Enemy3D_12": Vector3(0.0, 14.0, -76.0)
	}

	# 3. Test Two Candidate Player Spawn Points in Valley
	# Candidate A: Current Stage08 Z=48.0
	# Candidate B: Lower Valley Approach Z=85.0 (Optimal natural vista)
	var player_candidates := {
		"Spawn_Current_Z48": Vector3(0.0, 50.0, 48.0),
		"Spawn_Valley_Z85": Vector3(0.0, 50.0, 85.0)
	}

	print("\n--- 1. REAL PHYSICAL RAYCAST GROUNDING RESULTS ---")
	var grounded_positions := {}

	# Find exact ground height using physical raycast on Trimesh collision
	for name in enemy_spawns.keys():
		var pos: Vector3 = enemy_spawns[name]
		var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, 60.0, pos.z), Vector3(pos.x, -30.0, pos.z))
		var hit := space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Failed to hit physical terrain at " + name)
		var ground_y: float = hit.position.y
		var normal: Vector3 = hit.normal
		var slope_angle_deg: float = rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		grounded_positions[name] = Vector3(pos.x, ground_y, pos.z)
		print("%s: Ground Y=%.3f (Normal Y=%.2f, Slope=%.1f deg) [Old was Y=%.1f, Diff=%+.2f m]" % [
			name, ground_y, normal.y, slope_angle_deg, pos.y, ground_y - pos.y
		])

	var player_grounded := {}
	for c_name in player_candidates.keys():
		var c_pos: Vector3 = player_candidates[c_name]
		var query := PhysicsRayQueryParameters3D.create(c_pos, Vector3(c_pos.x, -30.0, c_pos.z))
		var hit := space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Failed to hit terrain for " + c_name)
		player_grounded[c_name] = hit.position
		var slope_deg := rad_to_deg(acos(clampf(hit.normal.y, -1.0, 1.0)))
		print("%s: Physical Surface Ground Y=%.3f (Slope=%.1f deg)" % [c_name, hit.position.y, slope_deg])

	# 4. Instantiate and settle actual CharacterBody3D nodes on the Trimesh collision
	print("\n--- 2. REAL CHARACTERBODY3D PHYSICS & FLOOR SETTLING TEST ---")
	var spawned_enemies := {}
	for name in grounded_positions.keys():
		var enemy: CharacterBody3D = ENEMY_SCENE.instantiate() as CharacterBody3D
		enemy.name = name
		# Place precisely so feet (bottom of capsule at Y=0.0) touch ground surface (+2cm clearance)
		enemy.position = grounded_positions[name] + Vector3(0.0, 0.02, 0.0)
		stage.add_child(enemy)
		spawned_enemies[name] = enemy

	# Spawn real player at Candidate B (Valley Approach Z=85)
	var active_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	active_player.name = "Player3D_Active"
	active_player.position = player_grounded["Spawn_Valley_Z85"] + Vector3(0.0, 0.05, 0.0)
	stage.add_child(active_player)

	# Step physics for 20 frames so gravity and move_and_slide / collisions settle
	for _f in range(25):
		await process_frame

	var total_settled_ok := 0
	for name in spawned_enemies.keys():
		var enemy: CharacterBody3D = spawned_enemies[name]
		var on_floor := enemy.is_on_floor()
		var y_diff := absf(enemy.global_position.y - grounded_positions[name].y)
		var is_stable := y_diff < 0.25
		if on_floor or is_stable:
			total_settled_ok += 1
		print("%s: is_on_floor=%s, Final Y=%.3f (Settled drift: %.3fm)" % [
			name, str(on_floor), enemy.global_position.y, y_diff
		])

	print("[PHYSICS TEST] %d / 12 enemies successfully settled firmly on Trimesh terrain!" % total_settled_ok)

	# 5. Combat Distance and Early Detection Analysis
	print("\n--- 3. COMBAT DISTANCE & SIGHTLINE (LOS) ANALYSIS ---")
	var p_pos: Vector3 = active_player.global_position
	print("Active Player Spawn Position: (%.2f, %.2f, %.2f)" % [p_pos.x, p_pos.y, p_pos.z])

	for name in spawned_enemies.keys():
		var enemy: CharacterBody3D = spawned_enemies[name]
		var e_pos: Vector3 = enemy.global_position
		var dist := p_pos.distance_to(e_pos)
		var elevation_gap := absf(e_pos.y - p_pos.y)

		# Raycast check from enemy eye (1.35m) to player chest (1.25m)
		var los_query := PhysicsRayQueryParameters3D.create(
			e_pos + Vector3.UP * 1.35,
			p_pos + Vector3.UP * 1.25,
			1,
			[enemy.get_rid(), active_player.get_rid()]
		)
		var los_hit := space_state.intersect_ray(los_query)
		var has_los := los_hit.is_empty() # empty means unblocked line of sight between enemy and player
		var los_status: String = "CLEAR LINE OF SIGHT"
		if not has_los:
			var col_name: String = str(los_hit.collider.name) if los_hit.collider else "terrain"
			los_status = "BLOCKED by " + col_name

		print("%s: Dist=%.1fm, ElevGap=%.1fm | %s" % [name, dist, elevation_gap, los_status])

	# 6. Check Patrol / Look Target Orientation
	print("\n--- 4. PATROL / LOOK TARGET ANALYSIS ---")
	for name in look_targets.keys():
		var enemy: CharacterBody3D = spawned_enemies[name]
		var raw_target: Vector3 = look_targets[name]
		# Find terrain surface at look target
		var lquery := PhysicsRayQueryParameters3D.create(Vector3(raw_target.x, 60.0, raw_target.z), Vector3(raw_target.x, -30.0, raw_target.z))
		var lhit := space_state.intersect_ray(lquery)
		var target_y: float = float(lhit.position.y) if not lhit.is_empty() else float(raw_target.y)
		var adjusted_target := Vector3(raw_target.x, target_y, raw_target.z)
		
		# Check vector from enemy to look target
		var dir := (adjusted_target - enemy.global_position).normalized()
		var pitch_deg := rad_to_deg(asin(clampf(dir.y, -1.0, 1.0)))
		print("%s -> LookTarget (%.1f, %.1f, %.1f): Pitch=%.1f deg" % [
			name, adjusted_target.x, adjusted_target.y, adjusted_target.z, pitch_deg
		])

	# 7. Capture High-Resolution Tactical Verification Screenshots
	print("\n--- 5. CAPTURING VERIFICATION SCREENSHOTS ---")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.make_current()

	# Screenshot 1: Valley Spawn & Grounding View
	cam.position = Vector3(0.0, 8.5, 95.0)
	cam.look_at(Vector3(0.0, 5.0, 40.0), Vector3.UP)
	for _i in range(10):
		await process_frame
	var img1 := root.get_viewport().get_texture().get_image()
	if img1:
		img1.save_png(OUT_DIR + "01_valley_spawn_grounding.png")
		print("[PASS] Saved: " + OUT_DIR + "01_valley_spawn_grounding.png")

	# Screenshot 2: Mid-Ridge Patrol Overlook
	cam.position = Vector3(-15.0, 15.0, 5.0)
	cam.look_at(Vector3(2.0, 8.0, -18.0), Vector3.UP)
	for _i in range(10):
		await process_frame
	var img2 := root.get_viewport().get_texture().get_image()
	if img2:
		img2.save_png(OUT_DIR + "02_mid_ridge_patrol_los.png")
		print("[PASS] Saved: " + OUT_DIR + "02_mid_ridge_patrol_los.png")

	# Screenshot 3: High Summit Sentinels
	cam.position = Vector3(0.0, 24.0, -45.0)
	cam.look_at(Vector3(0.0, 17.0, -75.0), Vector3.UP)
	for _i in range(10):
		await process_frame
	var img3 := root.get_viewport().get_texture().get_image()
	if img3:
		img3.save_png(OUT_DIR + "03_summit_radar_sentinels.png")
		print("[PASS] Saved: " + OUT_DIR + "03_summit_radar_sentinels.png")

	# Screenshot 4: Full Tactical Route & Sightlines Overview
	cam.position = Vector3(-45.0, 45.0, 80.0)
	cam.look_at(Vector3(0.0, 10.0, -20.0), Vector3.UP)
	for _i in range(10):
		await process_frame
	var img4 := root.get_viewport().get_texture().get_image()
	if img4:
		img4.save_png(OUT_DIR + "04_tactical_los_route_overview.png")
		print("[PASS] Saved: " + OUT_DIR + "04_tactical_los_route_overview.png")

	print("\n======================================================================")
	print("[PASS] COMPATIBILITY TEST COMPLETE: All data and screenshots generated.")
	print("======================================================================")
	quit(0)
