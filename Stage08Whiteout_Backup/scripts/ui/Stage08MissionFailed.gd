class_name Stage08MissionFailed
extends Control
## Stage 08 — Operation Whiteout Dedicated Mission Failed Screen
## Strictly implements art_reference/stage08/06_mission_failed.png

signal retry_requested
signal load_checkpoint_requested
signal main_menu_requested

@onready var reason_text_label: Label = $CenterContainer/MainCard/Margin/VBox/CardsHBox/ReasonCard/Margin/VBox/HBox/ReasonText
@onready var checkpoint_dist_label: Label = $CenterContainer/MainCard/Margin/VBox/CardsHBox/CheckpointCard/Margin/VBox/HBox/DistText

@onready var retry_btn: Button = $CenterContainer/MainCard/Margin/VBox/ButtonHBox/RetryButton
@onready var checkpoint_btn: Button = $CenterContainer/MainCard/Margin/VBox/ButtonHBox/CheckpointButton
@onready var exit_btn: Button = $CenterContainer/MainCard/Margin/VBox/ButtonHBox/ExitButton
@onready var back_btn: Button = $CenterContainer/MainCard/Margin/VBox/FooterHBox/BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()


func _setup_buttons() -> void:
	if retry_btn:
		retry_btn.pressed.connect(_on_retry_pressed)
	if checkpoint_btn:
		checkpoint_btn.pressed.connect(_on_checkpoint_pressed)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_exit_pressed)


func _apply_styles() -> void:
	var main_card := $CenterContainer/MainCard as PanelContainer
	if main_card:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.02, 0.02, 0.95)
		sb.border_color = Color(0.55, 0.16, 0.16, 0.85)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.7)
		sb.shadow_size = 14
		main_card.add_theme_stylebox_override("panel", sb)

	var reason_card := $CenterContainer/MainCard/Margin/VBox/CardsHBox/ReasonCard as PanelContainer
	if reason_card:
		reason_card.add_theme_stylebox_override("panel", Stage08WhiteoutUITheme.create_failed_panel())

	var checkpoint_card := $CenterContainer/MainCard/Margin/VBox/CardsHBox/CheckpointCard as PanelContainer
	if checkpoint_card:
		checkpoint_card.add_theme_stylebox_override("panel", Stage08WhiteoutUITheme.create_failed_panel(Color(0.05, 0.04, 0.05, 0.85), Color(0.38, 0.22, 0.25, 0.75)))

	if retry_btn:
		retry_btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_active_menu_button())
		retry_btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_active_menu_button(Color(0.12, 0.52, 0.96, 1.0)))

	var secondary_btns: Array[Button] = [checkpoint_btn, exit_btn, back_btn]
	for btn in secondary_btns:
		if btn:
			btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_outline_button(Color(0.06, 0.04, 0.06, 0.85), Color(0.35, 0.25, 0.30, 0.80)))
			btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_outline_button(Color(0.12, 0.08, 0.10, 0.95), Color(0.55, 0.35, 0.40, 0.95)))


func display_failure(reason: String = "Killed by sniper", distance_m: int = 37) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if reason_text_label:
		reason_text_label.text = reason
	if checkpoint_dist_label:
		checkpoint_dist_label.text = "%d m" % distance_m


func _on_retry_pressed() -> void:
	retry_requested.emit()
	get_tree().paused = false
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("restart_current_stage"):
		stg_mgr.restart_current_stage()
	else:
		get_tree().reload_current_scene()


func _on_checkpoint_pressed() -> void:
	load_checkpoint_requested.emit()
	get_tree().paused = false
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("restart_current_stage"):
		stg_mgr.restart_current_stage()
	else:
		get_tree().reload_current_scene()


func _on_exit_pressed() -> void:
	main_menu_requested.emit()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")
