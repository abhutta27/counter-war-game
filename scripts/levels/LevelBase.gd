extends Node2D
## LevelBase.gd
## Base Game Level Controller managing combat loop, metric tracking, and Supabase score synchronization.

class_name LevelBase

@export var stage_id: int = 1
@export var stage_name: String = "OPERATION FIRST CONTACT"

# Tactical Combat Metrics
var shots_fired: int = 0
var shots_hit: int = 0
var targets_eliminated: int = 0
var total_targets: int = 0
var elapsed_time: float = 0.0
var is_stage_active: bool = false
var is_stage_finished: bool = false

# Scene Nodes
@onready var player: Node2D = $Player
@onready var targets_container: Node2D = $Targets
@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = $HUD/TopBar/TimerLabel
@onready var targets_label: Label = $HUD/TopBar/TargetsLabel
@onready var accuracy_label: Label = $HUD/TopBar/AccuracyLabel
@onready var health_bar: ProgressBar = $HUD/BottomBar/HealthBar
@onready var ammo_label: Label = $HUD/BottomBar/AmmoLabel
@onready var summary_dialog: Control = $HUD/StageSummaryDialog

func _ready() -> void:
	# Check if stage was selected from StageSelection screen
	if get_tree().has_meta("selected_stage_id"):
		stage_id = int(get_tree().get_meta("selected_stage_id"))
		
	_initialize_level()

func _initialize_level() -> void:
	shots_fired = 0
	shots_hit = 0
	targets_eliminated = 0
	elapsed_time = 0.0
	is_stage_active = true
	is_stage_finished = false
	
	# Connect player signals
	if player:
		player.shot_fired.connect(_on_player_shot_fired)
		player.shot_hit.connect(_on_player_shot_hit)
		player.health_changed.connect(_on_player_health_changed)
		player.ammo_changed.connect(_on_player_ammo_changed)
		player.operative_died.connect(_on_player_died)
	
	# Connect targets
	total_targets = 0
	if targets_container:
		for target in targets_container.get_children():
			if target.has_signal("target_destroyed"):
				total_targets += 1
				target.target_destroyed.connect(_on_target_destroyed)
				
	# Connect summary dialog callbacks
	if summary_dialog:
		summary_dialog.visible = false
		summary_dialog.next_stage_requested.connect(_on_next_stage_requested)
		summary_dialog.retry_stage_requested.connect(_on_retry_stage_requested)
		summary_dialog.main_menu_requested.connect(_on_main_menu_requested)
		
	# Connect Supabase Manager response signals
	if SupabaseManager:
		SupabaseManager.stage_score_saved.connect(_on_cloud_score_saved)
		SupabaseManager.api_request_failed.connect(_on_cloud_api_failed)
		
	_update_hud()

func _process(delta: float) -> void:
	if not is_stage_active or is_stage_finished:
		return
		
	elapsed_time += delta
	_update_timer_display()

func _update_timer_display() -> void:
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var ms := int((elapsed_time - int(elapsed_time)) * 10)
	timer_label.text = "TIME: %02d:%02d.%d" % [minutes, seconds, ms]

func _update_hud() -> void:
	var accuracy := ScoreCalculator.calculate_accuracy(shots_fired, shots_hit)
	targets_label.text = "HOSTILES: %d / %d" % [targets_eliminated, total_targets]
	accuracy_label.text = "ACCURACY: %.1f%%" % accuracy

func _on_player_shot_fired() -> void:
	shots_fired += 1
	_update_hud()

func _on_player_shot_hit(_target: Node2D, _is_headshot: bool) -> void:
	shots_hit += 1
	_update_hud()

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = "AMMO: %d / %d (R to Reload)" % [current_ammo, max_ammo]

func _on_target_destroyed(_target: Node2D) -> void:
	targets_eliminated += 1
	_update_hud()
	
	if targets_eliminated >= total_targets:
		_complete_stage(true)

func _on_player_died() -> void:
	_complete_stage(false)

## Ends stage, computes scores, triggers UI summary and posts to Supabase
func _complete_stage(is_victory: bool) -> void:
	if is_stage_finished:
		return
	is_stage_finished = true
	is_stage_active = false
	
	if player:
		player.is_active = false
		
	var accuracy := ScoreCalculator.calculate_accuracy(shots_fired, shots_hit)
	var remaining_hp: int = player.current_health if player else 0
	
	# Compute complete score breakdown using ScoreCalculator Singleton
	var breakdown := ScoreCalculator.get_score_breakdown(
		targets_eliminated,
		accuracy,
		elapsed_time,
		remaining_hp
	)
	
	# Show summary dialog
	if summary_dialog:
		summary_dialog.display_summary(stage_id, breakdown, is_victory)
		
	# Post to Supabase if victory achieved
	if is_victory:
		print("[LevelBase] Submitting stage score to Supabase...")
		if SupabaseManager.is_authenticated():
			SupabaseManager.save_stage_score(
				stage_id,
				breakdown.final_score,
				accuracy,
				elapsed_time
			)
		else:
			if summary_dialog:
				summary_dialog.set_cloud_sync_status(false, "Offline/Guest session. Log in to sync high scores.")

func _on_cloud_score_saved(result_data: Dictionary) -> void:
	print("[LevelBase] Supabase confirmed stage score record: ", result_data)
	if summary_dialog:
		summary_dialog.set_cloud_sync_status(true)

func _on_cloud_api_failed(endpoint: String, error_msg: String) -> void:
	if endpoint == "save_stage_score" and summary_dialog:
		summary_dialog.set_cloud_sync_status(false, error_msg)

func _on_next_stage_requested() -> void:
	var next_stage: int = stage_id + 1
	get_tree().set_meta("selected_stage_id", next_stage)
	get_tree().reload_current_scene()

func _on_retry_stage_requested() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
