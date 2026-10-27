class_name StateBoot
extends "res://scripts/core/game_state.gd"
## StateBoot.gd
## Initial boot state: Verifies environment, initializes singletons, and routes to Main Menu.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.BOOT)

func enter(_params: Dictionary = {}) -> void:
	print("[StateBoot] Booting Counter War core systems...")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE