class_name Stage08IronPeakUITheme
extends RefCounted
## Stage 08 — Operation Iron Peak UI Theme Helper
## Provides the color palette and styled controls matching the UI Collage reference:
## Dark Navy Blue, Steel Blue, Bright Golden Yellow accents, Glowing Electric Blue borders.

const COLOR_PRIMARY_NAVY := Color(0.015, 0.035, 0.08, 0.94)
const COLOR_SECONDARY_STEEL := Color(0.07, 0.15, 0.26, 0.95)
const COLOR_ACCENT_YELLOW := Color(1.0, 0.78, 0.05, 1.0)
const COLOR_ACCENT_YELLOW_HOVER := Color(1.0, 0.88, 0.25, 1.0)
const COLOR_ACCENT_YELLOW_PRESSED := Color(0.85, 0.64, 0.02, 1.0)
const COLOR_BORDER_ELECTRIC := Color(0.18, 0.58, 0.98, 0.90)
const COLOR_BORDER_SUBTLE := Color(0.12, 0.34, 0.58, 0.70)
const COLOR_TEXT_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TEXT_MUTED := Color(0.75, 0.84, 0.92, 0.85)
const COLOR_TEXT_DARK := Color(0.04, 0.06, 0.08, 1.0)
const COLOR_SUCCESS_GREEN := Color(0.12, 0.82, 0.32, 1.0)
const COLOR_FAILED_RED := Color(0.92, 0.15, 0.15, 1.0)

static func create_panel(bg: Color = COLOR_PRIMARY_NAVY, border: Color = COLOR_BORDER_ELECTRIC, border_width: int = 2, corner_radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_color = Color(0.0, 0.2, 0.5, 0.35)
	sb.shadow_size = 8
	return sb

static func create_yellow_button(bg: Color = COLOR_ACCENT_YELLOW, text_col: Color = COLOR_TEXT_DARK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(1.0, 0.95, 0.6, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(1.0, 0.78, 0.0, 0.35)
	sb.shadow_size = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func create_outline_button(bg: Color = COLOR_SECONDARY_STEEL, border: Color = COLOR_BORDER_ELECTRIC) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func apply_yellow_button_style(btn: Button) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", create_yellow_button(COLOR_ACCENT_YELLOW))
	btn.add_theme_stylebox_override("hover", create_yellow_button(COLOR_ACCENT_YELLOW_HOVER))
	btn.add_theme_stylebox_override("pressed", create_yellow_button(COLOR_ACCENT_YELLOW_PRESSED))
	btn.add_theme_stylebox_override("focus", create_yellow_button(COLOR_ACCENT_YELLOW_HOVER))
	btn.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_focus_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_DARK)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func apply_outline_button_style(btn: Button) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", create_outline_button(COLOR_SECONDARY_STEEL, COLOR_BORDER_SUBTLE))
	btn.add_theme_stylebox_override("hover", create_outline_button(Color(0.12, 0.26, 0.44, 0.95), COLOR_BORDER_ELECTRIC))
	btn.add_theme_stylebox_override("pressed", create_outline_button(Color(0.05, 0.12, 0.22, 0.95), COLOR_BORDER_ELECTRIC))
	btn.add_theme_stylebox_override("focus", create_outline_button(Color(0.12, 0.26, 0.44, 0.95), COLOR_BORDER_ELECTRIC))
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
