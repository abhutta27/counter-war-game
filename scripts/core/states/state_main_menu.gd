class_name StateMainMenu
extends "res://scripts/core/game_state.gd"
## StateMainMenu.gd
## Main menu state: Manages menu navigation, operative profile viewing, and stage selection flow.

func _init(p_sm: Node) -> void:
	super(p_sm, GameConstants.GameState.MAIN_MENU)

func enter(_params: Dictionary = {}) -> void:
	print("[StateMainMenu] Entered Main Menu.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE