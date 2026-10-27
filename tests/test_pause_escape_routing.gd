extends SceneTree
## Esc routing regression. Events enter through Godot's Input pipeline rather
## than calling PauseMenu.open_menu()/toggle() directly.

const TEST_SAVE := "res://tests/.pause_escape_routing_test.json"

var profile: Node
var manager: Node
var game_manager: Node
var original_save_path: String
var original_profile: Dictionary
var original_stage_id: int

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for _frame in 5:
		await process_frame
	profile = root.get_node("ProfileManager")
	manager = root.get_node("StageManager")
	game_manager = root.get_node("GameManager")
	original_save_path = profile.save_path
	original_profile = profile.current_profile.duplicate(true)
	original_stage_id = manager.current_stage_id
	_cleanup()
	profile.save_path = TEST_SAVE
	profile.current_profile = {
		"save_version": 1,
		"player_name": "PauseRoutingTest",
		"highest_unlocked_stage": 6,
		"completed_stages": [],
		"best_scores": {},
		"highest_score": 0,
		"career_score": 0,
		"last_played_stage": 1
	}
	assert(profile.save_profile(), "Pause test fixture must save separately")

	var stage := (load("res://scenes/stages/Stage01.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 12:
		await process_frame
	var pause_menu: Control = stage.hud.pause_menu
	assert(pause_menu != null and pause_menu.get_parent() is CanvasLayer, "PauseMenu must exist inside the TacticalHUD CanvasLayer")
	assert(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "PauseMenu must process while the tree is paused")
	assert(not pause_menu.visible and game_manager.current_state == 3, "Stage must begin playing with menu hidden")

	await _press_escape()
	if "--expect-bug" in OS.get_cmdline_user_args():
		assert(not pause_menu.visible, "Pre-fix reproduction expects PauseMenu to remain hidden")
		assert(not paused and not game_manager.is_game_paused, "Pre-fix reproduction expects simulation not to pause")
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pre-fix reproduction expects only cursor release")
		print("[PauseEscapeRouting] REPRODUCED: Esc released cursor but menu remained hidden and gameplay stayed unpaused")
		_restore()
		quit(0)
		return

	assert(pause_menu.visible, "Esc must display PauseMenu")
	assert(paused and game_manager.is_game_paused and game_manager.current_state == 4, "Esc must pause tree and enter PAUSED state")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause must show cursor")
	assert(pause_menu.resume_btn.text.begins_with("RESUME") and pause_menu.menu_btn.text == "RETURN TO HQ", "Required pause actions must be visible")

	await _press_escape()
	assert(not pause_menu.visible, "Second Esc must close PauseMenu")
	assert(not paused and not game_manager.is_game_paused and game_manager.current_state == 3, "Second Esc must resume the same mission")
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Resume must recapture mouse")
	assert(current_scene == stage, "Resume must retain the same stage instance")

	await _press_escape()
	assert(pause_menu.visible and paused, "Esc must reopen PauseMenu for Resume button check")
	pause_menu.resume_btn.pressed.emit()
	for _frame in 3:
		await process_frame
	assert(not pause_menu.visible and not paused and game_manager.current_state == 3, "RESUME OPERATION must return to the same active mission")
	assert(current_scene == stage, "Resume button must retain the same stage instance")

	# Summary states own Esc and must never open the pause overlay.
	stage.summary_dialog.visible = true
	assert(game_manager.change_state(5), "Playing must transition to Mission Complete for conflict check")
	await _press_escape()
	assert(not pause_menu.visible and not paused, "Mission Complete Esc must not open PauseMenu")
	stage.summary_dialog.visible = false
	assert(game_manager.change_state(3), "Mission Complete must return to Playing for navigation check")

	# Leaving an unfinished attempt through the visible pause action is read-only.
	var profile_before_return: Dictionary = profile.get_profile()
	await _press_escape()
	assert(pause_menu.visible, "Esc must reopen PauseMenu")
	pause_menu.menu_btn.pressed.emit()
	for _frame in 12:
		await process_frame
	assert(current_scene != null and current_scene.name == "OperationsHQ", "RETURN TO HQ must open Operations HQ")
	assert(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "HQ return must be unpaused with visible cursor")
	assert(current_scene.get_selected_stage_id() == 1, "HQ must retain the last Stage01 selection")
	assert(profile.get_profile() == profile_before_return, "Abandoning an incomplete mission must not score, complete, or unlock")

	# HQ has no tactical pause overlay; Esc cannot create a conflicting menu.
	var hq := current_scene
	await _press_escape()
	assert(current_scene == hq and not paused, "Esc in HQ must not open a combat pause menu")

	# The same mission remains launchable again after returning.
	hq._select_stage(1)
	hq._on_action_pressed()
	for _frame in 20:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage01", "Stage01 must relaunch after Return to HQ")
	assert(not paused and game_manager.current_state == 3, "Relaunched stage must be active and unpaused")

	_restore()
	print("[PauseEscapeRouting] PASS: Esc pause, Esc resume, summary/HQ guards, Return to HQ, no award, relaunch")
	quit(0)

func _press_escape() -> void:
	var pressed_event := InputEventKey.new()
	pressed_event.keycode = KEY_ESCAPE
	pressed_event.physical_keycode = KEY_ESCAPE
	pressed_event.pressed = true
	Input.parse_input_event(pressed_event)
	for _frame in 3:
		await process_frame
	var released_event := pressed_event.duplicate()
	released_event.pressed = false
	Input.parse_input_event(released_event)
	await process_frame

func _restore() -> void:
	paused = false
	profile.save_path = original_save_path
	profile.current_profile = original_profile
	manager.current_stage_id = original_stage_id
	_cleanup()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
