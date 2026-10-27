class_name StateMissionFailed
extends "res://scripts/core/game_state.gd"
## StateMissionFailed.gd
## Mission failed state: Operative KIA or mission objective breach.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.MISSION_FAILED)

func enter(_params: Dictionary = {}) -> void:
	print("[StateMissionFailed] Operative KIA - Mission Failed.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE