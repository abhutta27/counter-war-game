class_name Stage08IronPeakIntroRebuild
extends Control
## Stage 08 — Operation Iron Peak Rebuilt Intro Screen
## Isolated, pixel-accurate implementation matching assets/ui/stage08_iron_peak/screens/01_intro.png.

const BRIEFING_SCENE := "res://scenes/stages/Stage08IronPeakBriefing.tscn"
const LOADOUT_SCENE := "res://scenes/stages/Stage08IronPeakLoadout.tscn"
const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const HQ_SCENE := "res://scenes/StageSelection.tscn"

@onready var start_btn: Button = $AspectContainer/Background/StartButton
@onready var briefing_btn: Button = $AspectContainer/Background/BriefingButton
@onready var back_btn: Button = $AspectContainer/Background/BackButton
@onready var settings_btn: Button = $AspectContainer/Background/SettingsButton
@onready var settings_modal: Control = get_node_or_null("SettingsModal")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_buttons()
	if start_btn:
		start_btn.grab_focus()

func _setup_buttons() -> void:
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
		_setup_button_feedback(start_btn)
	if briefing_btn:
		briefing_btn.pressed.connect(_on_briefing_pressed)
		_setup_button_feedback(briefing_btn)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_setup_button_feedback(back_btn)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		_setup_button_feedback(settings_btn)

func _setup_button_feedback(btn: Button) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(_play_hover_sound)

func _play_hover_sound() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui_hover"):
		sm.play_ui_hover()

func _play_click_sound() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui_click"):
		sm.play_ui_click()

func _on_start_pressed() -> void:
	_play_click_sound()
	print("[Stage08Intro] START MISSION pressed -> Navigating to Loadout/Stage")
	if ResourceLoader.exists(LOADOUT_SCENE):
		get_tree().change_scene_to_file(LOADOUT_SCENE)
	else:
		get_tree().change_scene_to_file(STAGE_SCENE)

func _on_briefing_pressed() -> void:
	_play_click_sound()
	print("[Stage08Intro] MISSION BRIEFING pressed -> Navigating to Briefing")
	if ResourceLoader.exists(BRIEFING_SCENE):
		get_tree().change_scene_to_file(BRIEFING_SCENE)

func _on_back_pressed() -> void:
	_play_click_sound()
	print("[Stage08Intro] BACK pressed -> Returning to Operations HQ")
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", 8)
	get_tree().change_scene_to_file(HQ_SCENE)

func _on_settings_pressed() -> void:
	_play_click_sound()
	if settings_modal:
		settings_modal.visible = not settings_modal.visible
		print("[Stage08Intro] SETTINGS toggled: %s" % str(settings_modal.visible))
	else:
		print("[Stage08Intro] SETTINGS pressed")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_modal and settings_modal.visible:
			settings_modal.visible = false
			get_viewport().set_input_as_handled()
		else:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
