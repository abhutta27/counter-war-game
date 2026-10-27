class_name StateGameOver
extends "res://scripts/core/game_state.gd"
## StateGameOver.gd
## Game over state: Terminal session state.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.GAME_OVER)

func enter(_params: Dictionary = {}) -> void:
	print("[StateGameOver] Game Over.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE