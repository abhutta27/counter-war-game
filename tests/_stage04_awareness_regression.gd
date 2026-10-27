extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage04.tscn")

func _init() -> void:
	call_deferred("_run")

func _new_stage():
	if current_scene:
		current_scene.queue_free()
		await process_frame
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 20:
		await physics_frame
	stage.player.max_health = 50000
	stage.player.current_health = 50000
	for enemy in stage.enemies_container.get_children():
		enemy.attack_damage = 0
	return stage

func _run() -> void:
	# TEST A: standing at spawn never wakes the facility or deep defenders.
	var stage = await _new_stage()
	for _frame in 180:
		await physics_frame
	for enemy in stage.enemies_container.get_children():
		assert(not stage.is_guard_active(enemy.name), "TEST A: %s must not activate at quiet entry" % enemy.name)
	assert(not stage.is_guard_suspicious("Enemy3D_9") and not stage.is_guard_suspicious("Enemy3D_12"), "TEST A: deep defenders remain unaware")

	# TEST D: close nominal range through a solid silo remains fully occluded.
	var occluded = stage.enemies_container.get_node("Enemy3D_9")
	var blocked_player_position := Vector3(-21, 0, -35)
	occluded.look_at(blocked_player_position + Vector3.UP * occluded.global_position.y, Vector3.UP)
	stage.player.global_position = blocked_player_position
	for _frame in 50:
		await physics_frame
	assert(not stage.is_guard_active("Enemy3D_9"), "TEST D: guard must not confirm through Silo1")
	assert(not stage.is_guard_suspicious("Enemy3D_9"), "TEST D: occluded guard must not become visually suspicious")

	# TESTS B/C: exposed forward approach first pauses patrol, then confirms;
	# an exposed 6 m approach confirms immediately.
	stage = await _new_stage()
	var patrol = stage.enemies_container.get_node("Enemy3D_1")
	var forward: Vector3 = -patrol.global_basis.z
	forward.y = 0.0
	stage.player.global_position = patrol.global_position + forward.normalized() * 14.0
	for _frame in 10:
		await physics_frame
	assert(stage.is_guard_suspicious("Enemy3D_1"), "TEST B: patrol must stop and become suspicious on visual contact")
	assert(patrol.velocity.length() < 0.2, "TEST B: suspicious patrol must stop casual walking")
	for _frame in 24:
		await physics_frame
	assert(stage.is_guard_active("Enemy3D_1"), "TEST B: sustained visible contact must enter combat quickly")
	var close_guard = stage.enemies_container.get_node("Enemy3D_5")
	var close_forward: Vector3 = -close_guard.global_basis.z
	close_forward.y = 0.0
	stage.player.global_position = close_guard.global_position + close_forward.normalized() * 6.0
	for _frame in 10:
		await physics_frame
	assert(stage.is_guard_active("Enemy3D_5"), "TEST C: exposed guard must react immediately at 6 m")

	# TESTS E/F: freight-yard gunfire and confirmed contact alert only neighbors.
	stage = await _new_stage()
	stage.player.global_position = Vector3(0, 0, 18)
	var weapon = stage.player.get_weapon_manager().get_current_weapon()
	var ammo_before: int = weapon.current_ammo
	stage.player._handle_fire_button(true)
	await physics_frame
	stage.player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before, "TEST E: Player must actually fire the freight-yard shot")
	await physics_frame
	var local_reactions := 0
	for guard_name in ["Enemy3D_1", "Enemy3D_2", "Enemy3D_5"]:
		if stage.is_guard_suspicious(guard_name) or stage.is_guard_active(guard_name):
			local_reactions += 1
	assert(local_reactions >= 2, "TEST E: freight-yard gunshot must alert nearby guards")
	for guard_name in ["Enemy3D_9", "Enemy3D_10", "Enemy3D_11", "Enemy3D_12"]:
		assert(not stage.is_guard_suspicious(guard_name) and not stage.is_guard_active(guard_name), "TEST E: far control defenders remain unaware")
	var source = stage.enemies_container.get_node("Enemy3D_1")
	stage.activate_guard(source, "awareness regression contact")
	await physics_frame
	assert(stage.is_guard_suspicious("Enemy3D_5") or stage.is_guard_active("Enemy3D_5"), "TEST F: nearby yard guard must react to guard 1 combat")
	assert(not stage.is_guard_suspicious("Enemy3D_11") and not stage.is_guard_active("Enemy3D_11"), "TEST F: control-room guard must not join yard combat")

	# TEST G: a deep defender naturally confirms once Player penetrates its area.
	stage = await _new_stage()
	var deep_guard = stage.enemies_container.get_node("Enemy3D_9")
	var deep_forward: Vector3 = -deep_guard.global_basis.z
	deep_forward.y = 0.0
	stage.player.global_position = deep_guard.global_position + deep_forward.normalized() * 8.0
	for _frame in 10:
		await physics_frame
	assert(stage.is_guard_suspicious("Enemy3D_9") or stage.is_guard_active("Enemy3D_9"), "TEST G: deep guard must notice local penetration")
	for _frame in 24:
		await physics_frame
	assert(stage.is_guard_active("Enemy3D_9"), "TEST G: deep guard must confirm and enter shared combat behavior")

	print("[Stage04Awareness] PASS A-G: quiet entry, visual alert, close contact, occlusion, gunshot, local sharing, deep awareness")
	quit(0)
