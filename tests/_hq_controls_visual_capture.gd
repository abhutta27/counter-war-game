extends SceneTree

const TEST_SAVE := "res://tests/.hq_controls_visual.json"
const OUTPUT := "res://verification_screenshots/hq_controls_help.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var profile = root.get_node("ProfileManager")
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_or_switch_profile("ControlsVisual"))
	var hq := (load("res://scenes/StageSelection.tscn") as PackedScene).instantiate()
	root.add_child(hq)
	current_scene = hq
	for _frame in 6:
		await process_frame
	hq.controls_button.pressed.emit()
	for _frame in 3:
		await process_frame
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("verification_screenshots"):
		dir.make_dir("verification_screenshots")
	root.get_viewport().get_texture().get_image().save_png(OUTPUT)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[HQControlsVisual] Saved %s" % OUTPUT)
	quit()
