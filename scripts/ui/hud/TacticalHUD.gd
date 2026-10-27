class_name TacticalHUD
extends CanvasLayer
## TacticalHUD.gd
## Central controller for the Modern Tactical Military FPS HUD:
## - Top HUD: Mission Title, Hostiles count, Objective, Timer, Accuracy, Stance
## - Objective Banner: Mission start presentation with smooth auto-compaction
## - Contact Alert: "CONTACT // HOSTILE DETECTED" alert on enemy detection
## - Health HUD: Styled segmented health bar, dynamic status states (Optimal, Low, Critical, KIA)
## - Weapon & Ammo HUD: Slot indicator, weapon title, ammo counts, dynamic reload warning, switch toast
## - Integrated CombatFeedback & PauseMenu
## - 100% Backwards-compatible proxy nodes for legacy scripts and automated tests.

# --- TOP BAR NODES ---
@onready var mission_label: Label = $TopBar/LeftPanel/LeftBox/MissionLabel
@onready var operation_label: Label = $TopBar/LeftPanel/LeftBox/OperationLabel
@onready var stance_label: Label = $TopBar/LeftPanel/LeftBox/StanceLabel

@onready var hostiles_counter_label: Label = $TopBar/CenterBox/HostilesPanel/HostilesLabel
@onready var compact_objective_label: Label = $TopBar/CenterBox/CompactObjectiveLabel

@onready var timer_val_label: Label = $TopBar/RightPanel/RightBox/TimerContainer/TimerVal
@onready var accuracy_val_label: Label = $TopBar/RightPanel/RightBox/AccuracyContainer/AccuracyVal

# --- OBJECTIVE & CONTACT BANNERS ---
@onready var objective_banner: Control = $ObjectiveBanner
@onready var objective_banner_text: Label = $ObjectiveBanner/BannerPanel/VBox/ObjectiveDesc
@onready var contact_banner: Control = $ContactAlertBanner
@onready var contact_banner_label: Label = $ContactAlertBanner/AlertPanel/AlertLabel

# --- BOTTOM LEFT: HEALTH HUD ---
@onready var health_val_label: Label = $BottomLeft/HealthPanel/VBox/Header/HealthValLabel
@onready var health_bar_node: ProgressBar = $BottomLeft/HealthPanel/VBox/HealthProgressBar
@onready var health_status_label: Label = $BottomLeft/HealthPanel/VBox/HealthStatusLabel
@onready var health_panel: PanelContainer = $BottomLeft/HealthPanel

# --- BOTTOM RIGHT: WEAPON & AMMO HUD ---
@onready var weapon_slot_label: Label = $BottomRight/WeaponPanel/VBox/Header/SlotLabel
@onready var weapon_name_label: Label = $BottomRight/WeaponPanel/VBox/Header/WeaponNameLabel
@onready var ammo_mag_label: Label = $BottomRight/WeaponPanel/VBox/AmmoRow/MagLabel
@onready var ammo_reserve_label: Label = $BottomRight/WeaponPanel/VBox/AmmoRow/ReserveLabel
@onready var reload_prompt_label: Label = $BottomRight/WeaponPanel/VBox/ReloadPromptLabel
@onready var weapon_switch_toast: PanelContainer = $BottomRight/WeaponSwitchToast
@onready var weapon_switch_label: Label = $BottomRight/WeaponSwitchToast/ToastLabel

# --- COMBAT FEEDBACK & MODALS ---
@onready var combat_feedback: Node = $CombatFeedback
@onready var pause_menu: Node = $PauseMenu
@onready var stage_summary_dialog: Control = $StageSummaryDialog

# --- COMPATIBILITY SHIM NODES ---
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var targets_label: Label = $TopBar/TargetsLabel
@onready var accuracy_label: Label = $TopBar/AccuracyLabel
@onready var health_bar: ProgressBar = $BottomBar/HealthBar
@onready var ammo_label: Label = $BottomBar/AmmoLabel

# Internal State Tracking
var _stage_id: int = 1
var _stage_name: String = "OPERATION DESERT OUTPOST"
var _targets_eliminated: int = 0
var _total_targets: int = 5
var _current_health: int = 100
var _max_health: int = 100
var _current_ammo: int = 30
var _max_ammo: int = 30
var _reserve_ammo: int = 90
var _is_contact_showing: bool = false
var _contact_tween: Tween = null
var _switch_tween: Tween = null
var _critical_pulse_tween: Tween = null
var _reload_blink_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if contact_banner:
		contact_banner.visible = false
		contact_banner.modulate.a = 0.0
	if weapon_switch_toast:
		weapon_switch_toast.visible = false
		weapon_switch_toast.modulate.a = 0.0
	if reload_prompt_label:
		reload_prompt_label.visible = false
		
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("enemy_state_changed"):
			eb.enemy_state_changed.connect(_on_event_bus_enemy_state_changed)
		if eb.has_signal("weapon_switched"):
			eb.weapon_switched.connect(_on_event_bus_weapon_switched)
			
	_play_mission_start_objective_animation()

func _on_event_bus_enemy_state_changed(_enemy: Node, new_state: int) -> void:
	if new_state == 1: # State.CHASE
		# Detection voice is owned by Enemy3D so it remains spatial. Keep the
		# invasive contact banner disabled.
		pass

func _on_event_bus_weapon_switched(new_weapon_name: String) -> void:
	var slot_num = 2 if ("PISTOL" in new_weapon_name.to_upper()) else 1
	show_weapon_switch_toast(new_weapon_name, slot_num)


func _input(event: InputEvent) -> void:
	var is_escape: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if not event.is_action_pressed("pause") and not is_escape:
		return
	# Mission result screens own input until the player chooses an explicit action.
	if stage_summary_dialog and stage_summary_dialog.visible:
		return
	var gm = get_node_or_null("/root/GameManager")
	if not gm or gm.current_state not in [GameConstants.GameState.PLAYING, GameConstants.GameState.PAUSED]:
		return
	if pause_menu:
		pause_menu.toggle()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Blink reload prompt if visible and low ammo
	if reload_prompt_label and reload_prompt_label.visible:
		_reload_blink_timer += delta * 4.0
		reload_prompt_label.modulate.a = 0.4 + 0.6 * absf(sin(_reload_blink_timer))

## Sets stage metadata
func setup_stage_info(stage_id: int, stage_name: String, total_targets: int, objective_desc: String = "ELIMINATE ALL HOSTILE FORCES") -> void:
	_stage_id = stage_id
	_stage_name = stage_name
	_total_targets = total_targets
	
	if mission_label:
		mission_label.text = "MISSION %02d" % _stage_id
	if operation_label:
		operation_label.text = _stage_name.to_upper()
	if compact_objective_label:
		compact_objective_label.text = "DIRECTIVE: %s" % objective_desc.to_upper()
	if objective_banner_text:
		objective_banner_text.text = objective_desc.to_upper()
		
	update_hostiles_count(0, _total_targets)

func _play_mission_start_objective_animation() -> void:
	if not objective_banner:
		return
	objective_banner.visible = true
	objective_banner.modulate.a = 0.0
	objective_banner.offset_top = 65.0
	objective_banner.offset_bottom = 120.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(objective_banner, "modulate:a", 1.0, 0.35)
	tw.tween_property(objective_banner, "offset_top", 90.0, 0.35)
	tw.tween_property(objective_banner, "offset_bottom", 145.0, 0.35)
	
	# Hold for 2.0 seconds then compact / fade
	tw.chain().tween_interval(2.0)
	tw.chain().set_parallel(true)
	tw.tween_property(objective_banner, "modulate:a", 0.0, 0.45)
	tw.tween_property(objective_banner, "offset_top", 70.0, 0.45)
	tw.tween_property(objective_banner, "offset_bottom", 125.0, 0.45)
	tw.chain().tween_callback(func():
		if objective_banner:
			objective_banner.visible = false
	)

## Called when hostile count changes
func update_hostiles_count(eliminated: int, total: int) -> void:
	_targets_eliminated = eliminated
	_total_targets = total
	
	var remaining = maxi(0, total - eliminated)
	if hostiles_counter_label:
		hostiles_counter_label.text = "HOSTILES: %02d / %02d" % [remaining, total]
		
	# Update legacy shim
	if targets_label:
		targets_label.text = "[STAGE %d: %s] HOSTILES: %d / %d" % [_stage_id, _stage_name, remaining, total]

## Updates timer display
func update_timer(elapsed_time: float) -> void:
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var ms := int((elapsed_time - int(elapsed_time)) * 10)
	var formatted = "%02d:%02d.%d" % [minutes, seconds, ms]
	
	if timer_val_label:
		timer_val_label.text = formatted
	if timer_label:
		timer_label.text = "TIME: " + formatted

## Updates accuracy display
func update_accuracy(accuracy: float) -> void:
	var formatted = "%.1f%%" % accuracy
	if accuracy_val_label:
		accuracy_val_label.text = formatted
	if accuracy_label:
		accuracy_label.text = "ACCURACY: " + formatted

## Updates stance badge (e.g. IDLE, SPRINTING, CROUCHING)
func update_stance(stance_name: String) -> void:
	if stance_label:
		stance_label.text = "STANCE: [%s]" % stance_name.to_upper()

## Updates Health HUD with dynamic status feedback
func update_health(current_hp: int, max_hp: int) -> void:
	_current_health = current_hp
	_max_health = max_hp
	
	if health_bar_node:
		health_bar_node.max_value = max_hp
		health_bar_node.value = current_hp
		
	if health_val_label:
		health_val_label.text = "%d / %d HP" % [current_hp, max_hp]
		
	# Sync legacy health_bar shim
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		
	var hp_ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	
	# Evaluate Health State & Feedback
	if current_hp <= 0:
		_set_health_state("KIA // CRITICAL FAILURE", Color(0.8, 0.1, 0.1, 1.0))
		_stop_critical_pulse()
	elif hp_ratio <= 0.25:
		_set_health_state("CRITICAL // HEAVY TRAUMA", Color(1.0, 0.2, 0.2, 1.0))
		_start_critical_pulse()
	elif hp_ratio <= 0.50:
		_set_health_state("CAUTION // VITALS LOW", Color(1.0, 0.65, 0.15, 1.0))
		_stop_critical_pulse()
	else:
		_set_health_state("SYSTEM OPTIMAL", Color(0.2, 0.9, 0.6, 1.0))
		_stop_critical_pulse()

func _set_health_state(status_text: String, status_color: Color) -> void:
	if health_status_label:
		health_status_label.text = status_text
		health_status_label.modulate = status_color
	if health_val_label:
		health_val_label.modulate = status_color

func _start_critical_pulse() -> void:
	if _critical_pulse_tween and _critical_pulse_tween.is_valid():
		return
	if not health_panel:
		return
	_critical_pulse_tween = create_tween().set_loops()
	_critical_pulse_tween.tween_property(health_panel, "modulate", Color(1.2, 0.6, 0.6, 1.0), 0.35)
	_critical_pulse_tween.tween_property(health_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)

func _stop_critical_pulse() -> void:
	if _critical_pulse_tween and _critical_pulse_tween.is_valid():
		_critical_pulse_tween.kill()
		_critical_pulse_tween = null
	if health_panel:
		health_panel.modulate = Color.WHITE

## Updates Weapon & Ammo HUD
func update_ammo(current_ammo: int, max_ammo: int, weapon_name: String = "ASSAULT RIFLE", is_secondary: bool = false, reserve: int = 90) -> void:
	_current_ammo = current_ammo
	_max_ammo = max_ammo
	_reserve_ammo = reserve
	
	if weapon_name_label:
		weapon_name_label.text = weapon_name.to_upper()
	if weapon_slot_label:
		weapon_slot_label.text = "SECONDARY [2]" if is_secondary else "PRIMARY [1]"
	if ammo_mag_label:
		ammo_mag_label.text = "%02d" % current_ammo
	if ammo_reserve_label:
		ammo_reserve_label.text = "/ %d" % reserve
		
	# Update Reload Prompt visibility
	var is_low = current_ammo <= 0 or current_ammo <= int(max_ammo * 0.25)
	if reload_prompt_label:
		reload_prompt_label.visible = is_low
		if current_ammo <= 0:
			reload_prompt_label.text = "[ R — RELOAD NEEDED ]"
			reload_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		else:
			reload_prompt_label.text = "[ R — RELOAD ]"
			reload_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1.0))
			
	# Update legacy shim
	if ammo_label:
		ammo_label.text = "[%s] AMMO: %d / %d (R to Reload)" % [weapon_name.to_upper(), current_ammo, max_ammo]

## Shows weapon switch toast banner
func show_weapon_switch_toast(weapon_name: String, slot_num: int) -> void:
	if not weapon_switch_toast or not weapon_switch_label:
		return
		
	weapon_switch_label.text = "WEAPON %d — %s READY" % [slot_num, weapon_name.to_upper()]
	weapon_switch_toast.visible = true
	weapon_switch_toast.modulate.a = 0.0
	
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
		
	_switch_tween = create_tween()
	_switch_tween.tween_property(weapon_switch_toast, "modulate:a", 1.0, 0.15)
	_switch_tween.tween_interval(1.1)
	_switch_tween.tween_property(weapon_switch_toast, "modulate:a", 0.0, 0.25)
	_switch_tween.tween_callback(func():
		if weapon_switch_toast:
			weapon_switch_toast.visible = false
	)

## Compatibility hook. Detection audio is triggered by Enemy3D, not the HUD.
func show_contact_alert(_alert_msg: String = "") -> void:
	if contact_banner:
		contact_banner.visible = false
		contact_banner.modulate.a = 0.0
