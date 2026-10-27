extends SceneTree

const TEST_SAVE := "res://tests/.stage01_polish_regression.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile = root.get_node("ProfileManager")
	var original_save_path: String = profile.save_path
	var original_profile: Dictionary = profile.current_profile.duplicate(true)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	profile.save_path = TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_or_switch_profile("Stage01Regression"), "Test profile must be created")
	profile.record_stage_completed(1)
	assert(profile.get_highest_unlocked_stage() >= 2, "Fixture must unlock Stage02 without changing production rules")

	var packed := load("res://scenes/stages/Stage01.tscn") as PackedScene
	assert(packed != null, "Stage01 must load")
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 12:
		await physics_frame

	var player: Player3D = stage.get_node("Player3D") as Player3D
	var enemies := stage.get_node("Enemies").get_children()
	assert(player != null, "Player3D must exist")
	assert(enemies.size() == 5, "Stage01 enemy count must remain five")
	assert(stage.total_targets == 5, "Hostile counter source count must remain five")
	assert(stage.get_node_or_null("Stage01Outpost") != null, "Shared outpost environment must exist")

	player.max_health = 10000
	player.current_health = 10000
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

	for _frame in 540:
		await physics_frame
	for enemy in enemies:
		var final_distance: float = enemy.global_position.distance_to(player.global_position)
		var initial_distance: float = initial_distances[enemy.name]
		print("[Stage01Regression] ", enemy.name, " distance ", initial_distance, " -> ", final_distance)
		assert(final_distance <= 13.0, "%s must reach the Player's combat ring" % enemy.name)

	for enemy in enemies:
		enemy.take_damage(enemy.current_health)
		await process_frame
	assert(stage.targets_eliminated == 5, "Hostile counter must reach five")
	assert(stage.is_stage_finished, "Mission Complete must trigger")
	assert(stage.summary_dialog != null and stage.summary_dialog.visible, "Mission summary must display")

	var stage_manager = root.get_node("StageManager")
	assert(stage_manager.load_next_stage(), "NEXT MISSION must request Stage02")
	for _frame in 30:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage02", "NEXT MISSION must load Stage02")
	profile.save_path = original_save_path
	profile.current_profile = original_profile
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("[Stage01Regression] PASS: movement paths, fire, reload, enemies, counter, completion, and Stage02 transition")
	quit(0)
