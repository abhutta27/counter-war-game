extends SceneTree
## combat_stance_verify.gd — headless verification of Enemy3D weapon stance.
## Run: godot --headless --script scripts/utilities/combat_stance_verify.gd
##
## Spawns an Enemy3D, forces State.ATTACK, runs a few frames, then checks:
##   1. SoldierModel rotation.x is near COMBAT_LEAN_DEGREES (-18°)
##   2. Weapon rotation_degrees.x is 0 (no spurious upward pitch)
##   3. enemy_weapon is a child of RightHandWeaponAttachment (bone-parented)
##   4. No arm-to-sky: weapon Y world position < head Y world position

func _init() -> void:
	await process_frame

	# Load the enemy scene
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	if not enemy_scene:
		print("[VERIFY] FAIL: Could not load Enemy3D.tscn")
		quit()
		return

	var enemy = enemy_scene.instantiate()
	if not enemy:
		print("[VERIFY] FAIL: Could not instantiate Enemy3D")
		quit()
		return

	root.add_child(enemy)
	enemy.global_position = Vector3(0, 0, 0)

	# Wait for _ready and setup
	await process_frame
	await process_frame
	await process_frame

	print("")
	print("=============================================================")
	print("  ENEMY3D COMBAT STANCE VERIFICATION")
	print("=============================================================")

	# ---- 1. Check weapon attachment exists and is parented correctly ----
	var soldier_model: Node3D = enemy.get_node_or_null("SoldierModel")
	var weapon_node: Node3D = null
	var attachment_node = null

	if soldier_model:
		var skel = soldier_model.find_child("Skeleton3D", true, false)
		if skel:
			attachment_node = skel.find_child("RightHandWeaponAttachment", true, false)
			if attachment_node:
				weapon_node = attachment_node.find_child("EnemyRifle", true, false)

	print("[1] BoneAttachment3D 'RightHandWeaponAttachment' found: %s" % str(attachment_node != null))
	print("[1] Bone name on attachment: %s" % (attachment_node.bone_name if attachment_node else "N/A"))
	print("[1] EnemyRifle parented to attachment: %s" % str(weapon_node != null))

	if weapon_node:
		var rot_deg: Vector3 = weapon_node.rotation_degrees
		print("[2] EnemyRifle local rotation_degrees: (%.1f, %.1f, %.1f)" % [rot_deg.x, rot_deg.y, rot_deg.z])
		var x_ok := absf(rot_deg.x) < 15.0  # X should be near 0 — no spurious up-tilt
		print("[2] Weapon X rotation <= 15° (no sky-pointing): %s  [expect: true, got X=%.1f°]" % [str(x_ok), rot_deg.x])

	# ---- 2. Force ATTACK state and run _process for lean to apply ----
	if enemy.has_method("_change_state"):
		# Access the state enum value — State.ATTACK = 2
		enemy.current_state = 2  # State.ATTACK
	elif "current_state" in enemy:
		enemy.current_state = 2

	# Run several frames so _update_combat_lean has time to blend
	for i in 30:
		await process_frame

	if soldier_model:
		var lean_x: float = soldier_model.rotation_degrees.x
		print("[3] SoldierModel rotation_degrees.x in ATTACK state: %.2f°" % lean_x)
		var lean_ok := lean_x < -5.0 and lean_x > -30.0
		print("[3] Forward lean applied (-5° to -30°): %s  [expect: true]" % str(lean_ok))

	# ---- 3. Weapon world position vs head world position ----
	if weapon_node and soldier_model:
		var skel = soldier_model.find_child("Skeleton3D", true, false)
		if skel:
			var weapon_world_y: float = weapon_node.global_position.y
			# Head bone index 5 = mixamorig_Head
			var head_idx: int = skel.find_bone("mixamorig_Head")
			var head_y: float = (skel.get_bone_global_pose(head_idx).origin.y
				+ enemy.global_position.y) if head_idx >= 0 else 99.0
			print("[4] Weapon world Y: %.3f,  Head world Y estimate: %.3f" % [weapon_world_y, head_y])
			var weapon_not_above_head := weapon_world_y < head_y + 0.3
			print("[4] Weapon below head level (not arm-to-sky): %s" % str(weapon_not_above_head))

	print("")
	print("=============================================================")
	print("  END VERIFICATION")
	print("=============================================================")
	quit()
