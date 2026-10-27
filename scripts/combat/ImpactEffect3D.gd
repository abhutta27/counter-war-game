class_name ImpactEffect3D
extends Node3D
## ImpactEffect3D.gd
## High-speed visual spark and impact burst spawned at bullet impact points.
## Orientated with surface normal, plays expanding spark burst, and auto-frees.

@export var duration: float = 0.22

@onready var spark_mesh_1: MeshInstance3D = get_node_or_null("SparkMesh1")
@onready var spark_mesh_2: MeshInstance3D = get_node_or_null("SparkMesh2")
@onready var spark_mesh_3: MeshInstance3D = get_node_or_null("SparkMesh3")
@onready var impact_light: OmniLight3D = get_node_or_null("ImpactLight")

static var _player_impact_material: StandardMaterial3D
static var _enemy_impact_material: StandardMaterial3D

func _ready() -> void:
	# Randomize sparks orientation
	rotation.z = randf_range(0.0, TAU)
	
	# Tween expansion and fade-out
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), duration)
	
	if spark_mesh_1:
		tw.tween_property(spark_mesh_1, "position", Vector3(randf_range(-0.15, 0.15), randf_range(0.1, 0.25), randf_range(-0.15, 0.15)), duration)
	if spark_mesh_2:
		tw.tween_property(spark_mesh_2, "position", Vector3(randf_range(-0.2, 0.2), randf_range(0.05, 0.2), randf_range(-0.2, 0.2)), duration)
	if spark_mesh_3:
		tw.tween_property(spark_mesh_3, "position", Vector3(randf_range(-0.18, 0.18), randf_range(0.08, 0.22), randf_range(-0.18, 0.18)), duration)
		
	if impact_light:
		tw.tween_property(impact_light, "light_energy", 0.0, duration)
		
	tw.chain().tween_callback(queue_free)

func setup(p_position: Vector3, p_normal: Vector3, p_is_player: bool = true) -> void:
	global_position = p_position
	if p_normal.length_squared() > 0.001 and abs(p_normal.y) < 0.99:
		look_at(p_position + p_normal, Vector3.UP)
	elif p_normal.length_squared() > 0.001:
		look_at(p_position + p_normal, Vector3.RIGHT)
		
	var spark_color = Color(1.0, 0.9, 0.35, 1.0) if p_is_player else Color(1.0, 0.45, 0.2, 1.0)
	var mat := _player_impact_material if p_is_player else _enemy_impact_material
	if not mat:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = spark_color
		if p_is_player:
			_player_impact_material = mat
		else:
			_enemy_impact_material = mat
	
	if spark_mesh_1:
		spark_mesh_1.material_override = mat
	if spark_mesh_2:
		spark_mesh_2.material_override = mat
	if spark_mesh_3:
		spark_mesh_3.material_override = mat
	if impact_light:
		impact_light.light_color = spark_color
