extends SceneTree
## weapon_facing_dump.gd
## Spawns Enemy3D, forces ATTACK state, plays Idle,
## then after several frames dumps:
##   - Enemy forward direction (world -Z)
##   - Weapon attachment world transform
##   - Muzzle flash world position
##   - Barrel direction vector and angles (yaw + pitch)
##   - What pivot rotation needed to make barrel face enemy forward

func _init() -> void:
	await process_frame

	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	if not enemy_scene:
		print("[WDUMP] ERROR: Could not load Enemy3D.tscn")
		quit()
		return

	var enemy: Node3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3.ZERO
	# Enemy faces -Z by default (no rotation)

	await process_frame
	await process_frame
	await process_frame

	# Force ATTACK state
	if "current_state" in enemy:
		enemy.current_state = 2  # State.ATTACK

	# Run 60 frames so AnimationPlayer and lean both settle
	for i in 60:
		await process_frame

	print("")
	print("================================================================")
	print("  ENEMY WEAPON FACING ANALYSIS")
	print("================================================================")

	var soldier_model: Node3D = enemy.get_node_or_null("SoldierModel")
	if not soldier_model:
		print("[WDUMP] ERROR: No SoldierModel")
		quit()
		return

	var skel: Skeleton3D = soldier_model.find_child("Skeleton3D", true, false)
	if not skel:
		print("[WDUMP] ERROR: No Skeleton3D")
		quit()
		return

	# Enemy facing
	var enemy_forward: Vector3 = -enemy.global_transform.basis.z
	print("  Enemy global_position: %s" % str(enemy.global_position))
	print("  Enemy forward dir (world -Z of enemy): (%.3f, %.3f, %.3f)" % [enemy_forward.x, enemy_forward.y, enemy_forward.z])

	# SoldierModel lean
	var sm_rot: Vector3 = soldier_model.rotation_degrees
	print("  SoldierModel rotation_degrees: (%.2f, %.2f, %.2f)" % [sm_rot.x, sm_rot.y, sm_rot.z])

	# BoneAttachment transform
	var attach: BoneAttachment3D = skel.find_child("RightHandWeaponAttachment", true, false)
	if attach:
		var att_world: Transform3D = attach.global_transform
		var att_euler: Vector3 = att_world.basis.get_euler(EULER_ORDER_XYZ) * (180.0 / PI)
		print("  BoneAttachment3D world pos: %s" % str(att_world.origin))
		print("  BoneAttachment3D world euler XYZ: (%.2f, %.2f, %.2f)" % [att_euler.x, att_euler.y, att_euler.z])
	else:
		print("  [WDUMP] No BoneAttachment3D found!")

	# Weapon node
	var weapon: Node3D = null
	if attach:
		weapon = attach.find_child("EnemyRifle", true, false)
	if not weapon:
		weapon = enemy.find_child("EnemyRifle", true, false)

	if weapon:
		var w_rot: Vector3 = weapon.rotation_degrees
		var w_world: Transform3D = weapon.global_transform
		var w_euler: Vector3 = w_world.basis.get_euler(EULER_ORDER_XYZ) * (180.0 / PI)
		print("  EnemyRifle local rotation_degrees: (%.2f, %.2f, %.2f)" % [w_rot.x, w_rot.y, w_rot.z])
		print("  EnemyRifle world pos: %s" % str(w_world.origin))
		print("  EnemyRifle world euler XYZ: (%.2f, %.2f, %.2f)" % [w_euler.x, w_euler.y, w_euler.z])

		# The rifle barrel in the GLB: check which axis is "forward" of the GLB barrel
		# After rotation (0,90,90), the barrel direction in world...
		# GLB barrel = model's local -Z. After rots, -Z becomes:
		var rifle_minus_z_world: Vector3 = -w_world.basis.z
		var rifle_plus_z_world: Vector3 = w_world.basis.z
		var rifle_plus_x_world: Vector3 = w_world.basis.x
		var rifle_minus_x_world: Vector3 = -w_world.basis.x
		print("")
		print("  Rifle -Z world (barrel forward?): (%.3f, %.3f, %.3f)  pitch=%.1f°  yaw=%.1f°" % [
			rifle_minus_z_world.x, rifle_minus_z_world.y, rifle_minus_z_world.z,
			rad_to_deg(asin(clampf(rifle_minus_z_world.y, -1.0, 1.0))),
			rad_to_deg(atan2(-rifle_minus_z_world.x, -rifle_minus_z_world.z))
		])
		print("  Rifle +X world (barrel alt?):     (%.3f, %.3f, %.3f)  pitch=%.1f°  yaw=%.1f°" % [
			rifle_plus_x_world.x, rifle_plus_x_world.y, rifle_plus_x_world.z,
			rad_to_deg(asin(clampf(rifle_plus_x_world.y, -1.0, 1.0))),
			rad_to_deg(atan2(-rifle_plus_x_world.x, -rifle_plus_x_world.z))
		])
		print("  Rifle -X world:                   (%.3f, %.3f, %.3f)  pitch=%.1f°" % [
			rifle_minus_x_world.x, rifle_minus_x_world.y, rifle_minus_x_world.z,
			rad_to_deg(asin(clampf(rifle_minus_x_world.y, -1.0, 1.0)))
		])

		print("")
		print("  Enemy forward: (%.3f, %.3f, %.3f)" % [enemy_forward.x, enemy_forward.y, enemy_forward.z])
		print("")
		# The correct barrel should match enemy_forward at y=0 (horizontal)
		# target = Vector3(enemy_forward.x, 0, enemy_forward.z).normalized()
		var target_barrel: Vector3 = Vector3(enemy_forward.x, 0.0, enemy_forward.z).normalized()
		print("  TARGET barrel direction (horizontal forward): (%.3f, %.3f, %.3f)" % [target_barrel.x, target_barrel.y, target_barrel.z])
		print("")

		# For each candidate barrel axis, compute the angle to target and the pivot correction
		for candidate_name in ["-Z", "+X", "+Z", "-X"]:
			var candidate: Vector3
			match candidate_name:
				"-Z": candidate = -w_world.basis.z
				"+X": candidate = w_world.basis.x
				"+Z": candidate = w_world.basis.z
				"-X": candidate = -w_world.basis.x
			var angle_to_target := rad_to_deg(candidate.angle_to(target_barrel))
			print("  Rifle %s → angle to target barrel: %.1f°" % [candidate_name, angle_to_target])
	else:
		print("  [WDUMP] No EnemyRifle found!")

	# Muzzle flash
	var muzzle: Node3D = enemy.find_child("EnemyMuzzleFlash", true, false)
	if muzzle:
		print("")
		print("  MuzzleFlash world pos: %s" % str(muzzle.global_position))
		print("  MuzzleFlash - enemy chest offset: %s" % str(muzzle.global_position - (enemy.global_position + Vector3(0, 1.2, 0))))

	print("")
	print("================================================================")
	quit()
