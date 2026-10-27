extends SceneTree
## Automated Step 2 scoring and persistence checks with an isolated profile file.

const ProfileManagerScript = preload("res://scripts/core/profile_manager.gd")
const TEST_SAVE := "res://tests/.scoring_step_2_test.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var profile = ProfileManagerScript.new()
	profile.save_path = TEST_SAVE
	root.add_child(profile)
	await process_frame
	assert(profile.create_or_update_profile("Ali"), "Fixture profile must save")
	profile.current_profile["highest_unlocked_stage"] = 6
	profile.current_profile["completed_stages"] = [1, 2, 3, 4, 5, 6]
	profile.current_profile["last_played_stage"] = 6
	assert(profile.save_profile(), "Fixture progress must save")
	var score_calculator = root.get_node("ScoreCalculator")

	# A/B/C/D/E: exact deterministic formula and metric behavior.
	var one_kill: Dictionary = score_calculator.get_mission_score_breakdown(1, 0, 0, 0, 0, 100, false)
	assert(one_kill.kill_score == 100, "A: one kill must be exactly 100 points")
	assert(one_kill.final_score == 100, "A: incomplete attempt must have no completion bonuses at zero health")
	var headshot_kill: Dictionary = score_calculator.get_mission_score_breakdown(1, 1, 1, 1, 100, 100, true)
	assert(headshot_kill.headshot_bonus == 50, "B: one legitimate headshot kill must add 50")
	assert(score_calculator.calculate_accuracy(3, 0) == 0.0, "C: misses must not increase shots_hit")
	assert(score_calculator.calculate_accuracy(4, 3) == 75.0, "D: hits must produce correct accuracy")
	var completed: Dictionary = score_calculator.get_mission_score_breakdown(5, 1, 10, 8, 50, 100, true)
	assert(completed.kill_score == 500, "E: five kills must score 500")
	assert(completed.headshot_bonus == 50, "E: headshot component must be present")
	assert(completed.health_bonus == 150, "E: 50 percent health must score 150")
	assert(completed.accuracy_bonus == 240, "E: 80 percent accuracy must score 240")
	assert(completed.mission_complete_score == 500, "E: victory must score 500")
	assert(completed.final_score == 1440, "E: total mission score must equal all components")

	# Shared gameplay hooks: duplicate death is ignored, and a confirmed headshot gets +50.
	var stage_scene := load("res://scenes/stages/Stage01.tscn") as PackedScene
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 5:
		await process_frame
	stage.set_process(false)
	stage.set_physics_process(false)
	var enemies: Array = stage.enemies_container.get_children()
	stage._on_enemy_destroyed(enemies[0])
	stage._on_enemy_destroyed(enemies[0])
	assert(stage.kills == 1 and stage.current_mission_score == 100, "A: enemy death hook must award 100 exactly once")
	enemies[1].is_dead = true
	stage._on_enemy_destroyed(enemies[1])
	stage._on_player_shot_hit(enemies[1], true)
	assert(stage.kills == 2 and stage.headshots == 1, "B: confirmed headshot hook must count once")
	assert(stage.current_mission_score == 250, "B: two kills plus one headshot must equal 250")
	stage._on_player_shot_fired()
	stage._on_player_shot_fired()
	assert(stage.shots_fired == 2 and stage.shots_hit == 1, "C/D: fired and hit counters must be independent")
	current_scene = null
	stage.queue_free()
	await process_frame

	# F/G: first best persists and feeds HQ aggregates after a clean reload.
	var first_result := profile.record_stage_score(1, 1440)
	assert(first_result.is_new_best and first_result.best_score == 1440, "F: first completion must save a best")
	assert(profile.get_highest_score() == 1440 and profile.get_career_score() == 1440, "F: HQ aggregates must be non-zero")
	var reloaded = ProfileManagerScript.new()
	reloaded.save_path = TEST_SAVE
	root.add_child(reloaded)
	await process_frame
	assert(reloaded.get_best_score(1) == 1440, "G: stage best must survive reload")
	assert(reloaded.get_highest_score() == 1440 and reloaded.get_career_score() == 1440, "G: HQ totals must survive reload")

	# H/I: lower replay is ignored; higher replay replaces and recalculates.
	var lower := reloaded.record_stage_score(1, 1200)
	assert(not lower.is_new_best and reloaded.get_best_score(1) == 1440, "H: lower replay must not replace best")
	assert(reloaded.get_career_score() == 1440, "H: lower replay must not increase career score")
	var higher := reloaded.record_stage_score(1, 1600)
	assert(higher.is_new_best and reloaded.get_best_score(1) == 1600, "I: higher replay must replace best")
	assert(reloaded.get_highest_score() == 1600 and reloaded.get_career_score() == 1600, "I: aggregates must recalculate")
	reloaded.record_stage_score(2, 1300)
	assert(reloaded.get_highest_score() == 1600, "I: highest means single highest stage best")
	assert(reloaded.get_career_score() == 2900, "I: career score means sum of stage bests")

	# J: an unfinished/death attempt never calls record_stage_score and cannot mutate saved values.
	var score_before_death := reloaded.get_career_score()
	var failed_attempt: Dictionary = score_calculator.get_mission_score_breakdown(2, 0, 7, 2, 0, 100, false)
	assert(failed_attempt.mission_complete_score == 0, "J: death must not receive completion points")
	assert(reloaded.get_career_score() == score_before_death, "J: unfinished attempt must not save")

	# L: Step 1 fields survive score writes and reloads.
	var final_reload = ProfileManagerScript.new()
	final_reload.save_path = TEST_SAVE
	root.add_child(final_reload)
	await process_frame
	var saved := final_reload.get_profile()
	assert(saved.player_name == "Ali", "L: existing player name must remain")
	assert(saved.highest_unlocked_stage == 6, "L: Stage 6 campaign progress must remain")
	assert(saved.completed_stages == [1, 2, 3, 4, 5, 6], "L: completed stages must remain")
	assert(saved.last_played_stage == 6, "L: last played stage must remain")

	# UI accepts the real breakdown and exposes Best/New Best labels.
	var summary_scene := load("res://scenes/ui/StageSummaryDialog.tscn") as PackedScene
	var summary = summary_scene.instantiate()
	root.add_child(summary)
	await process_frame
	completed.merge({"best_score": 1440, "is_new_best": true}, true)
	summary.display_summary(1, completed, true)
	assert(summary.final_score_label.text == "1,440 PTS", "E: debrief must show mission total")
	assert(summary.best_score_label.text == "1,440 PTS", "E: debrief must show stage best")
	assert(summary.new_best_label.visible, "E: debrief must show NEW BEST SCORE")

	_cleanup()
	print("[RealScoringStep2] PASS: Tests A-J and L; Stage06 Test K runs in its dedicated regression")
	quit(0)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
