extends SceneTree
## compare_enemy_states_anims.gd
## Compares CHASE (running) vs ATTACK (close to player) states:
## - Active animation name
## - Bone transforms for right arm, forearm, hand, left arm, forearm, hand
## - Weapon attachment global position and rotation
## - Barrel direction

func _init() -> void:
	await process_frame
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	for i in 15: await process_frame

	var player = level.get_node("Player3D")
	var enemy = level.get_node("Enemies/Enemy3D_2")
	var anim_player: AnimationPlayer = enemy.anim_player
	var weapon = enemy.enemy_weapon
	var flash = enemy.enemy_muzzle_flash
	var soldier = enemy.soldier_model
	var skel: Skeleton3D = soldier.find_child("Skeleton3D", true, false)

	print("=================================================================")
	print("  COMPARING ENEMY RUNNING (CHASE) vs COMBAT (ATTACK)")
	print("=================================================================")

	# 1. TEST CHASE STATE (Enemy chasing player from distance)
	enemy.global_position = Vector3(0.0, 0.0, -20.0)
	player.global_position = Vector3(0.0, 0.0, 0.0)
	enemy.current_state = Enemy3D.State.CHASE
	enemy._physics_process(0.016)
	for i in 20: await process_frame

	print("\n--- [STATE 1: CHASE / RUNNING] ---")
	print("State: ", enemy.current_state, " (Expect 1 = CHASE)")
	print("Playing Animation: '", anim_player.current_animation, "'")
	print("Enemy Velocity: ", enemy.velocity)
	_dump_skeleton_and_weapon(skel, weapon, flash, enemy)

	# 2. TEST ATTACK STATE (Enemy within combat distance 8.5m)
	enemy.global_position = Vector3(0.0, 0.0, -5.0)
	player.global_position = Vector3(0.0, 0.0, 0.0)
	enemy.current_state = Enemy3D.State.ATTACK
	enemy._physics_process(0.016)
	for i in 20: await process_frame

	print("\n--- [STATE 2: ATTACK / CLOSE TO PLAYER] ---")
	print("State: ", enemy.current_state, " (Expect 2 = ATTACK)")
	print("Playing Animation: '", anim_player.current_animation, "'")
	print("Enemy Velocity: ", enemy.velocity)
	_dump_skeleton_and_weapon(skel, weapon, flash, enemy)

	print("=================================================================")
	quit()

func _dump_skeleton_and_weapon(skel: Skeleton3D, weapon: Node3D, flash: Node3D, enemy: Node3D) -> void:
	var r_shoulder = skel.find_bone("mixamorig_RightShoulder")
	var r_arm = skel.find_bone("mixamorig_RightArm")
	var r_forearm = skel.find_bone("mixamorig_RightForeArm")
	var r_hand = skel.find_bone("mixamorig_RightHand")

	var l_shoulder = skel.find_bone("mixamorig_LeftShoulder")
	var l_arm = skel.find_bone("mixamorig_LeftArm")
	var l_forearm = skel.find_bone("mixamorig_LeftForeArm")
	var l_hand = skel.find_bone("mixamorig_LeftHand")

	var rh_world = skel.global_transform * skel.get_bone_global_pose(r_hand).origin
	var lh_world = skel.global_transform * skel.get_bone_global_pose(l_hand).origin

	var rh_rot = (skel.global_transform * skel.get_bone_global_pose(r_hand)).basis.get_euler() * (180.0 / PI)
	var lh_rot = (skel.global_transform * skel.get_bone_global_pose(l_hand)).basis.get_euler() * (180.0 / PI)

	print("  Right Hand World Pos: ", rh_world, " | Euler Deg: ", rh_rot)
	print("  Left Hand World Pos:  ", lh_world, " | Euler Deg: ", lh_rot)
	print("  Distance Between Hands: ", rh_world.distance_to(lh_world), "m")

	if weapon:
		print("  Weapon Global Pos: ", weapon.global_position)
		print("  Weapon Global Rot: ", weapon.global_rotation_degrees)
		var barrel_vec = (flash.global_position - weapon.global_position).normalized()
		var pitch = rad_to_deg(asin(clampf(barrel_vec.y, -1.0, 1.0)))
		print("  Muzzle Global Pos: ", flash.global_position)
		print("  Barrel Direction: ", barrel_vec, " (Pitch: ", pitch, " deg)")
