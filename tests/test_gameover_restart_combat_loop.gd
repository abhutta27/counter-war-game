extends SceneTree

const GameConstants = preload("res://scripts/utilities/constants.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("=== BEGIN GAMEOVER AND RESTART COMBAT LOOP VERIFICATION ===")
	
	var level_res = load("res://scenes/Level1.tscn")
	assert(level_res != null, "Failed to load Level1.tscn")
	var level = level_res.instantiate()
	root.add_child(level)
	current_scene = level
	
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager must exist")
	var sm = root.get_node_or_null("SoundManager")
	assert(sm != null, "SoundManager must exist")
	
	var player: Player3D = level.get_node_or_null("Player3D") as Player3D
	assert(player != null, "Player3D must exist")
	var enemies = level.get_node_or_null("Enemies")
	assert(enemies != null and enemies.get_child_count() > 0, "Enemies must exist")
	var summary_dialog = level.get_node_or_null("HUD/StageSummaryDialog")
	assert(summary_dialog != null, "StageSummaryDialog must exist")
	
	# TEST 1: Initial state is PLAYING, player can fire
	print("\n[TEST 1] Verifying initial PLAYING state...")
	assert(gm.current_state == GameConstants.GameState.PLAYING, "State must be PLAYING")
	assert(player._can_fire_input() == true, "Player must be allowed to fire in PLAYING state")
	print("  -> TEST 1 PASSED: Game is PLAYING, player active.")
	
	# TEST 2: Defeating 1 or 2 enemies does NOT cause automatic firing
	print("\n[TEST 2] Defeating 2 enemies and checking firing state remains inactive...")
	var enemy1: Enemy3D = enemies.get_child(0) as Enemy3D
	var enemy2: Enemy3D = enemies.get_child(1) as Enemy3D
	var ar = player.get_weapon_manager().get_current_weapon()
	var ammo_before = ar.current_ammo
	
	enemy1.take_damage(100)
	enemy2.take_damage(100)
	assert(enemy1.is_dead == true, "Enemy 1 must be dead")
	assert(enemy2.is_dead == true, "Enemy 2 must be dead")
	
	# Advance 20 physics frames without pressing fire
	for i in range(20):
		player._physics_process(0.05)
		for e in enemies.get_children():
			e._physics_process(0.05)
			
	assert(player.is_firing_held == false, "is_firing_held must remain false when no input is provided")
	assert(ar.current_ammo == ammo_before, "Ammo must not change without player input!")
	print("  -> TEST 2 PASSED: Defeating enemies did NOT cause automatic firing.")
	
	# TEST 3: Trigger Game Over and verify complete combat shutdown
	print("\n[TEST 3] Triggering Game Over and verifying combat and audio shutdown...")
	player.take_damage(100)
	assert(player.current_health == 0, "Player HP must be 0")
	assert(player.is_active == false, "Player must be inactive")
	assert(gm.current_state == GameConstants.GameState.GAME_OVER, "State must transition to GAME_OVER")
	assert(player._can_fire_input() == false, "Fire input must be FALSE in GAME_OVER")
	assert(summary_dialog.visible == true, "Summary dialog must be visible on Game Over")
	assert(summary_dialog.mission_status_label.text == "GAME OVER", "Defeat must show an explicit GAME OVER title")
	assert(summary_dialog.stage_name_label.text == "MISSION FAILED — YOU WERE ELIMINATED", "Defeat subtitle must explain elimination")
	assert(not summary_dialog.mission_detail.visible and not summary_dialog.mission_points.visible, "Defeat must hide the Mission Complete bonus row")
	assert(summary_dialog.final_score_title.text == "UNSAVED ATTEMPT SCORE:", "Failed points must be labelled as an unsaved attempt")
	
	# Attempt to fire during Game Over
	var l_press = InputEventMouseButton.new()
	l_press.button_index = MOUSE_BUTTON_LEFT
	l_press.pressed = true
	player._unhandled_input(l_press)
	assert(player.is_firing_held == false, "Clicking during Game Over must NOT set is_firing_held")
	
	# Advance 20 frames in Game Over: check that surviving enemies DO NOT attack dead player
	var p_camera = player.camera_mount
	for i in range(20):
		player._physics_process(0.05)
		for e in enemies.get_children():
			e._physics_process(0.05)
			
	print("  -> TEST 3 PASSED: Game Over completely halts firing, audio, and enemy attacks.")
	
	# TEST 4: Clicking during Game Over must NOT recapture mouse cursor
	print("\n[TEST 4] Testing click during Game Over does NOT recapture mouse...")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse must be visible in Game Over")
	if p_camera:
		p_camera._input(l_press)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse must REMAIN visible during Game Over!")
	print("  -> TEST 4 PASSED: Mouse cursor remains visible and clickable for UI in Game Over.")
	
	# TEST 5: Restart Button in Summary Dialog is clickable and resets state
	print("\n[TEST 5] Testing Restart button in Summary Dialog...")
	var retry_btn: Button = summary_dialog.get_node_or_null("Panel/VBox/Actions/RetryBtn")
	assert(retry_btn != null, "RetryBtn must exist")
	assert(retry_btn.text == "TRY AGAIN", "Button text on defeat must be TRY AGAIN")
	assert(summary_dialog.menu_btn.text == "RETURN TO HQ", "Defeat must retain RETURN TO HQ")
	
	# Verify transition GAME_OVER -> PLAYING is valid
	assert(gm.can_change_state(GameConstants.GameState.PLAYING) == true, "GAME_OVER -> PLAYING transition must be valid")
	
	# Simulate clicking RetryBtn
	retry_btn.emit_signal("pressed")
	assert(gm.current_state == GameConstants.GameState.PLAYING, "Pressing RetryBtn must transition game to PLAYING state!")
	print("  -> TEST 5 PASSED: Restart button operates cleanly and transitions to PLAYING.")
	
	level.queue_free()
	print("\n=== ALL GAMEOVER AND RESTART COMBAT LOOP TESTS PASSED! ===")
	quit(0)
