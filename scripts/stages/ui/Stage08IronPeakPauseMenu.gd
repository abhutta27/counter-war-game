class_name Stage08IronPeakPauseMenu
extends Control
## Stage 08 — Operation Iron Peak Pause Menu
## Matches panel 4 of the reference UI collage.
## Manages game pause lifecycle, uncaptured mouse state, settings modal, and restart/abort.

signal resumed()

const HQ_SCENE := "res://scenes/StageSelection.tscn"

@onready var resume_btn: Button = $Margin/Card/Margin/VBox/ResumeButton
@onready var restart_btn: Button = $Margin/Card/Margin/VBox/RestartButton
@onready var settings_btn: Button = $Margin/Card/Margin/VBox/SettingsButton
@onready var abort_btn: Button = $Margin/Card/Margin/VBox/AbortButton
@onready var settings_modal: Control = $SettingsModal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()
	visible = false

func _setup_buttons() -> void:
	if resume_btn:
		resume_btn.pressed.connect(resume_game)
	if restart_btn:
		restart_btn.pressed.connect(restart_mission)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if abort_btn:
		abort_btn.pressed.connect(abort_to_hq)

func _apply_styles() -> void:
	if resume_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(resume_btn)
	if restart_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(restart_btn)
	if settings_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(settings_btn)
	if abort_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(abort_btn)

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if resume_btn:
		resume_btn.grab_focus()

func resume_game() -> void:
	visible = false
	if settings_modal:
		settings_modal.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()

func restart_mission() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func abort_to_hq() -> void:
	get_tree().paused = false
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", 8)
	get_tree().change_scene_to_file(HQ_SCENE)

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.visible = not settings_modal.visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_modal and settings_modal.visible:
			settings_modal.visible = false
			get_viewport().set_input_as_handled()
		elif visible:
			resume_game()
			get_viewport().set_input_as_handled()
