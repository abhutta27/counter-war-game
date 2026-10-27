class_name Projectile3D
extends Node3D
## Projectile3D.gd
## High-visibility 3D projectile with elongated glowing tracer tail,
## smooth flight physics, obstacle raycast collision, and impact trigger.

@export var speed: float = 75.0
@export var is_player: bool = true
@export var max_lifetime: float = 2.5

var direction: Vector3 = Vector3.FORWARD
var target_point: Vector3 = Vector3.ZERO
var has_target: bool = false
var distance_traveled: float = 0.0
var max_distance: float = 100.0
var path_prevalidated: bool = false

var _on_hit_callback: Callable = Callable()
var _is_destroyed: bool = false
var _lifetime_timer: float = 0.0

static var _player_core_material: StandardMaterial3D
static var _enemy_core_material: StandardMaterial3D
static var _player_trail_material: StandardMaterial3D
static var _enemy_trail_material: StandardMaterial3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_mesh: MeshInstance3D = $TrailMesh
@onready var bullet_light: OmniLight3D = get_node_or_null("BulletLight")

func _ready() -> void:
	# Set colors based on shooter (Player = Golden Amber, Enemy = Crimson Orange)
	_apply_visual_styling()

func setup(p_origin: Vector3, p_target: Vector3, p_is_player: bool, p_callback: Callable = Callable(), p_speed: float = 75.0, p_path_prevalidated: bool = false) -> void:
	global_position = p_origin
	target_point = p_target
	has_target = true
	is_player = p_is_player
	_on_hit_callback = p_callback
	speed = p_speed
	path_prevalidated = p_path_prevalidated
	
	max_distance = global_position.distance_to(target_point)
	if max_distance < 0.1:
		max_distance = 100.0
		direction = -global_transform.basis.z
	else:
		direction = (target_point - global_position).normalized()
		# Orient bullet along flight path
		if direction.length_squared() > 0.001:
			look_at(global_position + direction, Vector3.UP if abs(direction.y) < 0.99 else Vector3.RIGHT)
			
	_apply_visual_styling()

func _apply_visual_styling() -> void:
	var core_color: Color = Color(1.0, 0.92, 0.35, 1.0) if is_player else Color(1.0, 0.32, 0.18, 1.0)
	var trail_color: Color = Color(1.0, 0.85, 0.25, 0.85) if is_player else Color(1.0, 0.25, 0.15, 0.85)
	
	if mesh_instance:
		var core_material := _player_core_material if is_player else _enemy_core_material
		if not core_material:
			core_material = StandardMaterial3D.new()
			core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			core_material.albedo_color = core_color
			if is_player:
				_player_core_material = core_material
			else:
				_enemy_core_material = core_material
		mesh_instance.material_override = core_material
		
	if trail_mesh:
		var trail_material := _player_trail_material if is_player else _enemy_trail_material
		if not trail_material:
			trail_material = StandardMaterial3D.new()
			trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			trail_material.albedo_color = trail_color
			if is_player:
				_player_trail_material = trail_material
			else:
				_enemy_trail_material = trail_material
		trail_mesh.material_override = trail_material
		
	if bullet_light:
		bullet_light.light_color = core_color
		bullet_light.light_energy = 1.2
		bullet_light.omni_range = 3.0

func _process(delta: float) -> void:
	if _is_destroyed:
		return
		
	_lifetime_timer += delta
	if _lifetime_timer >= max_lifetime:
		_destroy()
		return
		
	var move_amount = speed * delta
	var next_position = global_position + (direction * move_amount)
	
	# Raycast check along the current movement step to avoid tunneling through thin geometry
	var space_state = get_world_3d().direct_space_state if get_world_3d() else null
	if not path_prevalidated and space_state:
		var query = PhysicsRayQueryParameters3D.create(global_position, next_position)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider = hit.collider
			var hit_pos: Vector3 = hit.position
			var hit_norm: Vector3 = hit.normal
			
			var is_friendly_hit = false
			if is_player and (collider is CharacterBody3D and collider.is_in_group("player")):
				is_friendly_hit = true
			elif not is_player and (collider is CharacterBody3D and collider.is_in_group("enemies")):
				is_friendly_hit = true
				
			if not is_friendly_hit:
				global_position = hit_pos
				_on_impact(hit_pos, hit_norm)
				return
				
	# Advance position
	global_position = next_position
	distance_traveled += move_amount
	
	# Check if reached target destination
	if has_target and distance_traveled >= max_distance:
		_on_impact(target_point, -direction)

func _on_impact(impact_pos: Vector3, impact_normal: Vector3) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	
	# Trigger hit callback (e.g. deliver damage, hitmarker)
	if _on_hit_callback.is_valid():
		_on_hit_callback.call(impact_pos, impact_normal)
		
	# Trigger visual impact effect via ShootingSystem if available
	var sys = get_node_or_null("/root/ShootingSystem")
	if sys and sys.has_method("spawn_impact_effect"):
		sys.spawn_impact_effect(impact_pos, impact_normal, is_player)
		
	queue_free()

func _destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	queue_free()
