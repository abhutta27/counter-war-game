class_name Stage08IronPeakSettings
extends Control
## Stage 08 — Operation Iron Peak Dedicated Settings Screen / Modal
## Implements the bottom-right settings panel of the UI collage.

signal closed()

@onready var tab_graphics: Button = $Card/Margin/VBox/ContentHBox/TabsVBox/GraphicsTab
@onready var tab_audio: Button = $Card/Margin/VBox/ContentHBox/TabsVBox/AudioTab
@onready var tab_controls: Button = $Card/Margin/VBox/ContentHBox/TabsVBox/ControlsTab
@onready var tab_gameplay: Button = $Card/Margin/VBox/ContentHBox/TabsVBox/GameplayTab

@onready var options_graphics: VBoxContainer = $Card/Margin/VBox/ContentHBox/OptionsVBox/GraphicsOptions
@onready var options_audio: VBoxContainer = $Card/Margin/VBox/ContentHBox/OptionsVBox/AudioOptions
@onready var options_controls: VBoxContainer = $Card/Margin/VBox/ContentHBox/OptionsVBox/ControlsOptions
@onready var options_gameplay: VBoxContainer = $Card/Margin/VBox/ContentHBox/OptionsVBox/GameplayOptions

@onready var vsync_check: CheckBox = $Card/Margin/VBox/ContentHBox/OptionsVBox/GraphicsOptions/VSyncRow/CheckBox
@onready var motion_blur_check: CheckBox = $Card/Margin/VBox/ContentHBox/OptionsVBox/GraphicsOptions/MotionBlurRow/CheckBox
@onready var quality_btn: Button = $Card/Margin/VBox/ContentHBox/OptionsVBox/GraphicsOptions/QualityRow/ValueButton
@onready var fps_btn: Button = $Card/Margin/VBox/ContentHBox/OptionsVBox/GraphicsOptions/FpsRow/ValueButton

@onready var apply_btn: Button = $Card/Margin/VBox/FooterHBox/ApplyButton
@onready var default_btn: Button = $Card/Margin/VBox/FooterHBox/DefaultButton
@onready var back_btn: Button = $Card/Margin/VBox/HeaderHBox/BackButton

var current_tab: String = "graphics"
var quality_options: Array[String] = ["Low", "Medium", "High", "Ultra"]
var quality_idx: int = 2
var fps_options: Array[String] = ["30 FPS", "60 FPS", "120 FPS", "Unlimited"]
var fps_idx: int = 1

func _ready() -> void:
	_setup_buttons()
	_apply_styles()
	_select_tab("graphics")

func _setup_buttons() -> void:
	if tab_graphics: tab_graphics.pressed.connect(func(): _select_tab("graphics"))
	if tab_audio: tab_audio.pressed.connect(func(): _select_tab("audio"))
	if tab_controls: tab_controls.pressed.connect(func(): _select_tab("controls"))
	if tab_gameplay: tab_gameplay.pressed.connect(func(): _select_tab("gameplay"))

	if quality_btn: quality_btn.pressed.connect(_cycle_quality)
	if fps_btn: fps_btn.pressed.connect(_cycle_fps)
	if apply_btn: apply_btn.pressed.connect(_apply_settings)
	if default_btn: default_btn.pressed.connect(_reset_defaults)
	if back_btn: back_btn.pressed.connect(_close)

func _apply_styles() -> void:
	if apply_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(apply_btn)
	if default_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(default_btn)
	if back_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(back_btn)

func _select_tab(tab_name: String) -> void:
	current_tab = tab_name
	var tabs: Dictionary = {
		"graphics": [tab_graphics, options_graphics],
		"audio": [tab_audio, options_audio],
		"controls": [tab_controls, options_controls],
		"gameplay": [tab_gameplay, options_gameplay]
	}
	for t in tabs.keys():
		var btn: Button = tabs[t][0]
		var panel: Control = tabs[t][1]
		if panel:
			panel.visible = (t == tab_name)
		if btn:
			if t == tab_name:
				Stage08IronPeakUITheme.apply_yellow_button_style(btn)
			else:
				Stage08IronPeakUITheme.apply_outline_button_style(btn)

func _cycle_quality() -> void:
	quality_idx = (quality_idx + 1) % quality_options.size()
	if quality_btn:
		quality_btn.text = "<  " + quality_options[quality_idx] + "  >"

func _cycle_fps() -> void:
	fps_idx = (fps_idx + 1) % fps_options.size()
	if fps_btn:
		fps_btn.text = "<  " + fps_options[fps_idx] + "  >"

func _apply_settings() -> void:
	# Apply actual engine settings
	if vsync_check:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_check.button_pressed else DisplayServer.VSYNC_DISABLED)
	if fps_idx == 0:
		Engine.max_fps = 30
	elif fps_idx == 1:
		Engine.max_fps = 60
	elif fps_idx == 2:
		Engine.max_fps = 120
	else:
		Engine.max_fps = 0
	_close()

func _reset_defaults() -> void:
	quality_idx = 2
	fps_idx = 1
	if quality_btn: quality_btn.text = "<  High  >"
	if fps_btn: fps_btn.text = "<  60 FPS  >"
	if vsync_check: vsync_check.button_pressed = true
	if motion_blur_check: motion_blur_check.button_pressed = true

func _close() -> void:
	visible = false
	closed.emit()
