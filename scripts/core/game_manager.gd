extends Node
## GameManager.gd
## High-level coordinator of game state, current level, player reference, and session flow.
## Not a god-object: delegates state logic to GameStateMachine and communication to EventBus.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const GameStateMachine = preload("res://scripts/core/game_state_machine.gd")

var current_state: GameConstants.GameState = GameConstants.GameState.BOOT
var current_level_id: int = 1
var player_reference: CharacterBody3D = null
var level_manager: Node = null
var save_manager: Node = null
var is_game_paused: bool = false

var state_machine: GameStateMachine = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_state_machine()
	_connect_event_bus()
	print("[GameManager] Core Game Manager initialized with State Machine.")

func _setup_state_machine() -> void:
	state_machine = GameStateMachine.new()
	state_machine.name = "GameStateMachine"
	add_child(state_machine)
	
	state_machine.transition_completed.connect(_on_state_transition_completed)
	state_machine.transition_rejected.connect(_on_state_transition_rejected)

func _connect_event_bus() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.state_change_requested.connect(func(s): change_state(s))
		eb.player_spawned.connect(set_player)
		eb.player_eliminated.connect(_on_player_eliminated)
		eb.level_completed.connect(_on_level_completed)

## Checks if transition to target state is legally allowed
func can_change_state(new_state: GameConstants.GameState) -> bool:
	if not state_machine:
		return false
	return state_machine.can_transition_to(new_state)

## Transitions game to a new high-level state via the state machine
func change_state(new_state: GameConstants.GameState, params: Dictionary = {}) -> bool:
	if not state_machine:
		return false
	return state_machine.transition_to(new_state, params)

func _on_state_transition_completed(new_state: int, prev_state: int) -> void:
	current_state = new_state as GameConstants.GameState
	var from_name: String = GameConstants.GameState.keys()[prev_state]
	var to_name: String = GameConstants.GameState.keys()[current_state]
	print("[GameManager] State transition completed: %s -> %s" % [from_name, to_name])
	
	_handle_state_lifecycle(current_state)
	if current_state == GameConstants.GameState.MISSION_COMPLETE:
		var profile_manager = get_node_or_null("/root/ProfileManager")
		var stage_manager = get_node_or_null("/root/StageManager")
		if profile_manager and stage_manager and profile_manager.has_method("record_stage_completed"):
			profile_manager.record_stage_completed(stage_manager.get_current_stage_id())
	
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.state_changed.emit(current_state, prev_state)

func _on_state_transition_rejected(from_state: int, to_state: int, reason: String) -> void:
	var from_name: String = GameConstants.GameState.keys()[from_state]
	var to_name: String = GameConstants.GameState.keys()[to_state]
	print("[GameManager] Invalid transition blocked: %s -> %s. Reason: %s" % [from_name, to_name, reason])

func _handle_state_lifecycle(state: GameConstants.GameState) -> void:
	match state:
		GameConstants.GameState.BOOT:
			pass
		GameConstants.GameState.MAIN_MENU:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_game_paused:
				pause_game(false)
		GameConstants.GameState.PLAYING:
			if is_game_paused:
				pause_game(false)
		GameConstants.GameState.PAUSED:
			pause_game(true)
		GameConstants.GameState.MISSION_COMPLETE, GameConstants.GameState.MISSION_FAILED, GameConstants.GameState.GAME_OVER:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Registers the active player controller instance
func set_player(player: CharacterBody3D) -> void:
	player_reference = player
	print("[GameManager] Registered active player reference.")

func get_player() -> CharacterBody3D:
	return player_reference

## Registers current LevelManager
func set_level_manager(manager: Node) -> void:
	level_manager = manager

## Registers current SaveManager
func set_save_manager(manager: Node) -> void:
	save_manager = manager

## Toggles or sets game pause
func pause_game(paused: bool) -> void:
	is_game_paused = paused
	get_tree().paused = is_game_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_game_paused else Input.MOUSE_MODE_CAPTURED
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.game_paused.emit(is_game_paused)

func toggle_pause() -> void:
	if current_state == GameConstants.GameState.PLAYING:
		change_state(GameConstants.GameState.PAUSED)
	elif current_state == GameConstants.GameState.PAUSED:
		change_state(GameConstants.GameState.PLAYING)

func _on_player_eliminated() -> void:
	print("[GameManager] Operative KIA detected.")
	change_state(GameConstants.GameState.MISSION_FAILED)

func _on_level_completed(_level_id: int, victory: bool, _stats: Dictionary) -> void:
	if victory:
		change_state(GameConstants.GameState.MISSION_COMPLETE)
	else:
		change_state(GameConstants.GameState.MISSION_FAILED)
