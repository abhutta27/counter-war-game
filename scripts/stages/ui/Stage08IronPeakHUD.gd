class_name Stage08IronPeakHUD
extends CanvasLayer
## Stage 08 — Operation Iron Peak In-Game HUD
## Matches panel 7 of the reference UI collage:
## Circular minimap, clean crosshair, military status bars, ammo & weapon counter.

signal pause_requested()

@onready var minimap_container: Control = $MinimapContainer
@onready var minimap_subview: SubViewport = $MinimapContainer/SubViewportContainer/SubViewport
@onready var minimap_cam: Camera3D = $MinimapContainer/SubViewportContainer/SubViewport/MinimapCamera
@onready var player_marker: Control = $MinimapContainer/PlayerMarker

@onready var stage_title_label: Label = $TopBar/HeaderContainer/VBox/StageTitle
@onready var objective_label: Label = $TopBar/HeaderContainer/VBox/ObjectiveText
@onready var pause_button: Button = $TopBar/PauseButton

@onready var health_bar: ProgressBar = $BottomLeft/HealthContainer/VBox/HealthBar
@onready var health_label: Label = $BottomLeft/HealthContainer/VBox/HBox/HealthValue

@onready var ammo_mag_label: Label = $BottomRight/AmmoContainer/VBox/HBox/AmmoMag
@onready var ammo_reserve_label: Label = $BottomRight/AmmoContainer/VBox/HBox/AmmoReserve
@onready var weapon_name_label: Label = $BottomRight/AmmoContainer/VBox/WeaponName
@onready var fire_mode_label: Label = $BottomRight/AmmoContainer/VBox/FireMode

@onready var prompt_label: Label = $CenterContainer/PromptLabel
@onready var banner_label: Label = $BannerContainer/BannerLabel
@onready var crosshair: Control = $Crosshair

var _target_player: Node3D = null
var _banner_timer: float = 0.0

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
		Stage08IronPeakUITheme.apply_outline_button_style(pause_button)
	
	if prompt_label:
		prompt_label.visible = false
	if banner_label:
		banner_label.visible = false
	
	# Listen to global event bus if present
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("ammo_updated"):
			eb.ammo_updated.connect(_on_global_ammo_updated)
		if eb.has_signal("weapon_switched"):
			eb.weapon_switched.connect(_on_global_weapon_switched)

func track_player(player: Node3D) -> void:
	_target_player = player
	if _target_player:
		if _target_player.has_signal("health_changed"):
			_target_player.health_changed.connect(set_health)
		if "current_health" in _target_player and "max_health" in _target_player:
			set_health(_target_player.current_health, _target_player.max_health)
		elif "health" in _target_player:
			set_health(int(_target_player.health), 100)

func set_health(current: int, max_val: int = 100) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [current, max_val]

func set_ammo(mag: int, reserve: int) -> void:
	if ammo_mag_label:
		ammo_mag_label.text = str(mag)
	if ammo_reserve_label:
		ammo_reserve_label.text = "/ %d" % reserve

func set_weapon_info(w_name: String, fire_mode: String = "AUTO") -> void:
	if weapon_name_label:
		weapon_name_label.text = w_name
	if fire_mode_label:
		fire_mode_label.text = fire_mode

func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text

func show_prompt(msg: String) -> void:
	if prompt_label:
		prompt_label.text = msg
		prompt_label.visible = true

func hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false

func show_banner(msg: String, duration: float = 3.0) -> void:
	if banner_label:
		banner_label.text = msg
		banner_label.visible = true
		_banner_timer = duration

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and banner_label:
			banner_label.visible = false
	
	# Update minimap camera position to follow player
	if is_instance_valid(_target_player) and minimap_cam:
		var p_pos = _target_player.global_position
		minimap_cam.global_position = Vector3(p_pos.x, p_pos.y + 40.0, p_pos.z)
		if player_marker:
			var rot_y = _target_player.global_rotation.y
			player_marker.rotation = -rot_y

func _on_pause_button_pressed() -> void:
	pause_requested.emit()

func _on_global_ammo_updated(current: int, mag_size: int) -> void:
	if ammo_mag_label:
		ammo_mag_label.text = str(current)
	if ammo_reserve_label:
		ammo_reserve_label.text = "/ %d" % mag_size

func _on_global_weapon_switched(w_name: String) -> void:
	if weapon_name_label:
		weapon_name_label.text = w_name.to_upper()
