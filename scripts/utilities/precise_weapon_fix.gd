extends SceneTree
## precise_weapon_fix.gd
## Uses normalized bone attachment basis to find exact rifle rotation.
## The skeleton is at ~0.01 scale, so we must normalize before computing directions.

func _init() -> void:
	await process_frame

	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	if not enemy_scene:
		print("[FIX] ERROR: Could not load Enemy3D.tscn"); quit(); return

	var enemy: Node3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3.ZERO
	for _i in 5: await process_frame

	# Force ATTACK state, let animations settle
	if "current_state" in enemy: enemy.current_state = 2
	for _i in 60: await process_frame

	var attach: BoneAttachment3D = enemy.find_child("RightHandWeaponAttachment", true, false)
	var weapon: Node3D = enemy.find_child("EnemyRifle", true, false)
	if not attach or not weapon:
		print("[FIX] ERROR: missing attach or weapon"); quit(); return

	# NORMALIZED attachment world basis (removes the ~0.01 scale)
	var raw_basis: Basis = attach.global_transform.basis
	var att_basis := Basis(
		raw_basis.x.normalized(),
		raw_basis.y.normalized(),
		raw_basis.z.normalized()
	)

	print("=================================================================")
	print("  ATTACHMENT WORLD BASIS (normalized unit vectors)")
	print("=================================================================")
	print("  X (right):   (%.4f, %.4f, %.4f)" % [att_basis.x.x, att_basis.x.y, att_basis.x.z])
	print("  Y (up):      (%.4f, %.4f, %.4f)" % [att_basis.y.x, att_basis.y.y, att_basis.y.z])
	print("  Z (forward): (%.4f, %.4f, %.4f)" % [att_basis.z.x, att_basis.z.y, att_basis.z.z])
	print("")

	# Enemy faces -Z
	var target: Vector3 = Vector3(0.0, 0.0, -1.0)

	# BRUTE FORCE: sweep ALL three angles independently in 5° steps
	# to find rotation_degrees that makes rifle +Y point at target
	# (Rifle AABB longest axis = Z, but let's test all 6 axes)
	var best_rot := Vector3.ZERO
	var best_err := 999.0
	var best_axis := "?"

	for barrel_name in ["+Y", "-Y", "+Z", "-Z", "+X", "-X"]:
		for xd in range(-180, 185, 5):
			for yd in range(85, 96, 5):    # keep Y near 90 (only sweep ±5)
				for zd in range(85, 96, 5): # keep Z near 90 (only sweep ±5)
					var test_rot := Basis.from_euler(Vector3(
						deg_to_rad(float(xd)), deg_to_rad(float(yd)), deg_to_rad(float(zd))
					))
					var world_rot: Basis = att_basis * test_rot
					var candidate: Vector3
					match barrel_name:
						"+Y": candidate = world_rot.y
						"-Y": candidate = -world_rot.y
						"+Z": candidate = world_rot.z
						"-Z": candidate = -world_rot.z
						"+X": candidate = world_rot.x
						"-X": candidate = -world_rot.x
					var err := candidate.angle_to(target)
					if err < best_err:
						best_err = err
						best_rot = Vector3(float(xd), float(yd), float(zd))
						best_axis = barrel_name

	print("  SWEEP RESULT (5° steps, Y&Z fixed near 90):")
	print("  Best rotation_degrees = (%.0f, %.0f, %.0f)" % [best_rot.x, best_rot.y, best_rot.z])
	print("  Barrel axis = %s,  Error = %.2f°" % [best_axis, rad_to_deg(best_err)])
	print("")

	# Now refine with 1° steps around best
	var best2_rot := best_rot
	var best2_err := best_err
	var best2_axis := best_axis
	for barrel_name in [best_axis]:
		for xd in range(int(best_rot.x) - 10, int(best_rot.x) + 11, 1):
			for yd in range(int(best_rot.y) - 5, int(best_rot.y) + 6, 1):
				for zd in range(int(best_rot.z) - 5, int(best_rot.z) + 6, 1):
					var test_rot := Basis.from_euler(Vector3(
						deg_to_rad(float(xd)), deg_to_rad(float(yd)), deg_to_rad(float(zd))
					))
					var world_rot: Basis = att_basis * test_rot
					var candidate: Vector3
					match barrel_name:
						"+Y": candidate = world_rot.y
						"-Y": candidate = -world_rot.y
						"+Z": candidate = world_rot.z
						"-Z": candidate = -world_rot.z
						"+X": candidate = world_rot.x
						"-X": candidate = -world_rot.x
					var err := candidate.angle_to(target)
					if err < best2_err:
						best2_err = err
						best2_rot = Vector3(float(xd), float(yd), float(zd))
						best2_axis = barrel_name

	print("  REFINED RESULT (1° steps):")
	print("  Best rotation_degrees = (%.0f, %.0f, %.0f)" % [best2_rot.x, best2_rot.y, best2_rot.z])
	print("  Barrel axis = %s,  Error = %.3f°" % [best2_axis, rad_to_deg(best2_err)])
	print("")

	# Apply and verify
	weapon.rotation_degrees = best2_rot
	for _i in 3: await process_frame
	var w_world := weapon.global_transform.basis
	var barrel_vec: Vector3
	match best2_axis:
		"+Y": barrel_vec = w_world.y.normalized()
		"-Y": barrel_vec = -w_world.y.normalized()
		"+Z": barrel_vec = w_world.z.normalized()
		"-Z": barrel_vec = -w_world.z.normalized()
		"+X": barrel_vec = w_world.x.normalized()
		"-X": barrel_vec = -w_world.x.normalized()

	print("  VERIFIED after applying rotation:")
	print("  Barrel world dir: (%.4f, %.4f, %.4f)" % [barrel_vec.x, barrel_vec.y, barrel_vec.z])
	print("  Barrel pitch: %.2f°" % rad_to_deg(asin(clampf(barrel_vec.y, -1.0, 1.0))))
	print("  Barrel yaw from -Z: %.2f°" % rad_to_deg(atan2(barrel_vec.x, -barrel_vec.z)))
	print("  Angle to target: %.3f°" % rad_to_deg(barrel_vec.angle_to(target)))

	# Muzzle position check
	var muzzle: Node3D = enemy.find_child("EnemyMuzzleFlash", true, false)
	if muzzle:
		print("")
		print("  Muzzle world Y: %.3f (enemy base Y=%.3f, height above base=%.3fm)" % [
			muzzle.global_position.y,
			enemy.global_position.y,
			muzzle.global_position.y - enemy.global_position.y
		])

	print("=================================================================")
	print("  ACTION: Set enemy_weapon.rotation_degrees = Vector3(%d, %d, %d)" % [
		int(best2_rot.x), int(best2_rot.y), int(best2_rot.z)
	])
	print("=================================================================")
	quit()
