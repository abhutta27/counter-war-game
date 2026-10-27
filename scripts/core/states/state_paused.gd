class_name StatePaused
extends "res://scripts/core/game_state.gd"
## StatePaused.gd
## Paused state: Freezes gameplay simulation while keeping UI responsive.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.PAUSED)

func enter(_params: Dictionary = {}) -> void:
	print("[StatePaused] Game simulation paused.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit() -> void:
	print("[StatePaused] Resuming gameplay...")