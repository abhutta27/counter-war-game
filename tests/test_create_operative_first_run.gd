extends SceneTree
## First-run creation, save failure, help/Escape, submit guard, and layout QA.

const TEST_SAVE := "res://tests/.create_operative_first_run.json"
const BAD_SAVE := "res://tests/.missing_save_directory/profile.json"
const OUTPUT_DIR := "res://verification_screenshots"
const SIZES := [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720)]

var profile: Node
var identity: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	profile = root.get_node("ProfileManager")
	_cleanup()
	profile.save_path = TEST_SAVE
	assert(not profile.load_profile(), "Isolated first-run save must begin without a profile")
	_ensure_output_dir()

	for size in SIZES:
		DisplayServer.window_set_size(size)
		identity = (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
		root.add_child(identity)
		current_scene = identity
		for _frame in 5:
			await process_frame
		assert(identity.creation_section.visible and not identity.selection_section.visible, "No-profile startup must show creation")
		assert(identity.name_input.has_focus(), "Codename input must receive keyboard focus")
		assert(not identity.creation_back_button.visible and not identity.back_button.visible, "First-run creation must not expose a route to empty HQ")
		assert(identity.create_button.text == "CREATE & CONTINUE", "Primary action copy must match the approved flow")
		assert(identity.name_input.placeholder_text == "Enter your name", "Codename placeholder must match the approved copy")
		var panel: Control = identity.get_node("SafeMargin/Page/Center/CenterPanel")
		_capture_if_available("%s/create_operative_%dx%d.png" % [OUTPUT_DIR, size.x, size.y])
		var viewport_rect := root.get_viewport().get_visible_rect()
		print("[CreateOperativeFirstRun] %s viewport=%s panel=%s" % [size, viewport_rect, panel.get_global_rect()])
		assert(viewport_rect.encloses(panel.get_global_rect()), "Creation panel must stay inside %dx%d" % [size.x, size.y])
		identity.queue_free()
		await process_frame

	DisplayServer.window_set_size(Vector2i(960, 540))
	identity = (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 4:
		await process_frame
	identity._create_operative()
	assert("valid codename" in identity.feedback_label.text, "Blank submission must show a short validation error")
	identity.controls_button.pressed.emit()
	assert(identity.controls_overlay.visible, "Controls / Help must open on creation")
	for _frame in 2:
		await process_frame
	_capture_if_available("%s/create_operative_help_960x540.png" % OUTPUT_DIR)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	identity._input(escape)
	assert(not identity.controls_overlay.visible and current_scene == identity, "Escape must close Help without leaving creation")
	identity._input(escape)
	assert(current_scene == identity, "Escape with no profile must not open an empty HQ")

	profile.save_path = BAD_SAVE
	identity.name_input.text = "SAVEFAIL"
	identity._create_operative()
	assert("Could not save" in identity.feedback_label.text, "Save failure must leave the form with a clear error")
	assert(identity.creation_section.visible and identity.name_input.editable and not identity.create_button.disabled, "Save failure must keep the form usable")
	assert(not profile.has_valid_profile() and profile.get_profile_entries().is_empty(), "Failed save must roll back the unsaved profile")

	profile.save_path = TEST_SAVE
	identity.name_input.text = "FIRSTRUN"
	identity._create_operative()
	identity._create_operative()
	for _frame in 8:
		await process_frame
	assert(profile.get_profile_entries().size() == 1, "Repeated submit must create exactly one profile")
	assert(current_scene.name == "OperationsHQ", "Successful save must open the existing HQ")
	assert(profile.get_highest_unlocked_stage() == 1 and profile.get_career_score() == 0 and profile.get_highest_score() == 0, "New profile must start at Stage01 with zero scores")
	_capture_if_available("%s/new_operative_hq_960x540.png" % OUTPUT_DIR)
	assert(profile.load_profile() and profile.get_player_name() == "FIRSTRUN", "Created active profile must survive a reload")

	_cleanup()
	print("[CreateOperativeFirstRun] PASS: startup, copy, focus, bounds, Help/Escape, rollback, submit guard, defaults, persistence")
	quit(0)

func _ensure_output_dir() -> void:
	var directory := DirAccess.open("res://")
	if not directory.dir_exists("verification_screenshots"):
		directory.make_dir("verification_screenshots")

func _capture_if_available(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png(path)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
