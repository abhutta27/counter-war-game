extends Node3D
## Standalone art study. It does not inherit from or register a gameplay stage.

const TERRAIN_SCRIPT := preload("res://scripts/prototypes/Stage08AlpineHybridTerrain.gd")
const MODEL_ROOT := "res://assets/prototypes/stage08/models/"
const TEXTURE_ROOT := "res://assets/prototypes/stage08/textures/"

@export var terrain_shader: Shader
var terrain_generator: Variant

func _ready() -> void:
	_build_environment()
	var terrain_material := _make_terrain_material()
	terrain_generator = TERRAIN_SCRIPT.new()
	terrain_generator.name = "AlpineHybridTerrain"
	terrain_generator.terrain_material = terrain_material
	add_child(terrain_generator)
	_build_cliffs_and_boulders()
	_build_sparse_conifers()
	_build_cameras()

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.13, 0.22, 0.34)
	sky_material.sky_horizon_color = Color(0.64, 0.72, 0.79)
	sky_material.ground_bottom_color = Color(0.32, 0.39, 0.44)
	sky_material.ground_horizon_color = Color(0.58, 0.66, 0.72)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.67, 0.75, 0.81)
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.00125
	environment.fog_aerial_perspective = 0.8
	var world := WorldEnvironment.new()
	world.name = "AlpineAtmosphere"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "AlpineSun"
	sun.rotation_degrees = Vector3(-31.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _make_terrain_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = terrain_shader
	var snow_root := TEXTURE_ROOT + "snow_02/snow_02_"
	var rock_root := TEXTURE_ROOT + "dark_rock/dark_rock_"
	material.set_shader_parameter("snow_albedo", load(snow_root + "diffuse.jpg"))
	material.set_shader_parameter("snow_normal", load(snow_root + "nor_gl.png"))
	material.set_shader_parameter("snow_arm", load(snow_root + "arm.jpg"))
	material.set_shader_parameter("rock_albedo", load(rock_root + "diffuse.jpg"))
	material.set_shader_parameter("rock_normal", load(rock_root + "nor_gl.png"))
	material.set_shader_parameter("rock_arm", load(rock_root + "arm.jpg"))
	material.set_shader_parameter("texture_scale", 0.036)
	return material

func _build_cliffs_and_boulders() -> void:
	var left_cliff_y: float = terrain_generator.get_elevation(-151.0, -34.0)
	var right_cliff_y: float = terrain_generator.get_elevation(156.0, -58.0)
	_place_model("mountainside", Vector3(-151.0, left_cliff_y, -34.0), 54.0, 32.0)
	_place_model("mountainside", Vector3(156.0, right_cliff_y, -58.0), 50.0, 188.0)
	var boulders := [
		[Vector2(-16.0, 190.0), 10.5, 26.0],
		[Vector2(19.0, 174.0), 9.5, 112.0],
		[Vector2(-34.0, 139.0), 13.0, 208.0],
		[Vector2(38.0, 112.0), 11.0, 312.0]
	]
	for item in boulders:
		var ground_y: float = terrain_generator.get_elevation(item[0].x, item[0].y)
		_place_model("boulder_01", Vector3(item[0].x, ground_y, item[0].y), item[1], item[2])

func _build_sparse_conifers() -> void:
	var conifers := [
		["fir_sapling", Vector2(-13.0, 176.0), 22.0, -12.0],
		["fir_sapling", Vector2(18.0, 153.0), 20.0, 36.0],
		["pine_sapling_small", Vector2(-24.0, 122.0), 21.0, 91.0],
		["pine_sapling_small", Vector2(27.0, 94.0), 20.0, 162.0]
	]
	for item in conifers:
		var ground_y: float = terrain_generator.get_elevation(item[1].x, item[1].y)
		_place_model(item[0], Vector3(item[1].x, ground_y, item[1].y), item[2], item[3], true)

func _place_model(asset_name: String, world_pos: Vector3, target_size: float, yaw_degrees: float, is_vegetation := false) -> void:
	var path := MODEL_ROOT + asset_name + "/" + asset_name + "_2k.gltf"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not load prototype GLTF: " + path)
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("Expected a Node3D root in: " + path)
		return
	instance.name = "%s_%02d" % [asset_name, get_child_count()]
	instance.rotation_degrees.y = yaw_degrees
	add_child(instance)
	var local_bounds := _get_model_bounds(instance)
	if local_bounds.size.length_squared() < 0.0001:
		push_error("No renderable mesh found in: " + path)
		instance.queue_free()
		return
	var uniform_scale := target_size / maxf(local_bounds.size.x, maxf(local_bounds.size.y, local_bounds.size.z))
	instance.scale = Vector3.ONE * uniform_scale
	instance.position = world_pos - Vector3(0.0, local_bounds.position.y * uniform_scale, 0.0)
	var fade_begin := 135.0 if is_vegetation else 205.0
	var fade_end := 210.0 if is_vegetation else 330.0
	for candidate in instance.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		geometry.visibility_range_begin = fade_begin
		geometry.visibility_range_end = fade_end
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _get_model_bounds(root_node: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		var relative_transform := root_node.global_transform.affine_inverse() * mesh_node.global_transform
		var mesh_bounds: AABB = mesh_node.get_aabb() * relative_transform
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	return bounds

func _build_cameras() -> void:
	var camera_root := Node3D.new()
	camera_root.name = "CaptureCameras"
	add_child(camera_root)
	_add_camera(camera_root, "ValleyApproach", Vector3(0.0, 11.0, 215.0), Vector3(0.0, -16.0, -5.0), 76.0, true)
	_add_camera(camera_root, "RidgePanorama", Vector3(-151.0, 116.0, 132.0), Vector3(0.0, -6.0, -88.0), 74.0, false)
	_add_camera(camera_root, "ValleyFloor", Vector3(6.0, -7.0, 120.0), Vector3(-20.0, -13.0, -112.0), 72.0, false)

func _add_camera(parent: Node3D, camera_name: String, location: Vector3, target: Vector3, field_of_view: float, make_current: bool) -> void:
	var camera := Camera3D.new()
	camera.name = camera_name
	camera.position = location
	camera.fov = field_of_view
	parent.add_child(camera)
	camera.look_at(target, Vector3.UP)
	camera.current = make_current
