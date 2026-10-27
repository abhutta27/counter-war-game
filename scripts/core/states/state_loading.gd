class_name StateLoading
extends "res://scripts/core/game_state.gd"
## StateLoading.gd
## Loading state: Coordinates scene preparation and level resource loading.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.LOADING)

func enter(params: Dictionary = {}) -> void:
	var target_level: int = int(params.get("level_id", 1))
	print("[StateLoading] Loading Level: ", target_level)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE