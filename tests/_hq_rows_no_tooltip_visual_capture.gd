extends SceneTree

const TEST_SAVE := "res://tests/.hq_rows_no_tooltip_visual.json"
const OUTPUT := "res://verification_screenshots/hq_stage_rows_no_tooltip_960x540.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(960, 540))
	var profile = root.get_node("ProfileManager")
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_new_profile("TOOLTIP QA"), "Temporary visual profile must save")
	var hq := (load("res://scenes/StageSelection.tscn") as PackedScene).instantiate()
	root.add_child(hq)
	current_scene = hq
	for _frame in 8:
		await process_frame
	var rows: Array[Node] = hq.get_mission_rows()
	assert(rows.size() == 6, "HQ must render all six stage rows")
	for row in rows:
		assert(row.tooltip_text.is_empty(), "Stage row tooltip must be empty")
		for descendant in row.find_children("*", "Control", true, false):
			assert((descendant as Control).tooltip_text.is_empty(), "Stage row child tooltip must be empty")
	Input.warp_mouse(rows[1].get_global_rect().get_center())
	for _frame in 90:
		await process_frame
	var directory := DirAccess.open("res://")
	if not directory.dir_exists("verification_screenshots"):
		directory.make_dir("verification_screenshots")
	root.get_viewport().get_texture().get_image().save_png(OUTPUT)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[HQRowsNoTooltipVisual] PASS: six rows remained tooltip-free after pointer dwell")
	quit(0)
