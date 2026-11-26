extends SceneTree
## Step 3C regression. All mutations use a project-local temporary profile;
## the real user:// save is never opened for writing by this test.

const TEST_SAVE := "res://tests/.operations_hq_step3c_test.json"
var profile: Node
var manager: Node
var original_save_path: String
var original_profile: Dictionary
var original_stage_id: int

func _init() -> void:
	print("[OperationsHQStep3C] START")
	call_deferred("_run")

func _run() -> void:
	for _frame in 5:
		await process_frame
	profile = root.get_node("ProfileManager")
	manager = root.get_node("StageManager")
	original_save_path = profile.save_path
	original_profile = profile.current_profile.duplicate(true)
	original_stage_id = manager.current_stage_id
	_cleanup_test_save()
	profile.save_path = TEST_SAVE
	_set_profile(3, [1], {"1": 1850}, 1)

	# Catalog and grouping contain the existing missions plus the registered Stage08 entry.
	assert(manager.get_registered_stage_ids() == [1, 2, 3, 4, 5, 6, 7, 8], "Catalog must contain Stage01-Stage08")
	assert(manager.get_stages_for_operation(1).size() == 5, "Operation I must contain Stage01-Stage05")
	assert(manager.get_stages_for_operation(2).size() == 1, "Operation II must contain only Stage06")
	assert(manager.get_stages_for_operation(3).size() == 1, "Operation III must contain Stage07")
	assert(manager.get_stages_for_operation(4).size() == 1, "Operation IV must contain Stage08")
	assert(manager.get_stage_info(7).get("mission_title") == "OPERATION IRON HARBOR", "Stage07 must use the Iron Harbor title")
	assert(manager.get_stage_info(7).get("scene_path") == "res://scenes/stages/Stage07.tscn", "Stage07 must follow the stage scene path convention")
	assert(manager.get_stage_info(8).get("mission_title") in ["OPERATION IRON PEAK", "OPERATION WHITEOUT"], "Stage08 must use the Iron Peak title")
	assert(manager.get_stage_info(8).get("scene_path") == "res://scenes/stages/Stage08.tscn", "Stage08 must follow the stage scene path convention")

	var hq := await _open_hq()
	assert(hq.get_mission_rows().size() == 8, "HQ must render eight compact mission rows")
	assert(hq.missions_container.has_node("OperationHeader_3"), "Operation III header must exist in HQ")
	assert((hq.missions_container.get_node("OperationHeader_3") as Label).text == "OPERATION III", "Operation III label text must match")
	assert(hq.missions_container.has_node("OperationHeader_4"), "Operation IV header must exist in HQ")
	assert((hq.missions_container.get_node("OperationHeader_4") as Label).text == "OPERATION IV", "Operation IV label text must match")
	assert(hq.get_selected_stage_id() == 2, "First HQ visit must select the next available incomplete stage")
	assert(_rows_by_id(hq)[2].has_focus(), "Selected mission row must expose keyboard focus")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not paused, "HQ must restore visible mouse and unpaused menu input")
	assert(hq.codename_label.text == "CODENAME  OPERATIONSREGRESSION", "HQ must read codename from ProfileManager")
	assert(hq.highest_score_label.text == "1,850" and hq.career_score_label.text == "1,850", "Header scores must come from the profile")
	assert(hq.action_button.custom_minimum_size.y >= 48.0, "Primary action must remain touch-sized")

	var rows := _rows_by_id(hq)
	_assert_no_row_tooltips(hq)
	assert(rows[1].get_theme_stylebox("hover") != rows[1].get_theme_stylebox("normal"), "Row hover highlight must remain distinct")
	assert(rows[1].get_theme_stylebox("pressed") != rows[1].get_theme_stylebox("normal"), "Row selection highlight must remain distinct")
	assert(rows[1].stage_status == "COMPLETED" and rows[1].get_best_score_text() == "1,850", "Stage01 row must show completed and real best")
	assert(rows[2].stage_status == "AVAILABLE", "Stage02 must show available")
	assert(rows[4].stage_status == "LOCKED", "Stage04 must show locked")
	assert(rows[7].stage_status == "LOCKED", "Stage07 must remain locked until legitimately unlocked")
	assert(rows[8].stage_status == "LOCKED", "Stage08 must remain locked until legitimately unlocked")
	rows[1].emit_signal("mission_selected", 1)
	await process_frame
	assert(hq.get_selected_stage_id() == 1 and hq.action_button.text == "REPLAY MISSION", "Completed row selection must update details without launching")
	assert(current_scene == hq, "Selecting a mission row must not start gameplay")
	rows[4].emit_signal("mission_selected", 4)
	await process_frame
	assert(hq.get_selected_stage_id() == 4 and hq.action_button.disabled, "Locked row must show disabled central action")
	assert("STAGE 03" in hq.unlock_label.text, "Locked details must state the sequential unlock requirement")

	# Both UI and StageManager prevent locked deployment without profile mutation.
	var snapshot_before_block: Dictionary = profile.get_profile()
	var scene_before_block := current_scene
	hq._on_action_pressed()
	assert(current_scene == scene_before_block, "Locked central action must not launch")
	manager.current_stage_id = 2
	assert(not manager.load_stage(4), "StageManager must independently reject locked Stage04")
	assert(manager.current_stage_id == 2 and profile.get_profile() == snapshot_before_block, "Blocked load must not mutate stage or profile")
	assert(not manager.load_stage(7), "StageManager must independently reject locked Stage07")
	assert(manager.current_stage_id == 2 and profile.get_profile() == snapshot_before_block, "Locked Stage07 load must not mutate stage or profile")
	assert(not manager.is_stage_unlocked(7), "Stage07 must remain locked prior to completing Stage06")
	assert(not manager.load_stage(8), "StageManager must independently reject locked Stage08")
	assert(manager.current_stage_id == 2 and profile.get_profile() == snapshot_before_block, "Locked Stage08 load must not mutate stage or profile")
	assert(not manager.is_stage_unlocked(8), "Stage08 must remain locked prior to completing Stage07")

	# HQ refresh/selection cannot award a score, complete, or unlock anything.
	hq._on_refresh_pressed()
	for _frame in 3:
		await process_frame
	assert(profile.get_profile() == snapshot_before_block, "Opening/refreshing HQ must be profile read-only")
	_assert_no_row_tooltips(hq)

	# Return routes select the last played stage and display freshly saved data.
	profile.current_profile["best_scores"]["1"] = 2100
	profile.current_profile["highest_score"] = 2100
	profile.current_profile["career_score"] = 2100
	assert(profile.save_profile(), "Temporary updated result must save")
	set_meta("hq_return_stage_id", 1)
	hq.queue_free()
	await process_frame
	hq = await _open_hq()
	assert(hq.get_selected_stage_id() == 1, "Return to HQ must select the last played stage")
	assert(hq.detail_best_score_label.text == "2,100 PTS", "Return to HQ must display the fresh best score")

	# Completing Stage06 legitimately unlocks Stage07 while retaining old scores.
	_set_profile(6, [1, 2, 3, 4, 5, 6], {"1": 1850, "5": 2208, "6": 1989}, 6)
	profile.record_stage_completed(6)
	hq.queue_free()
	await process_frame
	hq = await _open_hq()
	rows = _rows_by_id(hq)
	assert(hq.get_selected_stage_id() == 7, "Stage07 must become the next available mission after Stage06 completion")
	assert(rows[1].get_best_score_text() == "1,850" and rows[6].get_best_score_text() == "1,989", "Existing Stage01 and Stage06 best scores must remain visible")
	assert(rows[7].stage_status == "AVAILABLE", "Stage07 must unlock through legitimate Stage06 progression")
	assert(rows[8].stage_status == "LOCKED", "Stage08 must remain locked when only Stage06 is completed")
	assert(hq.campaign_label.text == "STAGE 07 AVAILABLE", "Campaign header must report Stage07 availability")
	assert(hq.action_button.text == "DEPLOY", "Newly unlocked Stage07 must be deployable in the HQ")
	hq._select_stage(6)
	assert(hq.detail_best_score_label.text == "1,989 PTS", "Stage06 detail must read its real fixture best")
	manager.current_stage_id = 6
	assert(manager.get_next_registered_stage_id(6) == 7, "Stage06 must advance to registered Stage07")
	assert(manager.is_stage_unlocked(7), "Registered Stage07 must be unlocked after Stage06 completion")
	assert(not manager.is_stage_unlocked(8), "Registered Stage08 must remain locked after Stage06 completion")

	# The single HQ action launches the selected real mission; both result-return
	# handlers route directly back and retain selection.
	var score_snapshot: Dictionary = profile.get_profile()
	hq._select_stage(5)
	hq._on_action_pressed()
	for _frame in 24:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage05", "Replay action must launch selected Stage05")
	current_scene._on_main_menu_requested()
	for _frame in 12:
		await process_frame
	hq = current_scene
	assert(hq.name == "OperationsHQ" and hq.get_selected_stage_id() == 5, "Stage05 RETURN TO HQ must return directly with Stage05 selected")
	hq._select_stage(6)
	hq._on_action_pressed()
	for _frame in 24:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage06", "Replay action must launch selected Stage06")
	current_scene.summary_dialog.display_summary(6, {}, true)
	current_scene._configure_stage06_debrief()
	assert(current_scene.summary_dialog.mission_status_label.text == "MISSION COMPLETE", "Stage06 debrief must not claim campaign completion")
	assert(current_scene.summary_dialog.next_btn.visible, "Unlocked Stage07 must expose NEXT MISSION")
	assert(current_scene.summary_dialog.menu_btn.text == "RETURN TO HQ", "Stage06 result return label must be consistent")
	current_scene._on_main_menu_requested()
	for _frame in 12:
		await process_frame
	hq = current_scene
	assert(hq.name == "OperationsHQ" and hq.get_selected_stage_id() == 7, "Stage06 RETURN TO HQ must select unlocked Stage07")

	# Deploy directly to Stage 07 from HQ
	hq._on_action_pressed()
	for _frame in 24:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage07", "HQ Action button must deploy to unlocked Stage07")
	current_scene._on_main_menu_requested()
	for _frame in 12:
		await process_frame
	hq = current_scene
	assert(hq.name == "OperationsHQ" and hq.get_selected_stage_id() == 7, "Return from Stage07 must select Stage07 in HQ")
	assert(profile.get_career_score() == int(score_snapshot["career_score"]), "Mission navigation without completion must not double-count Career Score")

	# Completing Stage07 legitimately unlocks Stage08
	profile.record_stage_completed(7)
	hq.queue_free()
	await process_frame
	hq = await _open_hq()
	rows = _rows_by_id(hq)
	assert(hq.get_selected_stage_id() == 8, "Stage08 must become the next available mission after Stage07 completion")
	assert(rows[7].stage_status == "COMPLETED", "Stage07 must show completed")
	assert(rows[8].stage_status == "AVAILABLE", "Stage08 must unlock through legitimate Stage07 progression")
	assert(hq.campaign_label.text == "STAGE 08 AVAILABLE", "Campaign header must report Stage08 availability")
	assert(manager.get_next_registered_stage_id(7) == 8, "Stage07 must advance to registered Stage08")
	assert(manager.is_stage_unlocked(8), "Registered Stage08 must be unlocked after Stage07 completion")
	assert(manager.get_next_registered_stage_id(8) == -1, "No registered stage follows Stage08")

	# No-profile startup remains on identity creation; Switch Operative also uses it.
	hq.queue_free()
	await process_frame
	_cleanup_test_save()
	assert(not profile.load_profile(), "No-profile fixture must clear the temporary registry")
	var identity_scene := load("res://scenes/IdentityScreen.tscn") as PackedScene
	var identity := identity_scene.instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 3:
		await process_frame
	assert(current_scene == identity and identity.creation_section.visible and identity.name_input.has_focus(), "No-profile startup must open focused creation directly")
	identity.queue_free()
	await process_frame
	_set_profile(6, [1, 2, 3, 4, 5, 6], {"5": 2208, "6": 1989}, 6)
	set_meta("switching_operative", true)
	identity = identity_scene.instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 3:
		await process_frame
	assert(identity.selection_section.visible and identity.profile_selector.item_count == 1, "Switch Operative must show the registry-backed selector")
	assert(identity.profile_selector.get_item_text(identity.profile_selector.selected) == "OperationsRegression", "Active operative must be preselected without typing")
	assert(identity.back_button.visible and identity.new_operative_button.visible, "Switch screen must expose Back and a separate New Operative action")
	identity.queue_free()
	await process_frame
	identity = identity_scene.instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 8:
		await process_frame
	assert(current_scene != null and current_scene.name == "OperationsHQ", "Saved-profile startup must bypass the old dossier stop and open HQ")

	_restore()
	print("[OperationsHQStep3C] PASS: startup, 7+1 rows, selection/details, locked guard, fresh return, campaign progression, identity/switch, no score mutation")
	quit(0)

func _open_hq() -> Node:
	var hq_scene := load("res://scenes/StageSelection.tscn") as PackedScene
	var hq := hq_scene.instantiate()
	root.add_child(hq)
	current_scene = hq
	for _frame in 4:
		await process_frame
	return hq

func _rows_by_id(hq: Node) -> Dictionary:
	var result := {}
	for row in hq.get_mission_rows():
		result[row.stage_id] = row
	return result

func _assert_no_row_tooltips(hq: Node) -> void:
	for row in hq.get_mission_rows():
		assert(row.tooltip_text.is_empty(), "Stage row tooltip must stay empty")
		for descendant in row.find_children("*", "Control", true, false):
			assert((descendant as Control).tooltip_text.is_empty(), "Stage row child tooltip must stay empty")

func _set_profile(highest: int, completed: Array, scores: Dictionary, last_played: int) -> void:
	var career := 0
	var highest_score := 0
	for score in scores.values():
		career += int(score)
		highest_score = maxi(highest_score, int(score))
	profile.current_profile = {
		"save_version": 1,
		"player_name": "OperationsRegression",
		"highest_unlocked_stage": highest,
		"completed_stages": completed,
		"best_scores": scores,
		"highest_score": highest_score,
		"career_score": career,
		"last_played_stage": last_played
	}
	assert(profile.save_profile(), "Temporary Operations HQ fixture must save")

func _restore() -> void:
	profile.save_path = original_save_path
	profile.current_profile = original_profile
	manager.current_stage_id = original_stage_id
	_cleanup_test_save()

func _cleanup_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
