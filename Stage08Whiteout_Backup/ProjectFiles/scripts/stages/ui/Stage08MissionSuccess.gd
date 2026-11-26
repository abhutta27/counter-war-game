class_name Stage08MissionSuccess
extends Control
## Stage 08 — Operation Whiteout Dedicated Mission Success Screen
## Strictly implements art_reference/stage08/05_mission_success.png

signal continue_requested
signal view_stats_requested

@onready var mission_time_label: Label = $CenterContainer/MainCard/Margin/VBox/StatsPanel/Margin/HBox/StatsColumn/TimeValue
@onready var enemies_label: Label = $CenterContainer/MainCard/Margin/VBox/StatsPanel/Margin/HBox/StatsColumn/EnemiesValue
@onready var shots_label: Label = $CenterContainer/MainCard/Margin/VBox/StatsPanel/Margin/HBox/StatsColumn/ShotsValue
@onready var accuracy_label: Label = $CenterContainer/MainCard/Margin/VBox/StatsPanel/Margin/HBox/StatsColumn/AccuracyValue

@onready var score_label: Label = $CenterContainer/MainCard/Margin/VBox/ScoreSection/ScoreValue
@onready var stars_label: Label = $CenterContainer/MainCard/Margin/VBox/ScoreSection/StarsRow/StarsLabel

@onready var view_stats_btn: Button = $CenterContainer/MainCard/Margin/VBox/ButtonHBox/ViewStatsButton
@onready var continue_btn: Button = $CenterContainer/MainCard/Margin/VBox/ButtonHBox/ContinueButton

@onready var detailed_stats_modal: PanelContainer = $CenterContainer/DetailedStatsModal
@onready var detailed_stats_text: Label = $CenterContainer/DetailedStatsModal/Margin/VBox/StatsList

var _recorded_metrics: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()


func _setup_buttons() -> void:
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	if view_stats_btn:
		view_stats_btn.pressed.connect(_on_view_stats_pressed)


func _apply_styles() -> void:
	var main_card := $CenterContainer/MainCard as PanelContainer
	if main_card:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.04, 0.07, 0.95)
		sb.border_color = Color(0.18, 0.45, 0.75, 0.85)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 14
		main_card.add_theme_stylebox_override("panel", sb)

	var stats_panel := $CenterContainer/MainCard/Margin/VBox/StatsPanel as PanelContainer
	if stats_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.06, 0.10, 0.85)
		sb.border_color = Color(0.15, 0.32, 0.50, 0.70)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		stats_panel.add_theme_stylebox_override("panel", sb)

	if continue_btn:
		continue_btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_glow_button())
		continue_btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_glow_button(Color(0.08, 0.52, 0.96, 1.0), Color(0.3, 0.75, 1.0, 1.0)))

	if view_stats_btn:
		view_stats_btn.add_theme_stylebox_override("normal", Stage08WhiteoutUITheme.create_outline_button())
		view_stats_btn.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_outline_button(Color(0.06, 0.14, 0.22, 0.95), Color(0.25, 0.60, 0.90, 0.95)))


func display_results(stage_id: int, breakdown: Dictionary) -> void:
	_recorded_metrics = breakdown
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Format Time: MM:SS
	var elapsed: float = float(breakdown.get("elapsed_time", 0.0))
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	if mission_time_label:
		mission_time_label.text = "%02d:%02d" % [mins, secs]

	# Enemies eliminated (kills)
	var kills: int = int(breakdown.get("kills", breakdown.get("targets_eliminated", 12)))
	if enemies_label:
		enemies_label.text = str(kills)

	# Shots fired
	var shots: int = int(breakdown.get("shots_fired", 0))
	if shots_label:
		shots_label.text = str(shots)

	# Accuracy
	var accuracy: float = float(breakdown.get("accuracy", 0.0))
	if accuracy == 0.0 and shots > 0:
		var hits: int = int(breakdown.get("shots_hit", 0))
		accuracy = (float(hits) / float(shots)) * 100.0
	if accuracy_label:
		accuracy_label.text = "%.0f%%" % accuracy

	# Final Score
	var final_score: int = int(breakdown.get("final_score", 3850))
	if score_label:
		score_label.text = _format_number_with_commas(final_score)

	# Stars
	var stars_count: int = int(breakdown.get("stars", 3))
	if stars_count <= 0:
		if final_score >= 3000:
			stars_count = 3
		elif final_score >= 1500:
			stars_count = 2
		else:
			stars_count = 1
	if stars_label:
		match stars_count:
			3: stars_label.text = "★   ★   ★"
			2: stars_label.text = "★   ★   ☆"
			_: stars_label.text = "★   ☆   ☆"

	# Build detailed modal text
	if detailed_stats_text:
		var headshots: int = int(breakdown.get("headshots", 0))
		var streak: int = int(breakdown.get("max_streak", 0))
		detailed_stats_text.text = (
			"STAGE: 08 — OPERATION WHITEOUT\n" +
			"STATUS: MISSION ACCOMPLISHED // ANOMALOUS SIGNAL SECURED\n\n" +
			"KILLS CONFIRMED: %d\n" % kills +
			"HEADSHOTS: %d\n" % headshots +
			"SHOTS FIRED: %d\n" % shots +
			"SHOT ACCURACY: %.1f%%\n" % accuracy +
			"MISSION TIME: %02d:%02d\n" % [mins, secs] +
			"BASE SCORE: %d\n" % int(breakdown.get("base_score", final_score)) +
			"TOTAL SCORE: %d\n" % final_score
		)

	# Record completed stage in ProfileManager
	var profile_manager = get_node_or_null("/root/ProfileManager")
	if profile_manager and profile_manager.has_method("record_stage_completed"):
		profile_manager.record_stage_completed(stage_id)


func _format_number_with_commas(num: int) -> String:
	var s := str(num)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res


func _on_continue_pressed() -> void:
	continue_requested.emit()
	get_tree().paused = false
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("set_current_stage_id"):
		stg_mgr.set_current_stage_id(8)
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")


func _on_view_stats_pressed() -> void:
	view_stats_requested.emit()
	if detailed_stats_modal:
		detailed_stats_modal.visible = !detailed_stats_modal.visible
