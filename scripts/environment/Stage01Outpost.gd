class_name Stage01Outpost
extends Node3D
## Performance-conscious modular desert outpost used only by Stage 01.

var _materials: Dictionary = {}

func _ready() -> void:
	_build_palette()
	_build_atmosphere()
	_build_terrain()
	_build_perimeter()
	_build_compound_structures()
	_build_tactical_cover()
	_build_background_scenery()

func _build_palette() -> void:
	_materials = {
		"sand": _make_material(Color("#9a7548"), 0.96),
		"sand_light": _make_material(Color("#b18b59"), 0.94),
		"road": _make_material(Color("#665441"), 0.98),
		"concrete": _make_material(Color("#77736a"), 0.91),
		"concrete_dark": _make_material(Color("#4d4d49"), 0.90),
		"olive": _make_material(Color("#394536"), 0.86),
		"olive_light": _make_material(Color("#58624a"), 0.86),
		"metal": _make_material(Color("#343b3b"), 0.70, 0.25),
		"rust": _make_material(Color("#70402c"), 0.86, 0.12),
		"wood": _make_material(Color("#624a32"), 0.88),
		"sandbag": _make_material(Color("#827259"), 0.97),
		"dark": _make_material(Color("#242725"), 0.82),
		"warning": _make_material(Color("#b89a44"), 0.84),
	}

func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _build_atmosphere() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#38628a")
	sky_material.sky_horizon_color = Color("#c9b38d")
	sky_material.ground_bottom_color = Color("#55452f")
	sky_material.ground_horizon_color = Color("#b99a6b")
	sky_material.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("#d7c6a6")
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#bda982")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.32

	var world_environment := WorldEnvironment.new()
	world_environment.name = "DesertWorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#ffe4b5")
	sun.light_energy = 1.28
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)

func _build_terrain() -> void:
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	_add_static_box(terrain, "PackedSandGround", Vector3(0, -0.5, 0), Vector3(82, 1, 82), _materials.sand)
	_add_visual_box(terrain, "MainVehicleTrack", Vector3(0, 0.015, -2), Vector3(9.5, 0.025, 70), _materials.road)
	_add_visual_box(terrain, "WestTireTrack", Vector3(-2.65, 0.035, -2), Vector3(0.35, 0.028, 67), _materials.concrete_dark)
	_add_visual_box(terrain, "EastTireTrack", Vector3(2.65, 0.035, -2), Vector3(0.35, 0.028, 67), _materials.concrete_dark)
	for patch_data in [
		[Vector3(-19, 0.02, 17), Vector3(13, 0.03, 8), -8.0],
		[Vector3(18, 0.02, 10), Vector3(12, 0.03, 7), 11.0],
		[Vector3(-21, 0.02, -24), Vector3(10, 0.03, 7), 4.0],
		[Vector3(20, 0.02, -29), Vector3(11, 0.03, 6), -7.0],
	]:
		_add_visual_box(terrain, "WornSandPatch", patch_data[0], patch_data[1], _materials.sand_light, patch_data[2])

func _build_perimeter() -> void:
	var perimeter := Node3D.new()
	perimeter.name = "Perimeter"
	add_child(perimeter)
	_add_static_box(perimeter, "NorthWall", Vector3(0, 1.75, -34), Vector3(68, 3.5, 0.7), _materials.concrete)
	_add_static_box(perimeter, "WestWall", Vector3(-34, 1.75, 0), Vector3(0.7, 3.5, 68), _materials.concrete)
	_add_static_box(perimeter, "EastWall", Vector3(34, 1.75, 0), Vector3(0.7, 3.5, 68), _materials.concrete)
	_add_static_box(perimeter, "SouthWallWest", Vector3(-20.25, 1.75, 34), Vector3(27.5, 3.5, 0.7), _materials.concrete)
	_add_static_box(perimeter, "SouthWallEast", Vector3(20.25, 1.75, 34), Vector3(27.5, 3.5, 0.7), _materials.concrete)

	for x in [-6.9, 6.9]:
		_add_static_box(perimeter, "GatePillar", Vector3(x, 2.35, 33.8), Vector3(1.1, 4.7, 1.1), _materials.concrete_dark)
	_add_visual_box(perimeter, "GateHeader", Vector3(0, 4.25, 33.8), Vector3(12.8, 0.55, 0.75), _materials.metal)
	_add_visual_box(perimeter, "GateStripeA", Vector3(-3.1, 4.25, 33.38), Vector3(2.4, 0.12, 0.03), _materials.warning, 12.0)
	_add_visual_box(perimeter, "GateStripeB", Vector3(3.1, 4.25, 33.38), Vector3(2.4, 0.12, 0.03), _materials.warning, 12.0)

	for z in range(-28, 29, 8):
		_add_visual_box(perimeter, "WestButtress", Vector3(-33.45, 1.1, z), Vector3(0.8, 2.2, 1.2), _materials.concrete_dark)
		_add_visual_box(perimeter, "EastButtress", Vector3(33.45, 1.1, z), Vector3(0.8, 2.2, 1.2), _materials.concrete_dark)
	for x in range(-28, 29, 8):
		_add_visual_box(perimeter, "NorthButtress", Vector3(x, 1.1, -33.45), Vector3(1.2, 2.2, 0.8), _materials.concrete_dark)

	_add_fence_run(perimeter, Vector3(-15, 3.75, 33.65), 15.0, true)
	_add_fence_run(perimeter, Vector3(15, 3.75, 33.65), 15.0, true)
	_add_gate_sign(perimeter)

func _build_compound_structures() -> void:
	var structures := Node3D.new()
	structures.name = "Structures"
	add_child(structures)
	_add_building(structures, "WestBarracks", Vector3(-21.5, 2.25, -12.5), Vector3(12.5, 4.5, 10), _materials.olive_light)
	_add_building(structures, "EastCommand", Vector3(21.0, 2.45, -20.5), Vector3(13.5, 4.9, 11), _materials.concrete)
	_add_building(structures, "GateHouseWest", Vector3(-11.0, 1.65, 26.5), Vector3(5.0, 3.3, 5.2), _materials.concrete)
	_add_building(structures, "GateHouseEast", Vector3(11.0, 1.65, 26.5), Vector3(5.0, 3.3, 5.2), _materials.concrete)
	_add_container(structures, "WestCargoContainer", Vector3(-17.5, 1.35, 5.5), -4.0, _materials.olive)
	_add_container(structures, "EastCargoContainer", Vector3(17.0, 1.35, 3.0), 6.0, _materials.rust)
	_add_watchtower(structures, Vector3(-27.0, 0.0, -27.0))

	# Rear maintenance shelter frames the objective end without blocking the road.
	_add_static_box(structures, "RearShelter", Vector3(0, 1.65, -31.0), Vector3(12, 3.3, 4.0), _materials.olive)
	_add_visual_box(structures, "RearShelterRoof", Vector3(0, 3.55, -31.0), Vector3(13, 0.35, 5), _materials.metal)
	_add_visual_box(structures, "RearShelterDoor", Vector3(0, 1.35, -28.97), Vector3(3.1, 2.7, 0.08), _materials.dark)

func _add_building(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var building := Node3D.new()
	building.name = node_name
	building.position = position
	parent.add_child(building)
	_add_static_box(building, "MainBlock", Vector3.ZERO, size, material)
	_add_visual_box(building, "RoofSlab", Vector3(0, size.y * 0.5 + 0.16, 0), Vector3(size.x + 0.5, 0.32, size.z + 0.5), _materials.metal)
	_add_visual_box(building, "Foundation", Vector3(0, -size.y * 0.5 + 0.15, 0), Vector3(size.x + 0.35, 0.3, size.z + 0.35), _materials.concrete_dark)
	_add_visual_box(building, "Door", Vector3(0, -size.y * 0.5 + 1.25, size.z * 0.5 + 0.045), Vector3(1.65, 2.5, 0.09), _materials.dark)
	for x in [-size.x * 0.28, size.x * 0.28]:
		_add_visual_box(building, "Window", Vector3(x, 0.4, size.z * 0.5 + 0.05), Vector3(1.8, 0.95, 0.1), _materials.metal)
		_add_visual_box(building, "WindowShade", Vector3(x, 1.0, size.z * 0.5 + 0.28), Vector3(2.15, 0.12, 0.55), _materials.olive)
	_add_visual_box(building, "RoofVent", Vector3(size.x * 0.25, size.y * 0.5 + 0.65, 0), Vector3(1.2, 0.9, 1.2), _materials.metal)

func _add_container(parent: Node3D, node_name: String, position: Vector3, rotation_y: float, material: Material) -> void:
	var container := Node3D.new()
	container.name = node_name
	container.position = position
	container.rotation_degrees.y = rotation_y
	parent.add_child(container)
	_add_static_box(container, "ContainerBody", Vector3.ZERO, Vector3(3.1, 2.7, 8.2), material)
	for z in [-3.7, -2.45, -1.2, 0.0, 1.2, 2.45, 3.7]:
		_add_visual_box(container, "SideRibLeft", Vector3(-1.58, 0, z), Vector3(0.12, 2.76, 0.13), _materials.metal)
		_add_visual_box(container, "SideRibRight", Vector3(1.58, 0, z), Vector3(0.12, 2.76, 0.13), _materials.metal)
	_add_visual_box(container, "DoorFrame", Vector3(0, 0, 4.13), Vector3(2.75, 2.35, 0.12), _materials.metal)
	_add_visual_box(container, "DoorSplit", Vector3(0, 0, 4.2), Vector3(0.08, 2.15, 0.08), _materials.dark)

func _add_watchtower(parent: Node3D, position: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "Watchtower"
	tower.position = position
	parent.add_child(tower)
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			_add_static_box(tower, "TowerLeg", Vector3(x, 3.0, z), Vector3(0.38, 6.0, 0.38), _materials.metal)
	_add_visual_box(tower, "Platform", Vector3(0, 5.5, 0), Vector3(4.6, 0.35, 4.6), _materials.metal)
	_add_visual_box(tower, "Cabin", Vector3(0, 6.65, 0), Vector3(3.8, 2.0, 3.8), _materials.olive)
	_add_visual_box(tower, "Canopy", Vector3(0, 7.85, 0), Vector3(4.5, 0.25, 4.5), _materials.metal)
	for x in [-1.95, 1.95]:
		_add_visual_box(tower, "Rail", Vector3(x, 6.0, 0), Vector3(0.12, 0.8, 4.2), _materials.metal)
	for z in [-1.95, 1.95]:
		_add_visual_box(tower, "Rail", Vector3(0, 6.0, z), Vector3(4.2, 0.8, 0.12), _materials.metal)

func _build_tactical_cover() -> void:
	var cover := Node3D.new()
	cover.name = "TacticalCover"
	add_child(cover)
	_add_jersey_barrier(cover, Vector3(-10.5, 0, -2.5), 8.0)
	_add_jersey_barrier(cover, Vector3(10.5, 0, -8.0), -7.0)
	_add_jersey_barrier(cover, Vector3(-12.0, 0, -25.0), -18.0)
	_add_sandbag_wall(cover, Vector3(-7.5, 0, -16.5), 4.8, 8.0)
	_add_sandbag_wall(cover, Vector3(12.5, 0, -24.5), 5.2, -10.0)
	_add_sandbag_wall(cover, Vector3(17.0, 0, 17.0), 4.2, 90.0)

	_add_crate_stack(cover, Vector3(-13.0, 0, 16.0), 0.0)
	_add_crate_stack(cover, Vector3(14.5, 0, 13.5), 12.0)
	_add_crate_stack(cover, Vector3(27.0, 0, -10.0), -8.0)

	# Sparse debris lives outside the main movement lanes.
	for debris in [
		[Vector3(-28, 0.18, 13), Vector3(2.1, 0.35, 0.55), 24.0],
		[Vector3(27, 0.12, 18), Vector3(1.5, 0.24, 0.42), -31.0],
		[Vector3(-25, 0.1, -4), Vector3(1.2, 0.2, 0.35), 63.0],
	]:
		_add_visual_box(cover, "LimitedDebris", debris[0], debris[1], _materials.wood, debris[2])

func _add_jersey_barrier(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var barrier := Node3D.new()
	barrier.name = "ConcreteBarrier"
	barrier.position = position
	barrier.rotation_degrees.y = rotation_y
	parent.add_child(barrier)
	_add_static_box(barrier, "BarrierCore", Vector3(0, 0.58, 0), Vector3(4.4, 1.16, 0.72), _materials.concrete)
	_add_visual_box(barrier, "BarrierFoot", Vector3(0, 0.16, 0), Vector3(4.7, 0.32, 1.12), _materials.concrete_dark)
	_add_visual_box(barrier, "WarningBand", Vector3(0, 0.78, 0.37), Vector3(1.2, 0.16, 0.03), _materials.warning)

func _add_sandbag_wall(parent: Node3D, position: Vector3, length: float, rotation_y: float) -> void:
	var wall := Node3D.new()
	wall.name = "SandbagWall"
	wall.position = position
	wall.rotation_degrees.y = rotation_y
	parent.add_child(wall)
	_add_collision_box(wall, "SandbagCollision", Vector3(0, 0.48, 0), Vector3(length, 0.96, 0.72))
	var bag_count := maxi(3, int(length / 0.85))
	var spacing := length / float(bag_count)
	for row in 2:
		for i in bag_count:
			var x := -length * 0.5 + spacing * (float(i) + 0.5) + (spacing * 0.25 if row == 1 else 0.0)
			_add_capsule(wall, "Sandbag", Vector3(x, 0.27 + row * 0.46, 0), 0.24, 0.82, _materials.sandbag, Vector3(0, 0, 90))

func _add_crate_stack(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var stack := Node3D.new()
	stack.name = "SupplyCrates"
	stack.position = position
	stack.rotation_degrees.y = rotation_y
	parent.add_child(stack)
	for crate_data in [
		[Vector3(-0.72, 0.65, 0), Vector3(1.3, 1.3, 1.3)],
		[Vector3(0.72, 0.65, 0.08), Vector3(1.3, 1.3, 1.3)],
		[Vector3(0, 1.95, 0), Vector3(1.3, 1.3, 1.3)],
	]:
		_add_static_box(stack, "Crate", crate_data[0], crate_data[1], _materials.wood)
		_add_visual_box(stack, "CrateBand", crate_data[0] + Vector3(0, 0, 0.66), Vector3(0.16, 1.08, 0.03), _materials.metal)

func _build_background_scenery() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "DistantScenery"
	add_child(backdrop)
	for dune_data in [
		[Vector3(-52, -1.5, -42), Vector3(24, 5, 12)],
		[Vector3(48, -1.8, -47), Vector3(22, 4.5, 13)],
		[Vector3(-50, -2.0, 35), Vector3(20, 4, 10)],
		[Vector3(51, -2.2, 31), Vector3(26, 5, 12)],
	]:
		_add_dune(backdrop, dune_data[0], dune_data[1])
	for rock_data in [
		[Vector3(-39, 0.5, -19), Vector3(2.8, 1.4, 2.0)],
		[Vector3(40, 0.4, 8), Vector3(2.2, 1.1, 1.7)],
		[Vector3(-42, 0.3, 18), Vector3(1.8, 0.9, 1.4)],
	]:
		_add_dune(backdrop, rock_data[0], rock_data[1], _materials.concrete_dark)

func _add_dune(parent: Node3D, position: Vector3, scale_value: Vector3, material: Material = null) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Dune"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material if material else _materials.sand_light
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = scale_value
	parent.add_child(mesh_instance)

func _add_fence_run(parent: Node3D, center: Vector3, length: float, along_x: bool) -> void:
	var fence := Node3D.new()
	fence.name = "SecurityFence"
	fence.position = center
	parent.add_child(fence)
	var post_count := maxi(2, int(length / 3.0) + 1)
	for i in post_count:
		var offset := -length * 0.5 + length * float(i) / float(post_count - 1)
		var post_pos := Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
		_add_visual_box(fence, "FencePost", post_pos, Vector3(0.12, 1.6, 0.12), _materials.metal)
	var rail_size := Vector3(length, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, length)
	_add_visual_box(fence, "FenceRail", Vector3(0, -0.45, 0), rail_size, _materials.metal)
	_add_visual_box(fence, "FenceRail", Vector3(0, 0.35, 0), rail_size, _materials.metal)

func _add_gate_sign(parent: Node3D) -> void:
	var sign := Label3D.new()
	sign.name = "OutpostSign"
	sign.text = "FORWARD OUTPOST 01  //  RESTRICTED"
	sign.font_size = 42
	sign.modulate = Color("#d7c38a")
	sign.outline_modulate = Color("#1b1d1b")
	sign.outline_size = 8
	sign.position = Vector3(0, 4.45, 33.35)
	sign.rotation_degrees.y = 180.0
	sign.pixel_size = 0.007
	parent.add_child(sign)

func _add_static_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees.y = rotation_y
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _add_visual_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation_y: float = 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees.y = rotation_y
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_collision_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _add_capsule(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance
