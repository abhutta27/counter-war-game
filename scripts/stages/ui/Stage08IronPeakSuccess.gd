class_name Stage08IronPeakSuccess
extends Control
## Stage 08 — Operation Iron Peak Mission Success Screen
## Matches panel 5 of the reference UI collage:
## Mission Success green banner, tactical performance stats, continue/replay actions.

const HQ_SCENE := "res://scenes/StageSelection.tscn"
const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const Stage08IronPeakUITheme = preload("res://scripts/stages/ui/Stage08IronPeakUITheme.gd")

@onready var hostiles_label: Label = $Margin/Card/Margin/VBox/StatsGrid/HostilesValue
@onready var time_label: Label = $Margin/Card/Margin/VBox/StatsGrid/TimeValue
@onready var rating_label: Label = $Margin/Card/Margin/VBox/StatsGrid/RatingValue
@onready var continue_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/ContinueButton
@onready var replay_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/ReplayButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()
	visible = false

func _setup_buttons() -> void:
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	if replay_btn:
		replay_btn.pressed.connect(_on_replay_pressed)

func _apply_styles() -> void:
	if continue_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(continue_btn)
	if replay_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(replay_btn)

func display_success(time_elapsed: float = 120.0, enemies_killed: int = 18, total_enemies: int = 18) -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if hostiles_label:
		hostiles_label.text = "%d / %d (100%%)" % [enemies_killed, total_enemies]
	
	if time_label:
		var mins: int = int(time_elapsed) / 60
		var secs: int = int(time_elapsed) % 60
		time_label.text = "%02d:%02d" % [mins, secs]
		
	if rating_label:
		rating_label.text = "S-RANK [OUTSTANDING]"
	
	# Update ProfileManager / StageManager if present
	var pm = get_node_or_null("/root/ProfileManager")
	if pm and pm.has_method("complete_stage"):
		pm.complete_stage(8)
	var sm = get_node_or_null("/root/StageManager")
	if sm and sm.has_method("mark_stage_completed"):
		sm.mark_stage_completed(8)

func _on_continue_pressed() -> void:
	get_tree().paused = false
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", 8)
	get_tree().change_scene_to_file(HQ_SCENE)

func _on_replay_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE_SCENE)
