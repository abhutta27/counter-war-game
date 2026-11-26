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
var _aim_control: Control
var _aim_touch_index: int = -1
var _aim_last_position: Vector2 = Vector2.ZERO
var _fire_button: Button
var _fire_touch_index: int = -1
var _reload_button: Button
var _reload_touch_index: int = -1
var _switch_button: Button
var _switch_touch_index: int = -1
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
	_aim_control = _make_touch_disc("AimControl", 108.0, Color(0.05, 0.12, 0.18, 0.2))
	var aim_style := _aim_control.get_theme_stylebox("panel") as StyleBoxFlat
	if aim_style:
		aim_style.border_width_left = 1
		aim_style.border_width_top = 1
		aim_style.border_width_right = 1
		aim_style.border_width_bottom = 1
		aim_style.border_color = Color(0.5, 0.78, 0.92, 0.55)
	_mobile_controls.add_child(_aim_control)
	_add_aim_markers()
	_fire_button = _make_mobile_button("FIRE", 88.0)
	_fire_button.name = "FireButton"
	_fire_button.anchor_left = 1.0
	_fire_button.anchor_right = 1.0
	_fire_button.anchor_top = 1.0
	_fire_button.anchor_bottom = 1.0
	_fire_button.offset_left = -126.0
	_fire_button.offset_right = -24.0
	_fire_button.offset_top = -142.0
	_fire_button.offset_bottom = -40.0
	_fire_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.add_child(_fire_button)
	_reload_button = _make_mobile_button("RELOAD", 54.0)
	_reload_button.name = "ReloadButton"
	_reload_button.anchor_left = 1.0
	_reload_button.anchor_right = 1.0
	_reload_button.anchor_top = 1.0
	_reload_button.anchor_bottom = 1.0
	_reload_button.offset_left = -190.0
	_reload_button.offset_right = -136.0
	_reload_button.offset_top = -92.0
	_reload_button.offset_bottom = -38.0
	_reload_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.add_child(_reload_button)
	_switch_button = _make_mobile_button("SWAP", 54.0)
	_switch_button.name = "SwitchButton"
	_switch_button.anchor_left = 1.0
	_switch_button.anchor_right = 1.0
	_switch_button.anchor_top = 1.0
	_switch_button.anchor_bottom = 1.0
	_switch_button.offset_left = -190.0
	_switch_button.offset_right = -136.0
	_switch_button.offset_top = -154.0
	_switch_button.offset_bottom = -100.0
	_switch_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.add_child(_switch_button)
	_layout_mobile_joystick()
	get_viewport().size_changed.connect(_layout_mobile_joystick)

func _add_aim_markers() -> void:
	var marker_color := Color(0.72, 0.88, 0.95, 0.72)
	_add_aim_direction("AimUp", "▲", Vector2(45, 4), Vector2(18, 16), marker_color)
	_add_aim_direction("AimDown", "▼", Vector2(45, 88), Vector2(18, 16), marker_color)
	_add_aim_direction("AimLeft", "◀", Vector2(4, 46), Vector2(16, 18), marker_color)
	_add_aim_direction("AimRight", "▶", Vector2(88, 46), Vector2(16, 18), marker_color)
	var horizontal := ColorRect.new()
	horizontal.position = Vector2(42, 53)
	horizontal.size = Vector2(24, 2)
	horizontal.color = marker_color
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_control.add_child(horizontal)
	var vertical := ColorRect.new()
	vertical.position = Vector2(53, 42)
	vertical.size = Vector2(2, 24)
	vertical.color = marker_color
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_control.add_child(vertical)
	var center_dot := _make_touch_disc("AimCenterDot", 5.0, marker_color)
	center_dot.position = Vector2(51.5, 51.5)
	_aim_control.add_child(center_dot)

func _add_aim_direction(node_name: String, glyph: String, marker_position: Vector2, marker_size: Vector2, marker_color: Color) -> void:
	var marker := Label.new()
	marker.name = node_name
	marker.text = glyph
	marker.position = marker_position
	marker.size = marker_size
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", marker_color)
	marker.add_theme_font_size_override("font_size", 10)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_control.add_child(marker)

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
	var font_size := 15 if label_text == "FIRE" else (9 if label_text == "RELOAD" else 12)
	button.add_theme_font_size_override("font_size", font_size)
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
	if _aim_control:
		_aim_control.position = Vector2(_joystick_base.position.x + 5.0, _joystick_base.position.y - 120.0)

func _handle_mobile_touch_event(event: InputEvent) -> void:
	if not _mobile_controls or not is_instance_valid(_mobile_controls):
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if _release_mobile_touch(event.index):
				get_viewport().set_input_as_handled()
			return
		if _mobile_touch_is_owned(event.index):
			return
		if _aim_touch_index == -1 and _touch_inside_circle(_aim_control, event.position, 54.0):
			_aim_touch_index = event.index
			_aim_last_position = event.position
			_mobile_player = _get_mobile_player()
			get_viewport().set_input_as_handled()
			return
		var joystick_center := _joystick_base.position + _joystick_base.size * 0.5
		if _joystick_touch_index == -1 and event.position.distance_to(joystick_center) <= 72.0:
			_joystick_touch_index = event.index
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
			return
		if _fire_touch_index == -1 and _button_contains(_fire_button, event.position):
			_fire_touch_index = event.index
			_on_mobile_fire_down()
			get_viewport().set_input_as_handled()
			return
		if _reload_touch_index == -1 and _button_contains(_reload_button, event.position):
			_reload_touch_index = event.index
			_on_mobile_reload()
			get_viewport().set_input_as_handled()
			return
		if _switch_touch_index == -1 and _button_contains(_switch_button, event.position):
			_switch_touch_index = event.index
			_on_mobile_switch()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _aim_touch_index:
		var drag_event := event as InputEventScreenDrag
		var look_delta: Vector2 = drag_event.relative
		if look_delta.length() > 200.0:
			look_delta = look_delta.limit_length(200.0)
		_aim_last_position = event.position
		if _mobile_player and is_instance_valid(_mobile_player) and _mobile_player.has_method("apply_mobile_look"):
			_mobile_player.apply_mobile_look(look_delta)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _mobile_touch_is_owned(event.index):
		get_viewport().set_input_as_handled()

func _release_mobile_touch(touch_index: int) -> bool:
	if touch_index == _joystick_touch_index:
		_joystick_touch_index = -1
		_joystick_vector = Vector2.ZERO
		_joystick_knob.position = _joystick_base.position + Vector2(32.0, 32.0)
		if _mobile_player and is_instance_valid(_mobile_player) and _mobile_player.has_method("set_mobile_movement"):
			_mobile_player.set_mobile_movement(Vector2.ZERO)
		return true
	if touch_index == _aim_touch_index:
		_aim_touch_index = -1
		_aim_last_position = Vector2.ZERO
		return true
	if touch_index == _fire_touch_index:
		_fire_touch_index = -1
		_on_mobile_fire_up()
		return true
	if touch_index == _reload_touch_index:
		_reload_touch_index = -1
		return true
	if touch_index == _switch_touch_index:
		_switch_touch_index = -1
		return true
	return false

func _mobile_touch_is_owned(touch_index: int) -> bool:
	return touch_index in [_joystick_touch_index, _aim_touch_index, _fire_touch_index, _reload_touch_index, _switch_touch_index]

func _touch_inside_circle(control: Control, screen_position: Vector2, radius: float) -> bool:
	if not control or not is_instance_valid(control):
		return false
	return screen_position.distance_to(control.position + control.size * 0.5) <= radius

func _button_contains(button: Button, screen_position: Vector2) -> bool:
	return button and is_instance_valid(button) and button.get_global_rect().grow(6.0).has_point(screen_position)

func _get_mobile_player() -> Node:
	if not _mobile_player or not is_instance_valid(_mobile_player):
		_mobile_player = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
	return _mobile_player

func _update_joystick(screen_position: Vector2) -> void:
	var center := _joystick_base.position + _joystick_base.size * 0.5
	var raw_offset: Vector2 = screen_position - center
	var dist: float = raw_offset.length()
	var max_radius: float = 52.0
	var deadzone: float = 5.0
	if dist <= deadzone:
		_joystick_vector = Vector2.ZERO
		_joystick_knob.position = center - _joystick_knob.size * 0.5
	else:
		var clamped_dist: float = minf(dist, max_radius)
		var normalized_mag: float = (clamped_dist - deadzone) / (max_radius - deadzone)
		var dir: Vector2 = raw_offset / dist
		_joystick_vector = dir * normalized_mag
		_joystick_knob.position = center + dir * clamped_dist - _joystick_knob.size * 0.5

	_mobile_player = _get_mobile_player()
	if _mobile_player and _mobile_player.has_method("set_mobile_movement"):
		_mobile_player.set_mobile_movement(_joystick_vector)

func _on_mobile_fire_down() -> void:
	_mobile_player = _get_mobile_player()
	if _mobile_player and _mobile_player.has_method("mobile_fire_pressed"):
		_mobile_player.mobile_fire_pressed(true)

func _on_mobile_fire_up() -> void:
	if _mobile_player and _mobile_player.has_method("mobile_fire_pressed"):
		_mobile_player.mobile_fire_pressed(false)

func _on_mobile_reload() -> void:
	_mobile_player = _get_mobile_player()
	if _mobile_player and _mobile_player.has_method("mobile_reload"):
		_mobile_player.mobile_reload()

func _on_mobile_switch() -> void:
	_mobile_player = _get_mobile_player()
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
		if OS.has_feature("mobile"):
			weapon_slot_label.text = "SECONDARY" if is_secondary else "PRIMARY"
		else:
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
			reload_prompt_label.text = "[ RELOAD BUTTON NEEDED ]" if OS.has_feature("mobile") else "[ R — RELOAD NEEDED ]"
			reload_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		else:
			reload_prompt_label.text = "[ RELOAD BUTTON ]" if OS.has_feature("mobile") else "[ R — RELOAD ]"
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
