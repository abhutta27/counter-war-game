extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/stages/Stage02.tscn") as PackedScene
	assert(packed != null, "Stage02 must load")
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 12:
		await physics_frame

	var player: Player3D = stage.get_node("Player3D") as Player3D
	var enemies := stage.get_node("Enemies").get_children()
	assert(player != null, "Player3D must exist")
	assert(enemies.size() == 6, "Stage02 enemy count must remain six")
	assert(stage.total_targets == 6, "HUD hostile source count must be six")
	assert(stage.get_node_or_null("Stage02UrbanZone") != null, "Urban environment must exist")

	player.max_health = 20000
	player.current_health = 20000
	var initial_distances: Dictionary = {}
	for enemy in enemies:
		enemy.attack_damage = 0
		initial_distances[enemy.name] = enemy.global_position.distance_to(player.global_position)

	var weapon = player.get_weapon_manager().get_current_weapon()
	var ammo_before: int = weapon.current_ammo
	player._handle_fire_button(true)
	await physics_frame
	player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before, "Player firing must consume ammo")
	player._reload_active_weapon()
	assert(weapon.is_reloading, "R reload path must start reload")
	for _frame in 240:
		await physics_frame
	assert(weapon.current_ammo == weapon.data.magazine_size, "Reload must refill the magazine")

	for _frame in 1200:
		await physics_frame
	for enemy in enemies:
		var final_distance: float = enemy.global_position.distance_to(player.global_position)
		var initial_distance: float = initial_distances[enemy.name]
		print("[Stage02Regression] ", enemy.name, " distance ", initial_distance, " -> ", final_distance)
		assert(final_distance <= 13.0, "%s must reach the Player's combat ring" % enemy.name)

	for enemy in enemies:
		enemy.take_damage(enemy.current_health)
		await process_frame
	assert(stage.targets_eliminated == 6, "Hostile counter must reach six")
	assert(stage.is_stage_finished, "Mission Complete must trigger")
	assert(stage.summary_dialog != null and stage.summary_dialog.visible, "Mission summary must display")

	var stage_manager = root.get_node("StageManager")
	assert(stage_manager.load_next_stage(), "NEXT MISSION must request Stage03")
	for _frame in 30:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage03", "NEXT MISSION must load Stage03")
	print("[Stage02Regression] PASS: routes, fire, reload, six enemies, counter, completion, and Stage03 transition")
	quit(0)
