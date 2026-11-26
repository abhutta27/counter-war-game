extends Control
## Stage 08 — Operation Whiteout Mission Briefing.
## Strictly faithful to art_reference/stage08/01_briefing.png.

const Stage08WhiteoutUITheme = preload("res://scripts/stages/ui/Stage08WhiteoutUITheme.gd")
const WHITEOUT_THEME = Stage08WhiteoutUITheme
const STAGE_SELECTION_SCENE_PATH := "res://scenes/StageSelection.tscn"
const STAGE_SELECTION_FALLBACK_PATH := "res://scenes/ui/StageSelection.tscn"
const LOADOUT_SCENE_PATH := "res://scenes/stages/Stage08WhiteoutLoadout.tscn"
const SINGLE_COLUMN_WIDTH := 900.0

@onready var back_button: Button = $OuterMargin/Page/Footer/BackButton
@onready var continue_button: Button = $OuterMargin/Page/Footer/ContinueButton
@onready var start_mission_button: Button = $OuterMargin/Page/MainCard/CardMargin/ColumnsHBox/RightColumn/ActionRow/StartMissionButton

# Compatibility properties for existing automated tests
@onready var briefing_grid: GridContainer = $OuterMargin/Page/MainScroll/BriefingGrid
@onready var header_status: Control = $OuterMargin/Page/Header/HeaderStatus


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = WHITEOUT_THEME.build()
	_apply_tactical_styles()

	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if start_mission_button and not start_mission_button.pressed.is_connected(_on_continue_pressed):
		start_mission_button.pressed.connect(_on_continue_pressed)
	if continue_button and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)


func _apply_tactical_styles() -> void:
	# Style Start Mission button as prominent glowing military blue
	if start_mission_button:
		var norm: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button()
		var hov: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button(Stage08WhiteoutUITheme.get_primary_hover(), Color(0.4, 0.85, 1.0))
		var prs: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button(Color(0.03, 0.32, 0.68, 1.0), Stage08WhiteoutUITheme.get_primary_blue())
		start_mission_button.add_theme_stylebox_override("normal", norm)
		start_mission_button.add_theme_stylebox_override("hover", hov)
		start_mission_button.add_theme_stylebox_override("pressed", prs)
		start_mission_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# Style Back button as tactical dark outline
	if back_button:
		var b_norm: StyleBoxFlat = Stage08WhiteoutUITheme.create_outline_button()
		var b_hov: StyleBoxFlat = Stage08WhiteoutUITheme.create_outline_button(Color(0.07, 0.14, 0.22, 0.95), Color(0.18, 0.58, 0.92, 0.95))
		back_button.add_theme_stylebox_override("normal", b_norm)
		back_button.add_theme_stylebox_override("hover", b_hov)
		back_button.add_theme_color_override("font_color", Stage08WhiteoutUITheme.get_text_muted())

	# Style Intel panel
	var intel_panel: PanelContainer = get_node_or_null("OuterMargin/Page/MainCard/CardMargin/ColumnsHBox/RightColumn/IntelPanel")
	if intel_panel:
		var intel_style: StyleBoxFlat = Stage08WhiteoutUITheme.create_tactical_panel(Color(0.025, 0.065, 0.1, 0.92), Color(0.14, 0.32, 0.48, 0.8), 6, 1)
		intel_panel.add_theme_stylebox_override("panel", intel_style)

	# Style Mountain image frame
	var mtn_frame: PanelContainer = get_node_or_null("OuterMargin/Page/MainCard/CardMargin/ColumnsHBox/RightColumn/MountainImageFrame")
	if mtn_frame:
		var mtn_style: StyleBoxFlat = Stage08WhiteoutUITheme.create_tactical_panel(Color(0.015, 0.03, 0.05, 0.95), Color(0.12, 0.26, 0.4, 0.85), 6, 1)
		mtn_frame.add_theme_stylebox_override("panel", mtn_style)

	# Style Top Header bar
	var header_bar: PanelContainer = get_node_or_null("OuterMargin/Page/HeaderBar")
	if header_bar:
		var head_style := StyleBoxFlat.new()
		head_style.bg_color = Color(0.025, 0.055, 0.085, 0.92)
		head_style.border_width_bottom = 1
		head_style.border_color = Color(0.12, 0.28, 0.44, 0.75)
		head_style.corner_radius_top_left = 6
		head_style.corner_radius_top_right = 6
		header_bar.add_theme_stylebox_override("panel", head_style)


func _on_back_pressed() -> void:
	get_tree().set_meta("hq_return_stage_id", 8)
	var target_scene := STAGE_SELECTION_SCENE_PATH
	if not ResourceLoader.exists(target_scene):
		target_scene = STAGE_SELECTION_FALLBACK_PATH
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_warning("Could not navigate to StageSelection (error %d)." % err)


func _on_continue_pressed() -> void:
	if not ResourceLoader.exists(LOADOUT_SCENE_PATH):
		push_warning("Loadout scene not found: %s" % LOADOUT_SCENE_PATH)
		return
	var err := get_tree().change_scene_to_file(LOADOUT_SCENE_PATH)
	if err != OK:
		push_warning("Could not navigate to Stage08WhiteoutLoadout.tscn (error %d)." % err)
