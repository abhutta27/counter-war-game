class_name Stage08_SnowyAlpinePrototype
extends Node3D
## Stage08_SnowyAlpinePrototype.gd
## Playable snowy alpine mountain terrain prototype for Operation Whiteout.
## Features:
## - 3 readable natural elevation tiers (Lower Valley, Mid-Ridge, High Summit).
## - Walkable, gentle switchback trails with continuous collision.
## - Natural mountain peaks, lateral crags, and distant mountain backdrops.
## - Low winter sun, alpine atmospheric fog, and slope-based snow/rock PBR shading.
## - Integrated Player3D, physics, weapon rig, and HUD.

const PLAYER_SCENE := preload("res://scenes/entities/Player3D.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud/TacticalHUD.tscn")
const TERRAIN_SHADER := preload("res://shaders/stage08_alpine_hybrid.gdshader")

const MODEL_ROOT := "res://assets/prototypes/stage08/models/"
const TEXTURE_ROOT := "res://assets/prototypes/stage08/textures/"

@export var terrain_width: float = 240.0
@export var terrain_depth: float = 280.0
@export var grid_resolution_x: int = 120
@export var grid_resolution_z: int = 140

var _noise_macro: FastNoiseLite
var _noise_detail: FastNoiseLite
var _terrain_material: ShaderMaterial
var player: CharacterBody3D
var hud: CanvasLayer

# Waypoints along the natural playable mountain route (for QA & player reference)
const ROUTE_WAYPOINTS := [
	Vector3(0.0, 1.8, 105.0),    # Waypoint 0: Valley Drop Zone (Tier 1)
	Vector3(0.0, 2.0, 75.0),     # Waypoint 1: Valley Approach
	Vector3(-18.0, 4.8, 48.0),   # Waypoint 2: Switchback 1 West Apex
	Vector3(2.0, 7.8, 22.0),     # Waypoint 3: Switchback 1 Top (Entering Mid-Ridge)
	Vector3(8.0, 8.5, 0.0),      # Waypoint 4: Mid-Ridge Tactical Plateau (Tier 2)
	Vector3(18.0, 11.8, -25.0),  # Waypoint 5: Switchback 2 East Defile
	Vector3(-2.0, 16.2, -55.0),  # Waypoint 6: Switchback 2 Exit (Entering Summit)
	Vector3(0.0, 17.5, -85.0)    # Waypoint 7: High Summit Peak (Tier 3)
]

func _ready() -> void:
	_init_noises()
	_build_environment()
	_build_terrain_material()
	_build_sculpted_terrain()
	_build_distant_mountain_ranges()
	_place_natural_props()
	_spawn_player()
	_attach_hud()

func _init_noises() -> void:
	_noise_macro = FastNoiseLite.new()
	_noise_macro.seed = 9482
	_noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_macro.frequency = 0.006
	_noise_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_macro.fractal_octaves = 3
	_noise_macro.fractal_gain = 0.5

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = 3317
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_detail.frequency = 0.025
	_noise_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_detail.fractal_octaves = 2

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.30, 0.58)
	sky_mat.sky_horizon_color = Color(0.70, 0.80, 0.90)
	sky_mat.ground_bottom_color = Color(0.38, 0.46, 0.52)
	sky_mat.ground_horizon_color = Color(0.66, 0.76, 0.84)
	sky_mat.sun_angle_max = 28.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.72, 0.82, 0.92)
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05

	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.84, 0.92)
	env.fog_light_energy = 0.85
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.70
	env.fog_sky_affect = 0.35

	var world_env := WorldEnvironment.new()
	world_env.name = "AlpineAtmosphere"
	world_env.environment = env
	add_child(world_env)

	# Low angled morning winter sun casting realistic shadows along ridges
	var sun := DirectionalLight3D.new()
	sun.name = "AlpineSun"
	sun.rotation_degrees = Vector3(-34.0, -42.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.30
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func _build_terrain_material() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	var snow_path := TEXTURE_ROOT + "snow_02/snow_02_"
	var rock_path := TEXTURE_ROOT + "dark_rock/dark_rock_"
	_terrain_material.set_shader_parameter("snow_albedo", load(snow_path + "diffuse.jpg"))
	_terrain_material.set_shader_parameter("snow_normal", load(snow_path + "nor_gl.png"))
	_terrain_material.set_shader_parameter("snow_arm", load(snow_path + "arm.jpg"))
	_terrain_material.set_shader_parameter("rock_albedo", load(rock_path + "diffuse.jpg"))
	_terrain_material.set_shader_parameter("rock_normal", load(rock_path + "nor_gl.png"))
	_terrain_material.set_shader_parameter("rock_arm", load(rock_path + "arm.jpg"))
	_terrain_material.set_shader_parameter("texture_scale", 0.038)

## Evaluates the sculpted elevation at any continuous world coordinates (x, z)
func get_elevation(x: float, z: float) -> float:
	# 1. Base continuous elevation profiles across the 3 tiers
	# Z goes from +140m (South - Valley drop) to -140m (North - Summit crest)
	var base_tier_y: float = 0.0
	var corridor_center_x: float = 0.0

	if z >= 65.0:
		# Tier 1: Lower Valley (Y ~ 1.5m to 2.2m)
		base_tier_y = 1.8 + sin(z * 0.04) * 0.6
		corridor_center_x = 0.0
	elif z >= 20.0:
		# Switchback 1: Climbing from Valley (Y=1.8m) to Mid-Ridge (Y=8.0m)
		# T: 0.0 at z=65 -> 1.0 at z=20
		var t := (65.0 - z) / 45.0
		var smooth_t := smoothstep(0.0, 1.0, t)
		base_tier_y = lerpf(1.8, 8.2, smooth_t)
		# Gentle S-curve sweeping west then back to center
		corridor_center_x = sin(t * PI) * -22.0
	elif z >= -15.0:
		# Tier 2: Mid-Ridge Tactical Plateau (Y ~ 8.2m to 9.0m)
		base_tier_y = 8.2 + sin(z * 0.06 + x * 0.03) * 0.5
		corridor_center_x = 6.0
	elif z >= -58.0:
		# Switchback 2: Climbing from Mid-Ridge (Y=8.2m) to High Summit (Y=17.0m)
		# T: 0.0 at z=-15 -> 1.0 at z=-58
		var t := (-15.0 - z) / 43.0
		var smooth_t := smoothstep(0.0, 1.0, t)
		base_tier_y = lerpf(8.2, 17.0, smooth_t)
		# Gentle winding defile curving east then northwest into summit
		corridor_center_x = 6.0 + sin(t * PI) * 16.0 - (t * 8.0)
	else:
		# Tier 3: High Summit Crest (Y ~ 17.0m to 18.5m)
		base_tier_y = 17.2 + sin(z * 0.05) * 0.6
		corridor_center_x = 0.0

	# 2. Path corridor cross-section (flat walkable roadbed)
	var dist_from_path := absf(x - corridor_center_x)
	var road_half_width := 11.0 # 22m wide walkable corridor
	var path_factor := 1.0 - clampf((dist_from_path - road_half_width) / 18.0, 0.0, 1.0)

	# 3. Lateral Canyon Walls & Steep Mountain Flanks
	# When moving away from the path into the canyon borders, mountains rise steeply
	var canyon_dist := absf(x)
	var wall_factor := smoothstep(22.0, 95.0, canyon_dist)
	var wall_height := 42.0 * wall_factor + pow(wall_factor, 1.8) * 24.0

	# 4. Natural organic undulations
	var macro_noise := _noise_macro.get_noise_2d(x, z) * 6.5
	var detail_noise := _noise_detail.get_noise_2d(x, z) * 1.8
	var natural_noise := (macro_noise + detail_noise) * (1.0 - path_factor * 0.85)

	# 5. Terrace benches on valley and ridge shoulders
	var shoulder_bench := 0.0
	if absf(x) > 16.0 and absf(x) < 38.0:
		shoulder_bench = sin(z * 0.05 + x * 0.08) * 1.5

	return base_tier_y + wall_height + natural_noise + shoulder_bench

func _build_sculpted_terrain() -> void:
	var count_x := grid_resolution_x + 1
	var count_z := grid_resolution_z + 1
	var total_verts := count_x * count_z
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	vertices.resize(total_verts)
	uvs.resize(total_verts)

	var half_w := terrain_width * 0.5
	var half_d := terrain_depth * 0.5
	var step_x := terrain_width / float(grid_resolution_x)
	var step_z := terrain_depth / float(grid_resolution_z)

	for iz in range(count_z):
		var z := -half_d + float(iz) * step_z
		for ix in range(count_x):
			var x := -half_w + float(ix) * step_x
			var y := get_elevation(x, z)
			var idx := iz * count_x + ix
			vertices[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(x, z) * 0.038

	for iz in range(grid_resolution_z):
		for ix in range(grid_resolution_x):
			var a := iz * count_x + ix
			var b := a + count_x
			indices.append_array(PackedInt32Array([a, b + 1, b, a, a + 1, b + 1]))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size()):
		surface.set_uv(uvs[i])
		surface.add_vertex(vertices[i])
	for index in indices:
		surface.add_index(index)
	surface.generate_normals()
	surface.generate_tangents()

	var mesh: ArrayMesh = surface.commit()
	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "SnowyAlpineTerrain"
	terrain_inst.mesh = mesh
	terrain_inst.material_override = _terrain_material
	add_child(terrain_inst)

	# Generate precise physical trimesh collision so player can walk on every slope and ramp
	terrain_inst.create_trimesh_collision()

func _build_distant_mountain_ranges() -> void:
	# 3 dramatic distant mountain horizons with sharp sawtooth peaks
	var ranges := [
		{"z": -175.0, "height": 95.0, "seed": 14.0, "segments": 42},
		{"z": -235.0, "height": 135.0, "seed": 48.0, "segments": 46},
		{"z": -305.0, "height": 175.0, "seed": 89.0, "segments": 50}
	]

	for r_idx in range(ranges.size()):
		var data: Dictionary = ranges[r_idx]
		var segments: int = data["segments"]
		var base_z: float = data["z"]
		var max_h: float = data["height"]
		var seed_val: float = data["seed"]

		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()

		var range_width := 420.0
		var step := range_width / float(segments)

		for ix in range(segments + 1):
			var x := -range_width * 0.5 + float(ix) * step
			# Sharp alpine horns and pyramidal peak math
			var peak_profile := 0.0
			for p in range(6):
				var px := -180.0 + float(p) * 72.0 + sin(float(p) * 2.3 + seed_val) * 28.0
				var p_width := 55.0 + float((p * 23) % 43)
				var rel := absf(x - px) / p_width
				var horn := exp(-pow(rel, 1.8) * 1.1)
				peak_profile = maxf(peak_profile, horn)

			var jagged := absf(_noise_macro.get_noise_2d(x + seed_val * 11.0, base_z)) * 26.0
			var y_crest := 22.0 + peak_profile * (max_h + jagged)
			var y_base := -8.0

			# Vertex 0: Bottom
			vertices.append(Vector3(x, y_base, base_z))
			uvs.append(Vector2(x, y_base) * 0.02)
			# Vertex 1: Peak crest
			vertices.append(Vector3(x, y_crest, base_z - 28.0))
			uvs.append(Vector2(x, y_crest) * 0.02)

		for ix in range(segments):
			var a := ix * 2
			var b := a + 1
			var c := a + 2
			var d := a + 3
			indices.append_array(PackedInt32Array([a, b, d, a, d, c]))

		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(vertices.size()):
			surface.set_uv(uvs[i])
			surface.add_vertex(vertices[i])
		for idx in indices:
			surface.add_index(idx)
		surface.generate_normals()
		surface.generate_tangents()

		var distant_mesh := MeshInstance3D.new()
		distant_mesh.name = "DistantMountainRange_%02d" % (r_idx + 1)
		distant_mesh.mesh = surface.commit()
		distant_mesh.material_override = _terrain_material
		add_child(distant_mesh)

func _place_natural_props() -> void:
	# Tactical boulders along trail shoulders for cover and natural landscape framing
	var boulders := [
		[Vector2(-12.0, 95.0), 9.0, 35.0],
		[Vector2(14.0, 88.0), 10.5, 115.0],
		[Vector2(-26.0, 52.0), 12.0, 210.0],
		[Vector2(16.0, 32.0), 11.0, 45.0],
		[Vector2(-14.0, 10.0), 10.0, 290.0],
		[Vector2(24.0, -8.0), 13.0, 160.0],
		[Vector2(10.0, -32.0), 11.5, 80.0],
		[Vector2(-16.0, -70.0), 12.0, 320.0],
		[Vector2(18.0, -75.0), 10.5, 195.0]
	]
	for b in boulders:
		var pos_2d: Vector2 = b[0]
		var y := get_elevation(pos_2d.x, pos_2d.y)
		_place_model("boulder_01", Vector3(pos_2d.x, y, pos_2d.y), b[1], b[2], false)

	# Mountain side rock formations on the lateral cliff walls
	_place_model("mountainside", Vector3(-58.0, get_elevation(-58.0, 60.0), 60.0), 45.0, 45.0, false)
	_place_model("mountainside", Vector3(62.0, get_elevation(62.0, 40.0), 40.0), 48.0, 195.0, false)
	_place_model("mountainside", Vector3(-65.0, get_elevation(-65.0, -40.0), -40.0), 52.0, 25.0, false)
	_place_model("mountainside", Vector3(68.0, get_elevation(68.0, -50.0), -50.0), 50.0, 175.0, false)

	# Alpine fir and pine saplings in the lower valley and sheltered ridge defiles
	var conifers := [
		["fir_sapling", Vector2(-8.0, 115.0), 18.0, 20.0],
		["fir_sapling", Vector2(10.0, 108.0), 20.0, -45.0],
		["pine_sapling_small", Vector2(-18.0, 85.0), 19.0, 65.0],
		["pine_sapling_small", Vector2(16.0, 72.0), 21.0, 140.0],
		["fir_sapling", Vector2(-28.0, 38.0), 18.5, 95.0],
		["pine_sapling_small", Vector2(6.0, 15.0), 19.0, 180.0],
		["fir_sapling", Vector2(22.0, -18.0), 17.5, 310.0]
	]
	for c in conifers:
		var pos_2d: Vector2 = c[1]
		var y := get_elevation(pos_2d.x, pos_2d.y)
		_place_model(c[0], Vector3(pos_2d.x, y, pos_2d.y), c[2], c[3], true)

func _place_model(asset_name: String, world_pos: Vector3, target_size: float, yaw_deg: float, is_tree: bool) -> void:
	var path := MODEL_ROOT + asset_name + "/" + asset_name + "_2k.gltf"
	var packed := load(path) as PackedScene
	if not packed:
		return
	var inst := packed.instantiate() as Node3D
	if not inst:
		return
	var aabb := _compute_aabb(inst)
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim <= 0.001:
		max_dim = 1.0
	var scale_factor := target_size / max_dim
	inst.scale = Vector3.ONE * scale_factor
	inst.position = world_pos
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	add_child(inst)

	# Add physical collision for boulders so player can use them for tactical cover
	if not is_tree:
		var body := StaticBody3D.new()
		body.name = asset_name + "_Col"
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size * scale_factor * 0.75
		col.shape = box
		body.position = world_pos + Vector3(0.0, box.size.y * 0.5, 0.0)
		body.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
		add_child(body)

func _compute_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is VisualInstance3D and not (current is Light3D):
			var current_aabb: AABB = current.get_aabb()
			if first:
				aabb = current_aabb
				first = false
			else:
				aabb = aabb.merge(current_aabb)
		for child in current.get_children():
			stack.push_back(child)
	if first:
		aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	return aabb

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player3D"
	# Spawn at lower valley drop zone at Y = 2.8m (ground is Y ~ 1.8m)
	player.position = Vector3(0.0, 2.8, 105.0)
	add_child(player)

func _attach_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	hud.name = "TacticalHUD"
	add_child(hud)
