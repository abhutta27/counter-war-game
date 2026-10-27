extends SceneTree

const STAGE_PATHS := [
	"res://scenes/stages/Stage01.tscn",
	"res://scenes/stages/Stage02.tscn",
	"res://scenes/stages/Stage03.tscn",
	"res://scenes/stages/Stage04.tscn",
	"res://scenes/stages/Stage05.tscn",
	"res://scenes/stages/Stage06.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for stage_index in STAGE_PATHS.size():
		await _verify_stage(stage_index + 1, STAGE_PATHS[stage_index])
	print("[GlobalOutOfBoundsRecovery] PASS: Stage01-Stage06 boundaries, recovery, progress, movement, firing, and completion")
	quit(0)

func _verify_stage(stage_id: int, scene_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
		await process_frame
	var packed := load(scene_path) as PackedScene
	assert(packed != null, "Stage%d scene must load" % stage_id)
	var stage = packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 24:
		await physics_frame

	var player = stage.player
	player.max_health = 50000
	player.current_health = 50000
	for enemy in stage.enemies_container.get_children():
		enemy.attack_damage = 0
	assert(stage.recovery_bounds_enabled, "Stage%d must configure recovery bounds" % stage_id)
	if stage_id <= 5:
		assert(stage.has_node("OutOfBoundsSafetyBoundaries"), "Stage%d must build an invisible physical perimeter" % stage_id)
		assert(stage.get_node("OutOfBoundsSafetyBoundaries").get_child_count() == 4, "Stage%d physical perimeter must have four sides" % stage_id)
	else:
		assert(stage.has_node("Environment/WallNorth") and stage.has_node("Environment/WallSouth") and stage.has_node("Environment/WallWest") and stage.has_node("Environment/WallEast"), "Stage06 must retain its authored four-wall perimeter")

	# Exercise the rear edge that is reachable by walking backward from the spawn
	# in the affected stages. The Player must stop at physical collision.
	player.global_position = Vector3(0.0, 0.15, stage.recovery_bounds_max.y - 2.0)
	player.velocity = Vector3.ZERO
	for _frame in 8:
		await physics_frame
	Input.action_press("move_backward")
	for _frame in 90:
		await physics_frame
	Input.action_release("move_backward")
	assert(player.global_position.z <= stage.recovery_bounds_max.y + 0.6, "Stage%d rear boundary must stop backward escape (z=%s)" % [stage_id, player.global_position.z])

	# Let the grounded point qualify as a stable last-safe position.
	for _frame in 35:
		await physics_frame
	var safe_before_fall: Vector3 = stage.last_safe_position
	assert(safe_before_fall.y > stage.out_of_bounds_y + 1.0, "Stage%d must record a valid grounded safe position" % stage_id)
	# An ordinary airborne moment must neither recover nor replace the checkpoint.
	player.global_position = safe_before_fall + Vector3.UP * 1.5
	player.velocity = Vector3.ZERO
	for _frame in 10:
		await physics_frame
	assert(stage.last_safe_position.distance_to(safe_before_fall) < 0.05, "Stage%d must not checkpoint while airborne" % stage_id)

	var killed_enemy = null
	var eliminated_before_fall: int = stage.targets_eliminated
	if stage_id == 5:
		killed_enemy = stage.enemies_container.get_node("Enemy3D_1")
		killed_enemy.take_damage(killed_enemy.current_health)
		for _frame in 5:
			await process_frame
		assert(killed_enemy.is_dead, "Stage05 pre-fall enemy must be dead")
		assert(stage.targets_eliminated == 1, "Stage05 HOSTILES progress must be reduced before fall")
		eliminated_before_fall = stage.targets_eliminated

	var weapon = player.get_weapon_manager().get_current_weapon()
	var ammo_before_fall: int = weapon.current_ammo
	var recoveries: Array = []
	var recovery_velocities: Array[Vector3] = []
	stage.player_recovered_from_out_of_bounds.connect(func(from: Vector3, to: Vector3):
		recoveries.append([from, to])
		recovery_velocities.append(player.velocity)
	)
	player.global_position = Vector3(safe_before_fall.x, stage.out_of_bounds_y - 3.0, safe_before_fall.z)
	player.velocity = Vector3(0.0, -25.0, 0.0)
	for _frame in 8:
		await process_frame
	assert(recoveries.size() == 1, "Stage%d fall must trigger exactly one recovery" % stage_id)
	assert(player.global_position.distance_to(safe_before_fall) < 1.0, "Stage%d must recover near last safe position" % stage_id)
	assert(recovery_velocities[0].length() < 0.01, "Stage%d recovery must clear dangerous velocity immediately" % stage_id)
	assert(stage.targets_eliminated == eliminated_before_fall, "Stage%d recovery must preserve HOSTILES progress" % stage_id)
	assert(weapon.current_ammo == ammo_before_fall, "Stage%d recovery must preserve ammo" % stage_id)
	assert(stage.is_stage_active and not stage.is_stage_finished, "Stage%d mission must continue after recovery" % stage_id)
	if killed_enemy:
		assert(killed_enemy.is_dead and is_instance_valid(killed_enemy), "Stage05 killed enemy must remain dead after recovery")
	# A normal short drop back onto valid ground must not look like another OOB.
	player.global_position += Vector3.UP * 1.0
	player.velocity = Vector3.ZERO
	for _frame in 35:
		await physics_frame
	assert(recoveries.size() == 1, "Stage%d normal short drop must not trigger recovery" % stage_id)

	# Normal movement and the current weapon remain immediately usable.
	var position_before_move: Vector3 = player.global_position
	Input.action_press("move_forward")
	for _frame in 12:
		await physics_frame
	Input.action_release("move_forward")
	assert(player.global_position.distance_to(position_before_move) > 0.15, "Stage%d Player must move after recovery" % stage_id)
	var ammo_before_fire: int = weapon.current_ammo
	player._handle_fire_button(true)
	await physics_frame
	player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before_fire, "Stage%d weapon must fire after recovery" % stage_id)

	# Recovery never reloads the scene: all surviving enemies can still be killed
	# and the same stage instance can reach Mission Complete.
	for enemy in stage.enemies_container.get_children():
		if not enemy.is_dead:
			enemy.take_damage(enemy.current_health)
			await process_frame
	assert(stage.targets_eliminated == stage.total_targets, "Stage%d must remain completable after recovery" % stage_id)
	assert(stage.is_stage_finished, "Stage%d must reach Mission Complete after recovery" % stage_id)
	print("[GlobalOutOfBoundsRecovery] Stage%02d PASS threshold=%.1f safe=%s" % [stage_id, stage.out_of_bounds_y, safe_before_fall])
