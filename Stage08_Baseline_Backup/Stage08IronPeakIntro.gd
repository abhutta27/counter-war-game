class_name Stage08IronPeakIntro
extends Control
## Stage 08 — Operation Iron Peak Introduction Screen
## Matches the top-left panel of the reference UI collage.

const BRIEFING_SCENE := "res://scenes/stages/Stage08IronPeakBriefing.tscn"
const LOADOUT_SCENE := "res://scenes/stages/Stage08IronPeakLoadout.tscn"
const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const HQ_SCENE := "res://scenes/StageSelection.tscn"

@onready var briefing_btn: Button = $Margin/BottomBar/BriefingButton
@onready var start_btn: Button = $Margin/BottomBar/StartButton
@onready var back_btn: Button = $Margin/TopBar/BackButton
@onready var settings_btn: Button = $Margin/TopBar/SettingsButton
@onready var settings_modal: Control = $SettingsModal

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_buttons()
	_apply_styles()

func _setup_buttons() -> void:
	if briefing_btn:
		briefing_btn.pressed.connect(_on_briefing_pressed)
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)

func _apply_styles() -> void:
	if start_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(start_btn)
	if briefing_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(briefing_btn)
		briefing_btn.add_theme_color_override("font_color", Stage08IronPeakUITheme.COLOR_ACCENT_YELLOW)
	if back_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(back_btn)
	if settings_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(settings_btn)

func _on_briefing_pressed() -> void:
	get_tree().change_scene_to_file(BRIEFING_SCENE)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LOADOUT_SCENE)

func _on_back_pressed() -> void:
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", 8)
	get_tree().change_scene_to_file(HQ_SCENE)

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.visible = not settings_modal.visible
