extends SceneTree

func _init() -> void:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	inst.rotation_degrees.x = -90.0
	inst.scale = Vector3(0.01, 0.01, 0.01)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var head_idx = skel.find_bone("mixamorig_Head")
	var head_pose = skel.global_transform * skel.get_bone_global_pose(head_idx)
	print("Rotated Head World Position: ", head_pose.origin)
	inst.queue_free()
	quit(0)
