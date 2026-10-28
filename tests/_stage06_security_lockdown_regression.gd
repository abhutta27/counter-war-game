extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage06.tscn")
const SCORE_TEST_SAVE := "res://tests/.stage06_score_test.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup_score_profile()
	var profile = root.get_node("ProfileManager")
	profile.save_path = SCORE_TEST_SAVE
	profile.current_profile = {}
	assert(profile.create_or_update_profile("Stage06Regression"), "Stage06 score fixture must save")
	profile.current_profile["highest_unlocked_stage"] = 6
	assert(profile.save_profile(), "Stage06 progress fixture must save")

	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 20:
		await physics_frame
	stage.player.max_health = 50000
	stage.player.current_health = 50000
	stage.player.walk_speed = 24.0
	for enemy in stage.enemies_container.get_children():
		enemy.attack_damage = 0
	# A-D baseline: spawn, count, checkpoint, and both authored routes.
	assert(stage.player.global_position.distance_to(Vector3(0, 0, 36)) < 0.35, "A: Player must spawn at outer approach")
	assert(stage.total_targets == 12 and stage.enemies_container.get_child_count() == 12, "A/O: Stage06 must track exactly 12 hostiles")
	assert(stage.hud.hostiles_counter_label.text == "HOSTILES: 12 / 12", "O: HUD must start at 12 / 12")
	assert(await _path_is_clear(stage, stage.get_route_a_waypoints()), "B/C: illuminated security road must be traversable")
	assert(await _path_is_clear(stage, stage.get_route_b_waypoints()), "B/D: dark maintenance route must be traversable")
	var opening_guard = stage.enemies_container.get_node("Enemy3D_1")
	var reserve_guard = stage.enemies_container.get_node("Enemy3D_2")
	assert(opening_guard.is_stage06_combat_active(), "Opening fix: Enemy3D_1 must be the sole active checkpoint guard")
	assert(not reserve_guard.is_stage06_combat_active(), "Opening fix: Enemy3D_2 must remain inactive at mission start")
	assert(stage.get_active_guard_count() == 1, "Opening fix: exactly one guard may engage at spawn")
	for _frame in 180:
		await physics_frame
	assert(not reserve_guard.is_stage06_combat_active(), "Opening fix: reserve guard must not join several seconds of checkpoint combat")
	opening_guard.take_damage(opening_guard.current_health)
	for _frame in 8:
		await physics_frame
	assert(not reserve_guard.is_stage06_combat_active(), "Opening fix: reserve guard must not instantly replace the eliminated opening guard")
	stage.player.global_position = Vector3(0, 0.2, 23)
	for _frame in 12:
		await physics_frame
	assert(reserve_guard.is_stage06_combat_active(), "Opening fix: reserve guard must activate after the security gate is crossed")

	# Continue through both routes with real Player physics after the opening test.
	for enemy in stage.enemies_container.get_children():
		enemy.set_physics_process(false)
	for target in stage.get_route_a_waypoints().slice(1):
		await _walk_to(stage, target)
	stage.player.global_position = Vector3(0, 0.2, 36)
	stage.player.velocity = Vector3.ZERO
	for _frame in 8:
		await physics_frame
	for target in stage.get_route_b_waypoints().slice(1):
		await _walk_to(stage, target)
	# Shared firing/ammo/reload remains intact inside the rebuilt scene.
	var weapon = stage.player.get_weapon_manager().get_current_weapon()
	var ammo_before: int = weapon.current_ammo
	stage.player._handle_fire_button(true)
	await physics_frame
	stage.player._handle_fire_button(false)
	assert(weapon.current_ammo < ammo_before, "Regression: Player firing must consume ammunition")
	var fired_ammo: int = weapon.current_ammo
	var reserve_before: int = weapon.reserve_ammo
	stage.player._reload_active_weapon()
	for _frame in 120:
		await physics_frame
	assert(weapon.current_ammo > fired_ammo and weapon.reserve_ammo < reserve_before, "Regression: reload must transfer reserve ammunition")

	# E: the paired searchlights genuinely sweep.
	var west_pivot: Node3D = stage._searchlight_pivots[0]
	var start_yaw := west_pivot.rotation.y
	for _frame in 20:
		await physics_frame
	assert(absf(west_pivot.rotation.y - start_yaw) > 0.005, "E: tower searchlight must sweep")

	# F: authored solid booth blocks searchlight/world vision.
	stage.player.global_position = Vector3(11, 0, 23.5)
	for _frame in 5:
		await physics_frame
	assert(not stage._has_world_los(Vector3(11, 6.5, 34)), "F: checkpoint booth must block detection ray")

	# G/H/I: use the real cone + world ray. Brief exposure is suspicious only;
	# sustained clear exposure reaches lockdown without releasing the whole base.
	stage.set_physics_process(false)
	var test_lamp: SpotLight3D = stage._searchlight_lamps[0]
	var illuminated_point: Vector3 = test_lamp.global_position + (-test_lamp.global_basis.z) * 16.0
	stage.player.global_position = Vector3(illuminated_point.x, 0, illuminated_point.z)
	for _frame in 5:
		await physics_frame
	assert(stage._is_player_inside_searchlight(test_lamp), "G/H: Player must be inside the real unobstructed searchlight cone")
	for _sample in 3:
		stage._poll_searchlight_exposure()
	assert(stage.get_security_state_name() == "SUSPICIOUS", "G: brief exposure must not instantly lock down")
	stage.searchlight_exposure = 0.0
	stage._set_security_state(stage.SecurityState.STEALTH)
	for _sample in 13:
		stage._poll_searchlight_exposure()
	assert(stage.get_security_state_name() == "LOCKDOWN", "H: confirmed searchlight exposure must trigger lockdown")
	assert(stage.get_active_guard_count() <= 6, "I/M: lockdown must respect six-guard cap")
	var inactive_count := 0
	for enemy in stage.enemies_container.get_children():
		if not enemy.is_dead and not enemy.is_stage06_combat_active():
			inactive_count += 1
	assert(inactive_count >= 6, "I: distant base defenders must remain gated")

	# J: a legitimately requested local group enters normal shared combat.
	stage._request_group_activation("maintenance", "regression local contact")
	for enemy in stage.enemies_container.get_children():
		if enemy.security_group == "maintenance" and stage.get_active_guard_count() <= 6:
			assert(enemy.local_mode in [enemy.LocalMode.HOLD, enemy.LocalMode.COMBAT], "J: local guards use controlled Stage06 modes")

	# K: a solid world barrier vetoes direct Enemy3D damage; clear space restores it.
	var shooter = stage.enemies_container.get_node("Enemy3D_5")
	shooter.set_physics_process(false)
	shooter.global_position = Vector3(0, 0, 5)
	stage.player.global_position = Vector3(0, 0, -5)
	shooter.target_player = stage.player
	var blocker: Node3D = stage._box(stage.get_node("Environment"), "RegressionLoSBlocker", Vector3(0, 1.2, 0), Vector3(3, 2.4, 0.8), "concrete")
	for _frame in 4:
		await physics_frame
	assert(not shooter.has_clear_stage06_fire_path(), "K: solid cover must block enemy damage")
	blocker.queue_free()
	for _frame in 4:
		await physics_frame
	assert(shooter.has_clear_stage06_fire_path(), "K: clear firing lane must permit normal combat")

	# L: all authored spawns are clear at torso height and supported by ground.
	stage.queue_free()
	await process_frame
	stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	for enemy in stage.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	for _frame in 12:
		await physics_frame
	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	for enemy in stage.enemies_container.get_children():
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, enemy.global_position + Vector3.UP * 0.95)
		query.collision_mask = 1
		var overlaps: Array[Dictionary] = stage.get_world_3d().direct_space_state.intersect_shape(query, 8)
		assert(overlaps.is_empty(), "L: %s must spawn outside static collision" % enemy.name)
		var ray := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 1.5, enemy.global_position + Vector3.DOWN * 0.5, 1)
		assert(not stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "L: %s must have supported ground" % enemy.name)

	# N: Stage06 retains approved shared OOB recovery and bounds.
	stage.last_safe_position = Vector3(0, 0, 36)
	stage._has_safe_position = true
	stage.player.global_position = Vector3(50, -9, 36)
	stage._recover_player_from_out_of_bounds()
	assert(stage.player.global_position.distance_to(Vector3(0, 0.2, 36)) < 0.25, "N: OOB recovery must return Player to last safe position")

	# O/P/Q: 12/12 completion, Stage07 unlock, and guarded next-mission flow.
	for enemy in stage.enemies_container.get_children():
		enemy.take_damage(enemy.current_health)
		await process_frame
	await process_frame
	assert(stage.targets_eliminated == 12 and stage.hud.hostiles_counter_label.text == "HOSTILES: 00 / 12", "O: HUD must reach 00 / 12")
	assert(stage.is_stage_finished and stage.summary_dialog.visible, "O/Q: final summary must appear")
	assert(stage.current_mission_score == 2000, "O: 12 kills, full health, no accuracy, and completion must score 2000")
	assert(profile.get_best_score(6) == 2000, "O: Stage06 best score must save before Campaign Complete")
	assert(profile.get_career_score() == 2000, "O: Stage06 best must feed Career Score")
	await process_frame
	assert(profile.get_highest_unlocked_stage() == 7, "P: legitimate Stage06 completion must unlock Stage07")
	assert(stage.summary_dialog.mission_status_label.text == "MISSION COMPLETE", "Q: Stage06 must not claim the campaign is complete")
	assert(stage.summary_dialog.next_btn.visible, "P: unlocked Stage07 must expose NEXT MISSION")
	assert(stage.summary_dialog.retry_btn.text == "REPLAY STAGE06", "S: debrief must retain REPLAY STAGE06")
	assert(stage.summary_dialog.menu_btn.text == "RETURN TO HQ", "R: debrief must retain RETURN TO HQ")
	var manager = root.get_node("StageManager")
	manager.set_current_stage_id(6)
	stage._on_next_stage_requested()
	for _frame in 25:
		await process_frame
	assert(manager.get_current_stage_id() == 7 and current_scene.name == "Stage07", "P: unlocked Stage07 loads when NEXT MISSION is requested")

	# S: replay uses the shared lifecycle but returns to Stage06.
	manager.set_current_stage_id(6)
	assert(manager.load_stage(6), "Reload Stage06 for replay testing")
	for _frame in 25:
		await process_frame
	stage = current_scene
	stage._on_retry_stage_requested()
	for _frame in 25:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage06", "S: REPLAY STAGE06 must reload Stage06")
	assert(current_scene.total_targets == 12, "S: replayed Stage06 must restore 12 hostiles")

	# Regression: Stage05 progression still resolves to Stage06 without modifying Stage05.
	manager.set_current_stage_id(5)
	assert(manager.load_next_stage(), "Regression: Stage05 NEXT MISSION request must succeed")
	for _frame in 25:
		await process_frame
	assert(current_scene != null and current_scene.name == "Stage06", "Regression: Stage05 must still advance to Stage06")

	# R: RETURN TO HQ selects the now-unlocked next mission.
	current_scene._on_main_menu_requested()
	for _frame in 25:
		await process_frame
	assert(current_scene != null and current_scene.name == "OperationsHQ", "R: RETURN TO HQ must load Operations HQ")
	assert(current_scene.get_selected_stage_id() == 7, "R: Stage06 return must select unlocked Stage07")

	_cleanup_score_profile()
	print("[Stage06SecurityRegression] PASS A-S: routes, searchlights, LoS, local activation, 12/12, score save, OOB, Stage07 unlock/debrief, replay, HQ selection, Stage05 progression")
	quit(0)

func _cleanup_score_profile() -> void:
	if FileAccess.file_exists(SCORE_TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORE_TEST_SAVE))

func _path_is_clear(stage: Node, waypoints: Array[Vector3]) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	for point in waypoints:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.95)
		query.collision_mask = 1
		query.exclude = [stage.player.get_rid()]
		var overlaps: Array[Dictionary] = stage.get_world_3d().direct_space_state.intersect_shape(query, 8)
		if not overlaps.is_empty():
			print("[Stage06SecurityRegression] Blocked waypoint %s by %s" % [point, overlaps])
			return false
	return true

func _walk_to(stage: Node, target: Vector3) -> void:
	var player = stage.player
	Input.action_press("move_forward")
	var reached := false
	for _frame in 240:
		var flat_target := Vector3(target.x, player.global_position.y, target.z)
		if player.global_position.distance_squared_to(flat_target) > 0.01:
			player.look_at(flat_target, Vector3.UP)
		await physics_frame
		var offset: Vector3 = target - player.global_position
		offset.y = 0.0
		if offset.length() < 0.9:
			reached = true
			break
	Input.action_release("move_forward")
	assert(reached, "Player route traversal stopped before %s at %s" % [target, player.global_position])
