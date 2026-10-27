extends SceneTree
## test_enemy_orientation_and_aim.gd
## Automated test suite for enemy orientation, aiming pose, and clean state resets.

func _init() -> void:
	await process_frame
	print("================================================================")
	print("  TESTING ENEMY MODEL ORIENTATION & AIMING POSE (GODOT 4)")
	print("================================================================")
	
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	assert(enemy_scene != null, "Enemy3D.tscn must load successfully")
	var enemy: Enemy3D = enemy_scene.instantiate() as Enemy3D
	root.add_child(enemy)
	enemy.global_position = Vector3(0, 0, 8.5)
	
	# Create a dummy player in GROUP_PLAYER
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayer"
	dummy_player.add_to_group("player")
	dummy_player.set("current_health", 100)
	dummy_player.set("is_active", true)
	root.add_child(dummy_player)
	dummy_player.global_position = Vector3(0, 0, 0)
	
	# Settle
	for i in 10:
		await process_frame
		
	# --- TEST 1: Enter ATTACK State & Verify Orientation ---
	print("\n[TEST 1] Verifying enemy facing orientation in ATTACK state...")
	enemy._change_state(Enemy3D.State.ATTACK)
	enemy._physics_process(0.016)
	await process_frame
	
	var enemy_forward = -enemy.global_transform.basis.z.normalized()
	var to_player_horiz = Vector3(dummy_player.global_position.x - enemy.global_position.x, 0.0, dummy_player.global_position.z - enemy.global_position.z).normalized()
	var face_dot = enemy_forward.dot(to_player_horiz)
	print("  Enemy forward: ", enemy_forward)
	print("  Dir to player: ", to_player_horiz)
	print("  Facing dot product (1.0 = facing player, -1.0 = back to player): ", face_dot)
	assert(face_dot > 0.99, "Enemy MUST face towards player, NOT showing back!")
	print("  -> TEST 1 PASSED: Enemy correctly faces towards player without inverted 180 deg rotation!")
	
	# --- TEST 2: Verify Procedural Arm Transforms ---
	print("\n[TEST 2] Verifying procedural arm bone transforms during ATTACK...")
	var skel: Skeleton3D = enemy.skeleton_node
	assert(skel != null, "Skeleton node must be valid")
	var r_arm = skel.find_bone("mixamorig_RightArm")
	var l_arm = skel.find_bone("mixamorig_LeftArm")
	assert(r_arm != -1 and l_arm != -1, "Arm bones must exist in skeleton")
	
	var r_rot = skel.get_bone_pose_rotation(r_arm)
	var l_rot = skel.get_bone_pose_rotation(l_arm)
	print("  RightArm pose rotation: ", r_rot)
	print("  LeftArm pose rotation: ", l_rot)
	assert(not r_rot.is_equal_approx(Quaternion.IDENTITY), "RightArm must have active aim pose")
	assert(not l_rot.is_equal_approx(Quaternion.IDENTITY), "LeftArm must have active aim pose")
	print("  -> TEST 2 PASSED: Both arms procedurally posed for combat!")
	
	# --- TEST 3: Verify Weapon Aiming at Chest Level ---
	print("\n[TEST 3] Verifying weapon forward points at player chest level...")
	var weapon = enemy.enemy_weapon
	assert(weapon != null, "Weapon node must exist")
	var chest_target = dummy_player.global_position + Vector3(0.0, 1.2, 0.0)
	var dir_to_chest = (chest_target - weapon.global_position).normalized()
	var weapon_fwd = -weapon.global_transform.basis.z.normalized()
	var aim_dot = weapon_fwd.dot(dir_to_chest)
	print("  Weapon forward: ", weapon_fwd)
	print("  Dir to chest:   ", dir_to_chest)
	print("  Aim dot product: ", aim_dot)
	assert(aim_dot > 0.95, "Weapon forward must align with direction to player's chest!")
	print("  -> TEST 3 PASSED: Weapon points directly at player chest level!")
	
	# --- TEST 4: Verify Clean Reset on Transition to CHASE ---
	print("\n[TEST 4] Verifying clean reset when transitioning ATTACK -> CHASE...")
	enemy._change_state(Enemy3D.State.CHASE)
	var r_rot_chase = skel.get_bone_pose_rotation(r_arm)
	var l_rot_chase = skel.get_bone_pose_rotation(l_arm)
	print("  RightArm after CHASE transition: ", r_rot_chase)
	print("  LeftArm after CHASE transition: ", l_rot_chase)
	assert(r_rot_chase.is_equal_approx(Quaternion.IDENTITY), "RightArm must reset to IDENTITY on exiting ATTACK")
	assert(l_rot_chase.is_equal_approx(Quaternion.IDENTITY), "LeftArm must reset to IDENTITY on exiting ATTACK")
	print("  -> TEST 4 PASSED: Bones reset cleanly on transition to CHASE!")
	
	# --- TEST 5: Verify Clean Reset on Transition to IDLE ---
	print("\n[TEST 5] Verifying clean reset when transitioning ATTACK -> IDLE...")
	enemy._change_state(Enemy3D.State.ATTACK)
	enemy._physics_process(0.016)
	assert(not skel.get_bone_pose_rotation(r_arm).is_equal_approx(Quaternion.IDENTITY), "Aim pose reapplied")
	enemy._change_state(Enemy3D.State.IDLE)
	assert(skel.get_bone_pose_rotation(r_arm).is_equal_approx(Quaternion.IDENTITY), "RightArm reset to IDENTITY")
	assert(skel.get_bone_pose_rotation(l_arm).is_equal_approx(Quaternion.IDENTITY), "LeftArm reset to IDENTITY")
	print("  -> TEST 5 PASSED: Bones reset cleanly on transition to IDLE!")
	
	# --- TEST 6: Verify Clean Reset on Death ---
	print("\n[TEST 6] Verifying clean reset on death...")
	enemy._change_state(Enemy3D.State.ATTACK)
	enemy._physics_process(0.016)
	enemy.take_damage(200) # lethal
	assert(skel.get_bone_pose_rotation(r_arm).is_equal_approx(Quaternion.IDENTITY), "RightArm reset to IDENTITY on death")
	assert(skel.get_bone_pose_rotation(l_arm).is_equal_approx(Quaternion.IDENTITY), "LeftArm reset to IDENTITY on death")
	print("  -> TEST 6 PASSED: Bones reset cleanly on death!")
	
	dummy_player.queue_free()
	enemy.queue_free()
	print("\n================================================================")
	print("  ALL 6 ORIENTATION & AIMING POSE TESTS PASSED PERFECTLY!")
	print("================================================================")
	quit(0)
