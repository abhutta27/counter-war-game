extends SceneTree
## Stage 08 Dedicated Gameplay HUD Automated QA & Visual Verification
## Tests Compass, Dynamic Waypoint Distance, and Objective Checklist end-to-end.

const IDENTITY_SCENE := "res://scenes/IdentityScreen.tscn"
const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"
const OUT_DIR := "res://verification_screenshots/stage08_hud"

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("================================================================")
	print(">>> STAGE 08 DEDICATED GAMEPLAY HUD AUTOMATED QA SUITE <<<")
	print("================================================================")
	
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# 1. Boot stage directly to test HUD in-depth
	var packed := load(STAGE08_SCENE) as PackedScene
	assert(packed != null, "Failed to load Stage 08 scene.")
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage

	for _i in range(25):
		await process_frame

	print("[QA 1] Stage08 instantiated with dedicated HUD elements.")

	var hud: CanvasLayer = stage.get_node_or_null("HUD") as CanvasLayer
	assert(hud != null, "HUD node missing in Stage08")

	# Check presence of new Stage 08 dedicated elements
	var compass_bar := hud.get_node_or_null("Stage08CompassBar") as PanelContainer
	var waypoint_bar := hud.get_node_or_null("Stage08WaypointBar") as PanelContainer
	var checklist_panel := hud.get_node_or_null("Stage08ChecklistPanel") as PanelContainer

	assert(compass_bar != null and compass_bar.visible, "Stage08CompassBar must be present and visible")
	assert(waypoint_bar != null and waypoint_bar.visible, "Stage08WaypointBar must be present and visible")
	assert(checklist_panel != null and checklist_panel.visible, "Stage08ChecklistPanel must be present and visible")
	print("[PASS 1] Compass Bar, Waypoint Bar, and Checklist Panel confirmed present on HUD.")

	var player = stage.get_node_or_null("Player3D")
	assert(player != null, "Player3D node missing")
	var cam: Camera3D = player.get_node_or_null("Camera3D") as Camera3D
	assert(cam != null, "Camera3D node missing on Player3D")

	# Neutralize guards for testing compass and movement safely
	var enemies := stage.get_node_or_null("Enemies") as Node3D
	if enemies:
		for e in enemies.get_children():
			if "is_dead" in e:
				e.is_dead = true
			e.set_physics_process(false)

	# -------------------------------------------------------------------------
	# 2. Test Compass Orientation & Dynamic Updates
	# -------------------------------------------------------------------------
	print("\n[QA 2] Testing Compass Orientation and Rotation Updates...")
	for _i in range(5):
		await process_frame

	var heading_lbl := compass_bar.find_child("CompassHeading", true, false) as Label
	var tape_lbl := compass_bar.find_child("CompassTape", true, false) as Label
	assert(heading_lbl != null, "CompassHeading label missing")
	assert(tape_lbl != null, "CompassTape label missing")

	var initial_deg: float = stage.get_compass_heading_degrees()
	print("[PASS 2] Initial Heading: '", heading_lbl.text, "' (", initial_deg, "°), Tape: '", tape_lbl.text, "'")
	_save_shot(OUT_DIR + "/01_stage08_hud_spawn_compass_checklist.png")

	# Rotate camera 90 degrees to East
	cam.global_rotation = Vector3(0.0, -PI * 0.5, 0.0)
	for _i in range(10):
		await process_frame
	var east_deg: float = stage.get_compass_heading_degrees()
	print("[PASS 2] Rotated East: '", heading_lbl.text, "' (", east_deg, "°)")
	assert(absf(east_deg - 90.0) < 5.0 or "E" in heading_lbl.text, "Heading must reflect East (90 deg)")
	_save_shot(OUT_DIR + "/02_stage08_hud_rotated_compass.png")

	# Rotate camera to North
	cam.global_rotation = Vector3(0.0, 0.0, 0.0)
	for _i in range(10):
		await process_frame

	# -------------------------------------------------------------------------
	# 3. Test Dynamic Waypoint Distance
	# -------------------------------------------------------------------------
	print("\n[QA 3] Testing Dynamic Waypoint Distance Updates...")
	var initial_dist: int = stage.get_waypoint_distance_meters()
	var wp_desc: String = stage.get_active_waypoint_name()
	assert(initial_dist > 0, "Initial waypoint distance must be > 0 m")
	print("[PASS 3] Waypoint at spawn: '", wp_desc, "' - Distance: ", initial_dist, " m")

	# Move player forward 30m towards radar
	var old_pos: Vector3 = player.global_position
	player.global_position = old_pos + Vector3(0.0, 4.0, -30.0)
	for _i in range(10):
		await process_frame
	var moved_dist: int = stage.get_waypoint_distance_meters()
	print("[PASS 3] After moving forward 30m: Distance: ", moved_dist, " m (decreased: ", moved_dist < initial_dist, ")")
	assert(moved_dist < initial_dist, "Distance must dynamically decrease as player approaches waypoint")

	# -------------------------------------------------------------------------
	# 4. Test Objective Checklist Progression
	# -------------------------------------------------------------------------
	print("\n[QA 4] Testing Objective Checklist Real-Time States...")
	var check_texts: Array = stage.get_objective_checklist_texts()
	assert(check_texts.size() == 4, "Checklist must contain exactly 4 objectives")
	assert("[▶]" in check_texts[0], "Objective 1 must be active initially: " + check_texts[0])
	assert("[  ]" in check_texts[1], "Objective 2 must be pending initially: " + check_texts[1])
	assert("[  ]" in check_texts[2], "Objective 3 must be pending initially: " + check_texts[2])
	assert("[  ]" in check_texts[3], "Objective 4 must be pending initially: " + check_texts[3])
	print("[PASS 4] Initial Checklist states confirmed: Objective 1 Active, 2-4 Pending.")

	# Simulate sentries eliminated
	stage.targets_eliminated = stage.total_targets
	stage._update_stage08_checklist()
	for _i in range(5):
		await process_frame
	check_texts = stage.get_objective_checklist_texts()
	assert("[✓]" in check_texts[0], "Objective 1 must be completed when targets eliminated: " + check_texts[0])
	assert("[▶]" in check_texts[1], "Objective 2 must become active after sentries secured: " + check_texts[1])
	print("[PASS 4] Checklist state after sentries cleared: Obj 1 Complete [✓], Obj 2 Active [▶].")

	# Teleport player near radar terminal
	player.global_position = stage.get_radar_console_position() + Vector3(0.0, 0.0, 2.0)
	for _i in range(15):
		await process_frame
	var console_dist: int = stage.get_waypoint_distance_meters()
	assert(console_dist <= 5, "Distance near console must be <= 5m: " + str(console_dist))
	print("[PASS 4] Waypoint distance at console: ", console_dist, " m")
	_save_shot(OUT_DIR + "/03_stage08_hud_radar_approached.png")

	# Trigger radar shutdown
	stage.trigger_radar_shutdown()
	for _i in range(5):
		await process_frame
	check_texts = stage.get_objective_checklist_texts()
	assert("[✓]" in check_texts[1], "Objective 2 must be completed after radar shutdown: " + check_texts[1])
	assert("[▶]" in check_texts[2], "Objective 3 must become active during intercept: " + check_texts[2])
	print("[PASS 4] Checklist state after radar shutdown: Obj 2 Complete [✓], Obj 3 Active [▶].")

	# Wait for secret signal burst
	await create_timer(1.8).timeout
	for _i in range(10):
		await process_frame
	stage.dismiss_secret_signal_panel()
	for _i in range(5):
		await process_frame
	check_texts = stage.get_objective_checklist_texts()
	assert("[✓]" in check_texts[2], "Objective 3 must be completed after secret signal burst: " + check_texts[2])
	assert("[▶]" in check_texts[3], "Objective 4 must become active to investigate vault: " + check_texts[3])
	print("[PASS 4] Checklist state after signal burst: Obj 3 Complete [✓], Obj 4 Active [▶].")
	_save_shot(OUT_DIR + "/04_stage08_hud_secret_signal_checklist.png")

	# Approach vault transducer and investigate
	player.global_position = stage.get_signal_source_position() + Vector3(0.0, 0.0, 2.0)
	for _i in range(10):
		await process_frame
	var vault_dist: int = stage.get_waypoint_distance_meters()
	assert(vault_dist <= 5, "Distance near vault must be <= 5m: " + str(vault_dist))
	print("[PASS 4] Waypoint distance at vault: ", vault_dist, " m")

	stage.investigate_signal_source()
	for _i in range(15):
		await process_frame
	check_texts = stage.get_objective_checklist_texts()
	assert("[✓]" in check_texts[3], "Objective 4 must be completed after decoding vault: " + check_texts[3])
	print("[PASS 4] All 4 objectives completed in checklist [✓] [✓] [✓] [✓].")
	_save_shot(OUT_DIR + "/05_stage08_hud_all_objectives_complete.png")

	print("\n================================================================")
	print(">>> ALL STAGE 08 DEDICATED HUD TESTS PASSED (100%) <<<")
	print("================================================================")
	quit(0)

func _save_shot(path: String) -> void:
	var vp := root.get_viewport()
	if not vp:
		return
	var img := vp.get_texture().get_image()
	if img:
		var global_path := ProjectSettings.globalize_path(path)
		img.save_png(global_path)
		print("[CAPTURE] Saved: ", global_path)
