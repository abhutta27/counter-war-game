extends SceneTree
## hand_world_rotation_dump.gd
## Loads Soldier.glb, plays Idle animation, then after several frames
## dumps the RIGHT HAND bone's global (world-space) euler rotation and
## the bone's local axes so we can compute the exact weapon pivot offset needed.

func _init() -> void:
	await process_frame

	var soldier_scene = load("res://assets/characters/Soldier.glb")
	if not soldier_scene:
		print("[DUMP] ERROR: Could not load Soldier.glb")
		quit()
		return

	var soldier: Node3D = soldier_scene.instantiate() as Node3D
	root.add_child(soldier)
	await process_frame

	# Find AnimationPlayer and Skeleton3D
	var ap: AnimationPlayer = _find_ap(soldier)
	var skel: Skeleton3D = _find_skel(soldier)
	if not ap or not skel:
		print("[DUMP] ERROR: Could not find AnimationPlayer or Skeleton3D")
		quit()
		return

	# Play Idle and let it run for 10 frames so it settles
	ap.play("Idle")
	for i in 30:
		await process_frame

	print("")
	print("=============================================================")
	print("  RIGHT HAND BONE — WORLD SPACE ANALYSIS (during Idle)")
	print("=============================================================")

	var rh_idx := skel.find_bone("mixamorig_RightHand")
	if rh_idx < 0:
		print("[DUMP] ERROR: mixamorig_RightHand not found")
		quit()
		return

	# Get the bone's GLOBAL pose (in skeleton's local space but accumulated)
	var bone_global_xform: Transform3D = skel.get_bone_global_pose(rh_idx)
	var world_xform: Transform3D = skel.global_transform * bone_global_xform

	var euler_xyz: Vector3 = world_xform.basis.get_euler(EULER_ORDER_XYZ) * (180.0 / PI)
	var euler_yxz: Vector3 = world_xform.basis.get_euler(EULER_ORDER_YXZ) * (180.0 / PI)

	print("  Bone global pose origin (in skeleton space): %s" % str(bone_global_xform.origin))
	print("  Bone world origin: %s" % str(world_xform.origin))
	print("  Bone world euler XYZ deg: (%.2f, %.2f, %.2f)" % [euler_xyz.x, euler_xyz.y, euler_xyz.z])
	print("  Bone world euler YXZ deg: (%.2f, %.2f, %.2f)" % [euler_yxz.x, euler_yxz.y, euler_yxz.z])
	print("")

	# Print the three local axes of the hand bone in world space
	# These tell us what direction the hand's X/Y/Z points in world
	var bx: Vector3 = world_xform.basis.x
	var by: Vector3 = world_xform.basis.y
	var bz: Vector3 = world_xform.basis.z
	print("  Hand bone world X axis: (%.3f, %.3f, %.3f)  [right of hand]"    % [bx.x, bx.y, bx.z])
	print("  Hand bone world Y axis: (%.3f, %.3f, %.3f)  [up of hand]"       % [by.x, by.y, by.z])
	print("  Hand bone world Z axis: (%.3f, %.3f, %.3f)  [forward of hand]"  % [bz.x, bz.y, bz.z])
	print("")

	# Now simulate what rotation_degrees=(0,90,90) does to the weapon
	# after the BoneAttachment inherits the hand bone world transform.
	# weapon local axes in bone space after (0,90,90) rotation:
	var weapon_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), deg_to_rad(90.0)))
	var weapon_world_basis := world_xform.basis * weapon_basis
	var wb_x: Vector3 = weapon_world_basis.x
	var wb_y: Vector3 = weapon_world_basis.y
	var wb_z: Vector3 = weapon_world_basis.z
	print("  After weapon rot(0,90,90) applied:")
	print("  Weapon world X axis: (%.3f, %.3f, %.3f)" % [wb_x.x, wb_x.y, wb_x.z])
	print("  Weapon world Y axis: (%.3f, %.3f, %.3f)" % [wb_y.x, wb_y.y, wb_y.z])
	print("  Weapon world Z axis: (%.3f, %.3f, %.3f)  <-- BARREL direction (-Z = forward)" % [wb_z.x, wb_z.y, wb_z.z])
	print("")

	# The barrel direction is -Z of the weapon in world space
	var barrel_world_dir: Vector3 = -wb_z
	print("  BARREL world direction vector: (%.3f, %.3f, %.3f)" % [barrel_world_dir.x, barrel_world_dir.y, barrel_world_dir.z])
	var barrel_pitch_deg := rad_to_deg(asin(clampf(barrel_world_dir.y, -1.0, 1.0)))
	print("  BARREL pitch from horizontal: %.2f degrees (0=horizontal, +90=straight up, -90=straight down)" % barrel_pitch_deg)
	print("")
	print("  -> To level the barrel, we need a pivot rotation that pitches the barrel UP by %.2f degrees" % (-barrel_pitch_deg))
	print("")

	# Compute what pivot rotation_degrees.x value (in bone-local space) would level the barrel
	# The pivot sits between BoneAttachment and weapon, its X axis = wb_x (right of weapon after the 90,90 rot)
	# Rotating around wb_x by angle alpha changes barrel from current to: barrel + alpha * something
	# The barrel needs to go from barrel_world_dir to (roughly) (0, 0, -1) or face_dir
	# In bone-local space, the pivot X axis = weapon_basis.x after (0,90,90) = ?
	var pivot_local_x: Vector3 = weapon_basis.x  # pivot X in bone/attachment local space
	print("  Pivot local X axis (bone space): (%.3f, %.3f, %.3f)" % [pivot_local_x.x, pivot_local_x.y, pivot_local_x.z])
	print("")
	print("  KEY: Rotate the weapon pivot by the above pitch amount around pivot local X")
	print("=============================================================")
	quit()

func _find_ap(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null

func _find_skel(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null
