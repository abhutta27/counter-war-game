class_name Stage08IronPeakFailed
extends Control
## Stage 08 — Operation Iron Peak Mission Failed Screen
## Matches panel 6 of the reference UI collage:
## Red military alert banner, loss statistics, retry and abort actions.

const HQ_SCENE := "res://scenes/StageSelection.tscn"
const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const Stage08IronPeakUITheme = preload("res://scripts/stages/ui/Stage08IronPeakUITheme.gd")

@onready var hostiles_label: Label = $Margin/Card/Margin/VBox/StatsGrid/HostilesValue
@onready var time_label: Label = $Margin/Card/Margin/VBox/StatsGrid/TimeValue
@onready var retry_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/RetryButton
@onready var abort_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/AbortButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buttons()
	_apply_styles()
	visible = false

func _setup_buttons() -> void:
	if retry_btn:
		retry_btn.pressed.connect(_on_retry_pressed)
	if abort_btn:
		abort_btn.pressed.connect(_on_abort_pressed)

func _apply_styles() -> void:
	if retry_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(retry_btn)
	if abort_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(abort_btn)

func display_failure(time_survived: float = 60.0, enemies_killed: int = 0, total_enemies: int = 18) -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if hostiles_label:
		hostiles_label.text = "%d / %d" % [enemies_killed, total_enemies]
	
	if time_label:
		var mins: int = int(time_survived) / 60
		var secs: int = int(time_survived) % 60
		time_label.text = "%02d:%02d" % [mins, secs]

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE_SCENE)

func _on_abort_pressed() -> void:
	get_tree().paused = false
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("get_current_stage_id"):
		get_tree().set_meta("hq_return_stage_id", 8)
	get_tree().change_scene_to_file(HQ_SCENE)
