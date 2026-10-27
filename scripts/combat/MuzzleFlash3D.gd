class_name MuzzleFlash3D
extends Node3D
## MuzzleFlash3D.gd
## High-intensity muzzle flash with stylized spark cross mesh, dynamic point light,
## and rapid-fire-safe automatic timer reset.

@export var flash_duration: float = 0.055
@export var is_player: bool = true

@onready var flash_mesh_1: MeshInstance3D = get_node_or_null("FlashMesh1")
@onready var flash_mesh_2: MeshInstance3D = get_node_or_null("FlashMesh2")
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")

var _flash_tween: Tween = null

func _ready() -> void:
	visible = false
	_apply_colors()

func _apply_colors() -> void:
	var flash_color: Color = Color(1.0, 0.95, 0.45, 1.0) if is_player else Color(1.0, 0.45, 0.2, 1.0)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = flash_color
	
	if flash_mesh_1:
		flash_mesh_1.material_override = mat
	if flash_mesh_2:
		flash_mesh_2.material_override = mat
	if omni_light:
		omni_light.light_color = flash_color

## Triggers crisp flash visible for flash_duration
func flash() -> void:
	visible = true
	rotation.z = randf_range(0.0, PI)
	var scale_var = randf_range(0.85, 1.15)
	scale = Vector3(scale_var, scale_var, scale_var)
	
	if omni_light:
		omni_light.light_energy = randf_range(2.0, 3.2)
		
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween()
	_flash_tween.tween_interval(flash_duration)
	_flash_tween.tween_callback(func():
		visible = false
	)
