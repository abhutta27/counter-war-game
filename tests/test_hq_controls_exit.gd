extends SceneTree
## Verifies Input Map-derived help and the visible Exit button's quit wiring.

const TEST_SAVE := "res://tests/.hq_controls_exit.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var profile = root.get_node("ProfileManager")
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_or_switch_profile("ControlsTest"), "Temporary profile must save")
	var hq := (load("res://scenes/StageSelection.tscn") as PackedScene).instantiate()
	root.add_child(hq)
	current_scene = hq
	for _frame in 5:
		await process_frame
	var help_text: String = hq.controls_label.text
	for expected in ["W/A/S/D", "Space", "Shift", "Ctrl/C", "Left Mouse Button", "R", "Q", "Escape"]:
		assert(expected in help_text, "Controls help must reflect Input Map binding: %s" % expected)
	assert("Right Mouse Button" not in help_text and "AIM" not in help_text, "Help must not advertise unimplemented aim")
	assert(hq.controls_button.visible and hq.controls_button.text == "CONTROLS / HELP", "Controls must use a clear button")
	hq.controls_button.pressed.emit()
	assert(hq.controls_overlay.visible, "Controls button must open the readable help panel")
	hq.controls_close_button.pressed.emit()
	assert(not hq.controls_overlay.visible, "Controls panel close button must hide the panel")
	hq.controls_button.pressed.emit()
	assert(hq.controls_overlay.visible, "Controls button must reopen the help panel")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	hq._input(escape_event)
	assert(not hq.controls_overlay.visible, "Escape must close the controls panel")
	assert(hq.exit_button.visible and hq.exit_button.text == "EXIT GAME", "Exit Game button must be visible and explicit")
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[HQControlsExit] PASS: Input Map help rendered; Close/Escape work; emitting EXIT GAME now")
	hq.exit_button.pressed.emit()
