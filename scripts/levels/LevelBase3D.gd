extends Node3D
## LevelBase3D.gd
## 3D FPS Game Level Controller managing combat loop, metric tracking, and Supabase score synchronization.

const GameConstants = preload("res://scripts/utilities/constants.gd")

@export var stage_id: int = 1
@export var stage_name: String = "OPERATION FIRST CONTACT (3D)"

# Tactical Combat Metrics
var shots_fired: int = 0
var shots_hit: int = 0
var targets_eliminated: int = 0
var total_targets: int = 0
var elapsed_time: float = 0.0
var is_stage_active: bool = false
var is_stage_finished: bool = false
var movement_state_name: String = "IDLE"

# Scene Nodes
@onready var player: Player3D = $Player3D
@onready var enemies_container: Node3D = $Enemies
@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = get_node_or_null("HUD/TopBar/TimerLabel")
@onready var targets_label: Label = get_node_or_null("HUD/TopBar/TargetsLabel")
@onready var accuracy_label: Label = get_node_or_null("HUD/TopBar/AccuracyLabel")
@onready var health_bar: ProgressBar = get_node_or_null("HUD/BottomBar/HealthBar")
@onready var ammo_label: Label = get_node_or_null("HUD/BottomBar/AmmoLabel")
@onready var summary_dialog: Control = get_node_or_null("HUD/StageSummaryDialog")

func _ready() -> void:
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("get_current_stage_id"):
		if stage_id <= 1 and stg_mgr.get_current_stage_id() > 1:
			stage_id = stg_mgr.get_current_stage_id()
		else:
			stg_mgr.set_current_stage_id(stage_id)
		var info = stg_mgr.get_stage_info(stage_id)
		if info and info.has("name"):
			stage_name = info["name"]
	elif get_tree().has_meta("selected_stage_id"):
		stage_id = int(get_tree().get_meta("selected_stage_id"))
		
	_initialize_level()

func _initialize_level() -> void:
	shots_fired = 0
	shots_hit = 0
	targets_eliminated = 0
	elapsed_time = 0.0
	is_stage_active = true
	is_stage_finished = false
	
	var snd_mgr = get_node_or_null("/root/SoundManager")
	if snd_mgr and snd_mgr.has_method("stop_all"):
		snd_mgr.stop_all()
		
	var shoot_sys = get_node_or_null("/root/ShootingSystem")
	if shoot_sys and shoot_sys.has_method("clear_all"):
		shoot_sys.clear_all()
	
	# Transition Game State Machine to PLAYING (respecting State Machine whitelist)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.current_state == GameConstants.GameState.BOOT:
			gm.change_state(GameConstants.GameState.MAIN_MENU)
		gm.change_state(GameConstants.GameState.PLAYING)
	
	if player:
		player.add_to_group("player")
		player.shot_fired.connect(_on_player_shot_fired)
		player.shot_hit.connect(_on_player_shot_hit)
		player.health_changed.connect(_on_player_health_changed)
		player.ammo_changed.connect(_on_player_ammo_changed)
		player.operative_died.connect(_on_player_died)
		if player.has_signal("movement_state_changed"):
			player.movement_state_changed.connect(_on_player_movement_state_changed)
		if player.has_signal("damage_received"):
			player.damage_received.connect(_on_player_damage_received)
	
	total_targets = 0
	if enemies_container:
		for enemy in enemies_container.get_children():
			if enemy.has_signal("target_destroyed"):
				total_targets += 1
				enemy.target_destroyed.connect(_on_enemy_destroyed)
				
	if summary_dialog == null and hud and hud.has_node("StageSummaryDialog"):
		summary_dialog = hud.get_node("StageSummaryDialog")
		
	if summary_dialog:
		summary_dialog.visible = false
		summary_dialog.next_stage_requested.connect(_on_next_stage_requested)
		summary_dialog.retry_stage_requested.connect(_on_retry_stage_requested)
		summary_dialog.main_menu_requested.connect(_on_main_menu_requested)
		
	if hud and hud.has_method("setup_stage_info"):
		hud.setup_stage_info(stage_id, stage_name, total_targets)
		
	var sm = get_node_or_null("/root/SupabaseManager")
	if sm:
		sm.stage_score_saved.connect(_on_cloud_score_saved)
		sm.api_request_failed.connect(_on_cloud_api_failed)
		
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
	if timer_label:
		timer_label.text = "TIME: %02d:%02d.%d" % [minutes, seconds, ms]
	if hud and hud.has_method("update_timer"):
		hud.update_timer(elapsed_time)

func _update_hud() -> void:
	var accuracy: float = 0.0
	var sc = get_node_or_null("/root/ScoreCalculator")
	if sc and sc.has_method("calculate_accuracy"):
		accuracy = sc.calculate_accuracy(shots_fired, shots_hit)
	elif shots_fired > 0:
		accuracy = (float(shots_hit) / float(shots_fired)) * 100.0
		
	if targets_label:
		targets_label.text = "[STAGE %d: %s] HOSTILES: %d / %d | STANCE: [%s]" % [stage_id, stage_name, targets_eliminated, total_targets, movement_state_name]
	if accuracy_label:
		accuracy_label.text = "ACCURACY: %.1f%%" % accuracy
		
	if hud:
		if hud.has_method("update_hostiles_count"):
			hud.update_hostiles_count(targets_eliminated, total_targets)
		if hud.has_method("update_accuracy"):
			hud.update_accuracy(accuracy)
		if hud.has_method("update_stance"):
			hud.update_stance(movement_state_name)

func _on_player_movement_state_changed(new_state: int, _old_state: int) -> void:
	match new_state:
		GameConstants.MovementState.IDLE:
			movement_state_name = "IDLE"
		GameConstants.MovementState.WALKING:
			movement_state_name = "WALKING"
		GameConstants.MovementState.RUNNING:
			movement_state_name = "RUNNING"
		GameConstants.MovementState.SPRINTING:
			movement_state_name = "SPRINTING"
		GameConstants.MovementState.JUMPING:
			movement_state_name = "JUMPING"
		GameConstants.MovementState.FALLING:
			movement_state_name = "FALLING"
		GameConstants.MovementState.CROUCHING:
			movement_state_name = "CROUCHING"
		_:
			movement_state_name = "ACTIVE"
	_update_hud()

func _on_player_shot_fired() -> void:
	shots_fired += 1
	_update_hud()
	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_weapon_fired()

func _on_player_shot_hit(_target: Node, is_headshot: bool) -> void:
	shots_hit += 1
	_update_hud()
	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_shot_hit(is_headshot)

func _on_player_damage_received(amount: int, attacker_pos: Vector3) -> void:
	if hud and "combat_feedback" in hud and hud.combat_feedback and player and player.camera_mount:
		hud.combat_feedback.on_player_damaged(amount, attacker_pos, player.global_position, player.camera_mount.global_transform)

func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if hud and hud.has_method("update_health"):
		hud.update_health(current_hp, max_hp)

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	var weapon_name: String = "ASSAULT RIFLE"
	var is_sec: bool = false
	var reserve: int = 90
	if player and player.has_method("get_weapon_manager"):
		var wm = player.get_weapon_manager()
		if wm and wm.has_method("get_current_weapon"):
			var cur = wm.get_current_weapon()
			if cur and cur.data:
				weapon_name = cur.data.weapon_name.to_upper()
				reserve = cur.reserve_ammo
				is_sec = (cur.data.weapon_type == GameConstants.WeaponType.PISTOL)
	if ammo_label:
		ammo_label.text = "[%s] AMMO: %d / %d (Q: Switch | R: Reload)" % [weapon_name, current_ammo, max_ammo]
	if hud and hud.has_method("update_ammo"):
		hud.update_ammo(current_ammo, max_ammo, weapon_name, is_sec, reserve)

func _on_enemy_destroyed(_enemy: Node) -> void:
	targets_eliminated += 1
	_update_hud()
	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_enemy_eliminated("HOSTILE", 500)
	
	if targets_eliminated >= total_targets:
		_complete_stage(true)

func _on_player_died() -> void:
	_complete_stage(false)


func _complete_stage(is_victory: bool) -> void:
	if is_stage_finished:
		return
	is_stage_finished = true
	is_stage_active = false
	
	# Stop all audio immediately
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("stop_all"):
		sm.stop_all()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if player:
		player.is_active = false
		player.is_firing_held = false
		player._semi_auto_shot_taken = false
		if player.camera_mount and player.camera_mount.has_method("set_mouse_captured"):
			player.camera_mount.set_mouse_captured(false)
			
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state"):
		var target_state = GameConstants.GameState.MISSION_COMPLETE if is_victory else GameConstants.GameState.GAME_OVER
		gm.change_state(target_state)
		
	var accuracy: float = 0.0
	var sc = get_node_or_null("/root/ScoreCalculator")
	if sc and sc.has_method("calculate_accuracy"):
		accuracy = sc.calculate_accuracy(shots_fired, shots_hit)
	elif shots_fired > 0:
		accuracy = (float(shots_hit) / float(shots_fired)) * 100.0
		
	var remaining_hp: int = player.current_health if player else 0
	
	var breakdown: Dictionary = {}
	if sc and sc.has_method("get_score_breakdown"):
		breakdown = sc.get_score_breakdown(
			targets_eliminated,
			accuracy,
			elapsed_time,
			remaining_hp
		)
	else:
		breakdown = {"final_score": 1000}
	
	if summary_dialog:
		summary_dialog.display_summary(stage_id, breakdown, is_victory)
		
	if is_victory:
		print("[LevelBase3D] Submitting stage score to Supabase...")
		var sup = get_node_or_null("/root/SupabaseManager")
		if sup and sup.is_authenticated():
			sup.save_stage_score(
				stage_id,
				breakdown.get("final_score", 0),
				accuracy,
				elapsed_time
			)
		else:
			if summary_dialog:
				summary_dialog.set_cloud_sync_status(false, "Guest/Offline mode. Log in to sync high scores.")

func _on_cloud_score_saved(result_data: Dictionary) -> void:
	print("[LevelBase3D] Supabase confirmed stage score record: ", result_data)
	if summary_dialog:
		summary_dialog.set_cloud_sync_status(true)

func _on_cloud_api_failed(endpoint: String, error_msg: String) -> void:
	if endpoint == "save_stage_score" and summary_dialog:
		summary_dialog.set_cloud_sync_status(false, error_msg)

func _on_next_stage_requested() -> void:
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("load_next_stage"):
		stg_mgr.load_next_stage()
	else:
		var next_stage: int = stage_id + 1
		get_tree().set_meta("selected_stage_id", next_stage)
		if next_stage == 2 and ResourceLoader.exists("res://scenes/stages/Stage02.tscn"):
			get_tree().change_scene_to_file("res://scenes/stages/Stage02.tscn")
		elif get_tree().current_scene:
			get_tree().reload_current_scene()
		elif ResourceLoader.exists("res://scenes/Level1.tscn"):
			get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_retry_stage_requested() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("stop_all"):
		sm.stop_all()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state"):
		gm.change_state(GameConstants.GameState.PLAYING)
	var stg_mgr = get_node_or_null("/root/StageManager")
	if stg_mgr and stg_mgr.has_method("restart_current_stage"):
		stg_mgr.restart_current_stage()
	elif get_tree().current_scene:
		get_tree().reload_current_scene()
	elif ResourceLoader.exists("res://scenes/Level1.tscn"):
		get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_main_menu_requested() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists("res://scenes/MainMenu.tscn"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	elif ResourceLoader.exists("res://scenes/ui/MainMenu.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
