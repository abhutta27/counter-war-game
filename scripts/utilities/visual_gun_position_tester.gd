extends SceneTree
## visual_gun_position_tester.gd
## Non-destructive visual tester: instantiates Level1, adjusts enemy gun position/rotation at runtime,
## captures screenshots of different test values, and calculates world coordinates & metrics.

func _init() -> void:
	await process_frame
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	for i in 15: await process_frame

	var player = level.get_node("Player3D")
	var enemy = level.get_node("Enemies/Enemy3D_2")

	# Position enemy directly in front of player with clear view
	enemy.global_position = Vector3(0.0, 0.0, -3.2)
	enemy.look_at(player.global_position, Vector3.UP)
	enemy.current_state = Enemy3D.State.ATTACK

	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.look_at(enemy.global_position + Vector3(0, 1.1, 0), Vector3.UP)

	for i in 20: await process_frame

	var weapon: Node3D = enemy.enemy_weapon
	var flash: Node3D = enemy.enemy_muzzle_flash
	var soldier = enemy.soldier_model
	var skel: Skeleton3D = soldier.find_child("Skeleton3D", true, false)

	# Get hand bone world positions
	var rh_idx = skel.find_bone("mixamorig_RightHand")
	var lh_idx = skel.find_bone("mixamorig_LeftHand")
	var spine_idx = skel.find_bone("mixamorig_Spine1")

	var rh_pos = skel.global_transform * skel.get_bone_global_pose(rh_idx).origin
	var lh_pos = skel.global_transform * skel.get_bone_global_pose(lh_idx).origin
	var spine_pos = skel.global_transform * skel.get_bone_global_pose(spine_idx).origin

	print("=== SKELETON REFERENCE POINTS (World Space) ===")
	print("Right Hand: ", rh_pos)
	print("Left Hand:  ", lh_pos)
	print("Chest/Spine1: ", spine_pos)
	print("===============================================")

	# Candidates to test:
	# Baseline
	# Option 1: raised slightly in Y and moved inward in X (towards chest/center)
	# Option 2: raised more in Y, shifted forward in Z
	# Option 3: chest level centered between hands
	# Option 4: optimal grip offset

	var test_configs = [
		{
			"id": "baseline",
			"pos": Vector3(0.04, 0.08, -0.04),
			"rot": Vector3(164.0, -15.0, -190.0)
		},
		{
			"id": "opt1_raised_inward",
			"pos": Vector3(0.02, 0.20, -0.06),
			"rot": Vector3(164.0, -15.0, -190.0)
		},
		{
			"id": "opt2_chest_level",
			"pos": Vector3(0.00, 0.26, -0.08),
			"rot": Vector3(162.0, -14.0, -190.0)
		},
		{
			"id": "opt3_tactical_aim",
			"pos": Vector3(-0.01, 0.28, -0.10),
			"rot": Vector3(160.0, -12.0, -188.0)
		},
		{
			"id": "opt4_high_chest",
			"pos": Vector3(-0.02, 0.32, -0.12),
			"rot": Vector3(158.0, -10.0, -185.0)
		}
	]

	for cfg in test_configs:
		weapon.position = cfg["pos"]
		weapon.rotation_degrees = cfg["rot"]
		for f in 8: await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var img_path = "res://verification_screenshots/test_gun_pos_" + cfg["id"] + ".png"
		img.save_png(img_path)

		var w_pos = weapon.global_position
		var m_pos = flash.global_position
		var barrel_vec = (m_pos - w_pos).normalized()
		var pitch = rad_to_deg(asin(barrel_vec.y))

		var dist_to_rh = w_pos.distance_to(rh_pos)
		var dist_to_lh = w_pos.distance_to(lh_pos)
		var height_above_base = w_pos.y - enemy.global_position.y
		var muzzle_height = m_pos.y - enemy.global_position.y

		print("CONFIG [", cfg["id"], "]:")
		print("  Position: ", cfg["pos"])
		print("  Rotation: ", cfg["rot"])
		print("  Weapon World Pos: ", w_pos, " (Height: ", height_above_base, "m)")
		print("  Muzzle World Pos: ", m_pos, " (Height: ", muzzle_height, "m)")
		print("  Barrel Pitch: ", pitch, " deg")
		print("  Dist to Right Hand: ", dist_to_rh, "m, Dist to Left Hand: ", dist_to_lh, "m")
		print("  Screenshot saved: ", img_path)
		print("--------------------------------------------------")

	quit()
