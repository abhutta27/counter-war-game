extends SceneTree

func _init() -> void:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst = scene.instantiate()
	root.add_child(inst)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var head_idx = skel.find_bone("mixamorig_Head")
	print("Head global pose: ", skel.get_bone_global_pose(head_idx).origin)
	inst.queue_free()
	quit(0)
