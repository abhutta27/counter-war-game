extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/stages/Stage03.tscn") as PackedScene
	assert(packed != null, "Stage03 must load")
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 18:
		await physics_frame

	var player: Player3D = stage.get_node("Player3D") as Player3D
	var enemies := stage.get_node("Enemies").get_children()
	assert(player != null, "Player3D must exist")
	assert(enemies.size() == 7 and stage.total_targets == 7, "Stage03 must retain exactly seven hostiles")
	assert(stage.hud.hostiles_counter_label.text == "HOSTILES: 07 / 07", "HUD must start at HOSTILES: 07 / 07")
	assert(stage.get_node_or_null("EncounterActivationZones/OuterForestActivation") != null, "Outer forest trigger must exist")
	assert(stage.get_node_or_null("EncounterActivationZones/CommunicationsCompoundActivation") != null, "Compound trigger must exist")
	assert(stage.get_node_or_null("EncounterActivationZones/InnerBlacksiteActivation") != null, "Inner blacksite trigger must exist")

	player.max_health = 50000
	player.current_health = 50000
	var spawn_positions: Dictionary = {}
	for enemy in enemies:
		enemy.attack_damage = 0
		spawn_positions[enemy.name] = enemy.global_position
		assert(not enemy.is_physics_processing(), "%s must begin as an inactive guard" % enemy.name)
		assert(enemy.current_state == 0, "%s must begin in IDLE" % enemy.name)
		assert(not enemy._has_detected_player, "%s must not falsely detect at mission start" % enemy.name)

	# Quiet opening: three seconds at spawn must not activate, move, fire, or call out.
	for _frame in 180:
		await physics_frame
	for enemy in enemies:
		assert(enemy.global_position.distance_to(spawn_positions[enemy.name]) < 0.05, "%s must remain at its guard post during the quiet opening" % enemy.name)
		assert(not enemy._has_detected_player, "%s must remain unaware during the quiet opening" % enemy.name)
	assert(not stage.is_zone_active(1) and not stage.is_zone_active(2) and not stage.is_zone_active(3), "No encounter may activate at spawn")

	# Existing player and weapon controls still work before contact.
	var start := player.global_position
	Input.action_press("move_forward")
	for _frame in 18:
		await physics_frame
	Input.action_release("move_forward")
	assert(player.global_position.distance_to(start) > 0.35, "Player movement must work in the infiltration section")
	var weapon = player.get_weapon_manager().get_current_weapon()
	var ammo_before: int = weapon.current_ammo
	player._handle_fire_button(true)
	await physics_frame
	player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before, "Player firing must remain operational")
	player._reload_active_weapon()
	for _frame in 240:
		await physics_frame
	assert(weapon.current_ammo == weapon.data.magazine_size, "Reload must remain operational")

	# Enter Zone 1 at z=28..20: only the two outer guards may wake.
	player.global_position = Vector3(0, 0.1, 25)
	for _frame in 6:
		await physics_frame
	assert(stage.is_zone_active(1), "Outer forest trigger must activate naturally")
	assert(not stage.is_zone_active(2) and not stage.is_zone_active(3), "Deeper zones must remain inactive after first contact")
	_assert_group_state(stage, ["Enemy3D_1", "Enemy3D_2"], true)
	_assert_group_state(stage, ["Enemy3D_3", "Enemy3D_4", "Enemy3D_5", "Enemy3D_6", "Enemy3D_7"], false)
	for _frame in 120:
		await physics_frame
	_assert_detected_and_moved(stage, ["Enemy3D_1", "Enemy3D_2"], spawn_positions)
	_assert_unaware_and_stationary(stage, ["Enemy3D_3", "Enemy3D_4", "Enemy3D_5", "Enemy3D_6", "Enemy3D_7"], spawn_positions)

	# Enter Zone 2 at z=4..-4: three compound guards wake, final defenders stay quiet.
	player.global_position = Vector3(0, 0.1, 1)
	for _frame in 6:
		await physics_frame
	assert(stage.is_zone_active(2), "Communications compound trigger must activate naturally")
	assert(not stage.is_zone_active(3), "Inner defenders must remain inactive during the compound encounter")
	_assert_group_state(stage, ["Enemy3D_3", "Enemy3D_4", "Enemy3D_5"], true)
	_assert_group_state(stage, ["Enemy3D_6", "Enemy3D_7"], false)
	for _frame in 180:
		await physics_frame
	_assert_detected_and_moved(stage, ["Enemy3D_3", "Enemy3D_4", "Enemy3D_5"], spawn_positions)
	_assert_unaware_and_stationary(stage, ["Enemy3D_6", "Enemy3D_7"], spawn_positions)

	# Enter Zone 3 at z=-17..-25: only now do the two mast defenders wake.
	player.global_position = Vector3(0, 0.1, -20)
	for _frame in 6:
		await physics_frame
	assert(stage.is_zone_active(3), "Inner blacksite trigger must activate naturally")
	_assert_group_state(stage, ["Enemy3D_6", "Enemy3D_7"], true)
	for _frame in 180:
		await physics_frame
	_assert_detected_and_moved(stage, ["Enemy3D_6", "Enemy3D_7"], spawn_positions)

	# All guards retain the original kill/completion flow after activation.
	for enemy in enemies:
		assert(enemy.get_node_or_null("EnemyAlertVoice3D") != null, "%s must retain its detection voice emitter" % enemy.name)
		enemy.take_damage(enemy.current_health)
		await process_frame
	assert(stage.targets_eliminated == 7, "Hostile counter must reach seven")
	assert(stage.hud.hostiles_counter_label.text == "HOSTILES: 00 / 07", "HUD must reach HOSTILES: 00 / 07")
	assert(stage.is_stage_finished, "Mission Complete must trigger")
	assert(stage.summary_dialog != null and stage.summary_dialog.visible, "Mission summary must display")

	var stage_manager = root.get_node("StageManager")
	assert(stage_manager.load_next_stage(), "NEXT MISSION must request Stage04")
	for _frame in 30:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage04", "NEXT MISSION must load Stage04")
	print("[Stage03Regression] PASS: quiet opening -> 2 outer -> 3 compound -> 2 inner; combat, 00/07, completion, Stage04")
	quit(0)

func _assert_group_state(stage: Node, names: Array, expected_active: bool) -> void:
	for enemy_name in names:
		assert(stage.is_enemy_encounter_active(enemy_name) == expected_active, "%s active state must be %s" % [enemy_name, expected_active])

func _assert_detected_and_moved(stage: Node, names: Array, starts: Dictionary) -> void:
	for enemy_name in names:
		var enemy = stage.get_node("Enemies/" + enemy_name)
		assert(enemy._has_detected_player, "%s must use normal detection after activation" % enemy_name)
		var moved: bool = enemy.global_position.distance_to(starts[enemy_name]) > 0.5
		var valid_combat_ring: bool = enemy.current_state == 2 and enemy.global_position.distance_to(stage.player.global_position) <= 10.5
		assert(moved or valid_combat_ring, "%s must chase or enter the existing 10m combat ring after activation" % enemy_name)

func _assert_unaware_and_stationary(stage: Node, names: Array, starts: Dictionary) -> void:
	for enemy_name in names:
		var enemy = stage.get_node("Enemies/" + enemy_name)
		assert(not enemy._has_detected_player, "%s must remain unaware before its zone" % enemy_name)
		assert(enemy.global_position.distance_to(starts[enemy_name]) < 0.05, "%s must remain at its deeper guard post" % enemy_name)
