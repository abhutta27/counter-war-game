extends Control
## StageSummaryDialog.gd
## International-standard military tactical debriefing modal shown at stage end.
## Displays mission victory / defeat debriefing, detailed stat breakdown cards,
## cloud synchronization status, and responsive tactical navigation buttons.

signal next_stage_requested()
signal retry_stage_requested()
signal main_menu_requested()

@onready var mission_status_label: Label = $Panel/VBox/Header/MissionStatusLabel
@onready var stage_name_label: Label = $Panel/VBox/Header/StageNameLabel

@onready var targets_detail: Label = $Panel/VBox/Grid/TargetsDetail
@onready var targets_points: Label = $Panel/VBox/Grid/TargetsPoints

@onready var accuracy_detail: Label = $Panel/VBox/Grid/AccuracyDetail
@onready var accuracy_points: Label = $Panel/VBox/Grid/AccuracyPoints

@onready var time_detail: Label = $Panel/VBox/Grid/TimeDetail
@onready var time_points: Label = $Panel/VBox/Grid/TimePoints

@onready var health_detail: Label = $Panel/VBox/Grid/HealthDetail
@onready var health_points: Label = $Panel/VBox/Grid/HealthPoints
@onready var mission_detail: Label = $Panel/VBox/Grid/MissionDetail
@onready var mission_points: Label = $Panel/VBox/Grid/MissionPoints

@onready var final_score_title: Label = $Panel/VBox/TotalContainer/FinalScoreTitle
@onready var final_score_label: Label = $Panel/VBox/TotalContainer/FinalScoreLabel
@onready var best_score_label: Label = $Panel/VBox/BestContainer/BestScoreLabel
@onready var new_best_label: Label = $Panel/VBox/NewBestLabel
@onready var cloud_status_label: Label = $Panel/VBox/CloudStatusLabel

@onready var next_btn: Button = $Panel/VBox/Actions/NextBtn
@onready var retry_btn: Button = $Panel/VBox/Actions/RetryBtn
@onready var menu_btn: Button = $Panel/VBox/Actions/MenuBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_btn.pressed.connect(func(): emit_signal("next_stage_requested"))
	retry_btn.pressed.connect(func(): emit_signal("retry_stage_requested"))
	menu_btn.pressed.connect(func(): emit_signal("main_menu_requested"))
	
	for btn in [next_btn, retry_btn, menu_btn]:
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Populate score breakdown and display dialog
func display_summary(stage_id: int, breakdown: Dictionary, is_victory: bool) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var total_registered_stages = 6
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and "STAGE_REGISTRY" in stg_mgr:
		total_registered_stages = stg_mgr.STAGE_REGISTRY.size()
	elif stg_mgr and "TOTAL_STAGES" in stg_mgr:
		total_registered_stages = stg_mgr.TOTAL_STAGES
		
	var stg_name: String = "STAGE %d" % stage_id
	if stg_mgr and stg_mgr.has_method("get_stage_info"):
		var info = stg_mgr.get_stage_info(stage_id)
		if info.has("name"):
			stg_name = info["name"]
			
	stage_name_label.text = "OPERATION DEBRIEF: " + stg_name.to_upper()
	
	if is_victory:
		mission_status_label.text = "MISSION COMPLETE"
		mission_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 1.0))
		mission_status_label.add_theme_font_size_override("font_size", 24)
		stage_name_label.text = "OPERATION DEBRIEF: " + stg_name.to_upper()
		stage_name_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.98, 1.0))
		next_btn.visible = (stage_id < total_registered_stages)
		next_btn.text = "NEXT MISSION"
		retry_btn.text = "REPLAY STAGE"
		retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mission_detail.visible = true
		mission_points.visible = true
		final_score_title.text = "MISSION SCORE:"
	else:
		mission_status_label.text = "GAME OVER"
		mission_status_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.1, 1.0))
		mission_status_label.add_theme_font_size_override("font_size", 38)
		stage_name_label.text = "MISSION FAILED — YOU WERE ELIMINATED"
		stage_name_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68, 1.0))
		next_btn.visible = false
		retry_btn.text = "TRY AGAIN"
		retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mission_detail.visible = false
		mission_points.visible = false
		final_score_title.text = "UNSAVED ATTEMPT SCORE:"
		
	var kills := int(breakdown.get("kills", breakdown.get("targets_eliminated", 0)))
	var kill_score := int(breakdown.get("kill_score", breakdown.get("target_score", kills * 100)))
	targets_detail.text = "HOSTILES ELIMINATED      %d" % kills
	targets_points.text = "+%s PTS" % _format_number(kill_score)

	var headshot_count := int(breakdown.get("headshots", 0))
	var headshot_bonus := int(breakdown.get("headshot_bonus", 0))
	accuracy_detail.text = "HEADSHOT BONUS           %d" % headshot_count
	accuracy_points.text = "+%s PTS" % _format_number(headshot_bonus)

	var health_percent := float(breakdown.get("health_percent", 0.0))
	var health_bonus := int(breakdown.get("health_bonus", breakdown.get("health_score", 0)))
	time_detail.text = "HEALTH BONUS             %.1f%%" % health_percent
	time_points.text = "+%s PTS" % _format_number(health_bonus)

	var accuracy_val := float(breakdown.get("accuracy_percent", breakdown.get("accuracy", 0.0)))
	var accuracy_bonus := int(breakdown.get("accuracy_bonus", breakdown.get("accuracy_score", 0)))
	health_detail.text = "ACCURACY BONUS           %.1f%%" % accuracy_val
	health_points.text = "+%s PTS" % _format_number(accuracy_bonus)

	if is_victory:
		mission_detail.text = "MISSION COMPLETE"
		mission_points.text = "+%s PTS" % _format_number(int(breakdown.get("mission_complete_score", 0)))
	
	var final_score = breakdown.get("final_score", 0)
	final_score_label.text = "%s PTS" % _format_number(final_score)
	best_score_label.text = "%s PTS" % _format_number(int(breakdown.get("best_score", final_score)))
	new_best_label.visible = is_victory and bool(breakdown.get("is_new_best", false))

	cloud_status_label.text = "Local operative record saved." if is_victory else "UNSAVED ATTEMPT — Best, Career, completion and unlock progress were not changed."
	cloud_status_label.modulate = Color.LIME_GREEN if is_victory else Color.YELLOW

func _format_number(num: int) -> String:
	var s = str(absi(num))
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

## Called once Supabase confirms record save
func set_cloud_sync_status(success: bool, msg: String = "") -> void:
	if success:
		cloud_status_label.text = "Tactical Report Synchronized with Cloud Database."
		cloud_status_label.modulate = Color.LIME_GREEN
	else:
		cloud_status_label.text = "Cloud Sync Notice: " + msg
		cloud_status_label.modulate = Color.YELLOW
