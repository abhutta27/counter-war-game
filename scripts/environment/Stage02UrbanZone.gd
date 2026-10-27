class_name Stage02UrbanZone
extends Node3D
## Optimized modular abandoned-city environment used exclusively by Stage 02.

var _materials: Dictionary = {}

func _ready() -> void:
	_build_palette()
	_build_atmosphere()
	_build_streets()
	_build_city_blocks()
	_build_street_details()
	_build_background_silhouette()

func _build_palette() -> void:
	_materials = {
		"asphalt": _make_material(Color("#343638"), 0.96),
		"asphalt_worn": _make_material(Color("#484640"), 0.97),
		"concrete": _make_material(Color("#6d6b65"), 0.92),
		"concrete_dark": _make_material(Color("#484947"), 0.90),
		"plaster": _make_material(Color("#796f65"), 0.93),
		"plaster_faded": _make_material(Color("#807a6c"), 0.94),
		"brick": _make_material(Color("#6d4739"), 0.94),
		"metal": _make_material(Color("#303537"), 0.72, 0.28),
		"rust": _make_material(Color("#754330"), 0.89, 0.10),
		"glass_dark": _make_material(Color("#263239"), 0.62, 0.08),
		"wood": _make_material(Color("#594735"), 0.92),
		"dust": _make_material(Color("#87755e"), 0.98),
		"faded_blue": _make_material(Color("#4f6266"), 0.90),
		"faded_green": _make_material(Color("#596255"), 0.91),
		"warning": _make_material(Color("#b69a4d"), 0.86),
	}

func _make_material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _build_atmosphere() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4a5967")
	sky_material.sky_horizon_color = Color("#a9957f")
	sky_material.ground_bottom_color = Color("#2d2b2a")
	sky_material.ground_horizon_color = Color("#75685a")
	sky_material.sun_angle_max = 14.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("#b8b2aa")
	environment.ambient_light_energy = 0.64
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#8f8375")
	environment.fog_light_energy = 0.48
	environment.fog_density = 0.0055
	environment.fog_sky_affect = 0.38

	var world_environment := WorldEnvironment.new()
	world_environment.name = "UrbanWorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = Color("#f3cfaa")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 92.0
	add_child(sun)

func _build_streets() -> void:
	var streets := Node3D.new()
	streets.name = "Streets"
	add_child(streets)
	_add_static_box(streets, "CityGround", Vector3(0, -0.5, 0), Vector3(88, 1, 88), _materials.concrete_dark)
	_add_visual_box(streets, "MainAvenue", Vector3(0, 0.015, -2), Vector3(17, 0.03, 82), _materials.asphalt)
	_add_visual_box(streets, "CrossStreet", Vector3(0, 0.025, -13), Vector3(72, 0.035, 9), _materials.asphalt)
	_add_visual_box(streets, "WestServiceAlley", Vector3(-25, 0.03, 11.5), Vector3(20, 0.04, 5), _materials.asphalt_worn)
	_add_visual_box(streets, "EastServiceAlley", Vector3(25, 0.03, 9), Vector3(20, 0.04, 4), _materials.asphalt_worn)

	# Raised-looking but non-colliding sidewalks preserve smooth FPS movement.
	_add_visual_box(streets, "WestSidewalk", Vector3(-10.5, 0.07, -2), Vector3(4, 0.14, 82), _materials.concrete)
	_add_visual_box(streets, "EastSidewalk", Vector3(10.5, 0.07, -2), Vector3(4, 0.14, 82), _materials.concrete)
	for z in range(-36, 37, 8):
		_add_visual_box(streets, "LaneDash", Vector3(0, 0.055, z), Vector3(0.22, 0.035, 3.1), _materials.warning)
	_add_visual_box(streets, "CrosswalkA", Vector3(-3.0, 0.06, -8.4), Vector3(1.25, 0.035, 3.8), _materials.concrete)
	_add_visual_box(streets, "CrosswalkB", Vector3(0.0, 0.06, -8.4), Vector3(1.25, 0.035, 3.8), _materials.concrete)
	_add_visual_box(streets, "CrosswalkC", Vector3(3.0, 0.06, -8.4), Vector3(1.25, 0.035, 3.8), _materials.concrete)

func _build_city_blocks() -> void:
	var blocks := Node3D.new()
	blocks.name = "DamagedCityBlocks"
	add_child(blocks)
	_add_damaged_building(blocks, "SouthWestApartments", Vector3(-25, 4.2, 23), Vector3(18, 8.4, 16), _materials.plaster_faded, 3)
	_add_storefront_building(blocks, "SouthEastStores", Vector3(25, 3.4, 21), Vector3(18, 6.8, 17), _materials.faded_blue)
	_add_damaged_building(blocks, "MidWestOffices", Vector3(-25, 5.1, 1), Vector3(18, 10.2, 16), _materials.concrete, 4)
	_add_damaged_building(blocks, "MidEastHotel", Vector3(25, 5.7, -3), Vector3(18, 11.4, 20), _materials.plaster, 5)
	_add_storefront_building(blocks, "NorthWestMarket", Vector3(-25, 4.0, -23), Vector3(18, 8.0, 14), _materials.faded_green)
	_add_damaged_building(blocks, "NorthEastResidences", Vector3(25, 4.6, -27), Vector3(18, 9.2, 12), _materials.brick, 4)
	_add_damaged_building(blocks, "TerminalBlock", Vector3(0, 4.0, -40), Vector3(25, 8, 6), _materials.concrete_dark, 3)

	# Boundary fragments suggest a larger district without a clean arena wall.
	_add_static_box(blocks, "WestBoundary", Vector3(-43, 2.0, 0), Vector3(1, 4, 86), _materials.concrete_dark)
	_add_static_box(blocks, "EastBoundary", Vector3(43, 2.0, 0), Vector3(1, 4, 86), _materials.concrete_dark)
	_add_static_box(blocks, "SouthBoundaryWest", Vector3(-27, 2.0, 43), Vector3(32, 4, 1), _materials.concrete_dark)
	_add_static_box(blocks, "SouthBoundaryEast", Vector3(27, 2.0, 43), Vector3(32, 4, 1), _materials.concrete_dark)

func _add_damaged_building(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, floors: int) -> void:
	var building := Node3D.new()
	building.name = node_name
	building.position = position
	parent.add_child(building)
	_add_static_box(building, "BuildingShell", Vector3.ZERO, size, material)
	_add_visual_box(building, "Foundation", Vector3(0, -size.y * 0.5 + 0.2, 0), Vector3(size.x + 0.4, 0.4, size.z + 0.4), _materials.concrete_dark)
	_add_visual_box(building, "RoofSlab", Vector3(-0.8, size.y * 0.5 + 0.18, 0), Vector3(size.x - 1.6, 0.36, size.z + 0.3), _materials.concrete_dark, -1.5)
	_add_visual_box(building, "BrokenRoofChunk", Vector3(size.x * 0.36, size.y * 0.5 + 0.05, size.z * 0.30), Vector3(size.x * 0.22, 0.6, size.z * 0.28), _materials.brick, 8.0)

	var floor_spacing := size.y / float(floors + 1)
	for floor_index in floors:
		var window_y := -size.y * 0.5 + floor_spacing * float(floor_index + 1)
		for x in [-size.x * 0.28, 0.0, size.x * 0.28]:
			if floor_index == floors - 1 and x > size.x * 0.2:
				continue
			_add_visual_box(building, "DarkWindow", Vector3(x, window_y, size.z * 0.5 + 0.055), Vector3(2.0, 1.15, 0.11), _materials.glass_dark)
			if (floor_index + int(absf(x))) % 3 == 0:
				_add_visual_box(building, "BoardedWindow", Vector3(x, window_y, size.z * 0.5 + 0.13), Vector3(2.25, 0.18, 0.10), _materials.wood, -9.0)
	_add_visual_box(building, "Entrance", Vector3(-size.x * 0.18, -size.y * 0.5 + 1.45, size.z * 0.5 + 0.06), Vector3(2.3, 2.9, 0.12), _materials.glass_dark)
	_add_visual_box(building, "FacadeScar", Vector3(size.x * 0.37, 0.3, size.z * 0.5 + 0.08), Vector3(1.2, size.y * 0.55, 0.14), _materials.brick, 7.0)

func _add_storefront_building(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> void:
	_add_damaged_building(parent, node_name, position, size, material, 3)
	var building := parent.get_node(node_name) as Node3D
	for x in [-size.x * 0.28, 0.0, size.x * 0.28]:
		_add_visual_box(building, "Storefront", Vector3(x, -size.y * 0.5 + 1.15, size.z * 0.5 + 0.12), Vector3(3.4, 2.15, 0.14), _materials.glass_dark)
	_add_visual_box(building, "FadedAwning", Vector3(0, -size.y * 0.5 + 2.45, size.z * 0.5 + 0.65), Vector3(size.x * 0.72, 0.18, 1.15), _materials.rust, -2.0)

func _build_street_details() -> void:
	var details := Node3D.new()
	details.name = "UrbanStreetDetails"
	add_child(details)

	_add_abandoned_car(details, "AbandonedSedan", Vector3(7.0, 0, 14.0), -13.0, _materials.rust)
	_add_abandoned_car(details, "DustyUtilityCar", Vector3(-7.0, 0, -20.0), 8.0, _materials.faded_green)
	_add_delivery_van(details, Vector3(29.0, 0, -13.0), 86.0)

	_add_road_barrier(details, Vector3(-8.0, 0, 7.0), 74.0)
	_add_road_barrier(details, Vector3(8.0, 0, -5.0), -72.0)
	_add_road_barrier(details, Vector3(-9.0, 0, -31.5), 82.0)
	_add_broken_wall(details, Vector3(-12.8, 0, -12.5), 4.5, 90.0)
	_add_broken_wall(details, Vector3(12.8, 0, 20.0), 4.0, 90.0)

	_add_fence(details, Vector3(-35.0, 1.0, 11.5), 13.0, true)
	_add_fence(details, Vector3(35.0, 1.0, 9.0), 12.0, true)
	_add_crates(details, Vector3(-13.0, 0, 29.0), 6.0)
	_add_crates(details, Vector3(34.0, 0, -16.0), -8.0)

	for lamp_data in [
		[Vector3(-13.0, 0, 30.0), 1.0], [Vector3(13.0, 0, 19.0), -1.0],
		[Vector3(-13.0, 0, 3.0), 1.0], [Vector3(13.0, 0, -10.0), -1.0],
		[Vector3(-13.0, 0, -27.0), 1.0], [Vector3(13.0, 0, -32.0), -1.0],
	]:
		_add_streetlight(details, lamp_data[0], lamp_data[1])

	# Restrained rubble stays against curbs, leaving the chase corridor open.
	for rubble_data in [
		[Vector3(-13.7, 0.18, 18.5), Vector3(2.4, 0.35, 1.1), 17.0],
		[Vector3(13.8, 0.16, 2.0), Vector3(2.0, 0.3, 1.0), -12.0],
		[Vector3(-14.0, 0.14, -6.5), Vector3(1.7, 0.28, 0.9), 31.0],
		[Vector3(14.0, 0.17, -25.0), Vector3(2.2, 0.34, 1.1), -28.0],
	]:
		_add_rubble_cluster(details, rubble_data[0], rubble_data[1], rubble_data[2])

func _add_abandoned_car(parent: Node3D, node_name: String, position: Vector3, rotation_y: float, material: Material) -> void:
	var car := Node3D.new()
	car.name = node_name
	car.position = position
	car.rotation_degrees.y = rotation_y
	parent.add_child(car)
	_add_static_box(car, "Chassis", Vector3(0, 0.62, 0), Vector3(2.1, 0.65, 4.2), material)
	_add_visual_box(car, "Cabin", Vector3(0, 1.15, -0.2), Vector3(1.8, 0.75, 2.15), _materials.metal)
	_add_visual_box(car, "Windshield", Vector3(0, 1.25, -1.32), Vector3(1.55, 0.5, 0.08), _materials.glass_dark)
	for x in [-1.05, 1.05]:
		for z in [-1.35, 1.35]:
			_add_cylinder(car, "Wheel", Vector3(x, 0.43, z), 0.38, 0.28, _materials.metal, Vector3(0, 0, 90))

func _add_delivery_van(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var van := Node3D.new()
	van.name = "AbandonedDeliveryVan"
	van.position = position
	van.rotation_degrees.y = rotation_y
	parent.add_child(van)
	_add_static_box(van, "VanBody", Vector3(0, 1.1, 0), Vector3(2.5, 2.2, 5.2), _materials.plaster_faded)
	_add_visual_box(van, "RearRust", Vector3(0, 1.1, 2.64), Vector3(1.9, 1.5, 0.10), _materials.rust)
	_add_visual_box(van, "Windshield", Vector3(0, 1.55, -2.64), Vector3(1.9, 0.72, 0.10), _materials.glass_dark)

func _add_road_barrier(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var barrier := Node3D.new()
	barrier.name = "ConcreteRoadBarrier"
	barrier.position = position
	barrier.rotation_degrees.y = rotation_y
	parent.add_child(barrier)
	_add_static_box(barrier, "Core", Vector3(0, 0.55, 0), Vector3(4.3, 1.1, 0.68), _materials.concrete)
	_add_visual_box(barrier, "Foot", Vector3(0, 0.14, 0), Vector3(4.6, 0.28, 1.0), _materials.concrete_dark)
	_add_visual_box(barrier, "Stripe", Vector3(0, 0.72, 0.35), Vector3(1.35, 0.14, 0.03), _materials.warning)

func _add_broken_wall(parent: Node3D, position: Vector3, length: float, rotation_y: float) -> void:
	var wall := Node3D.new()
	wall.name = "BrokenWall"
	wall.position = position
	wall.rotation_degrees.y = rotation_y
	parent.add_child(wall)
	_add_static_box(wall, "WallLeft", Vector3(-length * 0.28, 0.75, 0), Vector3(length * 0.42, 1.5, 0.42), _materials.brick)
	_add_static_box(wall, "WallRight", Vector3(length * 0.34, 0.48, 0), Vector3(length * 0.25, 0.96, 0.42), _materials.brick)

func _add_fence(parent: Node3D, position: Vector3, length: float, along_x: bool) -> void:
	var fence := Node3D.new()
	fence.name = "BentSecurityFence"
	fence.position = position
	parent.add_child(fence)
	var count := maxi(2, int(length / 2.5) + 1)
	for i in count:
		var offset := -length * 0.5 + length * float(i) / float(count - 1)
		var post_position := Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
		_add_visual_box(fence, "FencePost", post_position, Vector3(0.12, 2.0, 0.12), _materials.metal, -3.0 if i % 2 == 0 else 2.0)
	var rail_size := Vector3(length, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, length)
	_add_visual_box(fence, "FenceRail", Vector3(0, -0.55, 0), rail_size, _materials.metal)
	_add_visual_box(fence, "FenceRail", Vector3(0, 0.25, 0), rail_size, _materials.metal)

func _add_crates(parent: Node3D, position: Vector3, rotation_y: float) -> void:
	var stack := Node3D.new()
	stack.name = "AbandonedCrates"
	stack.position = position
	stack.rotation_degrees.y = rotation_y
	parent.add_child(stack)
	_add_static_box(stack, "CrateA", Vector3(-0.7, 0.6, 0), Vector3(1.2, 1.2, 1.2), _materials.wood)
	_add_static_box(stack, "CrateB", Vector3(0.65, 0.6, 0.1), Vector3(1.2, 1.2, 1.2), _materials.wood)
	_add_static_box(stack, "CrateC", Vector3(0, 1.8, 0), Vector3(1.2, 1.2, 1.2), _materials.wood)

func _add_streetlight(parent: Node3D, position: Vector3, arm_direction: float) -> void:
	var lamp := Node3D.new()
	lamp.name = "DamagedStreetlight"
	lamp.position = position
	parent.add_child(lamp)
	_add_visual_box(lamp, "Pole", Vector3(0, 2.8, 0), Vector3(0.16, 5.6, 0.16), _materials.metal, 2.0 * arm_direction)
	_add_visual_box(lamp, "Arm", Vector3(0.65 * arm_direction, 5.45, 0), Vector3(1.4, 0.12, 0.12), _materials.metal, 4.0 * arm_direction)
	_add_visual_box(lamp, "Fixture", Vector3(1.3 * arm_direction, 5.30, 0), Vector3(0.6, 0.18, 0.35), _materials.glass_dark, 7.0 * arm_direction)

func _add_rubble_cluster(parent: Node3D, position: Vector3, scale_value: Vector3, rotation_y: float) -> void:
	var rubble := Node3D.new()
	rubble.name = "RubbleCluster"
	rubble.position = position
	rubble.rotation_degrees.y = rotation_y
	parent.add_child(rubble)
	_add_visual_box(rubble, "ChunkA", Vector3(-0.45, 0, 0), scale_value, _materials.concrete_dark, 12.0)
	_add_visual_box(rubble, "ChunkB", Vector3(0.55, 0.08, 0.15), scale_value * 0.68, _materials.brick, -18.0)
	_add_visual_box(rubble, "Rebar", Vector3(0.2, 0.35, 0), Vector3(1.6, 0.07, 0.07), _materials.rust, 31.0)

func _build_background_silhouette() -> void:
	var background := Node3D.new()
	background.name = "BackgroundCitySilhouette"
	add_child(background)
	for block_data in [
		[Vector3(-52, 8, -24), Vector3(14, 16, 18)],
		[Vector3(53, 10, -18), Vector3(16, 20, 15)],
		[Vector3(-48, 6, 28), Vector3(11, 12, 16)],
		[Vector3(50, 7, 30), Vector3(13, 14, 18)],
		[Vector3(-24, 10, -51), Vector3(18, 20, 10)],
		[Vector3(24, 7, -50), Vector3(16, 14, 9)],
	]:
		_add_visual_box(background, "DistantBuilding", block_data[0], block_data[1], _materials.concrete_dark)

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

func _add_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance
