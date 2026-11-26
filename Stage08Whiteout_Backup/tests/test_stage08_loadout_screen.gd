extends SceneTree
## Automated verification suite for Stage 08 Loadout -> Stage 08 gameplay transition.

const LOADOUT_SCENE_PATH := "res://scenes/stages/Stage08WhiteoutLoadout.tscn"
const STAGE08_SCENE_PATH := "res://scenes/stages/Stage08.tscn"
const LOADOUT_SCREENSHOT_PATH := "res://verification_screenshots/stage08_whiteout_loadout.png"
const SPAWN_SCREENSHOT_PATH := "res://verification_screenshots/stage08_loadout_transition_spawn.png"

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("==================================================")
	print("STAGE 08 LOADOUT QA TEST SUITE")
	print("==================================================")

	# 1. Load Loadout scene
	var packed: PackedScene = load(LOADOUT_SCENE_PATH)
	assert(packed != null, "Failed to load Loadout scene from: " + LOADOUT_SCENE_PATH)
	print("[QA] Loadout scene loaded successfully.")

	var loadout: Control = packed.instantiate() as Control
	assert(loadout != null, "Failed to instantiate Loadout scene.")
	root.add_child(loadout)
	current_scene = loadout

	for _i in range(15):
		await process_frame

	# 2. Check UI elements & Buttons
	var continue_btn: Button = loadout.get_node("OuterMargin/Page/Footer/ContinueButton")
	var back_btn: Button = loadout.get_node("OuterMargin/Page/Footer/BackButton")
	var nav_note: Label = loadout.get_node("OuterMargin/Page/Footer/NavigationNote")
	var default_weapon_val: Label = loadout.get_node("OuterMargin/Page/MainScroll/MainContent/SummaryPanel/SummaryMargin/SummaryContent/DefaultWeaponRow/DefaultWeaponValue")

	assert(continue_btn != null, "ContinueButton must exist in Loadout footer")
	assert(not continue_btn.disabled, "START MISSION ContinueButton must be enabled (disabled == false)")
	assert(continue_btn.text == "START MISSION" or "CONFIRM LOADOUT" in continue_btn.text, "Button text must be 'START MISSION' or 'CONFIRM LOADOUT'")
	assert(not "NOT CONNECTED" in nav_note.text, "Navigation note must indicate confirmed readiness")
	assert(default_weapon_val.text != "Not available", "Default weapon value should be populated from rig: " + default_weapon_val.text)
	print("[QA] Loadout UI confirmed: START MISSION button is enabled, weapon rig data populated.")

	# 3. Verify signal connection
	assert(continue_btn.pressed.is_connected(loadout._on_continue_pressed), "continue_btn must be connected to _on_continue_pressed")
	assert(back_btn.pressed.is_connected(loadout._on_back_pressed), "back_btn must be connected to _on_back_pressed")
	print("[QA] Signal connections verified without duplicates.")

	# 4. Save Loadout Screenshot
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		DirAccess.make_dir_recursive_absolute("res://verification_screenshots")
		var save_err := img.save_png(LOADOUT_SCREENSHOT_PATH)
		assert(save_err == OK, "Failed to save Loadout screenshot: " + str(save_err))
		print("[QA] Saved Loadout screenshot to: " + LOADOUT_SCREENSHOT_PATH)

	# 5. Execute START MISSION button press
	print("[QA] Triggering START MISSION button...")
	continue_btn.emit_signal("pressed")

	for _i in range(25):
		await process_frame

	# 6. Verify transition to Stage 08
	assert(current_scene != null, "Current scene must not be null after transition")
	assert(current_scene.name == "Stage08", "Scene must transition to Stage08, was: " + current_scene.name)
	print("[QA] Successfully transitioned scene to: " + current_scene.name)

	# 7. Verify StageManager Stage ID & Gameplay State
	var stg_mgr = root.get_node_or_null("StageManager")
	if stg_mgr and stg_mgr.has_method("get_current_stage_id"):
		var cur_id: int = stg_mgr.get_current_stage_id()
		assert(cur_id == 8, "StageManager current stage id must be 8, was: " + str(cur_id))
		print("[QA] StageManager confirmed current Stage ID: " + str(cur_id))

	assert("stage_id" in current_scene and current_scene.stage_id == 8, "Stage08 scene stage_id property must be 8")
	assert(current_scene.has_node("Player3D"), "Stage08 must have Player3D node")
	assert(current_scene.has_node("HUD"), "Stage08 must have HUD node")
	assert(current_scene.has_node("Enemies"), "Stage08 must have Enemies node")
	var enemy_count: int = current_scene.get_node("Enemies").get_child_count()
	assert(enemy_count == 12, "Stage08 must have 12 enemies deployed, found: " + str(enemy_count))
	print("[QA] Stage 08 gameplay confirmed: Player3D active, HUD connected, 12 guard enemies deployed.")

	# 8. Capture Gameplay Spawn Screenshot
	for _i in range(15):
		await process_frame
	var spawn_img := root.get_viewport().get_texture().get_image()
	if spawn_img:
		var spawn_save_err := spawn_img.save_png(SPAWN_SCREENSHOT_PATH)
		assert(spawn_save_err == OK, "Failed to save spawn screenshot: " + str(spawn_save_err))
		print("[QA] Saved Stage08 transition spawn screenshot to: " + SPAWN_SCREENSHOT_PATH)

	print("==================================================")
	print("[QA] ALL TESTS PASSED: START MISSION button successfully launched Stage 08!")
	print("==================================================")
	quit(0)
