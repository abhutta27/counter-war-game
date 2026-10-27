extends SceneTree

func _process(_delta: float) -> bool:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	ap.play("Idle")
	ap.advance(0.1)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var head_idx = skel.find_bone("mixamorig_Head")
	var head_pose = skel.global_transform * skel.get_bone_global_pose(head_idx)
	print("While Idle playing, Head World Position: ", head_pose.origin)
	inst.queue_free()
	quit(0)
	return true
