class_name StateMissionComplete
extends "res://scripts/core/game_state.gd"
## StateMissionComplete.gd
## Mission complete state: Victory flow, score tally, and stage debriefing.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.MISSION_COMPLETE)

func enter(params: Dictionary = {}) -> void:
	var stage_id: int = int(params.get("stage_id", 1))
	print("[StateMissionComplete] Victory achieved for Stage ", stage_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE