extends SceneTree

func _init() -> void:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst = scene.instantiate()
	var mesh_inst: MeshInstance3D = inst.find_child("vanguard_Mesh", true, false)
	if mesh_inst:
		var aabb = mesh_inst.get_aabb()
		print("Mesh AABB: position=", aabb.position, " size=", aabb.size)
	inst.queue_free()
	quit(0)
