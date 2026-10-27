extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/stages/Stage04.tscn") as PackedScene
	assert(packed != null, "Stage04 must load")
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 20:
		await physics_frame

	var player: Player3D = stage.player
	var enemies: Array[Node] = stage.enemies_container.get_children()
	assert(enemies.size() == 12 and stage.total_targets == 12, "Stage04 must contain exactly twelve tracked hostiles")
	assert(stage.hud.hostiles_counter_label.text == "HOSTILES: 12 / 12", "HUD must start at HOSTILES: 12 / 12")
	assert(player.global_position.distance_to(Vector3(0, 0, 43)) < 0.25, "Player must start at the security entry")
	player.max_health = 50000
	player.current_health = 50000

	var starts := {}
	for enemy in enemies:
		enemy.attack_damage = 0
		starts[enemy.name] = enemy.global_position
		assert(not stage.is_guard_active(enemy.name), "%s must begin locally unaware" % enemy.name)
		assert(not enemy.is_physics_processing(), "%s shared combat AI must begin paused" % enemy.name)
		assert(not enemy._has_detected_player, "%s must not issue a false opening alert" % enemy.name)
		assert(enemy.get_node_or_null("EnemyAlertVoice3D") != null, "%s must retain the shared voice system" % enemy.name)

	# Three quiet seconds: local patrols move, positional/deep guards do not rush.
	for _frame in 180:
		await physics_frame
	for i in range(4):
		var patrol = enemies[i]
		assert(patrol.global_position.distance_to(starts[patrol.name]) > 1.0, "%s must perform its local patrol" % patrol.name)
		assert(not patrol._has_detected_player, "%s patrol must not know Player location globally" % patrol.name)
	for i in range(4, 12):
		var guard = enemies[i]
		assert(guard.global_position.distance_to(starts[guard.name]) < 0.05, "%s must hold its pre-contact position" % guard.name)
		assert(not guard._has_detected_player, "%s must remain unaware before contact" % guard.name)

	# Player controls, automatic fire, and reload remain functional in Stage04.
	var weapon = player.get_weapon_manager().get_current_weapon()
	var ammo_before: int = weapon.current_ammo
	player._handle_fire_button(true)
	for _frame in 4:
		await physics_frame
	player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before, "Automatic rifle firing must work")
	player._reload_active_weapon()
	for _frame in 150:
		await physics_frame
	assert(weapon.current_ammo == weapon.data.magazine_size, "Reload must work")

	# A natural close contact wakes one patrol and delegates to Enemy3D.
	var contact_guard = stage.enemies_container.get_node("Enemy3D_1")
	player.global_position = contact_guard.global_position + Vector3(0, 0, 4)
	for _frame in 20:
		await physics_frame
	assert(stage.is_guard_active("Enemy3D_1"), "Local patrol contact must activate guard 1")
	assert(contact_guard._has_detected_player, "Activated patrol must use existing Enemy3D detection")
	assert(not stage.is_guard_active("Enemy3D_9"), "Deep facility guard must remain inactive during yard contact")

	# Validate every authored spawn has body clearance above the floor.
	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	for enemy in enemies:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, starts[enemy.name] + Vector3.UP * 0.95)
		query.collision_mask = 1
		var overlaps: Array[Dictionary] = stage.get_world_3d().direct_space_state.intersect_shape(query, 8)
		assert(overlaps.is_empty(), "%s spawn must not intersect facility collision" % enemy.name)

	# Explicitly engage then eliminate all defenders; completion can only happen at 12.
	for i in range(enemies.size()):
		var enemy = enemies[i]
		stage.activate_guard(enemy, "regression progression")
		enemy.take_damage(enemy.current_health)
		await process_frame
		if i < 11:
			assert(not stage.is_stage_finished, "Mission must not complete before enemy 12")
	assert(stage.targets_eliminated == 12, "All twelve eliminations must be counted")
	assert(stage.hud.hostiles_counter_label.text == "HOSTILES: 00 / 12", "HUD must reach HOSTILES: 00 / 12")
	assert(stage.is_stage_finished and stage.summary_dialog.visible, "Mission Complete must appear after enemy 12")

	var stage_manager = root.get_node("StageManager")
	assert(stage_manager.load_next_stage(), "NEXT MISSION must request Stage05")
	for _frame in 30:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage05", "NEXT MISSION must load Stage05")
	print("[Stage04Regression] PASS: 4 patrol + 4 defensive + 4 deep; 12/12 -> 00/12; completion -> Stage05")
	quit(0)

