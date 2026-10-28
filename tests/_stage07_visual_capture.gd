extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage07.tscn")
const OUTPUT_DIR := "res://verification_screenshots/stage07_cinematic_design"

func _init() -> void:
	call_deferred("_run_test_and_capture")

func _run_test_and_capture() -> void:
	print("[Stage07Test] Initializing Stage 07 visual capture and runtime verification...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage

	for _frame in 12:
		await process_frame

	# Verify Stage 07 Basic Contract
	assert(stage.stage_id == 7, "Stage ID must be 7")
	assert(stage.stage_name == "OPERATION IRON HARBOR", "Stage name must be OPERATION IRON HARBOR")
	assert(stage.has_node("WorldEnvironment"), "WorldEnvironment must be present")
	assert(stage.has_node("MoonLight"), "MoonLight must be present")
	assert(stage.has_node("CinematicCamera"), "CinematicCamera must be present")
	assert(stage.has_node("Player3D"), "Player3D must be present")
	assert(stage.has_node("Environment"), "Environment must be present")

	print("[Stage07Test] Stage 07 nodes verified.")

	# Test Cinematic State at Start
	assert(stage.is_cinematic_active(), "Intro cinematic must be active upon stage start")
	assert(stage.cinematic_elapsed >= 0.0, "Cinematic elapsed time must be non-negative")
	var initial_cam_pos: Vector3 = stage.get_node("CinematicCamera").global_position
	print("[Stage07Test] Initial Cinematic Camera Pos: %s" % str(initial_cam_pos))

	# Advance frames to verify smooth camera motion
	for _frame in 20:
		await process_frame
	var progressed_cam_pos: Vector3 = stage.get_node("CinematicCamera").global_position
	assert(progressed_cam_pos != initial_cam_pos, "Cinematic camera must move over time")
	print("[Stage07Test] Cinematic Camera in-flight Pos: %s, Progress: %0.2f" % [str(progressed_cam_pos), stage.get_cinematic_progress()])

	# Capture Viewpoint 1: Cinematic establishing view
	var img1 := root.get_viewport().get_texture().get_image()
	img1.save_png("%s/01_cinematic_establishing_view.png" % OUTPUT_DIR)
	print("[Stage07Test] Saved 01_cinematic_establishing_view.png")

	# Test Skip Cinematic functionality
	stage.skip_cinematic()
	await process_frame
	assert(not stage.is_cinematic_active(), "Cinematic must be inactive after skip_cinematic()")
	var player = stage.get_node("Player3D")
	assert(player.is_active, "Player must be active after cinematic skip")
	print("[Stage07Test] PASS: Cinematic skip verified, player reactivated.")

	player.set_physics_process(false)
	var camera: Camera3D = player.get_node("Camera3D")
	camera.current = true

	# Viewpoints to capture full scope of the harbor
	var shots := [
		["02_player_spawn_view.png", Vector3(0, 0, 56), Vector3(0, 1.5, 30)],
		["03_container_yard_alpha.png", Vector3(-18, 0, 36), Vector3(-35, 2.5, 12)],
		["04_cargo_warehouse_07.png", Vector3(-24, 0, 18), Vector3(-42, 3.5, 4)],
		["05_east_watchtower_searchlight.png", Vector3(20, 0, 32), Vector3(44, 8.0, 26)],
		["06_enemy_command_center.png", Vector3(15, 0, -18), Vector3(34, 4.0, -32)],
		["07_quayside_sts_crane.png", Vector3(5, 0, -42), Vector3(16, 12.0, -57)],
		["08_moored_cargo_ship.png", Vector3(-12, 0, -52), Vector3(14, 5.0, -78)],
		["09_helipad_lz_charlie.png", Vector3(-20, 0, -36), Vector3(-36, 1.2, -48)],
		["10_night_tactical_panorama.png", Vector3(48, 18, 52), Vector3(-10, 4.0, -15)]
	]

	for shot in shots:
		player.global_position = shot[1]
		player.look_at(shot[2], Vector3.UP)
		camera.rotation = Vector3.ZERO
		for _frame in 6:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s" % [OUTPUT_DIR, shot[0]]
		var err := image.save_png(path)
		assert(err == OK, "Failed to save %s" % path)
		print("[Stage07Test] Saved %s" % path)

	print("[Stage07Test] ALL TESTS AND CAPTURES COMPLETED SUCCESSFULLY.")
	quit(0)
