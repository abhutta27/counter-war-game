extends SceneTree

func _init() -> void:
	call_deferred("_launch")

func _launch() -> void:
	var packed := load("res://scenes/stages/Stage03.tscn") as PackedScene
	if not packed:
		quit(1)
		return
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	print("[Stage03Manual] Stage03 progressive infiltration ready for manual play.")
