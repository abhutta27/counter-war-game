extends SceneTree
## test_barrel_axis_z.gd
## Sweeps rotations where -Z is the barrel.

func _init() -> void:
	await process_frame
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	var enemy: Node3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3.ZERO
	for _i in 5: await process_frame
	if "current_state" in enemy: enemy.current_state = 2
	for _i in 60: await process_frame

	var attach: BoneAttachment3D = enemy.find_child("RightHandWeaponAttachment", true, false)
	var weapon: Node3D = enemy.find_child("EnemyRifle", true, false)
	var raw_basis: Basis = attach.global_transform.basis
	var att_basis := Basis(
		raw_basis.x.normalized(), raw_basis.y.normalized(), raw_basis.z.normalized()
	)
	var target: Vector3 = Vector3(0.0, 0.0, -1.0)

	var best_rot := Vector3.ZERO
	var best_err := 999.0

	# Barrel is -Z of weapon mesh
	for xd in range(-180, 181, 5):
		for yd in range(-180, 181, 5):
			for zd in range(-180, 181, 5):
				var test_rot := Basis.from_euler(Vector3(
					deg_to_rad(float(xd)), deg_to_rad(float(yd)), deg_to_rad(float(zd))
				))
				var world_rot: Basis = att_basis * test_rot
				var candidate: Vector3 = -world_rot.z # Barrel is -Z
				var err := candidate.angle_to(target)
				if err < best_err:
					best_err = err
					best_rot = Vector3(float(xd), float(yd), float(zd))

	print("Coarse best for -Z barrel: rot=(%d, %d, %d), err=%.2f°" % [
		int(best_rot.x), int(best_rot.y), int(best_rot.z), rad_to_deg(best_err)
	])

	var fine_rot := best_rot
	var fine_err := best_err
	for xd in range(int(best_rot.x)-10, int(best_rot.x)+11):
		for yd in range(int(best_rot.y)-10, int(best_rot.y)+11):
			for zd in range(int(best_rot.z)-10, int(best_rot.z)+11):
				var test_rot := Basis.from_euler(Vector3(
					deg_to_rad(float(xd)), deg_to_rad(float(yd)), deg_to_rad(float(zd))
				))
				var world_rot: Basis = att_basis * test_rot
				var candidate: Vector3 = -world_rot.z
				var err := candidate.angle_to(target)
				if err < fine_err:
					fine_err = err
					fine_rot = Vector3(float(xd), float(yd), float(zd))

	print("Fine best for -Z barrel: rot=(%d, %d, %d), err=%.3f°" % [
		int(fine_rot.x), int(fine_rot.y), int(fine_rot.z), rad_to_deg(fine_err)
	])
	quit()
