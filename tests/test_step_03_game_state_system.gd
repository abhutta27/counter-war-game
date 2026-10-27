extends SceneTree
## test_step_03_game_state_system.gd
## Automated integration and verification tests for STEP 03: Game State System.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("--- BEGIN STEP 03 GAME STATE SYSTEM TEST SUITE ---")
	var success := true
	
	var gm = root.get_node_or_null("GameManager")
	var eb = root.get_node_or_null("EventBus")
	
	if not gm or not gm.state_machine:
		printerr("FAILED: GameManager or its StateMachine not found!")
		quit(1)
		return
		
	var sm: GameStateMachine = gm.state_machine
	
	# Test 1: Check all 8 states exist
	print("[Test 1] Verifying all 8 required states exist in state machine...")
	var expected_states := [
		GameConstants.GameState.BOOT,
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.LOADING,
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.PAUSED,
		GameConstants.GameState.MISSION_COMPLETE,
		GameConstants.GameState.MISSION_FAILED,
		GameConstants.GameState.GAME_OVER
	]
	for st in expected_states:
		if not sm.states.has(st):
			printerr("FAILED: Missing state: ", GameConstants.GameState.keys()[st])
			success = false
	if success:
		print("  -> All 8 states verified.")
		
	# Test 2: Verify Initial State
	print("[Test 2] Verifying initial state...")
	if sm.current_state_enum != GameConstants.GameState.BOOT:
		printerr("FAILED: Initial state is not BOOT. Got: ", sm.current_state_enum)
		success = false
	else:
		print("  -> Initial state is BOOT (PASSED)")

	# Test 3: Invalid Transition Guard from BOOT
	print("[Test 3] Testing rejection of invalid transitions from BOOT...")
	var rejected_box := [false]
	var reject_callable := func(from_s, to_s, reason): rejected_box[0] = true
	sm.transition_rejected.connect(reject_callable)
	
	# Cannot go from BOOT directly to PAUSED
	var invalid_res: bool = gm.change_state(GameConstants.GameState.PAUSED)
	if invalid_res or not rejected_box[0]:
		printerr("FAILED: Transition from BOOT to PAUSED should have been rejected!")
		success = false
	else:
		print("  -> BOOT to PAUSED properly rejected.")
		
	# Cannot go from BOOT directly to MISSION_COMPLETE
	rejected_box[0] = false
	invalid_res = gm.change_state(GameConstants.GameState.MISSION_COMPLETE)
	if invalid_res or not rejected_box[0]:
		printerr("FAILED: Transition from BOOT to MISSION_COMPLETE should have been rejected!")
		success = false
	else:
		print("  -> BOOT to MISSION_COMPLETE properly rejected.")
		
	sm.transition_rejected.disconnect(reject_callable)

	# Test 4: Valid Flow: BOOT -> MAIN_MENU -> LOADING -> PLAYING
	print("[Test 4] Testing sequential valid flow: BOOT -> MAIN_MENU -> LOADING -> PLAYING...")
	var eb_state_box := [-1]
	var eb_callable := func(cur, prev): eb_state_box[0] = cur
	eb.state_changed.connect(eb_callable)
	
	# 4a: BOOT -> MAIN_MENU
	var ok: bool = gm.change_state(GameConstants.GameState.MAIN_MENU)
	if not ok or sm.current_state_enum != GameConstants.GameState.MAIN_MENU or eb_state_box[0] != GameConstants.GameState.MAIN_MENU:
		printerr("FAILED: Transition to MAIN_MENU failed!")
		success = false
		
	# 4b: MAIN_MENU -> LOADING
	ok = gm.change_state(GameConstants.GameState.LOADING, {"level_id": 2})
	if not ok or sm.current_state_enum != GameConstants.GameState.LOADING:
		printerr("FAILED: Transition to LOADING failed!")
		success = false
		
	# 4c: LOADING -> PLAYING
	ok = gm.change_state(GameConstants.GameState.PLAYING)
	if not ok or sm.current_state_enum != GameConstants.GameState.PLAYING:
		printerr("FAILED: Transition to PLAYING failed!")
		success = false
	else:
		print("  -> BOOT -> MAIN_MENU -> LOADING -> PLAYING succeeded.")

	# Test 5: Pausing Flow: PLAYING -> PAUSED -> PLAYING
	print("[Test 5] Testing pause toggle flow in PLAYING state...")
	ok = gm.change_state(GameConstants.GameState.PAUSED)
	if not ok or sm.current_state_enum != GameConstants.GameState.PAUSED or not gm.is_game_paused or not paused:
		printerr("FAILED: PLAYING -> PAUSED transition failed!")
		success = false
		
	# In PAUSED, invalid transition check (cannot jump to MISSION_COMPLETE while paused)
	if sm.can_transition_to(GameConstants.GameState.MISSION_COMPLETE):
		printerr("FAILED: PAUSED -> MISSION_COMPLETE should be invalid!")
		success = false
		
	ok = gm.change_state(GameConstants.GameState.PLAYING)
	if not ok or sm.current_state_enum != GameConstants.GameState.PLAYING or gm.is_game_paused or paused:
		printerr("FAILED: PAUSED -> PLAYING unpause failed!")
		success = false
	else:
		print("  -> PLAYING <-> PAUSED flow succeeded.")

	# Test 6: Mission End Flow: PLAYING -> MISSION_COMPLETE -> MAIN_MENU
	print("[Test 6] Testing Mission Complete flow...")
	ok = gm.change_state(GameConstants.GameState.MISSION_COMPLETE, {"stage_id": 1})
	if not ok or sm.current_state_enum != GameConstants.GameState.MISSION_COMPLETE:
		printerr("FAILED: Transition to MISSION_COMPLETE failed!")
		success = false
		
	ok = gm.change_state(GameConstants.GameState.MAIN_MENU)
	if not ok or sm.current_state_enum != GameConstants.GameState.MAIN_MENU:
		printerr("FAILED: Transition MISSION_COMPLETE -> MAIN_MENU failed!")
		success = false
	else:
		print("  -> MISSION_COMPLETE -> MAIN_MENU succeeded.")

	# Test 7: Failure & Game Over Flow: MAIN_MENU -> PLAYING -> MISSION_FAILED -> GAME_OVER -> MAIN_MENU
	print("[Test 7] Testing Mission Failed & Game Over flow...")
	gm.change_state(GameConstants.GameState.PLAYING)
	ok = gm.change_state(GameConstants.GameState.MISSION_FAILED)
	if not ok or sm.current_state_enum != GameConstants.GameState.MISSION_FAILED:
		printerr("FAILED: Transition to MISSION_FAILED failed!")
		success = false
		
	ok = gm.change_state(GameConstants.GameState.GAME_OVER)
	if not ok or sm.current_state_enum != GameConstants.GameState.GAME_OVER:
		printerr("FAILED: Transition to GAME_OVER failed!")
		success = false
		
	ok = gm.change_state(GameConstants.GameState.MAIN_MENU)
	if not ok or sm.current_state_enum != GameConstants.GameState.MAIN_MENU:
		printerr("FAILED: Transition GAME_OVER -> MAIN_MENU failed!")
		success = false
	else:
		print("  -> MISSION_FAILED -> GAME_OVER -> MAIN_MENU succeeded.")
		
	eb.state_changed.disconnect(eb_callable)

	if success:
		print("--- ALL STEP 03 TESTS PASSED PERFECTLY! ---")
		quit(0)
	else:
		printerr("--- STEP 03 TESTS ENCOUNTERED FAILURES! ---")
		quit(1)