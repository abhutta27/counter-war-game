class_name PlayerCameraConfig
extends Resource
## PlayerCameraConfig.gd
## Configuration settings for First-Person Camera, mouse sensitivity, pitch limits, and FOV.

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.002
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = 85.0
@export var invert_y: bool = false

@export_group("Field Of View")
@export var base_fov: float = 75.0
@export var aim_fov: float = 60.0
@export var fov_transition_speed: float = 12.0

@export_group("Recoil & Shake Architecture")
@export var recoil_recovery_speed: float = 14.0
@export var max_recoil_pitch_deg: float = 10.0