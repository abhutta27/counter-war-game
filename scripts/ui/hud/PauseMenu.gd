class_name PauseMenu
extends Control
## PauseMenu.gd
## Tactical pause menu providing suspend control, restart, audio toggles, and main menu exit.

const GameConstants = preload("res://scripts/utilities/constants.gd")

signal resume_requested()
signal restart_requested()
signal main_menu_requested()

@onready var resume_btn: Button = $Panel/VBox/Actions/ResumeBtn
@onready var restart_btn: Button = $Panel/VBox/Actions/RestartBtn
@onready var sfx_btn: Button = $Panel/VBox/Actions/SfxBtn
@onready var menu_btn: Button = $Panel/VBox/Actions/MenuBtn

var is_sfx_muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	sfx_btn.pressed.connect(_on_sfx_toggle_pressed)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	
	for btn in [resume_btn, restart_btn, sfx_btn, menu_btn]:
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func open_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state") and gm.current_state == GameConstants.GameState.PLAYING:
		if not gm.change_state(GameConstants.GameState.PAUSED):
			gm.pause_game(true)
	elif gm and gm.has_method("pause_game"):
		gm.pause_game(true)
	else:
		get_tree().paused = true
	resume_btn.grab_focus()

func close_menu() -> void:
	visible = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state") and gm.current_state == GameConstants.GameState.PAUSED:
		if not gm.change_state(GameConstants.GameState.PLAYING):
			gm.pause_game(false)
	elif gm and gm.has_method("pause_game"):
		gm.pause_game(false)
	else:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle() -> void:
	if visible:
		close_menu()
		emit_signal("resume_requested")
	else:
		open_menu()

func _on_resume_pressed() -> void:
	close_menu()
	emit_signal("resume_requested")

func _on_restart_pressed() -> void:
	close_menu()
	emit_signal("restart_requested")
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("restart_current_stage"):
		stg_mgr.restart_current_stage()
	elif get_tree().current_scene:
		get_tree().reload_current_scene()

func _on_sfx_toggle_pressed() -> void:
	is_sfx_muted = not is_sfx_muted
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, is_sfx_muted)
	sfx_btn.text = "SFX AUDIO: " + ("MUTED" if is_sfx_muted else "ACTIVE")

func _on_main_menu_pressed() -> void:
	close_menu()
	emit_signal("main_menu_requested")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var stage_manager = get_node_or_null("/root/StageManager")
	if stage_manager and stage_manager.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", stage_manager.get_current_stage_id())
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")
