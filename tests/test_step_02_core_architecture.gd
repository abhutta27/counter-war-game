extends SceneTree
## test_core_architecture.gd
## Automated integration test for Step 02 Core Architecture.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")
const Helpers = preload("res://scripts/utilities/helpers.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_all_tests()
	return true

func _run_all_tests() -> void:
	print("--- BEGIN STEP 02 TEST RUNNER ---")
	var success := true
	
	# Test 1: GameConstants
	print("[Test 1] Testing GameConstants...")
	if GameConstants.LAYER_PLAYER != 2 or GameConstants.LAYER_ENEMY != 3 or GameConstants.LAYER_HEADSHOT != 4:
		printerr("FAILED: Layer constants mismatch")
		success = false
	if GameConstants.GROUP_PLAYER != "player" or GameConstants.GROUP_ENEMIES != "enemies":
		printerr("FAILED: Group constants mismatch")
		success = false
	if GameConstants.GameState.PLAYING != 3 or GameConstants.GameState.PAUSED != 4:
		printerr("FAILED: GameState enum mismatch")
		success = false
	print("  -> GameConstants PASSED")

	# Test 2: DamageInfo
	print("[Test 2] Testing DamageInfo data packet...")
	var dummy_attacker = Node.new()
	var dmg := DamageInfo.new(
		45,
		true,
		dummy_attacker,
		"M4A1",
		Vector3(1, 2, 3),
		Vector3.FORWARD,
		Vector3.UP,
		GameConstants.DamageType.BULLET
	)
	if dmg.amount != 45 or not dmg.is_critical or dmg.weapon_name != "M4A1" or dmg.attacker != dummy_attacker:
		printerr("FAILED: DamageInfo data corruption")
		success = false
	dummy_attacker.free()
	print("  -> DamageInfo PASSED")

	# Test 3: Helpers
	print("[Test 3] Testing Helpers static utilities...")
	var formatted_time := Helpers.format_time_minutes_seconds(125.4)
	if formatted_time != "02:05.4":
		printerr("FAILED: Helpers time format expected '02:05.4', got: ", formatted_time)
		success = false
	var dist := Helpers.horizontal_distance(Vector3(0, 5, 0), Vector3(3, 10, 4))
	if absf(dist - 5.0) > 0.001:
		printerr("FAILED: Helpers horizontal distance expected 5.0, got: ", dist)
		success = false
	print("  -> Helpers PASSED")

	# Test 4: EventBus Signals
	print("[Test 4] Testing EventBus decoupled messaging...")
	var eb = root.get_node_or_null("EventBus")
	if not eb:
		printerr("FAILED: EventBus singleton not found in root")
		success = false
	else:
		var signal_box := [false]
		var test_callable := func(cur, prev): signal_box[0] = true
		eb.state_changed.connect(test_callable)
		eb.state_changed.emit(GameConstants.GameState.PLAYING, GameConstants.GameState.MAIN_MENU)
		if not signal_box[0]:
			printerr("FAILED: EventBus state_changed signal did not trigger listener")
			success = false
		eb.state_changed.disconnect(test_callable)
	print("  -> EventBus PASSED")

	# Test 5: GameManager
	print("[Test 5] Testing GameManager state machine transitions...")
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		printerr("FAILED: GameManager singleton not found in root")
		success = false
	else:
		gm.change_state(GameConstants.GameState.MAIN_MENU)
		if gm.current_state != GameConstants.GameState.MAIN_MENU:
			printerr("FAILED: GameManager did not transition to MAIN_MENU")
			success = false
			
		gm.change_state(GameConstants.GameState.PLAYING)
		if gm.current_state != GameConstants.GameState.PLAYING:
			printerr("FAILED: GameManager did not transition to PLAYING")
			success = false
			
		gm.pause_game(true)
		if not gm.is_game_paused or not paused:
			printerr("FAILED: GameManager pause did not pause SceneTree")
			success = false
			
		gm.pause_game(false)
		if gm.is_game_paused or paused:
			printerr("FAILED: GameManager unpause failed")
			success = false
	print("  -> GameManager PASSED")

	if success:
		print("--- ALL STEP 02 TESTS PASSED SUCCESSFULLY! ---")
		quit(0)
	else:
		printerr("--- STEP 02 TESTS ENCOUNTERED FAILURES! ---")
		quit(1)