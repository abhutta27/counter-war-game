extends Node3D
## LevelBase3D.gd
## 3D FPS Game Level Controller managing combat loop, metric tracking, and Supabase score synchronization.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const SCORE_PER_KILL: int = 100
const SCORE_PER_HEADSHOT: int = 50

signal player_recovered_from_out_of_bounds(fallen_position: Vector3, recovery_position: Vector3)

@export var stage_id: int = 1
@export var stage_name: String = "OPERATION FIRST CONTACT (3D)"

@export_category("Out Of Bounds Recovery")
## Kept below the lowest legitimate floor for the current stage.
@export var out_of_bounds_y: float = -8.0
## X/Z limits reject unsafe checkpoints and recover a Player that somehow
## bypasses the physical perimeter.
@export var recovery_bounds_enabled: bool = false
@export var recovery_bounds_min: Vector2 = Vector2(-40.0, -40.0)
@export var recovery_bounds_max: Vector2 = Vector2(40.0, 40.0)
@export var recovery_bounds_margin: float = 2.0
## Optional because an authored stage may already have a complete perimeter.
@export var physical_boundaries_enabled: bool = false
@export var physical_boundary_height: float = 24.0
@export var physical_boundary_center_y: float = 6.0
@export var physical_boundary_thickness: float = 1.0
@export var safe_position_stable_time: float = 0.35
@export var recovery_height_offset: float = 0.20

# Tactical Combat Metrics
var shots_fired: int = 0
var shots_hit: int = 0
var kills: int = 0
var headshots: int = 0
var current_mission_score: int = 0
var targets_eliminated: int = 0
var total_targets: int = 0
var elapsed_time: float = 0.0
var is_stage_active: bool = false
var is_stage_finished: bool = false
var movement_state_name: String = "IDLE"
var _counted_enemy_ids: Dictionary = {}
var last_safe_position: Vector3 = Vector3.ZERO
var _safe_position_time: float = 0.0
var _recovery_cooldown: float = 0.0
var _has_safe_position: bool = false

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
	kills = 0
	headshots = 0
	current_mission_score = 0
	targets_eliminated = 0
	_counted_enemy_ids.clear()
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
		_initialize_player_recovery()
	
	total_targets = 0
	if enemies_container:
		for enemy in enemies_container.get_children():
			# Enemy3D reports confirmed lethal state through enemy_died. Keep the
			# legacy target_destroyed path for older target scenes.
			if enemy.has_signal("enemy_died"):
				total_targets += 1
				enemy.connect("enemy_died", _on_enemy_destroyed.bind(enemy))
			elif enemy.has_signal("target_destroyed"):
				total_targets += 1
				enemy.connect("target_destroyed", _on_enemy_destroyed)
				
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

	_update_player_recovery(delta)
	elapsed_time += delta
	_update_timer_display()

func _initialize_player_recovery() -> void:
	last_safe_position = player.global_position
	_safe_position_time = 0.0
	_recovery_cooldown = 0.0
	_has_safe_position = true
	if physical_boundaries_enabled:
		_build_physical_recovery_boundaries()

func _update_player_recovery(delta: float) -> void:
	if not player or not is_instance_valid(player) or not player.is_active or player.current_health <= 0:
		return
	_recovery_cooldown = maxf(0.0, _recovery_cooldown - delta)
	if _recovery_cooldown <= 0.0 and _is_player_out_of_bounds(player.global_position):
		_recover_player_from_out_of_bounds()
		return
	if _is_player_confidently_safe():
		_safe_position_time += delta
		if _safe_position_time >= safe_position_stable_time:
			last_safe_position = player.global_position
			_has_safe_position = true
	else:
		_safe_position_time = 0.0

func _is_player_confidently_safe() -> bool:
	if not player.is_on_floor() or absf(player.velocity.y) > 1.0:
		return false
	if player.global_position.y <= out_of_bounds_y + 1.0:
		return false
	if recovery_bounds_enabled and not _is_inside_recovery_bounds(player.global_position):
		return false
	# Normal ramps remain valid, while steep cliff contact is never checkpointed.
	return player.get_floor_normal().y >= 0.65

func _is_player_out_of_bounds(position: Vector3) -> bool:
	if position.y < out_of_bounds_y:
		return true
	if not recovery_bounds_enabled:
		return false
	return (
		position.x < recovery_bounds_min.x - recovery_bounds_margin
		or position.x > recovery_bounds_max.x + recovery_bounds_margin
		or position.z < recovery_bounds_min.y - recovery_bounds_margin
		or position.z > recovery_bounds_max.y + recovery_bounds_margin
	)

func _is_inside_recovery_bounds(position: Vector3) -> bool:
	return (
		position.x >= recovery_bounds_min.x
		and position.x <= recovery_bounds_max.x
		and position.z >= recovery_bounds_min.y
		and position.z <= recovery_bounds_max.y
	)

func _recover_player_from_out_of_bounds() -> void:
	if not _has_safe_position:
		return
	var fallen_position := player.global_position
	var recovery_position := last_safe_position + Vector3.UP * recovery_height_offset
	player.global_position = recovery_position
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_safe_position_time = 0.0
	_recovery_cooldown = 0.75
	player_recovered_from_out_of_bounds.emit(fallen_position, recovery_position)
	print("[LevelBase3D] Recovered Player from %s to safe position %s" % [fallen_position, recovery_position])

func _build_physical_recovery_boundaries() -> void:
	if has_node("OutOfBoundsSafetyBoundaries"):
		return
	var width := recovery_bounds_max.x - recovery_bounds_min.x
	var depth := recovery_bounds_max.y - recovery_bounds_min.y
	if width <= 0.0 or depth <= 0.0:
		push_warning("LevelBase3D: invalid recovery bounds; physical boundaries skipped")
		return
	var boundaries := Node3D.new()
	boundaries.name = "OutOfBoundsSafetyBoundaries"
	add_child(boundaries)
	_add_invisible_boundary(boundaries, "WestSafetyBoundary", Vector3(recovery_bounds_min.x, physical_boundary_center_y, (recovery_bounds_min.y + recovery_bounds_max.y) * 0.5), Vector3(physical_boundary_thickness, physical_boundary_height, depth + physical_boundary_thickness * 2.0))
	_add_invisible_boundary(boundaries, "EastSafetyBoundary", Vector3(recovery_bounds_max.x, physical_boundary_center_y, (recovery_bounds_min.y + recovery_bounds_max.y) * 0.5), Vector3(physical_boundary_thickness, physical_boundary_height, depth + physical_boundary_thickness * 2.0))
	_add_invisible_boundary(boundaries, "NorthSafetyBoundary", Vector3((recovery_bounds_min.x + recovery_bounds_max.x) * 0.5, physical_boundary_center_y, recovery_bounds_min.y), Vector3(width, physical_boundary_height, physical_boundary_thickness))
	_add_invisible_boundary(boundaries, "SouthSafetyBoundary", Vector3((recovery_bounds_min.x + recovery_bounds_max.x) * 0.5, physical_boundary_center_y, recovery_bounds_max.y), Vector3(width, physical_boundary_height, physical_boundary_thickness))

func _add_invisible_boundary(parent: Node3D, boundary_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = boundary_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

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
		
	var remaining_targets := maxi(0, total_targets - targets_eliminated)
	if targets_label:
		targets_label.text = "[STAGE %d: %s] HOSTILES: %d / %d | STANCE: [%s]" % [stage_id, stage_name, remaining_targets, total_targets, movement_state_name]
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

func _on_player_shot_hit(target: Node, is_headshot: bool) -> void:
	shots_hit += 1
	# Player3D emits this once after a confirmed headshot ray hit. Enemy death
	# immediately retires its hitboxes, so dead enemies cannot farm this bonus.
	if is_headshot and target:
		headshots += 1
		current_mission_score += SCORE_PER_HEADSHOT
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

func _on_enemy_destroyed(enemy: Node = null) -> void:
	if is_stage_finished:
		return
	if enemy:
		var enemy_id := enemy.get_instance_id()
		if _counted_enemy_ids.has(enemy_id):
			return
		_counted_enemy_ids[enemy_id] = true
	targets_eliminated = mini(total_targets, targets_eliminated + 1)
	kills = targets_eliminated
	current_mission_score += SCORE_PER_KILL
	_update_hud()
	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_enemy_eliminated("HOSTILE", SCORE_PER_KILL)
	
	if total_targets > 0 and targets_eliminated >= total_targets:
		call_deferred("_complete_stage_if_all_targets_eliminated")

func _complete_stage_if_all_targets_eliminated() -> void:
	if not is_stage_finished and total_targets > 0 and targets_eliminated >= total_targets:
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
		# The player handles every left mouse event in _input() and marks it handled.
		# Once combat is over, stop the retired scene instance from swallowing clicks
		# intended for StageSummaryDialog (notably NEXT MISSION / RETRY / MENU).
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		if player.camera_mount and player.camera_mount.has_method("set_mouse_captured"):
			player.camera_mount.set_mouse_captured(false)
			
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state"):
		var target_state = GameConstants.GameState.MISSION_COMPLETE if is_victory else GameConstants.GameState.GAME_OVER
		gm.change_state(target_state)
		
	var remaining_hp: int = player.current_health if player else 0
	var maximum_hp: int = player.max_health if player else 100
	
	var score_calculator = get_node_or_null("/root/ScoreCalculator")
	var breakdown: Dictionary = {}
	if score_calculator and score_calculator.has_method("get_mission_score_breakdown"):
		breakdown = score_calculator.get_mission_score_breakdown(
			kills, headshots, shots_fired, shots_hit,
			remaining_hp, maximum_hp, is_victory
		)
	else:
		breakdown = {"final_score": current_mission_score}
	current_mission_score = int(breakdown.get("final_score", current_mission_score))

	var profile_manager = get_node_or_null("/root/ProfileManager")
	if is_victory:
		if profile_manager and profile_manager.has_method("record_stage_score"):
			var profile_result: Dictionary = profile_manager.record_stage_score(stage_id, current_mission_score)
			breakdown.merge(profile_result, true)
		else:
			breakdown["best_score"] = current_mission_score
			breakdown["is_new_best"] = true
	else:
		breakdown["best_score"] = profile_manager.get_best_score(stage_id) if profile_manager else 0
		breakdown["is_new_best"] = false
	
	if summary_dialog:
		summary_dialog.display_summary(stage_id, breakdown, is_victory)

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
	get_tree().paused = false
	get_tree().set_meta("hq_return_stage_id", stage_id)
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")
