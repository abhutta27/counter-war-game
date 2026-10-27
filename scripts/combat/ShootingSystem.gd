extends Node
## ShootingSystem.gd
## Centralized, reusable combat effects and projectile coordinator.
## Manages visible projectile flight, muzzle flash triggers, and impact spark effects
## across all stages (Stage 1 to 6 and future stages) without code duplication.

const ProjectileScene = preload("res://scenes/combat/Projectile3D.tscn")
const MuzzleFlashScene = preload("res://scenes/combat/MuzzleFlash3D.tscn")
const ImpactEffectScene = preload("res://scenes/combat/ImpactEffect3D.tscn")

var _projectiles_container: Node3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Returns or creates a clean 3D container node inside the active scene for projectiles
func _get_active_world_container() -> Node3D:
	if _projectiles_container and is_instance_valid(_projectiles_container) and _projectiles_container.is_inside_tree():
		return _projectiles_container
		
	var tree = get_tree()
	if not tree:
		return null
		
	# Look for active level scene
	var current_scene = tree.current_scene
	if not current_scene:
		var root = tree.root
		for child in root.get_children():
			if child is Node3D and not (child is SubViewport):
				current_scene = child
				break
				
	if current_scene:
		var container = current_scene.get_node_or_null("ActiveCombatFX")
		if not container:
			container = Node3D.new()
			container.name = "ActiveCombatFX"
			current_scene.add_child(container)
		_projectiles_container = container
		return _projectiles_container
		
	return null

## Spawns a visible 3D bullet traveling from shooter origin towards target point
func spawn_projectile(origin: Vector3, target: Vector3, is_player: bool, callback: Callable = Callable(), custom_speed: float = -1.0, path_prevalidated: bool = false) -> Node3D:
	var container = _get_active_world_container()
	if not container:
		# Fallback if no 3D scene: invoke callback immediately
		if callback.is_valid():
			callback.call(target, Vector3.UP)
		return null
		
	var proj = ProjectileScene.instantiate() as Node3D
	container.add_child(proj)
	
	var flight_speed = custom_speed
	if flight_speed <= 0.0:
		flight_speed = 75.0 if is_player else 55.0
		
	if proj.has_method("setup"):
		proj.setup(origin, target, is_player, callback, flight_speed, path_prevalidated)
	return proj

## Attaches or triggers a reusable muzzle flash on a weapon barrel
func trigger_muzzle_flash(parent_node: Node3D, local_offset: Vector3 = Vector3.ZERO, is_player: bool = true) -> Node3D:
	if not parent_node or not is_instance_valid(parent_node):
		return null
		
	var flash_node: Node3D = parent_node.get_node_or_null("MuzzleFlash3D") as Node3D
	if not flash_node:
		flash_node = MuzzleFlashScene.instantiate() as Node3D
		flash_node.name = "MuzzleFlash3D"
		if "is_player" in flash_node:
			flash_node.is_player = is_player
		flash_node.position = local_offset
		parent_node.add_child(flash_node)
	else:
		flash_node.position = local_offset
		
	if flash_node.has_method("flash"):
		flash_node.flash()
	return flash_node

## Spawns a spark burst at the impact position aligned with surface normal
func spawn_impact_effect(pos: Vector3, normal: Vector3, is_player: bool = true) -> Node3D:
	var container = _get_active_world_container()
	if not container:
		return null
		
	var impact = ImpactEffectScene.instantiate() as Node3D
	container.add_child(impact)
	if impact.has_method("setup"):
		impact.setup(pos, normal, is_player)
	return impact

## Cleans up all projectiles when changing stages
func clear_all() -> void:
	if _projectiles_container and is_instance_valid(_projectiles_container):
		for child in _projectiles_container.get_children():
			child.queue_free()
