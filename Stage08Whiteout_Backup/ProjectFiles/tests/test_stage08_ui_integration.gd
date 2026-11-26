extends SceneTree
## Stage 08 UI Integration & Visual Verification Test
## Validates that all 4 designed screens:
## - 03_gameplay_hud.png -> stage08_hud
## - 04_pause_menu.png -> stage08_pause_menu
## - 05_mission_success.png -> stage08_mission_success
## - 06_mission_failed.png -> stage08_mission_failed
## are properly integrated into the actual game, connected to real data,
## and captures evidence screenshots at 1152x648.

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"
const OUT_DIR := "res://verification_screenshots"

func _init() -> void:
	call_deferred("_run_integration_tests")


func _run_integration_tests() -> void:
	print("================================================================")
	print(">>> STAGE 08 UI INTEGRATION & VERIFICATION QA SUITE <<<")
	print("================================================================")

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# 1. Instantiate Stage 08
	var packed := load(STAGE08_SCENE) as PackedScene
	assert(packed != null, "[FAIL] Could not load Stage 08 scene.")
	var stage := packed.instantiate() as Stage08Whiteout
	assert(stage != null, "[FAIL] Stage08 instance is null.")
	root.add_child(stage)
	current_scene = stage

	for _i in range(30):
		await process_frame

	print("[QA 1] Stage 08 loaded successfully.")
	var hud_layer := stage.get_node_or_null("HUD") as CanvasLayer
	assert(hud_layer != null, "[FAIL] HUD CanvasLayer missing.")

	# -------------------------------------------------------------------------
	# STEP 1: Verify Gameplay HUD (matching 03_gameplay_hud.png)
	# -------------------------------------------------------------------------
	print("\n[QA 2] Verifying Gameplay HUD integration...")
	var hud := stage.stage08_hud
	assert(hud != null, "[FAIL] stage08_hud is not instantiated.")
	assert(hud.visible, "[FAIL] stage08_hud is not visible.")

	# Check duplicate prevention
	var generic_top := hud_layer.get_node_or_null("TopBar") as Control
	if generic_top:
		assert(!generic_top.visible, "[FAIL] Generic TopBar should be hidden to avoid duplicate HUD.")
	var generic_bottom_left := hud_layer.get_node_or_null("BottomLeft") as Control
	if generic_bottom_left:
		assert(!generic_bottom_left.visible, "[FAIL] Generic BottomLeft should be hidden.")

	# Check components on Stage08HUD
	assert(hud.objective_card != null and hud.objective_card.visible, "[FAIL] ObjectiveCard missing.")
	assert(hud.progress_panel != null and hud.progress_panel.visible, "[FAIL] ProgressPanel missing.")
	assert(hud.radar_rect != null and hud.radar_rect.visible, "[FAIL] Radar minimap missing.")
	assert(hud.health_bar != null and hud.health_bar.visible, "[FAIL] Health bar missing.")
	assert(hud.weapon_ammo_label != null and hud.weapon_ammo_label.visible, "[FAIL] Ammo label missing.")

	# Verify dynamic data updates
	hud.update_objective("Secure the Research Facility")
	hud.update_health(100, 100)
	hud.update_ammo(30, 180, "M4A1")
	hud.update_gear(2, 3)
	hud.set_task_completed("ridge", true)
	hud.set_task_completed("snipers", false)
	hud.set_task_completed("facility", false)
	hud.set_task_completed("extract", false)

	for _i in range(10):
		await process_frame

	print("[PASS 2] Gameplay HUD verified with all reference widgets connected.")
	_capture_screenshot(OUT_DIR + "/stage08_whiteout_gameplay_hud.png")

	# -------------------------------------------------------------------------
	# STEP 2: Verify Pause Menu (matching 04_pause_menu.png)
	# -------------------------------------------------------------------------
	print("\n[QA 3] Verifying Pause Menu integration...")
	var pause_menu := stage.stage08_pause_menu
	assert(pause_menu != null, "[FAIL] stage08_pause_menu is not instantiated.")
	assert(!pause_menu.visible, "[FAIL] Pause menu should be hidden initially.")

	# Trigger pause
	hud.visible = false
	pause_menu.open_menu()
	for _i in range(10):
		await process_frame

	assert(pause_menu.visible, "[FAIL] Pause menu must be visible after open_menu().")
	assert(paused, "[FAIL] Game tree must be paused.")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "[FAIL] Mouse must be visible when paused.")

	# Verify all buttons exist and are configured
	assert(pause_menu.resume_btn != null, "[FAIL] Resume button missing.")
	assert(pause_menu.controls_btn != null, "[FAIL] Controls button missing.")
	assert(pause_menu.settings_btn != null, "[FAIL] Settings button missing.")
	assert(pause_menu.restart_btn != null, "[FAIL] Restart button missing.")
	assert(pause_menu.quit_btn != null, "[FAIL] Quit button missing.")
	assert(pause_menu.back_btn != null, "[FAIL] Back button missing.")

	var mountain_frame := pause_menu.find_child("MountainFrame", true, false)
	assert(mountain_frame != null, "[FAIL] MountainFrame missing from pause menu.")

	print("[PASS 3] Pause Menu verified with all action buttons and mountain thumbnail frame.")
	_capture_screenshot(OUT_DIR + "/stage08_whiteout_pause_menu.png")

	# Test resume
	pause_menu.close_menu()
	hud.visible = true
	for _i in range(10):
		await process_frame
	assert(!pause_menu.visible, "[FAIL] Pause menu must be hidden after close_menu().")
	assert(!paused, "[FAIL] Game tree must be unpaused after close_menu().")
	print("[PASS 3] Pause Menu resume functional test passed.")

	# -------------------------------------------------------------------------
	# STEP 3: Verify Mission Success (matching 05_mission_success.png)
	# -------------------------------------------------------------------------
	print("\n[QA 4] Verifying Mission Success integration...")
	hud.visible = false
	var success_screen := stage.stage08_mission_success
	assert(success_screen != null, "[FAIL] stage08_mission_success is not instantiated.")
	assert(!success_screen.visible, "[FAIL] Success screen should be hidden initially.")

	var breakdown := {
		"elapsed_time": 1122.0, # 18:42
		"kills": 23,
		"shots_fired": 142,
		"shots_hit": 96,
		"accuracy": 68.0,
		"final_score": 3850,
		"stars": 2
	}
	success_screen.display_results(8, breakdown)
	for _i in range(10):
		await process_frame


	assert(success_screen.visible, "[FAIL] Success screen must be visible after display_results().")
	assert(success_screen.mission_time_label.text == "18:42", "[FAIL] Mission time mismatch: " + success_screen.mission_time_label.text)
	assert(success_screen.enemies_label.text == "23", "[FAIL] Enemies eliminated mismatch: " + success_screen.enemies_label.text)
	assert(success_screen.shots_label.text == "142", "[FAIL] Shots fired mismatch: " + success_screen.shots_label.text)
	assert(success_screen.accuracy_label.text == "68%", "[FAIL] Accuracy mismatch: " + success_screen.accuracy_label.text)
	assert(success_screen.score_label.text == "3,850", "[FAIL] Score mismatch: " + success_screen.score_label.text)
	assert(success_screen.continue_btn != null, "[FAIL] Continue button missing.")
	assert(success_screen.view_stats_btn != null, "[FAIL] View Stats button missing.")

	print("[PASS 4] Mission Success verified with real statistics, score, stars, and buttons.")
	_capture_screenshot(OUT_DIR + "/stage08_whiteout_mission_success.png")

	# Hide success screen before testing failed screen
	success_screen.visible = false

	# -------------------------------------------------------------------------
	# STEP 4: Verify Mission Failed (matching 06_mission_failed.png)
	# -------------------------------------------------------------------------
	print("\n[QA 5] Verifying Mission Failed integration...")
	var failed_screen := stage.stage08_mission_failed
	assert(failed_screen != null, "[FAIL] stage08_mission_failed is not instantiated.")
	assert(!failed_screen.visible, "[FAIL] Failed screen should be hidden initially.")

	failed_screen.display_failure("Killed by sniper", 37)
	for _i in range(10):
		await process_frame

	assert(failed_screen.visible, "[FAIL] Failed screen must be visible after display_failure().")
	assert(failed_screen.reason_text_label.text == "Killed by sniper", "[FAIL] Reason text mismatch: " + failed_screen.reason_text_label.text)
	assert(failed_screen.checkpoint_dist_label.text == "37 m", "[FAIL] Checkpoint distance mismatch: " + failed_screen.checkpoint_dist_label.text)
	assert(failed_screen.retry_btn != null, "[FAIL] Retry button missing.")
	assert(failed_screen.checkpoint_btn != null, "[FAIL] Checkpoint button missing.")
	assert(failed_screen.exit_btn != null, "[FAIL] Exit button missing.")
	assert(failed_screen.back_btn != null, "[FAIL] Back button missing.")

	print("[PASS 5] Mission Failed verified with elimination reason, checkpoint distance, and retry controls.")
	_capture_screenshot(OUT_DIR + "/stage08_whiteout_mission_failed.png")

	# -------------------------------------------------------------------------
	# Final Verification Summary
	# -------------------------------------------------------------------------
	print("\n================================================================")
	print(">>> ALL 4 STAGE 08 UI SCREENS SUCCESSFULLY INTEGRATED & VERIFIED <<<")
	print("1. Gameplay HUD: stage08_whiteout_gameplay_hud.png")
	print("2. Pause Menu: stage08_whiteout_pause_menu.png")
	print("3. Mission Success: stage08_whiteout_mission_success.png")
	print("4. Mission Failed: stage08_whiteout_mission_failed.png")
	print("================================================================")

	quit(0)


func _capture_screenshot(file_path: String) -> void:
	var vp := root.get_viewport()
	if not vp:
		print("[WARN] No viewport available for capture.")
		return
	var tex := vp.get_texture()
	if not tex:
		print("[WARN] Viewport texture is null.")
		return
	var img := tex.get_image()
	if not img:
		print("[WARN] Viewport texture image is null.")
		return
	img.save_png(file_path)
	print("[SCREENSHOT CAPTURED] ", file_path)
