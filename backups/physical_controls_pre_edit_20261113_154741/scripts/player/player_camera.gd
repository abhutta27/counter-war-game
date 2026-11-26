class_name PlayerCamera
extends Camera3D
## PlayerCamera.gd
## First-Person Camera System providing responsive mouse-look, vertical pitch clamping,
## smooth FOV transitions, and recoil recovery.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const PlayerCameraConfig = preload("res://scripts/player/player_camera_config.gd")

@export var config: PlayerCameraConfig = null
@export var target_player: CharacterBody3D = null

var pitch: float = 0.0
var recoil_pitch: float = 0.0
var target_fov: float = 75.0
var is_mouse_captured: bool = false

func _init() -> void:
	if not config:
		config = PlayerCameraConfig.new()

func _ready() -> void:
	if not config:
		config = PlayerCameraConfig.new()
		
	if not target_player:
		target_player = get_parent() as CharacterBody3D
			
	current = true
	target_fov = config.base_fov
	fov = target_fov
	
	pitch = rotation.x
	
	# Always capture mouse cursor for tactical FPS gameplay
	set_mouse_captured(true)

func set_mouse_captured(captured: bool) -> void:
	is_mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func is_captured() -> bool:
	if DisplayServer.get_name() == "headless":
		return is_mouse_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# 1. Click window to re-capture mouse if not captured (ONLY allowed during active PLAYING state)
	if event is InputEventMouseButton and event.pressed and not is_captured():
		var gm = get_node_or_null("/root/GameManager")
		var is_playing = (gm != null and gm.current_state == GameConstants.GameState.PLAYING and not gm.is_game_paused)
		var is_alive = true
		if target_player:
			if "is_active" in target_player and not bool(target_player.get("is_active")):
				is_alive = false
			if "current_health" in target_player and int(target_player.get("current_health")) <= 0:
				is_alive = false
				
		if is_playing and is_alive:
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()
			return
			
	# 2. Mouse motion look
	if event is InputEventMouseMotion and is_captured():
		var mouse_x: float = -event.relative.x * config.mouse_sensitivity
		var dir_y: float = 1.0 if config.invert_y else -1.0
		var mouse_y: float = event.relative.y * config.mouse_sensitivity * dir_y
		
		# Horizontal Yaw rotates the Player body
		if target_player:
			target_player.rotate_y(mouse_x)
		else:
			rotate_y(mouse_x)
			
		# Vertical Pitch rotates Camera3D only
		pitch += mouse_y
		pitch = clampf(pitch, deg_to_rad(config.min_pitch_deg), deg_to_rad(config.max_pitch_deg))
		rotation.x = pitch + recoil_pitch
		get_viewport().set_input_as_handled()
		return
		
	# Esc is owned by TacticalHUD so one input atomically opens the pause menu,
	# pauses simulation, and releases the mouse. Consuming it here previously
	# produced a cursor-only pseudo-pause and starved the HUD input route.

func _unhandled_input(_event: InputEvent) -> void:
	# Legacy right-side free-look has been disabled in favor of TacticalHUD's dedicated
	# left circular aim controller. The right side is reserved for weapon controls (FIRE, RELOAD, SWAP).
	pass

func _process(delta: float) -> void:
	# Smoothly recover recoil pitch back to baseline
	if absf(recoil_pitch) > 0.0001:
		recoil_pitch = move_toward(recoil_pitch, 0.0, config.recoil_recovery_speed * delta)
		rotation.x = pitch + recoil_pitch
		
	# Smooth FOV transitions (e.g. for future aiming / sprint FOV)
	if absf(fov - target_fov) > 0.01:
		fov = move_toward(fov, target_fov, config.fov_transition_speed * delta * 10.0)

## Adds procedural recoil kick to pitch (negative pitch = kick up)
func apply_recoil(recoil_pitch_deg: float) -> void:
	var max_rad: float = deg_to_rad(config.max_recoil_pitch_deg)
	recoil_pitch = clampf(recoil_pitch + deg_to_rad(recoil_pitch_deg), -max_rad, max_rad)
	rotation.x = pitch + recoil_pitch

## Adjusts FOV between base and aim zoom
func set_aiming(is_aiming: bool) -> void:
	target_fov = config.aim_fov if is_aiming else config.base_fov

func get_pitch_deg() -> float:
	return rad_to_deg(pitch)

func get_camera_direction() -> Vector3:
	return -global_transform.basis.z
