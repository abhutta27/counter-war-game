extends SceneTree

func _init() -> void:
	await process_frame
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	var enemy: Enemy3D = enemy_scene.instantiate() as Enemy3D
	root.add_child(enemy)
	enemy.global_position = Vector3(0, 0, 8.5)
	
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayer"
	dummy_player.add_to_group("player")
	dummy_player.set("current_health", 100)
	dummy_player.set("is_active", true)
	root.add_child(dummy_player)
	dummy_player.global_position = Vector3(0, 0, 0)
	
	enemy.player_ref = dummy_player
	enemy._change_state(Enemy3D.State.ATTACK)
	
	# Let AnimationPlayer run 10 frames
	for i in 10:
		await process_frame
		
	# Now call _apply_armed_combat_pose
	enemy._apply_armed_combat_pose()
	
	var weapon = enemy.enemy_weapon
	var chest_target = dummy_player.global_position + Vector3(0.0, 1.2, 0.0)
	var dir_to_chest = (chest_target - weapon.global_position).normalized()
	var weapon_fwd = -weapon.global_transform.basis.z.normalized()
	var aim_dot = weapon_fwd.dot(dir_to_chest)
	print("Weapon forward immediately after _apply_armed_combat_pose: ", weapon_fwd)
	print("Aim dot: ", aim_dot)
	
	quit(0)
