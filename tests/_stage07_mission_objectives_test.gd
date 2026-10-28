extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage07.tscn")
const TEST_SAVE := "res://tests/.stage07_obj_verify_save.json"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[Stage07ObjectivesTest] START: Testing Stage 07 Mission Objectives...")

	var profile = root.get_node("ProfileManager")
	var orig_save_path: String = profile.save_path
	var orig_profile: Dictionary = profile.current_profile.duplicate(true)

	profile.save_path = TEST_SAVE
	profile.current_profile = {
		"save_version": 1,
		"player_name": "GHOST",
		"highest_unlocked_stage": 7,
		"completed_stages": [1, 2, 3, 4, 5, 6],
		"best_scores": {"1": 1000, "6": 2000},
		"highest_score": 2000,
		"career_score": 3000,
		"last_played_stage": 6
	}
	assert(profile.save_profile(), "Test profile must save")

	# -------------------------------------------------------------
	# STEP 1: LOAD STAGE 07 AND VERIFY OBJECTIVE NODES
	# -------------------------------------------------------------
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage

	for _f in 10:
		await process_frame

	assert(stage.stage_id == 7, "Stage ID must be 7")
	assert(stage.has_node("Environment/SecurityWatchtower/AlarmConsole"), "Alarm Console must exist in scene")
	assert(stage.has_node("Environment/EnemyCommandCenter/DataTerminal"), "Data Terminal must exist in scene")
	assert(stage.has_node("Environment/ExtractionHelipad/ExtractionArea"), "Extraction Area must exist in scene")
	assert(stage.has_node("HUD/InteractionPrompt"), "Interaction prompt HUD label must exist")

	assert(stage.is_alarm_disabled == false, "Alarm must initially be active")
	assert(stage.is_data_retrieved == false, "Data must initially NOT be retrieved")
	assert(stage._extraction_completed == false, "Extraction must initially NOT be completed")
	assert(stage.is_stage_finished == false, "Stage must not be finished at start")

	print("[Stage07ObjectivesTest] PASS: All objective nodes and initial state verified.")

	# -------------------------------------------------------------
	# STEP 2: TEST OUT-OF-SEQUENCE GUARDS
	# -------------------------------------------------------------
	print("[Stage07ObjectivesTest] Testing out-of-sequence protections...")

	# Attempt 1: Extract data before disabling alarm -> MUST FAIL
	var terminal_res_fail = stage.interact_with_terminal()
	assert(terminal_res_fail == false, "Interacting with terminal before alarm disable must fail")
	assert(stage.is_data_retrieved == false, "Data must remain unretrieved")

	# Attempt 2: Evac at LZ Charlie before completing any objectives -> MUST FAIL
	var evac_res_fail1 = stage.trigger_extraction()
	assert(evac_res_fail1 == false, "Extraction before completing objectives must fail")
	assert(stage.is_stage_finished == false, "Stage must not finish on invalid extraction")

	print("[Stage07ObjectivesTest] PASS: Out-of-sequence objective attempts rejected.")

	# -------------------------------------------------------------
	# STEP 3: OBJECTIVE 1 — DISABLE ALARM
	# -------------------------------------------------------------
	print("[Stage07ObjectivesTest] Completing Objective 1: Disable Alarm...")
	var alarm_res = stage.interact_with_alarm()
	assert(alarm_res == true, "Disabling alarm must succeed")
	assert(stage.is_alarm_disabled == true, "Alarm must be disabled")

	# Second call to disable alarm must return false (already disabled)
	assert(stage.interact_with_alarm() == false, "Redundant alarm interaction must be rejected")

	# Attempt 3: Evac at LZ Charlie with ONLY alarm disabled -> MUST FAIL (data still missing)
	var evac_res_fail2 = stage.trigger_extraction()
	assert(evac_res_fail2 == false, "Extraction without intel data must fail")
	assert(stage.is_stage_finished == false, "Stage must remain unfinished")

	print("[Stage07ObjectivesTest] PASS: Objective 1 secured; partial extraction blocked.")

	# -------------------------------------------------------------
	# STEP 4: OBJECTIVE 2 — EXTRACT COMMAND INTEL DATA
	# -------------------------------------------------------------
	print("[Stage07ObjectivesTest] Completing Objective 2: Extract Intel Data...")
	var terminal_res = stage.interact_with_terminal()
	assert(terminal_res == true, "Extracting intel after alarm disable must succeed")
	assert(stage.is_data_retrieved == true, "Data must be retrieved")

	# Second call to terminal must return false
	assert(stage.interact_with_terminal() == false, "Redundant terminal interaction must be rejected")

	print("[Stage07ObjectivesTest] PASS: Objective 2 secured.")

	# -------------------------------------------------------------
	# STEP 5: VERIFY KILLING ENEMIES DOES NOT FORCE PREMATURE VICTORY
	# -------------------------------------------------------------
	print("[Stage07ObjectivesTest] Verifying hostiles elimination does not bypass extraction...")
	# Kill 11 actual guards: the LZ must still reject extraction while one lives.
	var enemies_node: Node3D = stage.enemies_container
	for index in range(11):
		enemies_node.get_child(index).take_damage(100)
	await process_frame
	assert(stage.targets_eliminated == 11, "Eleven dead guards must be counted exactly once")
	assert(stage.is_stage_finished == false, "Eliminating hostiles must not complete Stage 07")
	assert(stage.trigger_extraction() == false, "LZ extraction must fail while the twelfth guard lives")
	assert(stage.is_stage_finished == false, "Stage must remain unfinished with one living guard")
	print("[Stage07ObjectivesTest] PASS: Extraction is blocked with one living guard.")

	# -------------------------------------------------------------
	# STEP 6: OBJECTIVE 3 — EXTRACTION AT LZ CHARLIE & VICTORY
	# -------------------------------------------------------------
	print("[Stage07ObjectivesTest] Completing Objective 3: Extraction at LZ Charlie...")
	enemies_node.get_child(11).take_damage(100)
	await process_frame
	assert(stage.targets_eliminated == 12, "The final guard death must increment the tally once")
	stage.current_mission_score = 1500
	var evac_res = stage.trigger_extraction()
	assert(evac_res == true, "Extraction with all objectives complete must succeed")

	for _f in 15:
		await process_frame

	assert(stage.is_stage_finished == true, "Stage 07 must be finished after valid extraction")
	assert(stage._extraction_completed == true, "Extraction must be marked completed")

	# Redundant extraction trigger must be rejected
	assert(stage.trigger_extraction() == false, "Second extraction trigger must be safely ignored")

	# Verify debrief summary customization
	assert(stage.summary_dialog != null, "Summary dialog must exist")
	assert(stage.summary_dialog.visible == true, "Summary dialog must be visible on victory")
	assert(stage.summary_dialog.mission_status_label.text == "OPERATION SECURED", "Debrief status must say OPERATION SECURED")
	assert(stage.summary_dialog.next_btn.visible == false, "Next button must be absent on final campaign stage")
	assert(stage.summary_dialog.menu_btn.text == "RETURN TO HQ", "Return to HQ button must exist")

	# Verify profile persistence
	var completed_stages: Array = profile.current_profile.get("completed_stages", [])
	assert(completed_stages.has(7), "Profile must record Stage 07 as completed")
	assert(profile.get_best_score(7) > 0, "Profile must record Stage 07 best score")

	print("[Stage07ObjectivesTest] PASS: Mission victory, debrief, and profile persistence verified.")

	# -------------------------------------------------------------
	# STEP 7: CLEANUP & RESTORE
	# -------------------------------------------------------------
	profile.save_path = orig_save_path
	profile.current_profile = orig_profile
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	print("\n[Stage07ObjectivesTest] ALL STAGE 07 MISSION OBJECTIVE VERIFICATIONS PASSED.")
	quit(0)
