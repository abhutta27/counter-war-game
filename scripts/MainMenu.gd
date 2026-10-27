extends Control
## Legacy route retained for older callers. The operative dossier and mission
## selection now live together in the central Operations HQ.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://scenes/StageSelection.tscn")
