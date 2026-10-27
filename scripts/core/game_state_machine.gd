class_name GameStateMachine
extends Node
## GameStateMachine.gd
## Central state machine managing active game state, strict transition validations, and state lifecycles.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const GameStateBase = preload("res://scripts/core/game_state.gd")

const StateBoot = preload("res://scripts/core/states/state_boot.gd")
const StateMainMenu = preload("res://scripts/core/states/state_main_menu.gd")
const StateLoading = preload("res://scripts/core/states/state_loading.gd")
const StatePlaying = preload("res://scripts/core/states/state_playing.gd")
const StatePaused = preload("res://scripts/core/states/state_paused.gd")
const StateMissionComplete = preload("res://scripts/core/states/state_mission_complete.gd")
const StateMissionFailed = preload("res://scripts/core/states/state_mission_failed.gd")
const StateGameOver = preload("res://scripts/core/states/state_game_over.gd")

signal transition_started(from_state: int, to_state: int)
signal transition_completed(current_state: int, previous_state: int)
signal transition_rejected(from_state: int, to_state: int, reason: String)

var states: Dictionary = {}
var current_state: GameStateBase = null
var current_state_enum: GameConstants.GameState = GameConstants.GameState.BOOT

# Strict whitelist of allowed state transitions
const VALID_TRANSITIONS: Dictionary = {
	GameConstants.GameState.BOOT: [
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.LOADING
	],
	GameConstants.GameState.MAIN_MENU: [
		GameConstants.GameState.LOADING,
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.BOOT
	],
	GameConstants.GameState.LOADING: [
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.GAME_OVER
	],
	GameConstants.GameState.PLAYING: [
		GameConstants.GameState.PAUSED,
		GameConstants.GameState.MISSION_COMPLETE,
		GameConstants.GameState.MISSION_FAILED,
		GameConstants.GameState.GAME_OVER,
		GameConstants.GameState.LOADING,
		GameConstants.GameState.MAIN_MENU
	],
	GameConstants.GameState.PAUSED: [
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.LOADING,
		GameConstants.GameState.GAME_OVER
	],
	GameConstants.GameState.MISSION_COMPLETE: [
		GameConstants.GameState.LOADING,
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.PLAYING
	],
	GameConstants.GameState.MISSION_FAILED: [
		GameConstants.GameState.LOADING,
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.GAME_OVER
	],
	GameConstants.GameState.GAME_OVER: [
		GameConstants.GameState.MAIN_MENU,
		GameConstants.GameState.LOADING,
		GameConstants.GameState.PLAYING,
		GameConstants.GameState.BOOT
	]
}

func _init() -> void:
	_register_states()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Initialize default state
	if states.has(current_state_enum):
		current_state = states[current_state_enum]
		current_state.enter()

func _register_states() -> void:
	states[GameConstants.GameState.BOOT] = StateBoot.new(self)
	states[GameConstants.GameState.MAIN_MENU] = StateMainMenu.new(self)
	states[GameConstants.GameState.LOADING] = StateLoading.new(self)
	states[GameConstants.GameState.PLAYING] = StatePlaying.new(self)
	states[GameConstants.GameState.PAUSED] = StatePaused.new(self)
	states[GameConstants.GameState.MISSION_COMPLETE] = StateMissionComplete.new(self)
	states[GameConstants.GameState.MISSION_FAILED] = StateMissionFailed.new(self)
	states[GameConstants.GameState.GAME_OVER] = StateGameOver.new(self)

## Validates if transition from current state to target state is legally allowed
func can_transition_to(target_state: GameConstants.GameState) -> bool:
	if current_state_enum == target_state:
		return false
		
	var allowed_targets: Array = VALID_TRANSITIONS.get(current_state_enum, [])
	if not (target_state in allowed_targets):
		return false
		
	if current_state and not current_state.can_transition_to(target_state):
		return false
		
	return states.has(target_state)

## Executes strict state transition with validation, exit/enter lifecycle, and notification
func transition_to(target_state: GameConstants.GameState, params: Dictionary = {}) -> bool:
	if current_state_enum == target_state:
		return true
		
	if not can_transition_to(target_state):
		var from_name: String = GameConstants.GameState.keys()[current_state_enum]
		var to_name: String = GameConstants.GameState.keys()[target_state]
		var reason: String = "Transition from %s to %s is not permitted by rules" % [from_name, to_name]
		print("[GameStateMachine] REJECTED: ", reason)
		transition_rejected.emit(current_state_enum, target_state, reason)
		return false
		
	var prev_state_enum: GameConstants.GameState = current_state_enum
	transition_started.emit(prev_state_enum, target_state)
	
	if current_state:
		current_state.exit()
		
	current_state_enum = target_state
	current_state = states[current_state_enum]
	current_state.enter(params)
	
	transition_completed.emit(current_state_enum, prev_state_enum)
	return true

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)