extends SceneTree
## Stage 08 — Operation Whiteout Briefing Automated QA and Screenshot Capture.

const BRIEFING_SCENE_PATH := "res://scenes/stages/Stage08WhiteoutBriefing.tscn"
const SCREENSHOT_PATH := "res://verification_screenshots/stage08_whiteout_briefing.png"

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("==================================================")
	print("STAGE 08 WHITEOUT BRIEFING QA TEST SUITE")
	print("==================================================")

	# 1. Load scene
	var packed: PackedScene = load(BRIEFING_SCENE_PATH)
	assert(packed != null, "Briefing scene failed to load from: " + BRIEFING_SCENE_PATH)
	print("[QA] Briefing scene loaded successfully.")

	var briefing: Control = packed.instantiate() as Control
	assert(briefing != null, "Briefing scene failed to instantiate.")
	root.add_child(briefing)
	current_scene = briefing

	for _i in range(15):
		await process_frame

	# 2. Check UI Nodes and Tactical Mission Content
	var operation_title: Label = briefing.get_node("OuterMargin/Page/Header/TitleBlock/OperationTitle")
	var status_text: Label = briefing.get_node("OuterMargin/Page/Header/HeaderStatus/StatusText")
	var summary_text: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/SummaryPanel/SummaryMargin/SummaryContent/SummaryText")
	var obj1_title: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/SummaryPanel/SummaryMargin/SummaryContent/ObjectiveOne/ObjectiveOneTitle")
	var obj1_text: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/SummaryPanel/SummaryMargin/SummaryContent/ObjectiveOne/ObjectiveOneText")
	var obj2_title: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/SummaryPanel/SummaryMargin/SummaryContent/ObjectiveTwo/ObjectiveTwoTitle")
	var obj2_text: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/SummaryPanel/SummaryMargin/SummaryContent/ObjectiveTwo/ObjectiveTwoText")
	var area_val: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/IntelPanel/IntelMargin/IntelContent/AreaValue")
	var threat_val: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/IntelPanel/IntelMargin/IntelContent/ThreatValue")
	var profile_val: Label = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid/IntelPanel/IntelMargin/IntelContent/ProfileValue")
	var nav_note: Label = briefing.get_node("OuterMargin/Page/Footer/NavigationNote")
	var back_btn: Button = briefing.get_node("OuterMargin/Page/Footer/BackButton")
	var continue_btn: Button = briefing.get_node("OuterMargin/Page/Footer/ContinueButton")

	assert(operation_title.text == "OPERATION WHITEOUT", "Operation title mismatch: " + operation_title.text)
	assert(not "PENDING" in status_text.text, "Status text must not be PENDING: " + status_text.text)
	assert("AUTHORIZED" in status_text.text, "Status text must show AUTHORIZED")
	assert("alpine" in summary_text.text.to_lower() or "radar" in summary_text.text.to_lower(), "Summary must describe alpine/radar mission")
	assert(not "Awaiting" in obj1_text.text, "Objective 1 must not be awaiting data")
	assert(not "Awaiting" in obj2_text.text, "Objective 2 must not be awaiting data")
	assert(not "Not provided" in area_val.text, "Area must not be 'Not provided'")
	assert("12" in threat_val.text, "Threat must specify 12 hostiles")
	assert(not "STANDALONE" in nav_note.text, "Footer note must not say navigation unavailable standalone")
	print("[QA] Tactical mission text verified: all placeholders replaced with Operation Whiteout dossier.")

	# 3. Check Buttons and Signals
	assert(not back_btn.disabled, "BACK button must be enabled")
	assert(not continue_btn.disabled, "CONTINUE button must be enabled")
	assert(back_btn.pressed.is_connected(briefing._on_back_pressed), "BACK button must be connected to _on_back_pressed")
	assert(continue_btn.pressed.is_connected(briefing._on_continue_pressed), "CONTINUE button must be connected to _on_continue_pressed")
	print("[QA] Button enablement and signal connections verified.")

	# 4. Check Navigation Targets
	assert(ResourceLoader.exists(briefing.STAGE_SELECTION_SCENE_PATH), "STAGE_SELECTION_SCENE_PATH must exist: " + briefing.STAGE_SELECTION_SCENE_PATH)
	var stage_select_packed = load(briefing.STAGE_SELECTION_SCENE_PATH)
	assert(stage_select_packed != null, "Stage selection scene must load cleanly")

	assert(ResourceLoader.exists(briefing.LOADOUT_SCENE_PATH), "LOADOUT_SCENE_PATH must exist: " + briefing.LOADOUT_SCENE_PATH)
	var loadout_packed = load(briefing.LOADOUT_SCENE_PATH)
	assert(loadout_packed != null, "Loadout scene must load cleanly")
	print("[QA] Navigation targets verified: both StageSelection and Stage08 Loadout load cleanly.")

	# 5. Check Responsive Layout Logic
	var briefing_grid: GridContainer = briefing.get_node("OuterMargin/Page/MainScroll/BriefingGrid")
	var header_status: Control = briefing.get_node("OuterMargin/Page/Header/HeaderStatus")

	# Test wide layout logic
	var wide_cols = 1 if 1280.0 < briefing.SINGLE_COLUMN_WIDTH else 2
	assert(wide_cols == 2, "Wide viewports should have 2 columns")
	var narrow_cols = 1 if 600.0 < briefing.SINGLE_COLUMN_WIDTH else 2
	assert(narrow_cols == 1, "Narrow viewports should have 1 column")
	print("[QA] Responsive layout column thresholds verified.")

	# 6. Capture Visual Screenshot
	for _i in range(15):
		await process_frame

	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		DirAccess.make_dir_recursive_absolute("res://verification_screenshots")
		var save_err := img.save_png(SCREENSHOT_PATH)
		assert(save_err == OK, "Failed to save screenshot, error code: " + str(save_err))
		print("[QA] Screenshot saved successfully to: " + SCREENSHOT_PATH)
	else:
		printerr("[QA] Failed to acquire viewport texture image.")

	# 7. Navigation Execution Test (Simulate Continue Button Press)
	print("[QA] Testing CONTINUE button transition to Loadout...")
	briefing.continue_button.emit_signal("pressed")
	for _i in range(10):
		await process_frame

	assert(current_scene != briefing, "Scene should transition away from Briefing after CONTINUE")
	assert("Loadout" in current_scene.name, "New scene should be Loadout, was: " + current_scene.name)
	print("[QA] Scene successfully transitioned from Briefing to: " + current_scene.name)

	# 8. Navigation Execution Test (Simulate Back Button Press from Loadout back to Briefing)
	var loadout_back_btn = current_scene.get_node_or_null("OuterMargin/Page/Footer/BackButton")
	assert(loadout_back_btn != null, "Loadout must have BackButton")
	loadout_back_btn.emit_signal("pressed")
	for _i in range(10):
		await process_frame

	assert("Briefing" in current_scene.name, "Back button from Loadout should return to Briefing, was: " + current_scene.name)
	print("[QA] Scene successfully transitioned back from Loadout to: " + current_scene.name)

	# 9. Navigation Execution Test (Simulate Back Button Press from Briefing to Stage Selection)
	var current_briefing = current_scene
	var return_back_btn = current_briefing.get_node_or_null("OuterMargin/Page/Footer/BackButton")
	assert(return_back_btn != null, "Briefing must have BackButton")
	return_back_btn.emit_signal("pressed")
	for _i in range(10):
		await process_frame

	assert(current_scene != current_briefing, "Scene should transition away from Briefing after BACK")
	assert("StageSelection" in current_scene.name or "OperationsHQ" in current_scene.name, "New scene should be StageSelection/OperationsHQ, was: " + current_scene.name)
	print("[QA] Scene successfully transitioned from Briefing back to: " + current_scene.name)

	print("==================================================")
	print("[QA] ALL TESTS PASSED: Briefing UI, Content, Buttons, and Two-Way Navigation verified!")
	print("==================================================")
	quit(0)
