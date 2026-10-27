extends SceneTree

func _init() -> void:
	print("--- INSPECTING SOLDIER.GLB ---")
	var scene = load("res://assets/characters/Soldier.glb")
	if not scene:
		printerr("FAILED to load Soldier.glb")
		quit(1)
		return
	var inst = scene.instantiate()
	print("Instance name: ", inst.name)
	_print_tree(inst, "")
	inst.queue_free()
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	print(indent, "- ", node.name, " (", node.get_class(), ")")
	if node is AnimationPlayer:
		print(indent, "  ANIMATIONS: ", node.get_animation_list())
	for child in node.get_children():
		_print_tree(child, indent + "  ")
