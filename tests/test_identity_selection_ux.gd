extends SceneTree
## Identity UX regression using only a project-local temporary registry.

const TEST_SAVE := "res://tests/.identity_selection_ux.json"

var profile: Node
var original_save_path: String
var original_profile: Dictionary

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for _frame in 4:
		await process_frame
	profile = root.get_node("ProfileManager")
	original_save_path = profile.save_path
	original_profile = profile.current_profile.duplicate(true)
	_cleanup()
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_new_profile("EAGLE"), "Fixture EAGLE must be created")
	profile.current_profile["highest_unlocked_stage"] = 4
	profile.current_profile["completed_stages"] = [1, 2, 3]
	profile.current_profile["best_scores"] = {"1": 1850, "3": 2208}
	profile.current_profile["last_played_stage"] = 3
	assert(profile.save_profile(), "EAGLE progress fixture must save")
	var eagle_id: String = profile.get_active_profile_id()
	assert(profile.create_new_profile("FALCON"), "Fixture FALCON must be created")
	var falcon_id: String = profile.get_active_profile_id()
	assert(profile.get_highest_unlocked_stage() == 1 and profile.get_career_score() == 0, "New operative must start at zero with Stage01")

	set_meta("switching_operative", true)
	var identity := (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 4:
		await process_frame
	assert(identity.selection_section.visible and not identity.creation_section.visible, "Saved profiles must open selection flow")
	assert(identity.profile_selector.item_count == 2, "Selector must contain registry profiles exactly once")
	assert(str(identity.profile_selector.get_item_metadata(identity.profile_selector.selected)) == falcon_id, "Current operative must be preselected")
	assert(identity.profile_selector.has_focus(), "Selector must receive initial keyboard focus")
	var eagle_index := _find_selector_id(identity.profile_selector, eagle_id)
	assert(eagle_index >= 0, "EAGLE must be present by registry ID")
	identity.profile_selector.select(eagle_index)
	identity._continue_selected_profile()
	for _frame in 8:
		await process_frame
	assert(profile.get_active_profile_id() == eagle_id, "Continue must switch by selected ID without typed name")
	assert(profile.get_highest_unlocked_stage() == 4 and profile.get_career_score() == 4058, "Selected operative progress and scores must be restored")
	assert(current_scene.name == "OperationsHQ" and "EAGLE" in current_scene.codename_label.text, "HQ must show selected operative data")
	for row in current_scene.get_mission_rows():
		assert(row.tooltip_text.is_empty(), "Profile-switched HQ rows must not restore tooltips")
		for descendant in row.find_children("*", "Control", true, false):
			assert((descendant as Control).tooltip_text.is_empty(), "Profile-switched HQ row children must not restore tooltips")

	current_scene.queue_free()
	await process_frame
	set_meta("switching_operative", true)
	identity = (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 3:
		await process_frame
	assert(identity.back_button.visible, "Switch flow must expose Back when an active operative exists")
	identity.back_button.pressed.emit()
	for _frame in 8:
		await process_frame
	assert(current_scene.name == "OperationsHQ" and profile.get_active_profile_id() == eagle_id, "Back must return to HQ without changing the active operative")
	current_scene.queue_free()
	await process_frame
	set_meta("switching_operative", true)
	identity = (load("res://scenes/IdentityScreen.tscn") as PackedScene).instantiate()
	root.add_child(identity)
	current_scene = identity
	for _frame in 3:
		await process_frame
	identity._show_creation_flow()
	assert(identity.creation_section.visible and identity.name_input.has_focus(), "New Operative must expose focused name entry")
	identity.name_input.text = "falcon"
	identity._create_operative()
	assert(profile.get_profile_entries().size() == 2, "Duplicate name must not create a second profile")
	assert(profile.get_active_profile_id() == eagle_id, "Duplicate name must not switch or overwrite the active profile")
	assert("already exists" in identity.feedback_label.text, "Duplicate must show a useful validation message")

	identity._show_selection_flow()
	identity.profile_selector.get_popup().popup(Rect2i(0, 0, 360, 180))
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	identity._input(escape)
	assert(not identity.profile_selector.get_popup().visible and current_scene == identity, "Escape must close an open dropdown before navigation")
	identity._show_creation_flow()
	identity._input(escape)
	assert(identity.selection_section.visible and identity.profile_selector.has_focus(), "Escape in creation flow must return to selector")

	identity._show_creation_flow()
	identity.name_input.text = "RAVEN"
	identity._create_operative()
	for _frame in 8:
		await process_frame
	assert(profile.get_player_name() == "RAVEN", "Unique New Operative must become active")
	assert(profile.get_highest_unlocked_stage() == 1 and profile.get_career_score() == 0, "Unique New Operative must keep default unlocks and zero scores")
	assert(profile.load_profile() and profile.get_player_name() == "RAVEN", "Active selection must persist after reload")
	assert(profile.switch_profile(eagle_id), "Original operative must remain addressable after creation")
	assert(profile.get_highest_unlocked_stage() == 4 and profile.get_career_score() == 4058, "Original operative data must remain unchanged")

	_restore()
	print("[IdentitySelectionUX] PASS: dropdown switch, focus/Esc, duplicate safety, creation defaults, HQ data, and persistence")
	quit(0)

func _find_selector_id(selector: OptionButton, profile_id: String) -> int:
	for index in selector.item_count:
		if str(selector.get_item_metadata(index)) == profile_id:
			return index
	return -1

func _restore() -> void:
	profile.save_path = original_save_path
	profile.current_profile = original_profile
	_cleanup()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
