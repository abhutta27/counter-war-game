class_name StatePlaying
extends "res://scripts/core/game_state.gd"
## StatePlaying.gd
## Active gameplay state: First-person operative combat, physics simulation, and real-time updates.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.PLAYING)

func enter(_params: Dictionary = {}) -> void:
	print("[StatePlaying] Combat loop active.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED