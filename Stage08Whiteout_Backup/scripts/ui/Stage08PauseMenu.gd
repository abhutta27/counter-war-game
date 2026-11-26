class_name Stage08PauseMenu
extends Control
## Stage 08 — Operation Whiteout Dedicated Pause Menu
## Strictly implements art_reference/stage08/04_pause_menu.png

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var resume_btn: Button = $CenterContainer/MainCard/Margin/VBox/ContentHBox/ButtonVBox/ResumeButton
@onready var controls_btn: Button = $CenterContainer/MainCard/Margin/VBox/ContentHBox/ButtonVBox/ControlsButton
@onready var settings_btn: Button = $CenterContainer/MainCard/Margin/VBox/ContentHBox/ButtonVBox/SettingsButton
@onready var restart_btn: Button = $CenterContainer/MainCard/Margin/VBox/ContentHBox/ButtonVBox/RestartButton
@onready var quit_btn: Button = $CenterContainer/MainCard/Margin/VBox/ContentHBox/ButtonVBox/QuitButton
@onready var back_btn: Button = $CenterContainer/MainCard/Margin/VBox/FooterHBox/BackButton
@onready var controls_modal: PanelContainer = $CenterContainer/ControlsModal
@onready var modal_back_btn: Button = get_node_or_null("%ModalBackButton") as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()


func _setup_buttons() -> void:
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_resume_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if modal_back_btn:
		modal_back_btn.pressed.connect(func(): if controls_modal: controls_modal.visible = false)

	var all_btns: Array[Button] = [resume_btn, controls_btn, settings_btn, restart_btn, quit_btn, back_btn, modal_back_btn]
	for btn in all_btns:
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_styles() -> void:
	# Main card panel
	var main_card := $CenterContainer/MainCard as PanelContainer
	if main_card:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.04, 0.07, 0.94)
		sb.border_color = Color(0.18, 0.45, 0.72, 0.85)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 12
		main_card.add_theme_stylebox_override("panel", sb)

	# Mountain picture frame
	var frame := $CenterContainer/MainCard/Margin/VBox/ContentHBox/MountainFrame as PanelContainer
	if frame:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.01, 0.02, 0.04, 0.9)
		sb.border_color = Color(0.25, 0.55, 0.85, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		frame.add_theme_stylebox_override("panel", sb)

	# Buttons
	if resume_btn:
		resume_btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_active_menu_button())
		resume_btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_active_menu_button(Color(0.12, 0.52, 0.96, 1.0)))
	
	var secondary_btns: Array[Button] = [controls_btn, settings_btn, restart_btn, quit_btn, back_btn]
	for btn in secondary_btns:
		if btn:
			btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_outline_button())
			btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_outline_button(Color(0.06, 0.14, 0.22, 0.95), Color(0.25, 0.60, 0.90, 0.95)))


func open_menu() -> void:
	visible = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state") and gm.current_state == GameConstants.GameState.PLAYING:
		if not gm.change_state(GameConstants.GameState.PAUSED):
			gm.pause_game(true)
	elif gm and gm.has_method("pause_game"):
		gm.pause_game(true)
	else:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if resume_btn:
		resume_btn.grab_focus()


func close_menu() -> void:
	visible = false
	if controls_modal:
		controls_modal.visible = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state") and gm.current_state == GameConstants.GameState.PAUSED:
		if not gm.change_state(GameConstants.GameState.PLAYING):
			gm.pause_game(false)
	elif gm and gm.has_method("pause_game"):
		gm.pause_game(false)
	else:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_requested.emit()


func toggle() -> void:
	if visible:
		close_menu()
	else:
		open_menu()



func _on_resume_pressed() -> void:
	close_menu()


func _on_restart_pressed() -> void:
	close_menu()
	restart_requested.emit()
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("restart_current_stage"):
		stg_mgr.restart_current_stage()
	else:
		get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main_menu_requested.emit()
	var stage_manager = get_node_or_null("/root/StageManager")
	if stage_manager and stage_manager.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", stage_manager.get_current_stage_id())
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")


func _on_controls_pressed() -> void:
	if controls_modal:
		controls_modal.visible = !controls_modal.visible


func _on_settings_pressed() -> void:
	if controls_modal:
		controls_modal.visible = false
