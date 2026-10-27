class_name PlayerMovementConfig
extends Resource
## PlayerMovementConfig.gd
## Data-driven configuration for physics-based character movement and speeds.

@export_group("Speeds")
@export var walk_speed: float = 4.5
@export var run_speed: float = 6.5
@export var sprint_speed: float = 9.0
@export var crouch_speed: float = 2.5

@export_group("Jump & Gravity")
@export var jump_velocity: float = 4.8
@export var gravity: float = 14.0
@export var fall_gravity_multiplier: float = 1.2
@export var max_fall_speed: float = 30.0

@export_group("Acceleration & Deceleration")
@export var ground_acceleration: float = 14.0
@export var ground_deceleration: float = 16.0
@export var air_acceleration: float = 4.0
@export var air_deceleration: float = 2.0

@export_group("Crouch Architecture")
@export var standing_height: float = 1.8
@export var crouch_height: float = 1.2
@export var standing_camera_y: float = 1.55
@export var crouching_camera_y: float = 0.95
@export var crouch_transition_speed: float = 10.0