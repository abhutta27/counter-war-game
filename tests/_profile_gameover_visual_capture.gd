extends SceneTree
## Rendered UI evidence. Uses only a project-local temporary profile save.

const TEST_SAVE := "res://tests/.profile_gameover_visual.json"
const OUTPUT_DIR := "res://verification_screenshots"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var profile = root.get_node("ProfileManager")
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_or_switch_profile("ALI"), "ALI fixture must save")
	profile.current_profile["highest_unlocked_stage"] = 6
	profile.current_profile["completed_stages"] = [1, 2, 3, 4, 5, 6]
	profile.current_profile["best_scores"] = {"1": 1850, "2": 1548, "3": 1455, "4": 1989, "5": 2208, "6": 1989}
	assert(profile.save_profile(), "ALI record must save")
	assert(profile.create_or_switch_profile("AHMAD"), "AHMAD fixture must save")

	var hq_scene := load("res://scenes/StageSelection.tscn") as PackedScene
	var hq = hq_scene.instantiate()
	root.add_child(hq)
	current_scene = hq
	for _frame in 8:
		await process_frame
	assert(hq.codename_label.text == "CODENAME  AHMAD", "AHMAD HQ must be active")
	assert(hq.highest_score_label.text == "0" and hq.career_score_label.text == "0", "AHMAD HQ scores must be zero")
	assert(hq.get_mission_rows()[0].stage_status == "AVAILABLE" and hq.get_mission_rows()[1].stage_status == "LOCKED", "Only Stage01 may be available")
	await _capture("profile_isolation_ahmad_hq.png")

	assert(profile.create_or_switch_profile("ALI"), "Switch back to ALI must save")
	hq.refresh_from_profile()
	for _frame in 5:
		await process_frame
	assert(hq.codename_label.text == "CODENAME  ALI", "ALI HQ must be restored")
	assert(hq.highest_score_label.text == "2,208" and hq.career_score_label.text == "11,039", "ALI scores must be restored")
	await _capture("profile_isolation_ali_restored_hq.png")

	hq.queue_free()
	await process_frame
	var stage := (load("res://scenes/stages/Stage01.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 8:
		await process_frame
	var profile_before: Dictionary = profile.get_profile()
	var failed_breakdown: Dictionary = root.get_node("ScoreCalculator").get_mission_score_breakdown(2, 1, 6, 3, 0, 100, false)
	failed_breakdown["best_score"] = profile.get_best_score(1)
	failed_breakdown["is_new_best"] = false
	stage.summary_dialog.display_summary(1, failed_breakdown, false)
	for _frame in 4:
		await process_frame
	assert(profile.get_profile() == profile_before, "Displaying a failed attempt must not mutate the profile")
	assert(stage.summary_dialog.mission_status_label.text == "GAME OVER", "GAME OVER title must render")
	assert(not stage.summary_dialog.mission_detail.visible, "Mission Complete row must remain hidden")
	await _capture("game_over_unsaved_attempt.png")

	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[ProfileGameOverVisual] PASS: AHMAD HQ, ALI restore, and Game Over screenshots saved")
	quit(0)

func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	assert(image.save_png(path) == OK, "Could not save %s" % path)
	print("[ProfileGameOverVisual] Saved %s" % path)
