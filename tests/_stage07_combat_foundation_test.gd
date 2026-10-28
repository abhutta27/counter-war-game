extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage07.tscn")
const DamageInfo := preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[Stage07CombatTest] START: Testing Stage 07 Enemy Combat Foundation...")

	# -------------------------------------------------------------
	# STEP 1: LOAD STAGE 07 AND VERIFY ENEMY SETUP
	# -------------------------------------------------------------
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage

	for _f in 10:
		await process_frame

	assert(stage.stage_id == 7, "Stage ID must be 7")
	assert(stage.stage_name == "OPERATION IRON HARBOR", "Stage name must be OPERATION IRON HARBOR")
	assert(stage.has_node("Enemies"), "Stage 07 must have Enemies node")

	var enemies_node: Node3D = stage.get_node("Enemies")
	var count: int = enemies_node.get_child_count()
	print("[Stage07CombatTest] Total enemies under $Enemies: %d" % count)
	assert(count == 12, "Stage 07 must have exactly 12 deployed guards")
	assert(stage.total_targets == 12, "LevelBase3D total_targets must equal 12")
	assert(stage.targets_eliminated == 0, "Initial targets_eliminated must be 0")

	# Verify guards exist across all 3 requested zones
	var entrance_count := 0
	var yard_count := 0
	var command_count := 0

	for child in enemies_node.get_children():
		var guard := child as Enemy3D
		assert(guard != null, "Guard %s must be instance of Enemy3D" % child.name)
		assert(guard.current_health == 100, "Guard %s initial health must be 100" % child.name)
		assert(guard.global_position.y >= -0.1 and guard.global_position.y <= 2.0, "Guard %s must be grounded" % child.name)

		var g_data: Dictionary = stage.GUARD_DATA.get(guard.name, {})
		var zone: String = g_data.get("zone", "")
		match zone:
			"entrance": entrance_count += 1
			"yard": yard_count += 1
			"command": command_count += 1

	print("[Stage07CombatTest] Zone distribution: Entrance=%d, Yard=%d, Command=%d" % [entrance_count, yard_count, command_count])
	assert(entrance_count == 3, "Must have 3 entrance guards")
	assert(yard_count == 5, "Must have 5 container yard guards")
	assert(command_count == 4, "Must have 4 command center guards")

	# -------------------------------------------------------------
	# STEP 2: VERIFY GUARDS REMAIN FROZEN DURING CINEMATIC
	# -------------------------------------------------------------
	assert(stage.is_cinematic_active(), "Intro cinematic must be active at launch")
	var initial_positions: Dictionary = {}
	for child in enemies_node.get_children():
		assert(not child.is_physics_processing(), "Guard %s physics must be inactive during cinematic" % child.name)
		assert(child.velocity == Vector3.ZERO, "Guard %s velocity must be ZERO during cinematic" % child.name)
		initial_positions[child.name] = child.global_position

	# Advance 20 frames during cinematic
	for _f in 20:
		await process_frame

	for child in enemies_node.get_children():
		var pos_diff: float = child.global_position.distance_to(initial_positions[child.name])
		assert(pos_diff < 0.05, "Guard %s must not drift or chase during cinematic" % child.name)

	print("[Stage07CombatTest] PASS: Guards remained properly frozen during intro cinematic.")

	# -------------------------------------------------------------
	# STEP 3: SKIP CINEMATIC AND VERIFY COMBAT ACTIVATION
	# -------------------------------------------------------------
	stage.skip_cinematic()
	await process_frame
	assert(not stage.is_cinematic_active(), "Cinematic must be inactive after skip")
	assert(stage.player.is_active, "Player must be active")

	# Player is at (0, 0, 58). Guard 1 is at (-6, 0, 46) -> within 14m entrance proximity.
	for _f in 15:
		await process_frame

	var guard1: Enemy3D = enemies_node.get_node("Enemy3D_1") as Enemy3D
	assert(stage.guard_active.get("Enemy3D_1", false), "Entrance Guard 1 must activate due to player proximity")
	assert(guard1.is_physics_processing(), "Activated Guard 1 must run physics processing")
	print("[Stage07CombatTest] PASS: Entrance guard activated on player proximity.")

	# Distant command guard at (34, 0, -14) must remain unaware until approached/alerted
	var guard9: Enemy3D = enemies_node.get_node("Enemy3D_9") as Enemy3D
	assert(not stage.guard_active.get("Enemy3D_9", false), "Distant Command Guard 9 must remain inactive while player is at entrance")
	print("[Stage07CombatTest] PASS: Distant guards remain safely at their posts.")

	# -------------------------------------------------------------
	# STEP 4: DAMAGE AND ELIMINATION TEST
	# -------------------------------------------------------------
	print("[Stage07CombatTest] Testing combat damage and elimination on Guard 1...")
	var initial_score: int = stage.current_mission_score

	# Hit Guard 1 with 40 damage
	var dmg1 = DamageInfo.new(40, false, stage.player, "Rifle", guard1.global_position, Vector3.FORWARD, Vector3.UP, 0)
	guard1.take_damage(dmg1)
	assert(guard1.current_health == 60, "Guard 1 health must be 60 after 40 damage")

	# Fatal blow: 80 damage
	var dmg_fatal = DamageInfo.new(80, false, stage.player, "Rifle", guard1.global_position, Vector3.FORWARD, Vector3.UP, 0)
	guard1.take_damage(dmg_fatal)
	assert(guard1.is_dead, "Guard 1 must be dead after lethal damage")

	for _f in 10:
		await process_frame

	assert(stage.targets_eliminated == 1, "LevelBase3D targets_eliminated must increment to 1")
	assert(stage.current_mission_score == initial_score + 100, "Score must increase by 100 on enemy kill")
	print("[Stage07CombatTest] PASS: Damage, lethal elimination, targets_eliminated, and score tracking verified.")

	# -------------------------------------------------------------
	# STEP 5: GUNSHOT ALERT TEST
	# -------------------------------------------------------------
	print("[Stage07CombatTest] Testing gunshot alert propagation...")
	# Teleport player near Yard Alpha entrance (-12, 0, 32)
	stage.player.global_position = Vector3(-12.0, 0.0, 32.0)
	stage.player.shot_fired.emit()

	for _f in 8:
		await process_frame

	var guard4: Enemy3D = enemies_node.get_node("Enemy3D_4") as Enemy3D
	assert(stage.guard_active.get("Enemy3D_4", false), "Yard Guard 4 must activate upon hearing nearby gunshot")
	print("[Stage07CombatTest] PASS: Gunshot hearing alerted nearby yard guard.")

	# Verify enemy damage uses its muzzle-to-player fire ray and that layer-1 solid
	# cover blocks both a wall and a container independently of awareness/LoS.
	var shooter: Enemy3D = enemies_node.get_node("Enemy3D_2") as Enemy3D
	stage.player.global_position = Vector3(0.0, 0.0, 58.0)
	stage.player.force_update_transform()
	shooter.global_position = Vector3(0.0, 0.0, 50.0)
	shooter.force_update_transform()
	shooter.target_player = stage.player
	shooter.current_state = Enemy3D.State.ATTACK
	await physics_frame
	await process_frame
	await physics_frame
	var muzzle := shooter.enemy_weapon.get_node("MuzzleMarker") as Node3D
	var target_point: Vector3 = stage.player.global_position + Vector3.UP * 1.2
	var start_health: int = stage.player.current_health
	assert(shooter.has_clear_enemy_fire_path(), "Open enemy fire lane must reach the player")
	shooter._enemy_shoot()
	assert(stage.player.current_health < start_health, "Open-lane enemy shot must damage the player")
	print("[Stage07CombatTest] PASS: Open fire lane reaches player and inflicts damage (HP: %d -> %d)." % [start_health, stage.player.current_health])

	var cover := StaticBody3D.new()
	cover.name = "TestSolidCover"
	cover.collision_layer = 1
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(6.0, 5.0, 0.8)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	stage.add_child(cover)
	cover.global_position = muzzle.global_position.lerp(target_point, 0.5)
	cover.force_update_transform()
	await physics_frame
	await process_frame
	await physics_frame
	var health_before_cover: int = stage.player.current_health
	assert(not shooter.has_clear_enemy_fire_path(), "Solid wall must block the enemy fire ray")
	shooter._enemy_shoot()
	assert(stage.player.current_health == health_before_cover, "Player behind solid wall must take no damage")
	print("[Stage07CombatTest] PASS: Solid wall completely blocks fire path and prevents damage.")

	# Reuse the same test collider at a container-sized obstacle location.
	cover_box.size = Vector3(8.0, 6.0, 2.4)
	cover.global_position = muzzle.global_position.lerp(target_point, 0.5)
	cover.force_update_transform()
	await physics_frame
	await process_frame
	await physics_frame
	assert(not shooter.has_clear_enemy_fire_path(), "Solid container must block the enemy fire ray")
	shooter._enemy_shoot()
	assert(stage.player.current_health == health_before_cover, "Player behind solid container must take no damage")
	print("[Stage07CombatTest] PASS: Solid container completely blocks fire path and prevents damage.")
	cover.queue_free()

	print("\n[Stage07CombatTest] ALL STAGE 07 ENEMY COMBAT FOUNDATION CHECKS PASSED.")
	quit(0)
