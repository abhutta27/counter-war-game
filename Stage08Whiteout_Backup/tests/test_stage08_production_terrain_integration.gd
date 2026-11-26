extends SceneTree
## Stage 08 — Production Terrain Integration Verification Test.
## Validates the actual production Stage08 scene (res://scenes/stages/Stage08.tscn):
## - Sculpted alpine terrain and Trimesh collision
## - Distant sawtooth mountain horizon ranges
## - Player3D spawn in Valley Approach (Z=85.0, Y=2.24m)
## - All 12 Enemy3D instances solidly grounded on terrain physics
## - Tactical cover and Summit Radar installation placement
## - FPS and rendering performance verification
## - Visual verification screenshots saved to disk

const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const OUT_DIR := "res://verification_screenshots/stage08_terrain_integration/"

func _init() -> void:
	print("======================================================================")
	print("STAGE 08 — PRODUCTION TERRAIN INTEGRATION VERIFICATION")
	print("======================================================================")
	call_deferred("_run_verification")

func _run_verification() -> void:
	for _i in range(5):
		await process_frame

	print("[IntegrationTest] Loading production Stage08: %s" % STAGE_SCENE)
	var packed := load(STAGE_SCENE) as PackedScene
	assert(packed != null, "Failed to load " + STAGE_SCENE)

	var stage := packed.instantiate() as Node3D
	assert(stage != null, "Failed to instantiate Stage08")
	root.add_child(stage)
	current_scene = stage

	# Allow 15 frames for _ready, procedural generation, and initial setup
	for _f in range(15):
		await process_frame
		await physics_frame

	print("\n--- 1. SCENE ARCHITECTURE & TERRAIN VERIFICATION ---")
	assert(stage.stage_id == 8, "stage_id must be 8")
	assert(stage.stage_name == "OPERATION WHITEOUT", "stage_name must be 'OPERATION WHITEOUT'")
	print("PASS: Stage ID (%d) and Name (%s) verified." % [stage.stage_id, stage.stage_name])

	var env_node := stage.get_node_or_null("Environment")
	assert(env_node != null, "Environment node must exist")

	var terrain := env_node.get_node_or_null("SnowyAlpineTerrain") as MeshInstance3D
	assert(terrain != null, "SnowyAlpineTerrain mesh must exist under Environment")
	assert(terrain.material_override != null, "SnowyAlpineTerrain must have PBR ShaderMaterial")
	print("PASS: SnowyAlpineTerrain mesh and shader material verified.")

	# Check Trimesh collision
	var terrain_col := terrain.get_node_or_null("SnowyAlpineTerrain_col") as StaticBody3D
	assert(terrain_col != null, "SnowyAlpineTerrain_col StaticBody3D must exist for Trimesh collision")
	var col_shape := terrain_col.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(col_shape != null and col_shape.shape is ConcavePolygonShape3D, "Trimesh ConcavePolygonShape3D must exist")
	print("PASS: Precise Trimesh collision shape verified.")

	# Check distant mountain ranges
	for r in range(1, 4):
		var r_name := "DistantMountainRange_%02d" % r
		var range_mesh := env_node.get_node_or_null(r_name) as MeshInstance3D
		assert(range_mesh != null, "%s must exist under Environment" % r_name)
	print("PASS: All 3 distant sawtooth mountain horizon ranges verified.")

	# Check tactical cover and radar
	var cover := env_node.get_node_or_null("TacticalCover")
	assert(cover != null, "TacticalCover must exist under Environment")
	var radar := env_node.get_node_or_null("RadarInstallation")
	assert(radar != null, "RadarInstallation must exist under Environment")
	var plinth := radar.get_node_or_null("RadarPlinth")
	assert(plinth != null, "RadarPlinth must exist")
	print("PASS: Tactical cover and Summit Radar installation verified.")

	print("\n--- 2. PLAYER & ENEMY SPAWN GROUNDING VERIFICATION ---")
	var player = stage.get_node_or_null("Player3D") as CharacterBody3D
	assert(player != null, "Player3D must exist in Stage08")
	var p_pos: Vector3 = player.global_position
	print("Player Spawn Position: (%.3f, %.3f, %.3f)" % [p_pos.x, p_pos.y, p_pos.z])
	assert(p_pos.z >= 80.0, "Player must spawn in the southern valley approach (Z >= 80.0)")
	assert(p_pos.y >= 2.0, "Player Y must be at valley approach ground level (Y >= 2.0)")

	var enemies_container := stage.get_node_or_null("Enemies") as Node3D
	assert(enemies_container != null and enemies_container.get_child_count() == 12, "Enemies container must have 12 enemies")

	# Let physics simulate for 30 frames to allow gravity settling
	for _f in range(30):
		await process_frame
		await physics_frame

	var grounded_enemies := 0
	for enemy in enemies_container.get_children():
		var guard := enemy as CharacterBody3D
		if not guard:
			continue
		var on_floor := guard.is_on_floor()
		var y := guard.global_position.y
		var expected_y: float = stage.call("get_elevation", guard.global_position.x, guard.global_position.z)
		var drift := absf(y - expected_y)
		var stable := drift < 0.25
		if on_floor or stable:
			grounded_enemies += 1
		print("  %s: Pos=(%.2f, %.3f, %.2f) | Expected Ground=%.3f | Drift=%.3fm | OnFloor=%s" % [
			guard.name, guard.global_position.x, y, guard.global_position.z, expected_y, drift, str(on_floor)
		])

	assert(grounded_enemies == 12, "All 12 enemies must be firmly grounded on Trimesh collision (got %d/12)" % grounded_enemies)
	print("PASS: All 12 Enemy3D guards solidly grounded with zero fall-through!")

	var p_on_floor := player.is_on_floor()
	var p_expected: float = stage.call("get_elevation", player.global_position.x, player.global_position.z)
	var p_drift := absf(player.global_position.y - p_expected)
	print("Player final ground state: is_on_floor=%s, Drift=%.3fm" % [str(p_on_floor), p_drift])
	assert(p_on_floor or p_drift < 0.25, "Player must be firmly grounded on valley approach")
	print("PASS: Player3D grounded firmly on valley approach terrain!")

	print("\n--- 3. PERFORMANCE & FRAME RATE (FPS) BENCHMARK ---")
	var cpu_times: Array[float] = []
	var fps_readings: Array[float] = []
	for _f in range(60):
		await process_frame
		cpu_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		fps_readings.append(float(Performance.get_monitor(Performance.TIME_FPS)))

	var sum_cpu := 0.0
	var sum_fps := 0.0
	for i in range(cpu_times.size()):
		sum_cpu += cpu_times[i]
		sum_fps += fps_readings[i]
	var avg_cpu_ms := sum_cpu / float(cpu_times.size())
	var avg_fps := sum_fps / float(fps_readings.size())
	print("Engine Performance Benchmark (60 frames): Process CPU Time = %.2f ms | Engine FPS = %.1f FPS" % [avg_cpu_ms, avg_fps])

	print("\n--- 4. TACTICAL VISUAL CAPTURE ---")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 72.0
	stage.add_child(cam)

	var capture_views := [
		{
			"name": "01_production_player_valley_spawn.png",
			"pos": Vector3(0.0, 4.0, 91.0),
			"look": Vector3(0.0, 6.0, 30.0),
			"desc": "Player Valley Approach Spawn overlooking snow valley towards radar summit"
		},
		{
			"name": "02_production_valley_enemies_grounding.png",
			"pos": Vector3(14.0, 10.5, 48.0),
			"look": Vector3(0.0, 7.5, 32.0),
			"desc": "Lower Valley patrol sentinels (Enemy 1-4) firmly grounded on sculpted snow"
		},
		{
			"name": "03_production_mid_ridge_and_cover.png",
			"pos": Vector3(-18.0, 13.0, 5.0),
			"look": Vector3(0.0, 8.5, -18.0),
			"desc": "Mid-Ridge tactical plateau, outpost shack, barriers, and defile"
		},
		{
			"name": "04_production_summit_radar_sentinels.png",
			"pos": Vector3(0.0, 22.0, -52.0),
			"look": Vector3(0.0, 19.0, -78.0),
			"desc": "Commanding Summit Radar installation, plinth, and guarding sentinels"
		}
	]

	for v in capture_views:
		cam.global_position = v["pos"]
		cam.look_at(v["look"], Vector3.UP)
		for _w in range(4):
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		var out_path: String = OUT_DIR + v["name"]
		var err := img.save_png(out_path)
		assert(err == OK, "Failed to save screenshot: " + out_path)
		print("Saved screenshot: %s (%s)" % [out_path, v["desc"]])

	print("\n======================================================================")
	print("ALL PRODUCTION TERRAIN INTEGRATION VERIFICATIONS PASSED SUCCESSFULLY!")
	print("======================================================================")

	stage.queue_free()
	quit(0)
