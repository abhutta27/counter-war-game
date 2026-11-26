class_name Stage08IronPeakBriefing
extends Control
## Stage 08 — Operation Iron Peak Briefing Screen
## Matches the top-middle panel of the reference UI collage.

const INTRO_SCENE := "res://scenes/stages/Stage08IronPeakIntro.tscn"
const LOADOUT_SCENE := "res://scenes/stages/Stage08IronPeakLoadout.tscn"
const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"

@onready var continue_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/ContinueButton
@onready var back_btn: Button = $Margin/Card/Margin/VBox/HeaderHBox/BackButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
		Stage08IronPeakUITheme.apply_yellow_button_style(continue_btn)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		Stage08IronPeakUITheme.apply_outline_button_style(back_btn)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(LOADOUT_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)
