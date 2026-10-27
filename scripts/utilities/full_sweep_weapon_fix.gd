extends SceneTree
## full_sweep_weapon_fix.gd  
## Full unconstrained sweep: X from -180 to +180, Y from 0 to 179, Z from 0 to 179
## in 10° coarse steps, then 1° fine steps around best.
## Finds the rotation_degrees that minimizes barrel angle to enemy forward (0,0,-1).

func _init() -> void:
	await process_frame

	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	if not enemy_scene: print("[FULL] ERROR"); quit(); return

	var enemy: Node3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3.ZERO
	for _i in 5: await process_frame
	if "current_state" in enemy: enemy.current_state = 2
	for _i in 60: await process_frame

	var attach: BoneAttachment3D = enemy.find_child("RightHandWeaponAttachment", true, false)
	var weapon: Node3D = enemy.find_child("EnemyRifle", true, false)
	if not attach or not weapon: print("[FULL] ERROR: missing nodes"); quit(); return

	var raw_basis: Basis = attach.global_transform.basis
	var att_basis := Basis(
		raw_basis.x.normalized(), raw_basis.y.normalized(), raw_basis.z.normalized()
	)

	var target: Vector3 = Vector3(0.0, 0.0, -1.0)

	print("=================================================================")
	print("  FULL UNCONSTRAINED SWEEP (10° coarse)")
	print("=================================================================")

	# COARSE: all axes, 10° steps
	var best_rot := Vector3.ZERO
	var best_err := 999.0
	var best_axis := "?"

	# Test both +Y and -Y (the GLB AABB longest axis = Z, but barrel tip along model)
	# We already know barrel = +Y from previous sweep. Also test +Z and -Z.
	for barrel_name in ["+Y", "-Y", "+Z", "-Z", "+X", "-X"]:
		for xd in range(-180, 181, 10):
			for yd in range(0, 180, 10):
				for zd in range(0, 180, 10):
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

	print("  Coarse best: rot=(%d, %d, %d)  axis=%s  err=%.2f°" % [
		int(best_rot.x), int(best_rot.y), int(best_rot.z), best_axis, rad_to_deg(best_err)
	])

	# FINE: 1° steps around coarse best (±15° window)
	var fine_best_rot := best_rot
	var fine_best_err := best_err
	for xd in range(int(best_rot.x) - 15, int(best_rot.x) + 16, 1):
		for yd in range(int(best_rot.y) - 15, int(best_rot.y) + 16, 1):
			for zd in range(int(best_rot.z) - 15, int(best_rot.z) + 16, 1):
				var test_rot := Basis.from_euler(Vector3(
					deg_to_rad(float(xd)), deg_to_rad(float(yd)), deg_to_rad(float(zd))
				))
				var world_rot: Basis = att_basis * test_rot
				var candidate: Vector3
				match best_axis:
					"+Y": candidate = world_rot.y
					"-Y": candidate = -world_rot.y
					"+Z": candidate = world_rot.z
					"-Z": candidate = -world_rot.z
					"+X": candidate = world_rot.x
					"-X": candidate = -world_rot.x
				var err := candidate.angle_to(target)
				if err < fine_best_err:
					fine_best_err = err
					fine_best_rot = Vector3(float(xd), float(yd), float(zd))

	print("  Fine best: rot=(%d, %d, %d)  axis=%s  err=%.3f°" % [
		int(fine_best_rot.x), int(fine_best_rot.y), int(fine_best_rot.z),
		best_axis, rad_to_deg(fine_best_err)
	])
	print("")

	# Apply and verify
	weapon.rotation_degrees = fine_best_rot
	for _i in 3: await process_frame
	var w_world := weapon.global_transform.basis
	var barrel_vec: Vector3
	match best_axis:
		"+Y": barrel_vec = w_world.y.normalized()
		"-Y": barrel_vec = -w_world.y.normalized()
		"+Z": barrel_vec = w_world.z.normalized()
		"-Z": barrel_vec = -w_world.z.normalized()
		"+X": barrel_vec = w_world.x.normalized()
		"-X": barrel_vec = -w_world.x.normalized()

	var pitch_deg := rad_to_deg(asin(clampf(barrel_vec.y, -1.0, 1.0)))
	var yaw_deg := rad_to_deg(atan2(barrel_vec.x, -barrel_vec.z))

	print("=================================================================")
	print("  FINAL VERIFIED RESULT")
	print("=================================================================")
	print("  Barrel world dir: (%.4f, %.4f, %.4f)" % [barrel_vec.x, barrel_vec.y, barrel_vec.z])
	print("  Barrel pitch: %.2f° (0=horizontal, target: -15 to +15)" % pitch_deg)
	print("  Barrel yaw from enemy forward: %.2f°" % yaw_deg)
	print("  Angle to target (0,0,-1): %.3f°" % rad_to_deg(barrel_vec.angle_to(target)))
	print("")

	var muzzle: Node3D = enemy.find_child("EnemyMuzzleFlash", true, false)
	if muzzle:
		print("  Muzzle height above enemy base: %.3fm" % (muzzle.global_position.y - enemy.global_position.y))

	print("")
	print("=================================================================")
	print("  *** USE THIS IN Enemy3D.gd _setup_enemy_weapon(): ***")
	print("  enemy_weapon.rotation_degrees = Vector3(%d, %d, %d)" % [
		int(fine_best_rot.x), int(fine_best_rot.y), int(fine_best_rot.z)
	])
	print("  (barrel axis in GLB local space = %s)" % best_axis)
	print("=================================================================")
	quit()
