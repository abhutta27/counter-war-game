extends SceneTree
## inspect_enemy_runtime_weapon.gd
## Spawns Level1, locates Enemy3D_2, and inspects its entire weapon hierarchy and visibility.

func _init() -> void:
	await process_frame
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	for i in 15: await process_frame

	var enemy = level.get_node("Enemies/Enemy3D_2")
	var weapon = enemy.enemy_weapon
	var flash = enemy.enemy_muzzle_flash

	print("=== ENEMY WEAPON RUNTIME INSPECTION ===")
	print("Enemy global_position: ", enemy.global_position)
	print("Enemy visible: ", enemy.visible)
	print("Weapon null? ", weapon == null)
	if weapon:
		print("Weapon name: ", weapon.name)
		print("Weapon parent: ", weapon.get_parent().name, " (", weapon.get_parent().get_class(), ")")
		print("Weapon visible: ", weapon.visible)
		print("Weapon scale: ", weapon.scale)
		print("Weapon local pos: ", weapon.position)
		print("Weapon local rot: ", weapon.rotation_degrees)
		print("Weapon global pos: ", weapon.global_position)
		print("Weapon global rot: ", weapon.global_rotation_degrees)
		for c in weapon.get_children():
			print("  Child: ", c.name, " (", c.get_class(), "), visible=", c.visible if "visible" in c else "N/A")
			if c is MeshInstance3D:
				print("    Mesh: ", c.mesh, ", aabb: ", c.get_aabb())

	quit()
