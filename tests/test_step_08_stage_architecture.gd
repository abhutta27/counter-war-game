extends SceneTree
## test_step_08_stage_architecture.gd
## Automated test suite for STEP 08: Stage / Mission Architecture

const GameConstants = preload("res://scripts/utilities/constants.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=========================================================")
	print(" COUNTER WAR - STEP 08: STAGE ARCHITECTURE TEST SUITE")
	print("=========================================================")
	
	# Wait several frames to allow Autoloads and scene tree to fully mount
	for i in range(5):
		await process_frame
	
	# Execute all tests sequentially
	await test_01_stage_manager_singleton_and_registry()
	await test_02_stage_01_scene_and_shared_systems()
	await test_03_stage_02_distinct_environment_and_hostiles()
	await test_04_progression_stage_transition()
	await test_05_stage_02_restart_isolation()
	await test_06_invalid_stage_id_safety()
	
	print("=========================================================")
	print(" STEP 08 TEST RESULTS: %d Passed / %d Failed / %d Total" % [passed_tests, failed_tests, total_tests])
	print("=========================================================")
	
	if failed_tests == 0:
		print(">> ALL STEP 08 TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> STEP 08 TESTS ENCOUNTERED FAILURES! <<")
		quit(1)

func _assert(condition: bool, test_name: String, details: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] %s" % test_name)
		if details != "":
			print("       Details: %s" % details)
	else:
		failed_tests += 1
		printerr("[FAIL] %s" % test_name)
		if details != "":
			printerr("       Details: %s" % details)

# -----------------------------------------------------------------
# TEST 01: Stage Registry and Singleton Verification
# -----------------------------------------------------------------
func test_01_stage_manager_singleton_and_registry() -> void:
	print("\n--- TEST 01: Stage Manager Singleton & Registry ---")
	
	var stg_mgr = root.get_node_or_null("StageManager")
	_assert(stg_mgr != null, "TEST 01.1: StageManager Autoload exists in root tree")
	
	if stg_mgr:
		_assert(stg_mgr.STAGE_REGISTRY.has(1), "TEST 01.2: Stage 1 is registered in STAGE_REGISTRY")
		_assert(stg_mgr.STAGE_REGISTRY.has(2), "TEST 01.3: Stage 2 is registered in STAGE_REGISTRY")
		
		var s1_path = stg_mgr.STAGE_REGISTRY[1].get("scene_path", "")
		var s2_path = stg_mgr.STAGE_REGISTRY[2].get("scene_path", "")
		
		_assert(s1_path == "res://scenes/stages/Stage01.tscn", "TEST 01.4: Stage 1 path is res://scenes/stages/Stage01.tscn")
		_assert(s2_path == "res://scenes/stages/Stage02.tscn", "TEST 01.5: Stage 2 path is res://scenes/stages/Stage02.tscn")
		
		_assert(ResourceLoader.exists(s1_path), "TEST 01.6: Stage01.tscn resource file exists on disk")
		_assert(ResourceLoader.exists(s2_path), "TEST 01.7: Stage02.tscn resource file exists on disk")

# -----------------------------------------------------------------
# TEST 02: Stage 01 Independent Architecture & Shared Systems
# -----------------------------------------------------------------
func test_02_stage_01_scene_and_shared_systems() -> void:
	print("\n--- TEST 02: Stage 01 Scene & Shared Systems ---")
	
	var stage01_packed = ResourceLoader.load("res://scenes/stages/Stage01.tscn") as PackedScene
	_assert(stage01_packed != null, "TEST 02.1: Stage01.tscn loads as valid PackedScene")
	
	if stage01_packed:
		var stage01 = stage01_packed.instantiate()
		root.add_child(stage01)
		await process_frame
		
		_assert(stage01.stage_id == 1, "TEST 02.2: Stage01 stage_id is 1", "Found: %d" % stage01.stage_id)
		_assert(stage01.has_node("Player3D"), "TEST 02.3: Stage01 reuses shared Player3D")
		_assert(stage01.has_node("Enemies"), "TEST 02.4: Stage01 has Enemies container")
		_assert(stage01.has_node("HUD"), "TEST 02.5: Stage01 has shared HUD")
		
		var enemies = stage01.get_node("Enemies")
		var enemy_count = enemies.get_child_count()
		_assert(enemy_count == 5, "TEST 02.6: Stage01 has exactly 5 enemies", "Found: %d" % enemy_count)
		
		var player = stage01.get_node("Player3D")
		_assert(player.has_node("Camera3D"), "TEST 02.7: Shared Player3D has FirstPerson Camera3D")
		_assert(player.weapon_manager != null, "TEST 02.8: Shared Player3D has functional WeaponManager")
		
		stage01.queue_free()
		await process_frame

# -----------------------------------------------------------------
# TEST 03: Stage 02 Distinct Environment & 8 Enemies
# -----------------------------------------------------------------
func test_03_stage_02_distinct_environment_and_hostiles() -> void:
	print("\n--- TEST 03: Stage 02 Distinct Environment & 8 Enemies ---")
	
	var stage02_packed = ResourceLoader.load("res://scenes/stages/Stage02.tscn") as PackedScene
	_assert(stage02_packed != null, "TEST 03.1: Stage02.tscn loads as valid PackedScene")
	
	if stage02_packed:
		var stage02 = stage02_packed.instantiate()
		root.add_child(stage02)
		await process_frame
		
		_assert(stage02.stage_id == 2, "TEST 03.2: Stage02 stage_id is 2", "Found: %d" % stage02.stage_id)
		_assert(stage02.stage_name.begins_with("OPERATION SHADOW BARRACKS"), "TEST 03.3: Stage02 stage_name is OPERATION SHADOW BARRACKS", "Found: %s" % stage02.stage_name)
		
		var enemies = stage02.get_node_or_null("Enemies")
		_assert(enemies != null, "TEST 03.4: Stage02 has Enemies container")
		if enemies:
			var enemy_count = enemies.get_child_count()
			_assert(enemy_count == 8, "TEST 03.5: Stage02 has exactly 8 enemies (distinct combat encounter)", "Found: %d" % enemy_count)
			
		var env = stage02.get_node_or_null("Environment")
		_assert(env != null, "TEST 03.6: Stage02 has Environment container")
		if env:
			_assert(env.has_node("Buildings"), "TEST 03.7: Stage02 contains distinct Buildings compound")
			_assert(env.has_node("Buildings/BarracksAlpha"), "TEST 03.8: Stage02 has BarracksAlpha structure")
			_assert(env.has_node("Buildings/BarracksBravo"), "TEST 03.9: Stage02 has BarracksBravo structure")
			_assert(env.has_node("Buildings/CommandBunker"), "TEST 03.10: Stage02 has CommandBunker structure")
			_assert(env.has_node("Containers"), "TEST 03.11: Stage02 has tactical cargo containers")
			_assert(env.has_node("Barriers"), "TEST 03.12: Stage02 has defense barriers")
			
		var world_env = stage02.get_node_or_null("WorldEnvironment")
		_assert(world_env != null and world_env.environment != null, "TEST 03.13: Stage02 has distinct WorldEnvironment")
		if world_env and world_env.environment:
			var sky = world_env.environment.sky
			_assert(sky != null and sky.sky_material is ProceduralSkyMaterial, "TEST 03.14: Stage02 has procedural dusk sky material")
			if sky and sky.sky_material is ProceduralSkyMaterial:
				var dusk_sky = sky.sky_material as ProceduralSkyMaterial
				_assert(dusk_sky.sky_horizon_color.r > 0.7, "TEST 03.15: Stage02 sky has warm sunset/dusk horizon (Red > 0.7)", "Red = %.2f" % dusk_sky.sky_horizon_color.r)
		
		stage02.queue_free()
		await process_frame

# -----------------------------------------------------------------
# TEST 04: Progression Transition (Stage 01 -> Stage 02)
# -----------------------------------------------------------------
func test_04_progression_stage_transition() -> void:
	print("\n--- TEST 04: Progression Stage Transition ---")
	
	var stg_mgr = root.get_node_or_null("StageManager")
	if not stg_mgr:
		_assert(false, "TEST 04.1: StageManager missing for progression test")
		return
		
	stg_mgr.set_current_stage_id(1)
	_assert(stg_mgr.get_current_stage_id() == 1, "TEST 04.1: StageManager initialized to Stage 1")
	
	var next_id = stg_mgr.get_current_stage_id() + 1
	_assert(next_id == 2, "TEST 04.2: Next stage from Stage 1 evaluates to Stage 2")
	
	var info = stg_mgr.get_stage_info(next_id)
	_assert(info.get("name") == "OPERATION SHADOW BARRACKS", "TEST 04.3: Next stage info correctly resolves to OPERATION SHADOW BARRACKS")
	_assert(info.get("target_count") == 8, "TEST 04.4: Next stage target count correctly resolves to 8")

# -----------------------------------------------------------------
# TEST 05: Restart Isolation & State Retention (Stage 02 Failure -> Reloads Stage 02)
# -----------------------------------------------------------------
func test_05_stage_02_restart_isolation() -> void:
	print("\n--- TEST 05: Restart Isolation (Stage 02 Failure -> Reloads Stage 02) ---")
	
	var stg_mgr = root.get_node_or_null("StageManager")
	if not stg_mgr:
		_assert(false, "TEST 05.1: StageManager missing for restart test")
		return
		
	# Set current stage to 2
	stg_mgr.set_current_stage_id(2)
	_assert(stg_mgr.get_current_stage_id() == 2, "TEST 05.1: Active stage is Stage 2")
	
	# Verify that restarting keeps current_stage_id at 2
	var restart_signal_received: Array = []
	var on_restarted = func(id: int):
		restart_signal_received.append(id)
	stg_mgr.stage_restarted.connect(on_restarted)
	
	# Test restart logic
	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.change_state(GameConstants.GameState.GAME_OVER)
		_assert(gm.current_state == GameConstants.GameState.GAME_OVER, "TEST 05.2: Simulated player death -> Game Over state")
		
	stg_mgr.restart_current_stage()
	
	_assert(restart_signal_received.size() > 0 and restart_signal_received[0] == 2, 
		"TEST 05.3: stage_restarted signal emitted specifically for Stage 2", 
		"Emitted: %s" % str(restart_signal_received))
	_assert(stg_mgr.get_current_stage_id() == 2, 
		"TEST 05.4: CRITICAL: Restarting on Stage 2 preserves Stage 2 (NEVER falls back to Stage 1)")
		
	if gm:
		_assert(gm.current_state == GameConstants.GameState.PLAYING, 
			"TEST 05.5: Game state returned to PLAYING upon stage restart")
			
	stg_mgr.stage_restarted.disconnect(on_restarted)

# -----------------------------------------------------------------
# TEST 06: Invalid Stage Safety Clamping
# -----------------------------------------------------------------
func test_06_invalid_stage_id_safety() -> void:
	print("\n--- TEST 06: Invalid Stage ID Safety ---")
	
	var stg_mgr = root.get_node_or_null("StageManager")
	if not stg_mgr:
		_assert(false, "TEST 06.1: StageManager missing for safety test")
		return
		
	# Querying invalid stage ID
	var invalid_info = stg_mgr.get_stage_info(999)
	_assert(invalid_info.has("scene_path"), "TEST 06.1: Querying invalid Stage 999 returns valid fallback dictionary")
	
	# Loading invalid stage ID should clamp safely to 1
	stg_mgr.load_stage(999)
	_assert(stg_mgr.get_current_stage_id() == 1, 
		"TEST 06.2: Loading invalid Stage 999 safely clamped current_stage_id to Stage 1",
		"Current Stage ID: %d" % stg_mgr.get_current_stage_id())
		
	stg_mgr.load_stage(-5)
	_assert(stg_mgr.get_current_stage_id() == 1, 
		"TEST 06.3: Loading negative Stage ID safely clamped current_stage_id to Stage 1",
		"Current Stage ID: %d" % stg_mgr.get_current_stage_id())
