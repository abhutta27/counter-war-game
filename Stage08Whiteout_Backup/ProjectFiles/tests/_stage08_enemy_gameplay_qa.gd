extends SceneTree
## _stage08_enemy_gameplay_qa.gd
## Comprehensive Gameplay Verification for Stage 08 Enemy Behavior:
## 1. Direct Line-of-Sight & Visual FOV Activation
## 2. Obstacle / Cover Occlusion (guards do NOT detect player behind cover)
## 3. Damage Reaction & Engagement
## 4. Distant Elevation Isolation (Summit/Ridge guards do NOT attack prematurely)

func _init() -> void:
	print("\n=========================================================")
	print(" COUNTER-WAR: STAGE 08 ENEMY GAMEPLAY VERIFICATION       ")
	print("=========================================================")
	call_deferred("_run_qa")

func _run_qa() -> void:
	var stage_scene: PackedScene = load("res://scenes/stages/Stage08.tscn")
	assert(stage_scene != null, "Failed to load Stage 08 scene.")

	var stage: Node3D = stage_scene.instantiate() as Node3D
	assert(stage != null, "Failed to instantiate Stage 08 scene.")
	root.add_child(stage)

	# Allow initial scene initialization frames
	for _i in range(5):
		await process_frame
		await physics_frame

	var player := stage.get_node_or_null("Player3D") as Player3D
	assert(player != null, "Player3D node must exist.")
	player.max_health = 999999
	player.current_health = 999999

	var enemies_container := stage.get_node_or_null("Enemies") as Node3D
	assert(enemies_container != null, "Enemies container must exist.")

	# -----------------------------------------------------------------
	# TEST 1: DISTANT ELEVATION ISOLATION AT SPAWN (VALLEY TIER)
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 1: Distant Elevation Isolation at Spawn ---")
	# Player is at spawn (0.0, 0.2, 48.0) in Lower Valley
	player.global_position = Vector3(0.0, 0.2, 48.0)
	for _f in range(15):
		await process_frame
		await physics_frame

	var active_count_at_spawn := 0
	var summit_active_at_spawn := 0
	var ridge_active_at_spawn := 0

	for enemy in enemies_container.get_children():
		var tier: String = stage.call("get_guard_tier", enemy.name)
		var is_act: bool = stage.call("is_guard_active", enemy.name)
		if is_act:
			active_count_at_spawn += 1
			if tier == "high_summit":
				summit_active_at_spawn += 1
			elif tier == "mid_ridge":
				ridge_active_at_spawn += 1

	print("[GAMEPLAY QA] Active guards at spawn: %d (Ridge: %d, Summit: %d)" % [
		active_count_at_spawn, ridge_active_at_spawn, summit_active_at_spawn
	])
	assert(summit_active_at_spawn == 0, "No High Summit guards (Y=14) should activate at valley spawn.")
	assert(ridge_active_at_spawn == 0, "No Mid-Ridge guards (Y=6) should activate at valley spawn.")
	print("[GAMEPLAY QA] PASS: Distant elevations (Mid-Ridge & High Summit) remain unalerted at spawn.")

	# -----------------------------------------------------------------
	# TEST 2: OBSTACLE / COVER OCCLUSION (PLAYER BEHIND COVER)
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 2: Cover Occlusion (Behind Solid Obstacles) ---")
	var guard_e2 := enemies_container.get_node_or_null("Enemy3D_2") as CharacterBody3D
	assert(guard_e2 != null, "Enemy3D_2 must exist.")

	# Position player directly behind ValleyGenerator at (-14.0, 1.2, 36.0)
	# Enemy3D_2 is at (-11.0, 0.0, 35.0). Solid generator is at (-14, 1.2, 36).
	# Placing player at (-17.0, 0.2, 36.5) puts the generator squarely between them.
	player.global_position = Vector3(-17.0, 0.2, 36.5)
	assert(not stage.call("is_guard_active", guard_e2.name), "Enemy3D_2 must initially be inactive.")

	# Run 20 physics frames and let polling cycle execute
	for _f in range(20):
		await process_frame
		await physics_frame

	var los_behind_cover: bool = stage.call("_has_line_of_sight", guard_e2)
	assert(not los_behind_cover, "Solid generator cover must block line of sight.")
	assert(not stage.call("is_guard_active", guard_e2.name), "Enemy3D_2 must NOT activate while player is concealed behind generator.")
	print("[GAMEPLAY QA] PASS: Guard does NOT see or activate through solid cover.")

	# -----------------------------------------------------------------
	# TEST 3: ACTIVATION ON DIRECT LINE-OF-SIGHT & FOV
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 3: Direct Line-of-Sight & Visual FOV Activation ---")
	# Step out from behind the generator into Enemy3D_2's field of view
	# Enemy3D_2 is at (-11.0, 0.0, 35.0) looking north at (-11.0, 0.0, 20.0).
	# Placing player at (-11.0, 0.2, 29.0) puts player 6m directly in front of Enemy3D_2.
	player.global_position = Vector3(-11.0, 0.2, 29.0)

	for _f in range(20):
		await process_frame
		await physics_frame

	var los_in_open: bool = stage.call("_has_line_of_sight", guard_e2)
	assert(los_in_open, "Enemy3D_2 must have clear line of sight to open player.")
	assert(stage.call("is_guard_active", guard_e2.name), "Enemy3D_2 must activate upon visual confirmation.")
	assert(guard_e2.is_physics_processing(), "Enemy3D_2 physics process must be enabled.")
	assert(guard_e2.target_player == player, "Enemy3D_2 must target player.")
	print("[GAMEPLAY QA] PASS: Guard confirms visual contact and activates into combat.")

	# -----------------------------------------------------------------
	# TEST 4: REACTION TO INCOMING DAMAGE
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 4: Reaction to Incoming Damage ---")
	var guard_e7 := enemies_container.get_node_or_null("Enemy3D_7") as CharacterBody3D
	assert(guard_e7 != null, "Enemy3D_7 must exist.")
	# Player is down in Lower Valley, Enemy3D_7 is up on Mid-Ridge
	player.global_position = Vector3(0.0, 0.2, 48.0)
	for _f in range(5):
		await process_frame
		await physics_frame

	assert(not stage.call("is_guard_active", guard_e7.name), "Enemy3D_7 must initially be inactive.")

	# Inflict damage to Enemy3D_7
	print("[GAMEPLAY QA] Inflicting 30 damage to Enemy3D_7...")
	guard_e7.health_changed.emit(70, 100)
	for _f in range(5):
		await process_frame
		await physics_frame

	assert(stage.call("is_guard_active", guard_e7.name), "Damaged guard must activate immediately.")
	assert(guard_e7.is_physics_processing(), "Damaged guard must start physics processing.")
	print("[GAMEPLAY QA] PASS: Inactive guard responds to damage and engages combat state.")

	# -----------------------------------------------------------------
	# TEST 5: MID-RIDGE COMBAT ELEVATION ISOLATION FROM SUMMIT
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 5: Mid-Ridge Combat Elevation Isolation ---")
	# Move player to Mid-Ridge terrace at (0.0, 6.0, -14.0)
	player.global_position = Vector3(0.0, 6.0, -14.0)
	for _f in range(25):
		await process_frame
		await physics_frame

	# Check that summit guards at Y=14 (Enemy3D_9 to Enemy3D_12) remain inactive
	var summit_guards_active := 0
	for i in range(9, 13):
		var s_name := "Enemy3D_%d" % i
		if stage.call("is_guard_active", s_name):
			summit_guards_active += 1

	print("[GAMEPLAY QA] Summit guards active while player is on Mid-Ridge: %d / 4" % summit_guards_active)
	assert(summit_guards_active == 0, "Summit guards (Y=14) must NOT prematurely engage player fighting on Mid-Ridge (Y=6).")
	print("[GAMEPLAY QA] PASS: High summit enemies do not engage prematurely across elevation gap.")

	# -----------------------------------------------------------------
	# TEST 6: SUMMIT ARRIVAL COMBAT ACTIVATION
	# -----------------------------------------------------------------
	print("\n[GAMEPLAY QA] --- TEST 6: Summit Arrival Combat Activation ---")
	# Move player up to Summit perimeter at (0.0, 14.0, -66.0)
	# Enemy3D_9 is at (-8.0, 14.0, -67.0) and Enemy3D_10 is at (8.0, 14.0, -69.0)
	player.global_position = Vector3(0.0, 14.0, -66.0)
	for _f in range(25):
		await process_frame
		await physics_frame

	var summit_now_active := 0
	for i in range(9, 13):
		var s_name := "Enemy3D_%d" % i
		if stage.call("is_guard_active", s_name):
			summit_now_active += 1

	print("[GAMEPLAY QA] Summit guards active upon player arrival on High Summit: %d / 4" % summit_now_active)
	assert(summit_now_active >= 1, "Summit guards must legitimately engage once player ascends to High Summit.")
	print("[GAMEPLAY QA] PASS: Summit guards engage appropriately when player reaches summit elevation.")

	print("\n=========================================================")
	print(" ALL 4 ENEMY GAMEPLAY VERIFICATIONS PASSED!              ")
	print("=========================================================")

	stage.queue_free()
	quit(0)
