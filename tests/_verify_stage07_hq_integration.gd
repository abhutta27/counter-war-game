extends SceneTree

const TEST_SAVE := "res://tests/.stage07_hq_verify_save.json"
const OUTPUT_DIR := "res://verification_screenshots/stage07_hq_integration"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[HQStage07Verify] START: Verifying Stage 07 HQ visibility and campaign integration...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var profile = root.get_node("ProfileManager")
	var manager = root.get_node("StageManager")

	var orig_save_path: String = profile.save_path
	var orig_profile: Dictionary = profile.current_profile.duplicate(true)
	var orig_stage_id: int = manager.current_stage_id

	profile.save_path = TEST_SAVE

	# -------------------------------------------------------------
	# STEP 1: LOCKED STATE IN HQ (Operative at Stage 02)
	# -------------------------------------------------------------
	profile.current_profile = {
		"save_version": 1,
		"player_name": "GhostOperative",
		"highest_unlocked_stage": 2,
		"completed_stages": [1],
		"best_scores": {"1": 1900},
		"highest_score": 1900,
		"career_score": 1900,
		"last_played_stage": 1
	}
	assert(profile.save_profile(), "Test profile must save")

	var hq_scene := load("res://scenes/StageSelection.tscn") as PackedScene
	var hq = hq_scene.instantiate()
	root.add_child(hq)
	current_scene = hq

	for _f in 10:
		await process_frame

	var rows: Array[Node] = hq.get_mission_rows()
	print("[HQStage07Verify] Total mission rows in HQ: %d" % rows.size())
	assert(rows.size() == 7, "HQ must render 7 mission rows (Stages 01 to 07)")

	# Verify Operation Grouping Headers in Mission Index UI
	assert(hq.missions_container.has_node("OperationHeader_1"), "Operation I header must exist in Mission Index")
	assert(hq.missions_container.has_node("OperationHeader_2"), "Operation II header must exist in Mission Index")
	assert(hq.missions_container.has_node("OperationHeader_3"), "Operation III header must exist in Mission Index")
	var op3_header := hq.missions_container.get_node("OperationHeader_3") as Label
	assert(op3_header.text == "OPERATION III", "Operation III header text must match 'OPERATION III'")
	assert(op3_header.visible == true, "Operation III header must be visible in Mission Index")

	var row7 = null
	for r in rows:
		if r.stage_id == 7:
			row7 = r
			break

	assert(row7 != null, "Stage 07 row must exist in HQ")
	assert(hq.missions_container.has_node("MissionRow_07"), "MissionRow_07 node must exist in missions_container")
	print("[HQStage07Verify] Row 7 found: Number='%s', Title='%s', Status='%s'" % [
		row7.stage_number_label.text,
		row7.mission_title_label.text,
		row7.stage_status
	])
	assert(row7.stage_number_label.text == "07", "Row 7 number must be '07'")
	assert(row7.mission_title_label.text == "IRON HARBOR", "Row 7 title must be 'IRON HARBOR'")
	assert(row7.stage_status == "LOCKED", "Stage 07 must be LOCKED when operative has not completed Stage 06")
	assert(row7.get_parent() == hq.missions_container, "Row 7 must be a direct child of missions_container")
	assert(row7.get_index() > op3_header.get_index(), "Row 7 must be rendered after Operation III header")

	# Select Stage 07 in HQ while locked
	hq._select_stage(7)
	for _f in 4:
		await process_frame

	assert(hq.stage_code_label.text == "STAGE 07", "Dossier code must say 'STAGE 07'")
	assert(hq.detail_title_label.text == "OPERATION IRON HARBOR", "Dossier title must say 'OPERATION IRON HARBOR'")
	assert(hq.detail_status_label.text == "LOCKED", "Dossier status must say 'LOCKED'")
	assert(hq.action_button.text == "MISSION LOCKED", "Action button must say 'MISSION LOCKED'")
	assert(hq.action_button.disabled == true, "Action button must be disabled for locked mission")
	assert(hq.unlock_label.text == "COMPLETE STAGE 06 TO UNLOCK", "Unlock requirement must specify Stage 06")
	print("[HQStage07Verify] PASS: Locked Stage 07 dossier details verified.")

	# Capture Screenshot 1: Stage 07 Locked in HQ
	var img_locked = root.get_viewport().get_texture().get_image()
	img_locked.save_png("%s/01_hq_stage07_locked.png" % OUTPUT_DIR)
	print("[HQStage07Verify] Saved 01_hq_stage07_locked.png")

	# Verify deployment is blocked
	hq._on_action_pressed()
	for _f in 3:
		await process_frame
	assert(current_scene == hq, "Locked Stage 07 action pressed must not leave HQ")
	assert(not manager.load_stage(7), "StageManager.load_stage(7) must reject locked deployment")

	# -------------------------------------------------------------
	# STEP 2: UNLOCKING VIA STAGE 06 COMPLETION
	# -------------------------------------------------------------
	print("[HQStage07Verify] Completing Stage 06 to test progression...")
	profile.current_profile["highest_unlocked_stage"] = 6
	profile.current_profile["completed_stages"] = [1, 2, 3, 4, 5]
	profile.record_stage_completed(6)
	assert(profile.get_highest_unlocked_stage() == 7, "Stage 06 completion must unlock Stage 07 (highest_unlocked = 7)")

	hq.refresh_from_profile(7)
	for _f in 8:
		await process_frame

	rows = hq.get_mission_rows()
	for r in rows:
		if r.stage_id == 7:
			row7 = r
			break

	assert(row7.stage_status == "AVAILABLE", "Stage 07 must be AVAILABLE after Stage 06 completion")
	assert(hq.get_selected_stage_id() == 7, "Stage 07 must be selected in HQ")
	assert(hq.campaign_label.text == "STAGE 07 AVAILABLE", "Campaign header must report 'STAGE 07 AVAILABLE'")
	assert(hq.action_button.text == "DEPLOY", "Action button must say 'DEPLOY'")
	assert(hq.action_button.disabled == false, "Action button must be enabled for available mission")
	assert(hq.unlock_label.text == "CLEARED FOR DEPLOYMENT", "Unlock label must say 'CLEARED FOR DEPLOYMENT'")
	print("[HQStage07Verify] PASS: Unlocked Stage 07 verified in HQ.")

	# Capture Screenshot 2: Stage 07 Available & Cleared for Deployment
	var img_unlocked = root.get_viewport().get_texture().get_image()
	img_unlocked.save_png("%s/02_hq_stage07_unlocked_deployable.png" % OUTPUT_DIR)
	print("[HQStage07Verify] Saved 02_hq_stage07_unlocked_deployable.png")

	# -------------------------------------------------------------
	# STEP 3: DEPLOYMENT AND STAGE 07 SCENE LOADING
	# -------------------------------------------------------------
	print("[HQStage07Verify] Deploying to Stage 07 from HQ...")
	hq._on_action_pressed()
	for _f in 25:
		await process_frame

	assert(current_scene != null and current_scene.name == "Stage07", "Deploying from HQ must load Stage07 scene")
	assert(current_scene.stage_id == 7, "Loaded stage_id must be 7")
	assert(current_scene.stage_name == "OPERATION IRON HARBOR", "Loaded stage_name must be 'OPERATION IRON HARBOR'")
	assert(current_scene.has_node("Player3D"), "Stage 07 must have Player3D")
	assert(current_scene.has_node("HUD"), "Stage 07 must have HUD")
	assert(current_scene.has_node("CinematicCamera"), "Stage 07 must have CinematicCamera")
	assert(manager.current_stage_id == 7, "StageManager.current_stage_id must be 7")
	print("[HQStage07Verify] PASS: Stage 07 successfully loaded and running.")

	# Capture Screenshot 3: Stage 07 Gameplay Scene Loaded from HQ
	var img_stage = root.get_viewport().get_texture().get_image()
	img_stage.save_png("%s/03_stage07_scene_loaded_from_hq.png" % OUTPUT_DIR)
	print("[HQStage07Verify] Saved 03_stage07_scene_loaded_from_hq.png")

	# -------------------------------------------------------------
	# STEP 4: CLEANUP & RESTORE
	# -------------------------------------------------------------
	profile.save_path = orig_save_path
	profile.current_profile = orig_profile
	manager.current_stage_id = orig_stage_id
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	print("[HQStage07Verify] ALL HQ INTEGRATION AND SCENE LOADING TESTS PASSED.")
	quit(0)
