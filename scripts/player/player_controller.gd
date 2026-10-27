class_name PlayerController
extends CharacterBody3D
## PlayerController.gd
## Professional physics-based first/third-person operative movement controller.
## Manages ground detection, acceleration/deceleration, jump, gravity, crouch, and movement states.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const PlayerMovementConfig = preload("res://scripts/player/player_movement_config.gd")
const PlayerInput = preload("res://scripts/player/player_input.gd")

signal movement_state_changed(new_state: GameConstants.MovementState, old_state: GameConstants.MovementState)
signal jumped()
signal landed()
signal crouch_toggled(is_crouching: bool)

@export var config: PlayerMovementConfig = null

# Node references
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var camera_mount: Node3D = get_node_or_null("Camera3D")

# Runtime state
var current_movement_state: GameConstants.MovementState = GameConstants.MovementState.IDLE
var is_crouching: bool = false
var was_on_floor: bool = true
var target_speed: float = 0.0
var current_horizontal_speed: float = 0.0

# Current dynamic collision height
var current_shape_height: float = 1.8
var current_camera_y: float = 1.55

func _init() -> void:
	if not config:
		config = PlayerMovementConfig.new()

func _ready() -> void:
	add_to_group(GameConstants.GROUP_PLAYER)
	
	collision_layer = GameConstants.LAYER_PLAYER
	collision_mask = GameConstants.LAYER_WORLD | GameConstants.LAYER_ENEMY
	
	floor_snap_length = 0.2
	floor_max_angle = deg_to_rad(45.0)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		current_shape_height = config.standing_height
		collision_shape.shape.height = current_shape_height
		collision_shape.position.y = current_shape_height * 0.5
		
	if camera_mount:
		current_camera_y = config.standing_camera_y
		camera_mount.position.y = current_camera_y
		camera_mount.set("target_player", self)
		if camera_mount.has_method("set_mouse_captured"):
			camera_mount.set_mouse_captured(true)
		
	# Notify GameManager and EventBus
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.player_spawned.emit(self)
		
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_player(self)

func _physics_process(delta: float) -> void:
	# Check if gameplay is paused or game is not in playing state
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state != GameConstants.GameState.PLAYING and gm.current_state != GameConstants.GameState.BOOT:
		# If in main menu or paused, freeze movement velocity
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
		
	_handle_ground_detection()
	_handle_crouch(delta)
	_handle_gravity_and_jump(delta)
	_handle_horizontal_movement(delta)
	
	move_and_slide()
	
	_update_movement_state()

## Handles ground landing & departure events
func _handle_ground_detection() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not was_on_floor:
		landed.emit()
	was_on_floor = on_floor

## Handles crouch toggle and height interpolation
func _handle_crouch(delta: float) -> void:
	var crouch_pressed: bool = PlayerInput.is_crouch_pressed()
	if crouch_pressed != is_crouching:
		is_crouching = crouch_pressed
		crouch_toggled.emit(is_crouching)
		
	var target_height: float = config.crouch_height if is_crouching else config.standing_height
	var target_cam_y: float = config.crouching_camera_y if is_crouching else config.standing_camera_y
	
	current_shape_height = move_toward(current_shape_height, target_height, config.crouch_transition_speed * delta)
	current_camera_y = move_toward(current_camera_y, target_cam_y, config.crouch_transition_speed * delta)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = current_shape_height
		collision_shape.position.y = current_shape_height * 0.5
		
	if camera_mount:
		camera_mount.position.y = current_camera_y

## Applies gravity and handles jumping
func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		var effective_gravity: float = config.gravity
		if velocity.y < 0.0:
			effective_gravity *= config.fall_gravity_multiplier
		velocity.y -= effective_gravity * delta
		velocity.y = maxf(velocity.y, -config.max_fall_speed)
	else:
		# Jump only on floor and when not crouching
		if PlayerInput.is_jump_just_pressed() and not is_crouching:
			velocity.y = config.jump_velocity
			jumped.emit()

## Physics-based acceleration, deceleration, and direction translation
func _handle_horizontal_movement(delta: float) -> void:
	var input_vec: Vector2 = PlayerInput.get_movement_vector()
	var is_sprinting: bool = PlayerInput.is_sprint_pressed() and not is_crouching and input_vec.y < -0.1
	
	# Determine target speed based on movement mode
	if is_crouching:
		target_speed = config.crouch_speed
	elif is_sprinting:
		target_speed = config.sprint_speed
	elif input_vec.length_squared() > 0.01:
		target_speed = config.run_speed
	else:
		target_speed = 0.0
		
	# Transform input direction relative to character yaw
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var wish_dir: Vector3 = (right * input_vec.x + forward * -input_vec.y).normalized()
	
	var accel: float = config.ground_acceleration if is_on_floor() else config.air_acceleration
	var decel: float = config.ground_deceleration if is_on_floor() else config.air_deceleration
	
	var target_vel_h: Vector3 = wish_dir * target_speed
	
	if wish_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_vel_h.x, accel * target_speed * delta)
		velocity.z = move_toward(velocity.z, target_vel_h.z, accel * target_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * config.run_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * config.run_speed * delta)
		
	current_horizontal_speed = Vector2(velocity.x, velocity.z).length()

## Updates and signals movement states
func _update_movement_state() -> void:
	var new_state: GameConstants.MovementState = GameConstants.MovementState.IDLE
	
	if not is_on_floor():
		if velocity.y > 0.1:
			new_state = GameConstants.MovementState.JUMPING
		else:
			new_state = GameConstants.MovementState.FALLING
	elif is_crouching:
		new_state = GameConstants.MovementState.CROUCHING
	elif current_horizontal_speed < 0.1:
		new_state = GameConstants.MovementState.IDLE
	elif current_horizontal_speed > config.run_speed + 0.5:
		new_state = GameConstants.MovementState.SPRINTING
	elif current_horizontal_speed > config.walk_speed + 0.5:
		new_state = GameConstants.MovementState.RUNNING
	else:
		new_state = GameConstants.MovementState.WALKING
		
	if new_state != current_movement_state:
		var old_state: GameConstants.MovementState = current_movement_state
		current_movement_state = new_state
		movement_state_changed.emit(current_movement_state, old_state)

func get_movement_state() -> GameConstants.MovementState:
	return current_movement_state

func is_grounded() -> bool:
	return is_on_floor()

func get_weapon_manager() -> Node:
	var wm = get_node_or_null("Camera3D/WeaponManager")
	if not wm:
		wm = get_node_or_null("Camera3D/WeaponHolder")
	if not wm:
		wm = get_node_or_null("Camera3D/WeaponRig")
	return wm