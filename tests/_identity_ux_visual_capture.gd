extends SceneTree

const TEST_SAVE := "res://tests/.identity_ux_visual.json"
const OUTPUT := "res://verification_screenshots/identity_selector_960x540.png"
const SCROLL_OUTPUT := "res://verification_screenshots/identity_selector_scroll_960x540.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(960, 540))
	var profile = root.get_node("ProfileManager")
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	for index in 28:
		assert(profile.create_new_profile("OPERATIVE %02d" % (index + 1)))
	set_meta("switching_operative", true)
	var identity := (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 8:
		await process_frame
	var directory := DirAccess.open("res://")
	if not directory.dir_exists("verification_screenshots"):
		directory.make_dir("verification_screenshots")
	root.get_viewport().get_texture().get_image().save_png(OUTPUT)
	identity.profile_selector.show_popup()
	for _frame in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(SCROLL_OUTPUT)
	if OS.get_cmdline_user_args().has("manual"):
		print("[IdentityUXVisual] Interactive QA window ready at 960x540")
		return
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[IdentityUXVisual] PASS: saved %s at 960x540" % OUTPUT)
	quit(0)
