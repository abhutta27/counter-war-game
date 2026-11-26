extends SceneTree
## _stage08_enemy_deployment_test.gd
## Verification of Stage 08 (Operation Whiteout) enemy placement, tier distribution,
## collision/character setup, cover proximity, and awareness behavior.

func _init() -> void:
	print("\n=========================================================")
	print(" COUNTER-WAR: STAGE 08 ENEMY DEPLOYMENT VERIFICATION     ")
	print("=========================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	var stage_scene: PackedScene = load("res://scenes/stages/Stage08.tscn")
	assert(stage_scene != null, "Failed to load Stage 08 scene.")

	var stage: Node3D = stage_scene.instantiate() as Node3D
	assert(stage != null, "Failed to instantiate Stage 08 scene.")
	root.add_child(stage)

	for _i in range(5):
		await process_frame
		await physics_frame

	print("\n[EnemyTest] --- CHECK 1: Total Enemy Count & Node References ---")
	var enemies_container: Node3D = stage.get_node_or_null("Enemies") as Node3D
	assert(enemies_container != null, "Enemies container node must exist.")

	var enemies: Array[Node] = enemies_container.get_children()
	print("[EnemyTest] Found %d enemy instances under $Enemies." % enemies.size())
	assert(enemies.size() == 12, "Stage 08 must deploy exactly 12 enemies (found %d)." % enemies.size())

	# Verify every instance is an Enemy3D / CharacterBody3D with expected collision
	for i in range(1, 13):
		var ename := "Enemy3D_%d" % i
		var enemy: CharacterBody3D = enemies_container.get_node_or_null(ename) as CharacterBody3D
		assert(enemy != null, "%s must exist as CharacterBody3D." % ename)
		assert(enemy.is_in_group("enemies"), "%s must be in 'enemies' group." % ename)
		assert(enemy.collision_layer == 2, "%s must have collision_layer=2." % ename)
		assert(enemy.has_node("CollisionShape3D"), "%s must have CollisionShape3D." % ename)
		assert(enemy.max_health == 100, "%s max_health must be 100." % ename)
		assert(enemy.current_health == 100, "%s current_health must be 100." % ename)
		assert(enemy.has_signal("enemy_died"), "%s must have enemy_died signal." % ename)
		assert(enemy.has_signal("health_changed"), "%s must have health_changed signal." % ename)

	print("[EnemyTest] PASS: All 12 enemies verified with valid CharacterBody3D, group, and collision configuration.")

	print("\n[EnemyTest] --- CHECK 2: Tier Elevation & Distribution ---")
	var valley_guards: Array[CharacterBody3D] = []
	var ridge_guards: Array[CharacterBody3D] = []
	var summit_guards: Array[CharacterBody3D] = []

	for i in range(1, 13):
		var ename := "Enemy3D_%d" % i
		var enemy: CharacterBody3D = enemies_container.get_node_or_null(ename) as CharacterBody3D
		var pos: Vector3 = enemy.global_position
		var tier: String = stage.call("get_guard_tier", ename)

		if tier == "lower_valley":
			valley_guards.append(enemy)
			assert(is_equal_approx(pos.y, 0.0) or absf(pos.y - 0.0) < 0.25, "%s must be at Valley Y=0.0 (got %.2f)." % [ename, pos.y])
			assert(pos.z >= 20.0 and pos.z <= 50.0, "%s must be within Lower Valley Z bounds [20, 50] (got %.2f)." % [ename, pos.z])
		elif tier == "mid_ridge":
			ridge_guards.append(enemy)
			assert(is_equal_approx(pos.y, 6.0) or absf(pos.y - 6.0) < 0.25, "%s must be at Mid-Ridge Y=6.0 (got %.2f)." % [ename, pos.y])
			assert(pos.z <= -2.0 and pos.z >= -38.0, "%s must be within Mid-Ridge Z bounds [-38, -2] (got %.2f)." % [ename, pos.z])
		elif tier == "high_summit":
			summit_guards.append(enemy)
			assert(is_equal_approx(pos.y, 14.0) or absf(pos.y - 14.0) < 0.25, "%s must be at Summit Y=14.0 (got %.2f)." % [ename, pos.y])
			assert(pos.z <= -62.0 and pos.z >= -95.0, "%s must be within High Summit Z bounds [-95, -62] (got %.2f)." % [ename, pos.z])

	print("[EnemyTest] Tier distribution counts:")
	print("  - Lower Valley (Y=0.0m):  %d enemies" % valley_guards.size())
	print("  - Mid-Ridge    (Y=6.0m):  %d enemies" % ridge_guards.size())
	print("  - High Summit  (Y=14.0m): %d enemies" % summit_guards.size())

	assert(valley_guards.size() == 4, "Lower Valley must have exactly 4 enemies (got %d)." % valley_guards.size())
	assert(ridge_guards.size() == 4, "Mid-Ridge must have exactly 4 enemies (got %d)." % ridge_guards.size())
	assert(summit_guards.size() == 4, "High Summit must have exactly 4 enemies (got %d)." % summit_guards.size())
	print("[EnemyTest] PASS: Exactly 4 enemies deployed per tier across all 3 elevations.")

	print("\n[EnemyTest] --- CHECK 3: Tactical Spacing & Route Accessibility ---")
	# Check inter-enemy spacing per tier
	for tier_list in [valley_guards, ridge_guards, summit_guards]:
		for a in range(tier_list.size()):
			for b in range(a + 1, tier_list.size()):
				var e1: CharacterBody3D = tier_list[a]
				var e2: CharacterBody3D = tier_list[b]
				var dist: float = e1.global_position.distance_to(e2.global_position)
				assert(dist >= 5.0, "Enemies %s and %s are too close (%.2fm < 5.0m)." % [e1.name, e2.name, dist])

	# Check that central path corridors and ramps are not blocked by enemy positions
	for enemy in enemies:
		var pos: Vector3 = (enemy as CharacterBody3D).global_position
		# Ramp 1 zone: Z in [0, 20]
		if pos.z > 0.0 and pos.z < 20.0:
			assert(absf(pos.x) >= 3.0, "Enemy %s is obstructing Ramp 1 central pass at X=%.2f." % [enemy.name, pos.x])
		# Ramp 2 zone: Z in [-60, -38]
		if pos.z < -38.0 and pos.z > -60.0:
			assert(absf(pos.x) >= 3.0, "Enemy %s is obstructing Ramp 2 central pass at X=%.2f." % [enemy.name, pos.x])

	# Radar station core platform is at (0, 14, -78). Check that mast and plinth are accessible.
	var radar_dish_pos: Vector3 = stage.call("get_radar_position")
	for enemy in summit_guards:
		var dist_to_radar: float = enemy.global_position.distance_to(radar_dish_pos)
		assert(dist_to_radar >= 3.0, "Enemy %s is too close to radar mast center (%.2fm)." % [enemy.name, dist_to_radar])

	print("[EnemyTest] PASS: Tactical spacing, ramp access, and radar installation accessibility verified.")

	print("\n[EnemyTest] --- CHECK 4: Initial Guard Awareness & Freezing ---")
	# At startup, all guards should be frozen at their posts (physics process false)
	for enemy in enemies:
		var guard := enemy as CharacterBody3D
		assert(not guard.is_physics_processing(), "Guard %s must initially be frozen (physics_process=false)." % guard.name)
		assert(not stage.call("is_guard_active", guard.name), "Guard %s active flag must initially be false." % guard.name)

	print("[EnemyTest] PASS: All 12 guards initialized in frozen idle/sentry state.")

	print("\n[EnemyTest] --- CHECK 5: Line-of-Sight & Cover Occlusion ---")
	var player: Node3D = stage.get_node_or_null("Player3D") as Node3D
	assert(player != null, "Player3D node must exist.")

	var test_guard: CharacterBody3D = enemies_container.get_node("Enemy3D_1") as CharacterBody3D

	# Position player in clear line of sight in front of Enemy3D_1 (which is at (10, 0, 38))
	player.global_position = Vector3(10.0, 0.2, 44.0)
	await physics_frame
	var has_clear_los: bool = stage.call("_has_line_of_sight", test_guard)
	assert(has_clear_los, "Enemy3D_1 must have clear line of sight to open player.")

	# Position player behind ValleyCrateStack_A at (-8.0, 0.2, 44.0) from Enemy3D_2 at (-11.0, 0.0, 35.0)
	var test_guard2: CharacterBody3D = enemies_container.get_node("Enemy3D_2") as CharacterBody3D
	# Placing player directly behind ValleyGenerator (-14.0, 1.2, 36.0) relative to Enemy3D_2
	player.global_position = Vector3(-17.0, 0.2, 36.5)
	await physics_frame
	var blocked_los: bool = stage.call("_has_line_of_sight", test_guard2)
	assert(not blocked_los, "Solid cover must block line of sight between guard and player.")
	print("[EnemyTest] PASS: Line-of-sight raycasting confirms visual detection and cover occlusion.")

	print("\n[EnemyTest] --- CHECK 6: Combat Activation & Damage Alert ---")
	# Activating test_guard should start its physics process and target the player
	stage.call("activate_guard", test_guard, "test manual activation")
	assert(test_guard.is_physics_processing(), "Activated guard must enable physics process.")
	assert(stage.call("is_guard_active", test_guard.name), "Activated guard flag must be true.")
	assert(test_guard.target_player == player, "Activated guard must target player.")

	# Damaging an inactive guard should trigger its activation
	var inactive_guard: CharacterBody3D = enemies_container.get_node("Enemy3D_3") as CharacterBody3D
	assert(not stage.call("is_guard_active", inactive_guard.name), "Enemy3D_3 must initially be inactive.")
	inactive_guard.health_changed.emit(75, 100) # emit health change signal (damaged)
	await physics_frame
	assert(stage.call("is_guard_active", inactive_guard.name), "Damaged guard must activate immediately on incoming fire.")
	print("[EnemyTest] PASS: Combat activation and damage response verified.")

	print("\n[EnemyTest] --- CHECK 7: Acoustic Elevation Isolation ---")
	# Player firing in lower valley (Y=0.2) should NOT alert summit guards (Y=14)
	player.global_position = Vector3(0.0, 0.2, 45.0)
	var summit_guard: CharacterBody3D = enemies_container.get_node("Enemy3D_9") as CharacterBody3D
	assert(not stage.call("is_guard_active", summit_guard.name), "Summit guard must be inactive before gunshot.")

	stage.call("_on_player_gunshot_alert")
	await physics_frame
	assert(not stage.call("is_guard_active", summit_guard.name), "Summit guard at Y=14m must NOT be alerted by gunshot down in Valley at Y=0m.")
	print("[EnemyTest] PASS: Gunshot hearing respects elevation gaps between mountain tiers.")

	print("\n=========================================================")
	print(" ALL STAGE 08 ENEMY DEPLOYMENT VERIFICATIONS PASSED!     ")
	print("=========================================================")

	stage.queue_free()
	quit(0)
