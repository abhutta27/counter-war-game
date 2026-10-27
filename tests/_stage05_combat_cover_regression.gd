extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage05.tscn")
const EXPECTED_POSITIONS := [
	Vector3(-8,0,39), Vector3(14,0,31), Vector3(-15,4,2), Vector3(-3,4,-4),
	Vector3(15,4,-8), Vector3(21,4,-7), Vector3(18,8,-44), Vector3(6,8,-41),
	Vector3(13,8,-48), Vector3(-14,8,-38), Vector3(-7,8,-48),
	Vector3(-12,13,-74), Vector3(0,13,-79), Vector3(14,13,-84),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	var player = stage.player
	player.max_health = 5000
	player.current_health = 5000
	assert(stage.enemies_container.get_child_count() == 14, "Stage05 must retain exactly 14 enemies")
	for index in EXPECTED_POSITIONS.size():
		var authored_enemy = stage.enemies_container.get_child(index)
		authored_enemy.set_physics_process(false)
		authored_enemy.attack_damage = 0
		assert(authored_enemy.position.distance_to(EXPECTED_POSITIONS[index]) < 0.01, "%s position must remain unchanged" % authored_enemy.name)
		assert(authored_enemy.has_method("has_clear_stage05_fire_path"), "%s must use Stage05-local firing LoS" % authored_enemy.name)
	for _frame in 5:
		await process_frame
	var shooter = stage.enemies_container.get_node("Enemy3D_1")
	shooter.attack_damage = 7
	shooter.target_player = player
	shooter._change_state(2) # Enemy3D.State.ATTACK

	# A: unobstructed muzzle-to-torso path still produces normal damage.
	await _place_pair(shooter, player, Vector3(0,13,-70), Vector3(0,13,-65))
	assert(shooter.has_clear_stage05_fire_path(), "Test A: exposed Player must have clear firing LoS")
	await _expect_shot_damage(shooter, player, true, "Test A exposed Player")

	# B: the large SummitRock blocks both the ray and the actual damage event.
	await _place_pair(shooter, player, Vector3(-20,13,-76), Vector3(-20,13,-64))
	assert(not shooter.has_clear_stage05_fire_path(), "Test B: SummitRock must block firing LoS")
	await _expect_shot_damage(shooter, player, false, "Test B large rock cover")

	# C: command bunker body is solid cover; stepping to its side restores fire.
	await _place_pair(shooter, player, Vector3(-16,13,-90), Vector3(-16,13,-74))
	assert(not shooter.has_clear_stage05_fire_path(), "Test C: bunker wall must block firing LoS")
	await _expect_shot_damage(shooter, player, false, "Test C bunker cover")
	await _place_pair(shooter, player, Vector3(0,13,-70), Vector3(0,13,-65))
	assert(shooter.has_clear_stage05_fire_path(), "Test C: leaving bunker cover must restore LoS")
	await _expect_shot_damage(shooter, player, true, "Test C exposed after bunker")

	# D: Service Tunnel west wall blocks the firing path; same-side exposure works.
	await _place_pair(shooter, player, Vector3(-20,8,-24), Vector3(-12,8,-24))
	assert(not shooter.has_clear_stage05_fire_path(), "Test D: Service Tunnel wall must block firing LoS")
	await _expect_shot_damage(shooter, player, false, "Test D tunnel cover")
	await _place_pair(shooter, player, Vector3(0,13,-70), Vector3(0,13,-65))
	assert(shooter.has_clear_stage05_fire_path(), "Test D: same-side tunnel exposure must restore LoS")
	await _expect_shot_damage(shooter, player, true, "Test D exposed beside tunnel")

	# E: repeated hide/peek cycles never stick in either firing state.
	for cycle in 3:
		await _place_pair(shooter, player, Vector3(-16,13,-90), Vector3(-16,13,-74))
		await _expect_shot_damage(shooter, player, false, "Test E blocked cycle %d" % cycle)
		await _place_pair(shooter, player, Vector3(0,13,-70), Vector3(0,13,-65))
		await _expect_shot_damage(shooter, player, true, "Test E exposed cycle %d" % cycle)

	assert(shooter.current_state == 2, "Blocked LoS must not force the enemy out of combat")

	# G: the approved shared fall recovery still operates in the Stage05 scene.
	var recoveries: Array = []
	stage.player_recovered_from_out_of_bounds.connect(func(from: Vector3, to: Vector3): recoveries.append([from, to]))
	player.global_position = Vector3(0, stage.out_of_bounds_y - 3.0, 52)
	player.velocity = Vector3(0, -25, 0)
	for _frame in 8:
		await process_frame
	assert(recoveries.size() == 1, "Test G: Stage05 fall recovery must still trigger")
	assert(player.global_position.y > stage.out_of_bounds_y, "Test G: recovery must return Player above Stage05 threshold")

	# F: a fresh instance proves Observer 7 still positively relays to 8/9.
	stage.queue_free()
	await process_frame
	var relay_stage = STAGE_SCENE.instantiate()
	root.add_child(relay_stage)
	current_scene = relay_stage
	for _frame in 20:
		await physics_frame
	relay_stage.player.max_health = 5000
	relay_stage.player.current_health = 5000
	for enemy in relay_stage.enemies_container.get_children():
		enemy.attack_damage = 0
	var observer7 = relay_stage.enemies_container.get_node("Enemy3D_7")
	relay_stage.player.global_position = Vector3(18,8,-40)
	observer7.look_at(relay_stage.player.global_position, Vector3.UP)
	for _frame in 2:
		await physics_frame
	assert(relay_stage._has_line_of_sight(observer7), "Test F setup must give Observer 7 a clear route")
	for _frame in 35:
		await physics_frame
	assert(relay_stage.has_observer_relayed("Enemy3D_7"), "Test F: Observer 7 clear contact must still relay")
	assert(relay_stage.is_guard_active("Enemy3D_8") and relay_stage.is_guard_active("Enemy3D_9"), "Test F: Observer 7 must still activate only its linked road defenders")

	print("[Stage05CombatCover] PASS: A-E cover, F Observer 7 relay, G fall recovery, combat state, 14 positions")
	quit(0)

func _place_pair(shooter, player, shooter_position: Vector3, player_position: Vector3) -> void:
	shooter.global_position = shooter_position
	shooter.velocity = Vector3.ZERO
	shooter.reset_physics_interpolation()
	player.global_position = player_position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var flat_target := player_position
	flat_target.y = shooter_position.y
	shooter.look_at(flat_target, Vector3.UP)
	await physics_frame
	await physics_frame
	await process_frame

func _expect_shot_damage(shooter, player, should_damage: bool, label: String) -> void:
	var health_before: int = player.current_health
	shooter._enemy_shoot()
	await process_frame
	if should_damage:
		assert(player.current_health == health_before - shooter.attack_damage, "%s must damage an exposed Player" % label)
	else:
		assert(player.current_health == health_before, "%s must not damage through solid geometry" % label)
