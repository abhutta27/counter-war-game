extends SceneTree
## check_rifle_mesh_axis.gd
## Checks the actual mesh vertices/AABB of Assault Rifle.glb to see where the barrel points.

func _init() -> void:
	await process_frame
	var scene = load("res://assets/weapons/Assault Rifle.glb")
	var rifle = scene.instantiate()
	root.add_child(rifle)
	await process_frame

	for child in rifle.get_children():
		if child is MeshInstance3D:
			var m = child.mesh
			var aabb = child.get_aabb()
			print("Mesh: ", child.name)
			print("  AABB position: ", aabb.position)
			print("  AABB size: ", aabb.size)
			print("  AABB min: ", aabb.position)
			print("  AABB max: ", aabb.position + aabb.size)
	quit()
