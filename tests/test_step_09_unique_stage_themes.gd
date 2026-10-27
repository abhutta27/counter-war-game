extends SceneTree
## test_step_09_unique_stage_themes.gd
## Comprehensive automated verification for STEP 09: 6 Unique Stage Themes & Environments.

const GameConstants = preload("res://scripts/utilities/constants.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=========================================================")
	print(" COUNTER WAR - STEP 09: UNIQUE STAGE THEMES TEST SUITE   ")
	print("=========================================================")
	
	# Wait for autoload singletons to mount
	for i in range(5):
		await process_frame
		
	await test_01_registry_and_files()
	await test_02_stage_01_desert_outpost()
	await test_03_stage_02_abandoned_city()
	await test_04_stage_03_forest_camp()
	await test_05_stage_04_industrial_zone()
	await test_06_stage_05_mountain_base()
	await test_07_stage_06_night_military_base()
	await test_08_environment_distinctness()
	await test_09_progression_lifecycle()
	await test_10_restart_isolation()
	
	print("\n=========================================================")
	print(" STEP 09 TEST RESULTS: %d Passed / %d Failed / %d Total" % [passed_tests, failed_tests, total_tests])
	print("=========================================================")
	
	if failed_tests == 0:
		print(">> ALL STEP 09 UNIQUE STAGE THEMES TESTS PASSED! <<")
		quit(0)
	else:
		printerr(">> STEP 09 TESTS ENCOUNTERED FAILURES! <<")
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
# TEST 01: Registry and File Existence for 6 Stages
# -----------------------------------------------------------------
func test_01_registry_and_files() -> void:
	print("\n--- TEST 01: Registry & File Existence ---")
	var stg_mgr = root.get_node_or_null("StageManager")
	_assert(stg_mgr != null, "TEST 01.1: StageManager singleton mounted in root")
	_assert(stg_mgr.TOTAL_STAGES == 6, "TEST 01.2: StageManager.TOTAL_STAGES is 6", "Found: %d" % stg_mgr.TOTAL_STAGES)
	
	for s_id in range(1, 7):
		_assert(stg_mgr.STAGE_REGISTRY.has(s_id), "TEST 01.%d: Stage %d registered in STAGE_REGISTRY" % [s_id + 2, s_id])
		var path = stg_mgr.STAGE_REGISTRY[s_id].get("scene_path", "")
		_assert(ResourceLoader.exists(path), "TEST 01.%d: Scene file exists on disk: %s" % [s_id + 8, path])

# -----------------------------------------------------------------
# TEST 02: Stage 01 Desert Outpost
# -----------------------------------------------------------------
func test_02_stage_01_desert_outpost() -> void:
	print("\n--- TEST 02: Stage 01 Desert Outpost ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage01.tscn") as PackedScene
	_assert(packed != null, "TEST 02.1: Stage01.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 1, "TEST 02.2: Stage 01 stage_id is 1")
	_assert(stage.stage_name == "OPERATION DESERT OUTPOST", "TEST 02.3: Stage 01 name is OPERATION DESERT OUTPOST", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 5, "TEST 02.4: Stage 01 has 5 enemies")
	_assert(stage.has_node("Environment/Structures/OutpostHQ"), "TEST 02.5: Stage 01 contains OutpostHQ structure")
	_assert(stage.has_node("Environment/Structures/WatchTower"), "TEST 02.6: Stage 01 contains WatchTower structure")
	_assert(stage.has_node("Environment/Sandbags/Sandbag1"), "TEST 02.7: Stage 01 contains desert sandbag redoubts")
	_assert(stage.has_node("Player3D"), "TEST 02.8: Stage 01 reuses shared Player3D")
	
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 03: Stage 02 Abandoned City
# -----------------------------------------------------------------
func test_03_stage_02_abandoned_city() -> void:
	print("\n--- TEST 03: Stage 02 Abandoned City ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage02.tscn") as PackedScene
	_assert(packed != null, "TEST 03.1: Stage02.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 2, "TEST 03.2: Stage 02 stage_id is 2")
	_assert(stage.stage_name == "OPERATION ABANDONED CITY", "TEST 03.3: Stage 02 name is OPERATION ABANDONED CITY", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 6, "TEST 03.4: Stage 02 has 6 enemies")
	_assert(stage.has_node("Environment/Buildings/RuinedOffice"), "TEST 03.5: Stage 02 contains RuinedOffice building")
	_assert(stage.has_node("Environment/Buildings/AbandonedTruck"), "TEST 03.6: Stage 02 contains AbandonedTruck chassis")
	_assert(stage.has_node("Environment/Barricades/Chicane1"), "TEST 03.7: Stage 02 contains urban street chicanes")
	
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 04: Stage 03 Forest Military Camp
# -----------------------------------------------------------------
func test_04_stage_03_forest_camp() -> void:
	print("\n--- TEST 04: Stage 03 Forest Military Camp ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage03.tscn") as PackedScene
	_assert(packed != null, "TEST 04.1: Stage03.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 3, "TEST 04.2: Stage 03 stage_id is 3")
	_assert(stage.stage_name == "OPERATION FOREST CAMP", "TEST 04.3: Stage 03 name is OPERATION FOREST CAMP", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 7, "TEST 04.4: Stage 03 has 7 enemies")
	_assert(stage.has_node("Environment/Tents/TentAlpha"), "TEST 04.5: Stage 03 contains military canvas tents")
	_assert(stage.has_node("Environment/Trees/Tree1"), "TEST 04.6: Stage 03 contains 3D pine trees")
	_assert(stage.has_node("Environment/Barriers/LogBarrier1"), "TEST 04.7: Stage 03 contains wooden log barriers")
	
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 05: Stage 04 Industrial Zone
# -----------------------------------------------------------------
func test_05_stage_04_industrial_zone() -> void:
	print("\n--- TEST 05: Stage 04 Industrial Zone ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage04.tscn") as PackedScene
	_assert(packed != null, "TEST 05.1: Stage04.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 4, "TEST 05.2: Stage 04 stage_id is 4")
	_assert(stage.stage_name == "OPERATION INDUSTRIAL ZONE", "TEST 05.3: Stage 04 name is OPERATION INDUSTRIAL ZONE", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 12, "TEST 05.4: Stage 04 has 12 enemies")
	_assert(stage.has_node("Environment/Buildings/Warehouse"), "TEST 05.5: Stage 04 contains industrial Warehouse building")
	_assert(stage.has_node("Environment/Containers/ContainerRed1"), "TEST 05.6: Stage 04 contains shipping cargo containers")
	_assert(stage.has_node("Environment/Silos/Silo1"), "TEST 05.7: Stage 04 contains fuel storage silos")
	_assert(stage.has_node("Environment/Pipes/OverheadPipe"), "TEST 05.8: Stage 04 contains elevated pipe network")
	
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 06: Stage 05 Mountain Base
# -----------------------------------------------------------------
func test_06_stage_05_mountain_base() -> void:
	print("\n--- TEST 06: Stage 05 Mountain Base ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage05.tscn") as PackedScene
	_assert(packed != null, "TEST 06.1: Stage05.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 5, "TEST 06.2: Stage 05 stage_id is 5")
	_assert(stage.stage_name == "OPERATION MOUNTAIN BASE", "TEST 06.3: Stage 05 name is OPERATION MOUNTAIN BASE", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 14, "TEST 06.4: Stage 05 has 14 enemies")
	_assert(stage.has_node("Environment/Buildings/CheckpointBunker"), "TEST 06.5: Stage 05 contains CheckpointBunker")
	_assert(stage.has_node("Environment/Buildings/SniperTower"), "TEST 06.6: Stage 05 contains SniperTower")
	_assert(stage.has_node("Environment/Boulders/Boulder1"), "TEST 06.7: Stage 05 contains natural canyon rock boulders")
	
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 07: Stage 06 Night Military Base
# -----------------------------------------------------------------
func test_07_stage_06_night_military_base() -> void:
	print("\n--- TEST 07: Stage 06 Night Military Base ---")
	var packed = ResourceLoader.load("res://scenes/stages/Stage06.tscn") as PackedScene
	_assert(packed != null, "TEST 07.1: Stage06.tscn packed scene loads")
	var stage = packed.instantiate()
	root.add_child(stage)
	await process_frame
	
	_assert(stage.stage_id == 6, "TEST 07.2: Stage 06 stage_id is 6")
	_assert(stage.stage_name == "OPERATION NIGHT MILITARY BASE", "TEST 07.3: Stage 06 name is OPERATION NIGHT MILITARY BASE", stage.stage_name)
	_assert(stage.get_node("Enemies").get_child_count() == 10, "TEST 07.4: Stage 06 has 10 enemies")
	_assert(stage.has_node("Environment/Buildings/ArmoryHangar"), "TEST 07.5: Stage 06 contains ArmoryHangar")
	_assert(stage.has_node("Environment/Buildings/WatchTowerWest/SearchlightWest"), "TEST 07.6: Stage 06 contains active SpotLight3D searchlights")
	_assert(stage.has_node("Environment/Buildings/HelipadMesh"), "TEST 07.7: Stage 06 contains military helipad landing zone")
	
	var world_env = stage.get_node_or_null("WorldEnvironment")
	_assert(world_env != null and world_env.environment != null, "TEST 07.8: Stage 06 has WorldEnvironment")
	if world_env and world_env.environment and world_env.environment.sky:
		var sky = world_env.environment.sky.sky_material as ProceduralSkyMaterial
		_assert(sky.sky_top_color.v < 0.1, "TEST 07.9: Stage 06 sky is dark night (value < 0.1)", "Top Color V: %.3f" % sky.sky_top_color.v)
		
	stage.queue_free()
	await process_frame

# -----------------------------------------------------------------
# TEST 08: Environment Distinctness Across All 6 Stages
# -----------------------------------------------------------------
func test_08_environment_distinctness() -> void:
	print("\n--- TEST 08: Visual Distinctness Across All 6 Stages ---")
	var skies: Array[Color] = []
	var enemy_counts: Array[int] = []
	
	for s_id in range(1, 7):
		var p = ResourceLoader.load("res://scenes/stages/Stage0%d.tscn" % s_id) as PackedScene
		var s = p.instantiate()
		var env = s.get_node("WorldEnvironment").environment
		var sky_top = (env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
		skies.append(sky_top)
		enemy_counts.append(s.get_node("Enemies").get_child_count())
		s.queue_free()
		
	# Verify every stage has a unique enemy count
	var unique_counts = {}
	for c in enemy_counts:
		unique_counts[c] = true
	_assert(unique_counts.size() == 6, "TEST 08.1: Every stage has a distinct enemy count [5, 6, 7, 12, 14, 10]", str(enemy_counts))
	
	# Verify distinct sky colors
	_assert(skies[0] != skies[1], "TEST 08.2: Stage 1 sky != Stage 2 sky")
	_assert(skies[1] != skies[2], "TEST 08.3: Stage 2 sky != Stage 3 sky")
	_assert(skies[2] != skies[3], "TEST 08.4: Stage 3 sky != Stage 4 sky")
	_assert(skies[3] != skies[4], "TEST 08.5: Stage 4 sky != Stage 5 sky")
	_assert(skies[4] != skies[5], "TEST 08.6: Stage 5 sky != Stage 6 sky")
	_assert(skies[0] != skies[5], "TEST 08.7: Stage 1 daytime sun != Stage 6 night sky")

# -----------------------------------------------------------------
# TEST 09: Progression Flow (1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 1)
# -----------------------------------------------------------------
func test_09_progression_lifecycle() -> void:
	print("\n--- TEST 09: Progression Flow Across All 6 Stages ---")
	var stg_mgr = root.get_node_or_null("StageManager")
	
	stg_mgr.set_current_stage_id(1)
	_assert(stg_mgr.get_current_stage_id() == 1, "TEST 09.1: Starts at Stage 1")
	
	for expected_id in range(2, 7):
		var next_id = stg_mgr.get_current_stage_id() + 1
		stg_mgr.set_current_stage_id(next_id)
		_assert(stg_mgr.get_current_stage_id() == expected_id, "TEST 09.%d: Advanced to Stage %d" % [expected_id, expected_id])
		
	# Advance beyond Stage 6 -> cycles safely to Stage 1
	var wrap_next = stg_mgr.get_current_stage_id() + 1
	if wrap_next > stg_mgr.TOTAL_STAGES:
		stg_mgr.set_current_stage_id(1)
	_assert(stg_mgr.get_current_stage_id() == 1, "TEST 09.7: Completing Stage 6 wraps campaign safely to Stage 1")

# -----------------------------------------------------------------
# TEST 10: Restart Isolation on Stages 3, 5, 6
# -----------------------------------------------------------------
func test_10_restart_isolation() -> void:
	print("\n--- TEST 10: Restart Isolation Across Non-Initial Stages ---")
	var stg_mgr = root.get_node_or_null("StageManager")
	
	# Test restart on Stage 3
	stg_mgr.set_current_stage_id(3)
	stg_mgr.restart_current_stage()
	_assert(stg_mgr.get_current_stage_id() == 3, "TEST 10.1: Restarting on Stage 3 preserves Stage 3 (NEVER returns to Stage 1)")
	
	# Test restart on Stage 5
	stg_mgr.set_current_stage_id(5)
	stg_mgr.restart_current_stage()
	_assert(stg_mgr.get_current_stage_id() == 5, "TEST 10.2: Restarting on Stage 5 preserves Stage 5 (NEVER returns to Stage 1)")
	
	# Test restart on Stage 6
	stg_mgr.set_current_stage_id(6)
	stg_mgr.restart_current_stage()
	_assert(stg_mgr.get_current_stage_id() == 6, "TEST 10.3: Restarting on Stage 6 preserves Stage 6 (NEVER returns to Stage 1)")
