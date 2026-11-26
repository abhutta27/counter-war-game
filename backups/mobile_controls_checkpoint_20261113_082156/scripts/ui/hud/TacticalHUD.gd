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
var _mobile_controls: Control
var _joystick_base: Control
var _joystick_knob: Control
var _joystick_touch_index: int = -1
var _joystick_vector: Vector2 = Vector2.ZERO
var _mobile_player: Node

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
	if OS.has_feature("mobile"):
		_create_mobile_controls()

func _create_mobile_controls() -> void:
	_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_mobile_controls)
	_joystick_base = _make_touch_disc("JoystickBase", 118.0, Color(0.05, 0.12, 0.18, 0.48))
	_joystick_knob = _make_touch_disc("JoystickKnob", 54.0, Color(0.25, 0.7, 0.95, 0.8))
	_mobile_controls.add_child(_joystick_base)
	_mobile_controls.add_child(_joystick_knob)
	var fire_button := _make_mobile_button("FIRE", 88.0)
	fire_button.anchor_left = 1.0
	fire_button.anchor_right = 1.0
	fire_button.anchor_top = 1.0
	fire_button.anchor_bottom = 1.0
	fire_button.offset_left = -126.0
	fire_button.offset_right = -24.0
	fire_button.offset_top = -142.0
	fire_button.offset_bottom = -40.0
	fire_button.button_down.connect(_on_mobile_fire_down)
	fire_button.button_up.connect(_on_mobile_fire_up)
	_mobile_controls.add_child(fire_button)
	var reload_button := _make_mobile_button("R", 54.0)
	reload_button.anchor_left = 1.0
	reload_button.anchor_right = 1.0
	reload_button.anchor_top = 1.0
	reload_button.anchor_bottom = 1.0
	reload_button.offset_left = -190.0
	reload_button.offset_right = -136.0
	reload_button.offset_top = -92.0
	reload_button.offset_bottom = -38.0
	reload_button.pressed.connect(_on_mobile_reload)
	_mobile_controls.add_child(reload_button)
	var switch_button := _make_mobile_button("SWAP", 54.0)
	switch_button.anchor_left = 1.0
	switch_button.anchor_right = 1.0
	switch_button.anchor_top = 1.0
	switch_button.anchor_bottom = 1.0
	switch_button.offset_left = -190.0
	switch_button.offset_right = -136.0
	switch_button.offset_top = -154.0
	switch_button.offset_bottom = -100.0
	switch_button.pressed.connect(_on_mobile_switch)
	_mobile_controls.add_child(switch_button)
	_layout_mobile_joystick()
	get_viewport().size_changed.connect(_layout_mobile_joystick)

func _make_touch_disc(node_name: String, diameter: float, color: Color) -> Control:
	var disc := Panel.new()
	disc.name = node_name
	disc.custom_minimum_size = Vector2(diameter, diameter)
	disc.size = Vector2(diameter, diameter)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(diameter * 0.5)
	style.corner_radius_top_right = int(diameter * 0.5)
	style.corner_radius_bottom_left = int(diameter * 0.5)
	style.corner_radius_bottom_right = int(diameter * 0.5)
	disc.add_theme_stylebox_override("panel", style)
	return disc

func _make_mobile_button(label_text: String, size: float) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(size, size)
	button.size = Vector2(size, size)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15 if label_text == "FIRE" else 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.12, 0.1, 0.78) if label_text == "FIRE" else Color(0.05, 0.18, 0.27, 0.82)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	button.add_theme_stylebox_override("normal", style)
	return button

func _layout_mobile_joystick() -> void:
	if not _joystick_base or not is_instance_valid(_joystick_base):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_joystick_base.position = Vector2(28.0, viewport_size.y - 150.0)
	_joystick_knob.position = _joystick_base.position + Vector2(32.0, 32.0)

func _handle_mobile_touch_event(event: InputEvent) -> void:
	if not OS.has_feature("mobile") or not _mobile_controls or not is_instance_valid(_mobile_controls):
		return
	if event is InputEventScreenTouch:
		var center := _joystick_base.position + _joystick_base.size * 0.5
		if event.pressed and _joystick_touch_index == -1 and event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and event.position.distance_to(center) <= 110.0:
			_joystick_touch_index = event.index
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_joystick_vector = Vector2.ZERO
			_joystick_knob.position = _joystick_base.position + Vector2(32.0, 32.0)
			if _mobile_player and _mobile_player.has_method("set_mobile_movement"):
				_mobile_player.set_mobile_movement(Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()

func _update_joystick(screen_position: Vector2) -> void:
	var center := _joystick_base.position + _joystick_base.size * 0.5
	var offset := (screen_position - center).limit_length(52.0)
	_joystick_vector = Vector2(offset.x / 52.0, offset.y / 52.0)
	_joystick_knob.position = center + offset - _joystick_knob.size * 0.5
	if not _mobile_player or not is_instance_valid(_mobile_player):
		_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	if _mobile_player and _mobile_player.has_method("set_mobile_movement"):
		_mobile_player.set_mobile_movement(_joystick_vector)

func _on_mobile_fire_down() -> void:
	_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	if _mobile_player and _mobile_player.has_method("mobile_fire_pressed"):
		_mobile_player.mobile_fire_pressed(true)

func _on_mobile_fire_up() -> void:
	if _mobile_player and _mobile_player.has_method("mobile_fire_pressed"):
		_mobile_player.mobile_fire_pressed(false)

func _on_mobile_reload() -> void:
	if not _mobile_player or not is_instance_valid(_mobile_player):
		_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	if _mobile_player and _mobile_player.has_method("mobile_reload"):
		_mobile_player.mobile_reload()

func _on_mobile_switch() -> void:
	if not _mobile_player or not is_instance_valid(_mobile_player):
		_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	if _mobile_player and _mobile_player.has_method("mobile_switch_weapon"):
		_mobile_player.mobile_switch_weapon()

func _on_event_bus_enemy_state_changed(_enemy: Node, new_state: int) -> void:
	if new_state == 1: # State.CHASE
		# Detection voice is owned by Enemy3D so it remains spatial. Keep the
		# invasive contact banner disabled.
		pass

func _on_event_bus_weapon_switched(new_weapon_name: String) -> void:
	var slot_num = 2 if ("PISTOL" in new_weapon_name.to_upper()) else 1
	show_weapon_switch_toast(new_weapon_name, slot_num)


func _input(event: InputEvent) -> void:
	_handle_mobile_touch_event(event)
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
