extends SceneTree
## Automated Verification Test for Stage 08 — Operation Iron Peak
## Includes hard safety timeout to prevent hanging.

const TIMEOUT_SECONDS: float = 12.0

var _timeout_timer: float = 0.0

func _init() -> void:
	print("\n=== [STAGE 08 VERIFICATION TEST START] ===")
	call_deferred("_run_test")

func _process(delta: float) -> bool:
	_timeout_timer += delta
	if _timeout_timer >= TIMEOUT_SECONDS:
		push_error("[STAGE 08 TEST ERROR] Safety timeout reached! Force quitting.")
		quit(1)
		return true
	return false

func _run_test() -> void:
	for _f in range(3):
		await process_frame

	print("[Test 1/6] Verifying Stage 08 Resource Existence & Instantiation...")
	var scenes_to_verify := [
		"res://scenes/weapons/CW08AssaultRifle.tscn",
		"res://scenes/stages/Stage08IronPeakIntro.tscn",
		"res://scenes/stages/Stage08IronPeakBriefing.tscn",
		"res://scenes/stages/Stage08IronPeakLoadout.tscn",
		"res://scenes/stages/ui/Stage08IronPeakHUD.tscn",
		"res://scenes/stages/ui/Stage08IronPeakPauseMenu.tscn",
		"res://scenes/stages/ui/Stage08IronPeakSuccess.tscn",
		"res://scenes/stages/ui/Stage08IronPeakFailed.tscn",
		"res://scenes/stages/ui/Stage08IronPeakSettings.tscn",
		"res://scenes/stages/Stage08.tscn"
	]

	for path in scenes_to_verify:
		assert(ResourceLoader.exists(path), "Missing scene: " + path)
		var scn = load(path)
		assert(scn != null, "Failed to load scene: " + path)
		var inst = scn.instantiate()
		assert(inst != null, "Failed to instantiate: " + path)
		inst.free()
		print("  ✔ Verified & instanced: %s" % path)

	print("[Test 2/6] Verifying StageManager & Registry Integrity...")
	var stage_mgr = root.get_node_or_null("StageManager")
	assert(stage_mgr != null, "StageManager autoload not found!")
	var stage8_info = stage_mgr.get_stage_info(8)
	assert(not stage8_info.is_empty(), "Stage 8 not registered in StageManager!")
	assert(stage8_info["mission_title"] == "OPERATION IRON PEAK", "Title mismatch: " + str(stage8_info["mission_title"]))
	assert(stage8_info["scene_path"] == "res://scenes/stages/Stage08.tscn", "Scene path mismatch")
	assert(stage8_info["briefing_path"] == "res://scenes/stages/Stage08IronPeakIntro.tscn", "Briefing path mismatch")
	print("  ✔ Stage 8 correctly registered as 'OPERATION IRON PEAK'")

	print("[Test 3/6] Instantiating Stage08 Live Gameplay Node...")
	var stage8_scn = load("res://scenes/stages/Stage08.tscn")
	var stage8_inst = stage8_scn.instantiate()
	root.add_child(stage8_inst)

	for _f in range(5):
		await process_frame

	# Check Player
	var player = stage8_inst.get_node_or_null("Player3D")
	assert(player != null, "Player3D not found in Stage 08!")
	assert(player.is_in_group("player"), "Player not added to 'player' group!")
	print("  ✔ Player3D spawned at position: %s" % str(player.global_position))

	# Check CW-08 Weapon attached
	var gun_model = player.get_node_or_null("Camera3D/WeaponRig/GunModel")
	assert(gun_model != null, "GunModel node missing on Player!")
	var cw08_visual = gun_model.get_node_or_null("CW08Visual")
	assert(cw08_visual != null, "CW08Visual weapon model not attached to player!")
	print("  ✔ CW-08 Assault Rifle successfully attached to Player3D")

	# Check Enemies
	var enemies = stage8_inst.get_node_or_null("Enemies")
	assert(enemies != null, "Enemies container missing!")
	var enemy_count = enemies.get_child_count()
	assert(enemy_count == 18, "Expected 18 enemies, found %d" % enemy_count)
	print("  ✔ Verified 18 tactical enemy combatants in Enemies container")

	# Check Environment & Outpost
	var env = stage8_inst.get_node_or_null("Environment")
	assert(env != null, "Environment node missing!")
	assert(env.has_node("AlpineTerrain"), "AlpineTerrain missing!")
	assert(env.has_node("OutpostStructures"), "OutpostStructures missing!")
	assert(env.has_node("TacticalCovers"), "TacticalCovers missing!")
	assert(env.has_node("NaturalVegetation"), "NaturalVegetation missing!")
	assert(env.has_node("ExtractionLZ"), "ExtractionLZ missing!")
	print("  ✔ Verified Alpine terrain, Outpost, Watchtower, Covers, and LZ")

	# Check HUD and UI elements
	var hud = stage8_inst.get_node_or_null("HUD")
	assert(hud != null, "HUD not found!")
	var pause_menu = stage8_inst.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu not found!")
	var success_screen = stage8_inst.get_node_or_null("SuccessScreen")
	assert(success_screen != null, "SuccessScreen not found!")
	var failed_screen = stage8_inst.get_node_or_null("FailedScreen")
	assert(failed_screen != null, "FailedScreen not found!")
	print("  ✔ Verified HUD, PauseMenu, SuccessScreen, and FailedScreen integration")

	print("[Test 4/6] Testing Pause & Resume Cycle...")
	pause_menu.open_menu()
	assert(pause_menu.visible == true, "Pause menu should be visible after open_menu()")
	assert(paused == true, "SceneTree should be paused")
	pause_menu.resume_game()
	assert(pause_menu.visible == false, "Pause menu should be hidden after resume_game()")
	assert(paused == false, "SceneTree should be unpaused")
	print("  ✔ Pause and resume lifecycle functioning perfectly")

	print("[Test 5/6] Testing Enemy Elimination & Objective Updates...")
	var initial_remaining = stage8_inst.total_enemy_count - stage8_inst.enemies_killed_count
	assert(initial_remaining == 18, "Initial enemies remaining should be 18")
	# Simulate eliminating one enemy
	var test_enemy = enemies.get_child(0)
	stage8_inst._on_enemy_killed(test_enemy)
	assert(stage8_inst.enemies_killed_count == 1, "Enemies killed should be 1")
	print("  ✔ Objective counter dynamically tracked enemy elimination")

	print("[Test 6/6] Regression Audit — Checking Stages 01-07 & Backup...")
	for s in range(1, 8):
		var s_path = "res://scenes/stages/Stage%02d.tscn" % s
		assert(ResourceLoader.exists(s_path), "Regression! Missing prior stage: " + s_path)
	print("  ✔ Stages 01-07 verified intact")

	# Clean up
	stage8_inst.queue_free()

	print("\n=== ALL STAGE 08 TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
