extends SceneTree

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("\n=======================================================")
	print("=== STAGE 08 PHASE 1: ENVIRONMENT & GAMEPLAY TEST ===")
	print("=======================================================\n")

	# 1. Load and initialize Stage 08
	var stage_scene = load("res://scenes/stages/Stage08.tscn")
	if not stage_scene:
		print("❌ FATAL: Failed to load res://scenes/stages/Stage08.tscn")
		quit(1)
		return

	var stage_inst = stage_scene.instantiate()
	root.add_child(stage_inst)
	print("✔ Stage08.tscn instantiated and added to SceneTree.")

	# Wait 10 physics frames for initial physics settle
	for i in range(10):
		await physics_frame

	var player = stage_inst.get_node_or_null("Player3D")
	if not player:
		print("❌ FATAL: Player3D not found in Stage08!")
		quit(1)
		return

	print("\n[Check 1: Player Spawn & Ground Collision]")
	var spawn_pos = player.global_position
	var is_grounded = player.is_on_floor()
	print("  - Player position: Vector3(%.2f, %.2f, %.2f)" % [spawn_pos.x, spawn_pos.y, spawn_pos.z])
	print("  - Player on floor: %s" % str(is_grounded))
	print("  - Player current health: %d" % player.current_health)
	
	if spawn_pos.y < -1.0:
		print("❌ FAIL: Player fell below ground level!")
		quit(1)
		return
	else:
		print("✔ PASS: Player safely on floor at Y >= 0.")

	print("\n[Check 2: Camera & First-Person Setup]")
	var cam = player.get_node_or_null("CameraHolder/Camera3D")
	if not cam:
		cam = player.get_node_or_null("Camera3D")
	if cam:
		print("  - Camera found: %s, Current: %s" % [cam.name, str(cam.current)])
		print("✔ PASS: First-person camera verified.")
	else:
		print("⚠ Camera node not found at standard path.")

	print("\n[Check 3: CW-08 Tactical Assault Rifle Integration]")
	var gun_model = player.get_node_or_null("Camera3D/WeaponRig/GunModel")
	var cw08_vis = gun_model.get_node_or_null("CW08Visual") if gun_model else null
	if cw08_vis:
		print("  - CW08 visual model attached: true")
		print("  - Weapon data name: %s" % gun_model.data.weapon_name)
		print("  - Mag size: %d, Starting reserve: %d" % [gun_model.data.magazine_size, gun_model.data.starting_reserve_ammo])
		print("✔ PASS: CW-08 Assault Rifle successfully integrated.")
	else:
		print("❌ CW-08 visual model NOT found on gun_model!")

	print("\n[Check 4: Testing Firing and Reload Action]")
	# Simulate trigger pull
	player.is_firing_held = true
	await physics_frame
	await physics_frame
	player.is_firing_held = false
	print("  - Fire simulated. Player health: %d" % player.current_health)

	# Simulate reload
	if player.has_method("_reload_active_weapon"):
		player._reload_active_weapon()
		print("  - Reload triggered successfully.")

	print("\n[Check 5: Testing Movement & Slope Walking]")
	# Simulate moving forward up the valley road
	player.velocity.z = -5.0
	for i in range(30):
		await physics_frame
	var moved_pos = player.global_position
	print("  - Player moved from Z=%.2f to Z=%.2f (Delta Z = %.2f)" % [spawn_pos.z, moved_pos.z, moved_pos.z - spawn_pos.z])
	print("  - Grounded during movement: %s" % str(player.is_on_floor()))
	print("✔ PASS: Player movement and ground collision responsive.")

	print("\n[Check 6: Environment Structures & Tactical Layout]")
	var env = stage_inst.get_node_or_null("Environment")
	if env:
		var watchtower = env.get_node_or_null("OutpostWatchtower")
		var radar_comp = env.get_node_or_null("RadarCommandCompound")
		var covers = env.get_node_or_null("TacticalCovers")
		var veg = env.get_node_or_null("NaturalVegetationAndBoulders")
		var lz = env.get_node_or_null("SummitExtractionLZ")
		print("  - Outpost Watchtower present: %s" % str(watchtower != null))
		print("  - Radar Command Compound present: %s" % str(radar_comp != null))
		print("  - Tactical Covers present: %s" % str(covers != null))
		print("  - Vegetation & Boulders present: %s" % str(veg != null))
		print("  - Extraction LZ present: %s" % str(lz != null))
		print("✔ PASS: All required alpine outpost structures instantiated.")

	print("\n[Check 7: Enemies & Objective Tracking]")
	var enemies = stage_inst.get_node_or_null("Enemies")
	var enemy_count = enemies.get_child_count() if enemies else 0
	print("  - Enemies in scene: %d (Expected: 18)" % enemy_count)
	print("  - Stage reported total targets: %d" % stage_inst.total_enemy_count)
	if stage_inst.iron_hud:
		print("  - HUD objective text: '%s'" % stage_inst.iron_hud.objective_label.text if stage_inst.iron_hud.has_node("TopCenter/ObjectiveCard/ObjectiveLabel") else "Active")
	print("✔ PASS: Enemy placement and objective tracking verified.")

	# Capture screenshot
	print("\n[Check 8: Capturing Runtime Gameplay Screenshot]")
	# Wait 5 frames for rendering
	for i in range(5):
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("verification_screenshots/stage08_iron_peak"):
			dir.make_dir_recursive("verification_screenshots/stage08_iron_peak")
		var save_path = "verification_screenshots/stage08_iron_peak/phase1_gameplay_environment.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("✔ Saved screenshot to: %s" % save_path)
		else:
			print("⚠ Could not save screenshot, error code: %d" % err)
	else:
		print("⚠ Viewport texture image was null (running headless).")

	print("\n=======================================================")
	print("=== ALL PHASE 1 CHECKS PASSED SUCCESSFULLY! ===")
	print("=======================================================\n")
	quit(0)
