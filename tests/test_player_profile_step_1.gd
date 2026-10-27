extends SceneTree
## Automated Step 1 profile/save checks using an isolated temporary save file.

const ProfileManagerScript = preload("res://scripts/core/profile_manager.gd")
const TEST_SAVE := "res://tests/.profile_step_1_test.json"
const LEGACY_SAVE := "res://tests/.profile_step_1_legacy.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var profile_manager = ProfileManagerScript.new()
	profile_manager.save_path = TEST_SAVE
	root.add_child(profile_manager)
	await process_frame

	assert(not profile_manager.has_valid_profile(), "A: missing save must produce no active profile")
	assert(not profile_manager.create_or_update_profile("   "), "B: blank name must be rejected")
	assert(not profile_manager.has_valid_profile(), "B: blank name must not create a profile")

	assert(profile_manager.create_or_update_profile("  Ali  "), "C: trimmed valid profile must save")
	assert(profile_manager.get_player_name() == "Ali", "C: HQ name source must be Ali")
	assert(FileAccess.file_exists(TEST_SAVE), "C: profile JSON must exist")

	var reloaded = ProfileManagerScript.new()
	reloaded.save_path = TEST_SAVE
	root.add_child(reloaded)
	await process_frame
	assert(reloaded.has_valid_profile(), "D: saved profile must reload")
	assert(reloaded.get_player_name() == "Ali", "D: returning player name must persist")

	reloaded.record_stage_completed(3)
	reloaded.record_stage_score(3, 2208)
	var progress_reload = ProfileManagerScript.new()
	progress_reload.save_path = TEST_SAVE
	root.add_child(progress_reload)
	await process_frame
	assert(progress_reload.get_highest_unlocked_stage() == 4, "E: completion must persist next-stage unlock")
	assert(progress_reload.get_profile().get("completed_stages", []).has(3), "E: completed stage must persist")

	assert(progress_reload.create_new_profile("AHMAD"), "F: explicit creation must accept a valid new name")
	assert(progress_reload.get_player_name() == "AHMAD", "F: switched operative name must become active")
	assert(progress_reload.get_highest_unlocked_stage() == 1, "F: a new operative must begin at Stage01")
	assert(progress_reload.get_highest_score() == 0 and progress_reload.get_career_score() == 0, "F: a new operative must have zero scores")
	assert(progress_reload.get_profile().get("completed_stages", []).is_empty(), "F: a new operative must have no completions")
	var entry_count := progress_reload.get_profile_entries().size()
	assert(not progress_reload.create_new_profile("ali"), "F: duplicate creation must be rejected case-insensitively")
	assert(progress_reload.get_profile_entries().size() == entry_count and progress_reload.get_player_name() == "AHMAD", "F: duplicate rejection must not switch or overwrite data")
	var ali_id := ""
	for entry in progress_reload.get_profile_entries():
		if str(entry.get("player_name", "")).to_lower() == "ali":
			ali_id = str(entry.get("profile_id", ""))
	assert(progress_reload.switch_profile(ali_id), "G: existing profile must switch by registry ID without typing")
	assert(progress_reload.get_player_name() == "Ali", "G: switching back must restore original display name")
	assert(progress_reload.get_highest_unlocked_stage() == 4, "G: Ali progression must be restored")
	assert(progress_reload.get_highest_score() == 2208 and progress_reload.get_career_score() == 2208, "G: Ali scores must be restored")
	assert(progress_reload.rename_current_profile("ALI PRIME"), "H: rename must be a separate supported action")
	assert(progress_reload.get_player_name() == "ALI PRIME" and progress_reload.get_highest_unlocked_stage() == 4, "H: rename must preserve identity and progression")
	assert(not progress_reload.rename_current_profile("AHMAD"), "H: rename must not collide with another operative")

	var restart_reload = ProfileManagerScript.new()
	restart_reload.save_path = TEST_SAVE
	root.add_child(restart_reload)
	await process_frame
	assert(restart_reload.get_player_name() == "ALI PRIME", "I: active profile must persist across restart")
	var ahmad_id := ""
	for entry in restart_reload.get_profile_entries():
		if str(entry.get("player_name", "")) == "AHMAD":
			ahmad_id = str(entry.get("profile_id", ""))
	assert(restart_reload.switch_profile(ahmad_id), "I: Ahmad must persist across restart")
	assert(restart_reload.get_highest_unlocked_stage() == 1 and restart_reload.get_career_score() == 0, "I: Ahmad's isolated zero state must persist")
	restart_reload.record_stage_score(1, 1440)
	restart_reload.record_stage_completed(1)
	assert(restart_reload.get_highest_unlocked_stage() == 2 and restart_reload.get_career_score() == 1440, "J: Ahmad's successful mission must update only Ahmad")
	var ali_prime_id := ""
	for entry in restart_reload.get_profile_entries():
		if str(entry.get("player_name", "")) == "ALI PRIME":
			ali_prime_id = str(entry.get("profile_id", ""))
	assert(restart_reload.switch_profile(ali_prime_id), "I: Ali must remain switchable after restart")
	assert(restart_reload.get_highest_unlocked_stage() == 4 and restart_reload.get_career_score() == 2208, "J: Ahmad's mission must not change Ali's record")
	assert(restart_reload.switch_profile(ahmad_id), "J: Ahmad must remain switchable after his mission")
	assert(restart_reload.get_highest_unlocked_stage() == 2 and restart_reload.get_career_score() == 1440, "J: Ahmad's successful result must persist independently")

	var legacy_file := FileAccess.open(LEGACY_SAVE, FileAccess.WRITE)
	assert(legacy_file != null, "K: legacy fixture must be writable")
	legacy_file.store_string(JSON.stringify({
		"save_version": 1,
		"player_name": "ALI",
		"highest_unlocked_stage": 6,
		"completed_stages": [1, 2, 3, 4, 5, 6],
		"best_scores": {"1": 1850, "5": 2208, "6": 1989},
		"highest_score": 2208,
		"career_score": 6047,
		"last_played_stage": 6
	}, "\t"))
	legacy_file = null
	var legacy_reload = ProfileManagerScript.new()
	legacy_reload.save_path = LEGACY_SAVE
	root.add_child(legacy_reload)
	await process_frame
	assert(legacy_reload.get_player_name() == "ALI" and legacy_reload.get_career_score() == 6047, "K: v1 migration must preserve the one legacy owner's record")
	var migrated_file := FileAccess.open(LEGACY_SAVE, FileAccess.READ)
	var migrated_data: Dictionary = JSON.parse_string(migrated_file.get_as_text())
	assert(int(migrated_data.get("save_version", 0)) == 2 and migrated_data.get("profiles", {}).size() == 1, "K: migration must create one profile, never duplicate shared data")

	var save_file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	assert(save_file != null, "Safety: test save must be writable")
	save_file.store_string("{ definitely corrupt")
	save_file = null
	assert(not restart_reload.load_profile(), "Safety: corrupt JSON must fail safely")
	assert(not restart_reload.has_valid_profile(), "Safety: corrupt JSON must return to identity state")

	var identity_scene := load("res://scenes/IdentityScreen.tscn") as PackedScene
	var hq_scene := load("res://scenes/MainMenu.tscn") as PackedScene
	assert(identity_scene != null, "Identity screen resource must load")
	assert(hq_scene != null, "HQ scene resource must load")
	var identity_instance := identity_scene.instantiate()
	var hq_instance := hq_scene.instantiate()
	assert(identity_instance != null, "Identity screen must instantiate")
	assert(hq_instance != null, "HQ scene must instantiate")
	identity_instance.free()
	hq_instance.free()

	_cleanup()
	print("[PlayerProfileStep1] PASS: ID selection, explicit creation, duplicate safety, rename isolation, persistence, and UI loading")
	quit(0)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if FileAccess.file_exists(LEGACY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE))
