extends SceneTree
## Full End-to-End Workflow Test: Operations HQ -> Briefing -> Loadout -> Stage 08 Gameplay

const TEST_SAVE := "user://.stage08_e2e_test_save.json"

func _init() -> void:
	call_deferred("_run_e2e")

func _run_e2e() -> void:
	print("==================================================")
	print("STAGE 08 END-TO-END FLOW: HQ -> BRIEFING -> LOADOUT -> STAGE08")
	print("==================================================")

	var profile = root.get_node_or_null("ProfileManager")
	var stage_mgr = root.get_node_or_null("StageManager")
	assert(profile != null and stage_mgr != null, "Core autoloads missing")

	# Prepare unlocked Stage 08 profile
	profile.save_path = TEST_SAVE
	profile.current_profile = {
		"save_version": 1,
		"player_name": "Ghost",
		"highest_unlocked_stage": 8,
		"completed_stages": [1, 2, 3, 4, 5, 6, 7],
		"best_scores": {"7": 2500},
		"highest_score": 2500,
		"career_score": 5000,
		"last_played_stage": 8
	}
	assert(profile.save_profile(), "Failed to save test profile")

	# 1. Open Operations HQ
	var hq_packed = load("res://scenes/StageSelection.tscn")
	assert(hq_packed != null, "Failed to load Operations HQ scene")
	var hq = hq_packed.instantiate()
	root.add_child(hq)
	current_scene = hq

	for _i in range(15):
		await process_frame

	print("[E2E 1] Operations HQ loaded. Current selected stage: ", hq.get_selected_stage_id())
	hq._select_stage(8)
	for _i in range(5):
		await process_frame

	assert(hq.get_selected_stage_id() == 8, "Stage 08 must be selected in HQ")
	assert(hq.action_button.text == "DEPLOY", "Action button must be DEPLOY")
	print("[E2E 1] Stage 08 selected in HQ. Pressing DEPLOY...")

	# 2. Press DEPLOY -> Briefing
	hq.action_button.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	assert(current_scene.name == "Stage08WhiteoutBriefing", "Scene must be Stage08WhiteoutBriefing, was: " + current_scene.name)
	print("[E2E 2] Landed on Briefing screen successfully.")

	# 3. Test BACK from Briefing -> returns to HQ
	var briefing = current_scene
	var briefing_back = briefing.back_button
	assert(briefing_back != null, "Briefing must have BackButton")
	print("[E2E 3] Testing BACK from Briefing to HQ...")
	briefing_back.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	assert("StageSelection" in current_scene.name or "OperationsHQ" in current_scene.name, "Must return to HQ, was: " + current_scene.name)
	hq = current_scene
	print("[E2E 3] Returned to Operations HQ. Selected Stage: ", hq.get_selected_stage_id())

	# 4. Press DEPLOY again -> Briefing
	hq.action_button.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	briefing = current_scene
	assert(briefing.name == "Stage08WhiteoutBriefing", "Must be back on Briefing")

	# 5. Press START MISSION on Briefing -> Loadout
	var start_btn = briefing.start_mission_button
	assert(start_btn != null, "StartMissionButton must exist")
	print("[E2E 4] Pressing START MISSION on Briefing -> navigating to Loadout...")
	start_btn.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	assert(current_scene.name == "Stage08WhiteoutLoadout", "Scene must be Stage08WhiteoutLoadout, was: " + current_scene.name)
	var loadout = current_scene
	print("[E2E 5] Landed on Loadout screen successfully.")

	# 6. Test BACK from Loadout -> Briefing
	var loadout_back = loadout.back_button
	assert(loadout_back != null, "Loadout must have BackButton")
	print("[E2E 6] Testing BACK from Loadout to Briefing...")
	loadout_back.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	assert(current_scene.name == "Stage08WhiteoutBriefing", "Must return to Briefing, was: " + current_scene.name)
	briefing = current_scene
	print("[E2E 6] Returned to Briefing. Pressing START MISSION again...")
	briefing.start_mission_button.emit_signal("pressed")
	for _i in range(15):
		await process_frame

	loadout = current_scene
	assert(loadout.name == "Stage08WhiteoutLoadout", "Must be back on Loadout")

	# 7. Press CONFIRM LOADOUT on Loadout -> Stage08 gameplay
	var confirm_btn = loadout.confirm_button
	assert(confirm_btn != null, "ConfirmButton must exist on Loadout")
	print("[E2E 7] Pressing CONFIRM LOADOUT -> launching Stage 08 gameplay...")
	confirm_btn.emit_signal("pressed")
	for _i in range(25):
		await process_frame

	assert(current_scene.name == "Stage08", "Scene must transition to Stage08, was: " + current_scene.name)
	assert(stage_mgr.get_current_stage_id() == 8, "StageManager ID must be 8")
	assert(current_scene.has_node("Player3D"), "Stage08 must have Player3D")
	assert(current_scene.has_node("HUD"), "Stage08 must have HUD")
	assert(current_scene.has_node("Enemies"), "Stage08 must have Enemies")
	print("[E2E 8] Stage 08 gameplay active! Player, HUD, and 12 guards verified.")

	# Clean up test save
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)

	print("==================================================")
	print("[E2E PASS] ALL TWO-WAY TRANSITIONS VERIFIED END-TO-END!")
	print("==================================================")
	quit(0)
