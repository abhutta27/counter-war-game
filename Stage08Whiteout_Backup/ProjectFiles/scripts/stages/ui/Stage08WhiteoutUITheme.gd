class_name Stage08WhiteoutUITheme
extends RefCounted
## Stage 08 Operation Whiteout UI Theme & Style Builder
## Strictly follows the approved tactical art references (dark navy glass, cyan highlights, high-tech military aesthetic).

static func get_bg_color() -> Color:
	return Color(0.02, 0.045, 0.07, 1.0)

static func get_panel_bg() -> Color:
	return Color(0.035, 0.075, 0.115, 0.90)

static func get_panel_border() -> Color:
	return Color(0.12, 0.28, 0.42, 0.75)

static func get_border_cyan() -> Color:
	return Color(0.18, 0.65, 0.95, 1.0)

static func get_primary_blue() -> Color:
	return Color(0.04, 0.42, 0.84, 1.0)

static func get_primary_hover() -> Color:
	return Color(0.08, 0.52, 0.96, 1.0)

static func get_text_white() -> Color:
	return Color(0.96, 0.98, 1.0, 1.0)

static func get_text_muted() -> Color:
	return Color(0.62, 0.74, 0.84, 1.0)


static func build() -> Theme:
	var stage_theme := Theme.new()
	stage_theme.default_font_size = 14
	stage_theme.set_color("font_color", "Label", get_text_muted())
	stage_theme.set_color("font_color", "Button", get_text_white())
	stage_theme.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	stage_theme.set_color("font_pressed_color", "Button", Color(0.85, 0.95, 1, 1))
	stage_theme.set_color("font_disabled_color", "Button", Color(0.42, 0.52, 0.62, 1.0))
	
	stage_theme.set_stylebox("panel", "PanelContainer", create_tactical_panel())
	stage_theme.set_stylebox("normal", "Button", create_outline_button())
	stage_theme.set_stylebox("hover", "Button", create_outline_button(Color(0.07, 0.14, 0.22, 0.95), Color(0.18, 0.58, 0.92, 0.95)))
	stage_theme.set_stylebox("pressed", "Button", create_outline_button(Color(0.02, 0.05, 0.08, 0.95), get_primary_blue()))
	stage_theme.set_stylebox("disabled", "Button", create_outline_button(Color(0.03, 0.05, 0.08, 0.5), Color(0.1, 0.16, 0.22, 0.5)))
	
	stage_theme.set_constant("separation", "VBoxContainer", 8)
	stage_theme.set_constant("separation", "HBoxContainer", 8)
	return stage_theme


static func create_tactical_panel(fill: Color = Color(0.035, 0.075, 0.115, 0.90), border: Color = Color(0.12, 0.28, 0.42, 0.75), corner_radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	return style


static func create_glow_button(fill: Color = Color(0.04, 0.42, 0.84, 1.0), border: Color = Color(0.18, 0.65, 0.95, 1.0), corner_radius: int = 4, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 18.0
	style.content_margin_top = 8.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 8.0
	return style


static func create_hud_card(fill: Color = Color(0.04, 0.07, 0.11, 0.88), border: Color = Color(0.18, 0.40, 0.60, 0.75), corner_radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


static func create_active_menu_button(fill: Color = Color(0.08, 0.46, 0.88, 1.0), border: Color = Color(0.25, 0.70, 1.0, 0.95), corner_radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	return style


static func create_failed_panel(fill: Color = Color(0.08, 0.04, 0.05, 0.88), border: Color = Color(0.65, 0.18, 0.18, 0.75), corner_radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style


static func create_outline_button(fill: Color = Color(0.04, 0.08, 0.12, 0.85), border: Color = Color(0.16, 0.32, 0.46, 0.80), corner_radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 16.0
	style.content_margin_top = 6.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 6.0
	return style


