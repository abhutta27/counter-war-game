extends SceneTree
## find_exact_weapon_rotation.gd
## Brute-force finds the rotation_degrees for the EnemyRifle that makes
## its barrel (identified as its longest AABB axis) point toward (0,0,-1).
## Also sweeps pivot angles to find the minimal correction from current pose.

func _init() -> void:
	await process_frame

	# Load rifle GLB to inspect its geometry
	var rifle_scene = load("res://assets/weapons/Assault Rifle.glb")
	if not rifle_scene:
		print("[FIND] ERROR: Could not load rifle")
		quit()
		return

	var rifle: Node3D = rifle_scene.instantiate()
	root.add_child(rifle)
	await process_frame

	print("=============================================================")
	print("  RIFLE GLB GEOMETRY ANALYSIS")
	print("=============================================================")
	_dump_mesh_bounds(rifle, "Rifle root")
	print("")

	# Also spawn full enemy and measure
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	if not enemy_scene:
		print("[FIND] ERROR: Could not load Enemy3D.tscn")
		quit()
		return

	var enemy: Node3D = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3(0, 0, 0)
	await process_frame
	await process_frame
	await process_frame

	# Force ATTACK state and let animations settle
	if "current_state" in enemy:
		enemy.current_state = 2
	for i in 60:
		await process_frame

	print("=============================================================")
	print("  SWEEPING PIVOT X-ROTATION TO FIND FORWARD-FACING ANGLE")
	print("=============================================================")
	print("  (Enemy forward = world (0, 0, -1))")
	print("")

	var weapon: Node3D = enemy.find_child("EnemyRifle", true, false)
	if not weapon:
		print("[FIND] ERROR: EnemyRifle not found")
		quit()
		return

	# The attachment's world basis (without weapon rotation)
	var attach: BoneAttachment3D = enemy.find_child("RightHandWeaponAttachment", true, false)
	if not attach:
		print("[FIND] ERROR: BoneAttachment3D not found")
		quit()
		return

	var att_basis: Basis = attach.global_transform.basis

	# Current weapon local rotation: (-70, 90, 90)
	# We want to find what ADDITIONAL pivot rotation around which axis
	# makes the barrel vector = (0, 0, -1).
	#
	# Strategy: fix Y=90, Z=90, sweep X from -180 to +180 and check each candidate axis.
	# The "barrel" is most likely along +Y of the rifle GLB (typical long model axis).

	print("  BoneAttachment world basis columns:")
	print("    X: (%.4f, %.4f, %.4f)" % [att_basis.x.x, att_basis.x.y, att_basis.x.z])
	print("    Y: (%.4f, %.4f, %.4f)" % [att_basis.y.x, att_basis.y.y, att_basis.y.z])
	print("    Z: (%.4f, %.4f, %.4f)" % [att_basis.z.x, att_basis.z.y, att_basis.z.z])
	print("")

	var target: Vector3 = Vector3(0, 0, -1)  # enemy faces -Z
	var best_angle_x: float = -999.0
	var best_err: float = 999.0
	var best_barrel_axis: String = "?"

	# For each candidate "barrel axis" of the rifle and each X rotation, find minimum error
	for barrel_name in ["-Z", "+Z", "+Y", "-Y", "+X", "-X"]:
		for x_deg in range(-180, 181, 5):
			var test_rot := Basis.from_euler(Vector3(deg_to_rad(x_deg), deg_to_rad(90.0), deg_to_rad(90.0)))
			var world_rot: Basis = att_basis * test_rot
			var candidate: Vector3
			match barrel_name:
				"-Z": candidate = -world_rot.z
				"+Z": candidate = world_rot.z
				"+Y": candidate = world_rot.y
				"-Y": candidate = -world_rot.y
				"+X": candidate = world_rot.x
				"-X": candidate = -world_rot.x
			var err := candidate.angle_to(target)
			if err < best_err:
				best_err = err
				best_angle_x = x_deg
				best_barrel_axis = barrel_name

	print("  RESULT: Best X rotation = %.0f°  (barrel axis = %s  → error = %.2f°)" % [
		best_angle_x, best_barrel_axis, rad_to_deg(best_err)
	])
	print("  -> Set enemy_weapon.rotation_degrees = Vector3(%.0f, 90, 90)" % best_angle_x)
	print("")

	# Verify by actually setting it and checking
	weapon.rotation_degrees = Vector3(best_angle_x, 90.0, 90.0)
	await process_frame
	var w_world := weapon.global_transform.basis
	var barrel_vec: Vector3
	match best_barrel_axis:
		"-Z": barrel_vec = -w_world.z
		"+Z": barrel_vec = w_world.z
		"+Y": barrel_vec = w_world.y
		"-Y": barrel_vec = -w_world.y
		"+X": barrel_vec = w_world.x
		"-X": barrel_vec = -w_world.x

	print("  VERIFIED barrel world direction: (%.3f, %.3f, %.3f)" % [barrel_vec.x, barrel_vec.y, barrel_vec.z])
	print("  VERIFIED barrel pitch: %.2f°" % rad_to_deg(asin(clampf(barrel_vec.y, -1.0, 1.0))))
	print("  VERIFIED angle to target: %.2f°" % rad_to_deg(barrel_vec.angle_to(target)))
	print("")

	# Also check muzzle position with new rotation
	var muzzle: Node3D = enemy.find_child("EnemyMuzzleFlash", true, false)
	if muzzle:
		print("  Muzzle world pos: %s" % str(muzzle.global_position))
		print("  Muzzle Y height above ground (enemy.y=-1.8): %.3fm" % (muzzle.global_position.y - enemy.global_position.y))

	print("=============================================================")
	quit()

func _dump_mesh_bounds(node: Node, label: String) -> void:
	if node is MeshInstance3D:
		var aabb: AABB = (node as MeshInstance3D).get_aabb()
		print("  %s AABB: pos=%s  size=%s  longest_axis=%s" % [label, str(aabb.position), str(aabb.size),
			["X","Y","Z"][aabb.get_longest_axis_index()]])
	for c in node.get_children():
		_dump_mesh_bounds(c, label + "/" + c.name)
