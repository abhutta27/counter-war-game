class_name GameStateBase
extends RefCounted
## GameStateBase.gd
## Abstract base class for all concrete game states in the state machine.

const GameConstants = preload("res://scripts/utilities/constants.gd")

var state_machine: Node = null
var state_enum: GameConstants.GameState = GameConstants.GameState.BOOT

func _init(p_state_machine: Node, p_enum: GameConstants.GameState) -> void:
	state_machine = p_state_machine
	state_enum = p_enum

func enter(_params: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

## Optional custom condition check before allowing exit to a specific target state
func can_transition_to(_target_state: GameConstants.GameState) -> bool:
	return true