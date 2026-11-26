class_name AlpineTerrainGenerator
extends Node3D
## Procedural Alpine Mountain Terrain Generator for Counter-War Stage 08 Prototype.
## Constructs sculpted natural mountain ranges, knife-edge arêtes, deep valley basins,
## and a frozen alpine lake, shaded with slope-based triplanar snow & rock PBR shader.

@export var terrain_size_x: float = 380.0
@export var terrain_size_z: float = 380.0
@export var grid_resolution: int = 140 # 140x140 = 19,600 vertices, 38,400 triangles for smooth terrain

var terrain_shader: Shader = preload("res://shaders/alpine_mountain_terrain.gdshader")
var _terrain_material: ShaderMaterial
var _noise_base: FastNoiseLite
var _noise_ridge: FastNoiseLite
var _noise_warp: FastNoiseLite

func _ready() -> void:
	_init_noises()
	_init_materials()
	_generate_sculpted_terrain()
	_generate_frozen_lake()
	_generate_valley_mist()
	_generate_distant_peaks()
	_generate_alpine_forest()
	_generate_summit_radar_base()

func _init_noises() -> void:
	# Base broad elevation noise
	_noise_base = FastNoiseLite.new()
	_noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_base.seed = 10842
	_noise_base.frequency = 0.0028
	_noise_base.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_base.fractal_octaves = 4
	_noise_base.fractal_lacunarity = 2.0
	_noise_base.fractal_gain = 0.5

	# Ridged multi-fractal noise for majestic broad alpine mountain arêtes and crests
	_noise_ridge = FastNoiseLite.new()
	_noise_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_ridge.seed = 84921
	_noise_ridge.frequency = 0.0042
	_noise_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise_ridge.fractal_octaves = 4
	_noise_ridge.fractal_lacunarity = 2.0
	_noise_ridge.fractal_gain = 0.55

	# Domain warp noise for organic tectonic folding
	_noise_warp = FastNoiseLite.new()
	_noise_warp.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise_warp.seed = 42109
	_noise_warp.frequency = 0.0035

func _init_materials() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = terrain_shader
	_terrain_material.set_shader_parameter("snow_color", Color(0.95, 0.96, 0.98))
	_terrain_material.set_shader_parameter("snow_shadow_color", Color(0.65, 0.76, 0.88))
	_terrain_material.set_shader_parameter("dark_rock_color", Color(0.12, 0.14, 0.18))
	_terrain_material.set_shader_parameter("mid_rock_color", Color(0.22, 0.25, 0.30))
	_terrain_material.set_shader_parameter("slope_threshold", 0.56)
	_terrain_material.set_shader_parameter("slope_sharpness", 0.16)
	_terrain_material.set_shader_parameter("snowline_altitude", 0.0)

# Evaluates the exact alpine mountain elevation at any world point (x, z)
func get_mountain_elevation(x: float, z: float) -> float:
	# Domain warp
	var wx: float = x + _noise_warp.get_noise_2d(x, z) * 28.0
	var wz: float = z + _noise_warp.get_noise_2d(x + 100.0, z - 80.0) * 28.0

	# Base macro landscape
	var base_val: float = _noise_base.get_noise_2d(wx, wz) # range -1 to +1

	# Sharp mountain ridgeline
	var ridge_raw: float = _noise_ridge.get_noise_2d(wx, wz)
	var ridge_val: float = absf(ridge_raw) * 2.0 # sharp V-crests

	# 1. Macro Geographical Layout:
	# Deep Valley Basin: west side (x < -20), centered around x = -75, z = -30
	var valley_center_x := -75.0
	var valley_dist_x := (x - valley_center_x) / 60.0
	var valley_factor: float = clampf(exp(-valley_dist_x * valley_dist_x), 0.0, 1.0)

	# Mountain Massif: north & east side (z < 0 and x > -10)
	var north_dist: float = clampf((-z + 20.0) / 120.0, 0.0, 2.0)
	var east_dist: float = clampf((x - 10.0) / 60.0, 0.0, 2.0)

	# 2. Elevation synthesis
	var height: float = 0.0

	# Grand background alpine peaks
	var mountain_weight: float = maxf(north_dist, east_dist * 0.8)
	if mountain_weight > 0.1:
		var peak_noise: float = (base_val * 0.4 + ridge_val * 0.6) * 75.0
		height += peak_noise * mountain_weight

	# Deep sunken valley depression (carving down to Y = -26m to -35m)
	if valley_factor > 0.05 and z < 40.0:
		var sink_depth := 32.0 * valley_factor
		height -= sink_depth

	# Playable Mountain Pass Ridge & Road (centered around X = 0, Z = 50 to -70)
	# Smoothly connects Lower Valley (Y=0), Mid-Ridge (Y=6), and Summit (Y=14)
	var road_dist: float = absf(x)
	if road_dist < 26.0:
		var road_blend: float = 1.0 - smoothstep(8.0, 24.0, road_dist)
		var road_elevation := 0.0
		if z > 20.0:
			road_elevation = 0.0 # Lower Valley
		elif z > -2.0:
			var t: float = (20.0 - z) / 22.0
			road_elevation = lerpf(0.0, 6.0, t) # Ramp 1
		elif z > -38.0:
			road_elevation = 6.0 # Mid Ridge
		elif z > -62.0:
			var t2: float = (-38.0 - z) / 24.0
			road_elevation = lerpf(6.0, 14.0, t2) # Ramp 2
		else:
			road_elevation = 14.0 # High Summit

		height = lerpf(height, road_elevation, road_blend)

	return height

func _generate_sculpted_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_x := terrain_size_x * 0.5
	var half_z := terrain_size_z * 0.5
	var step_x := terrain_size_x / float(grid_resolution)
	var step_z := terrain_size_z / float(grid_resolution)

	# Build regular grid of vertices with sculpted elevations
	for iz in range(grid_resolution):
		var z0 := -half_z + float(iz) * step_z - 30.0 # offset northwards
		var z1 := z0 + step_z
		var v0 := float(iz) / float(grid_resolution)
		var v1 := float(iz + 1) / float(grid_resolution)

		for ix in range(grid_resolution):
			var x0 := -half_x + float(ix) * step_x
			var x1 := x0 + step_x
			var u0 := float(ix) / float(grid_resolution)
			var u1 := float(ix + 1) / float(grid_resolution)

			var y00 := get_mountain_elevation(x0, z0)
			var y10 := get_mountain_elevation(x1, z0)
			var y01 := get_mountain_elevation(x0, z1)
			var y11 := get_mountain_elevation(x1, z1)

			var p00 := Vector3(x0, y00, z0)
			var p10 := Vector3(x1, y10, z0)
			var p01 := Vector3(x0, y01, z1)
			var p11 := Vector3(x1, y11, z1)

			# Quad Triangle 1: p00 -> p10 -> p11
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p11)

			# Quad Triangle 2: p00 -> p11 -> p01
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p11)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p01)

	st.generate_normals()
	st.generate_tangents()

	var mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SculptedMountainTerrain"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _terrain_material
	add_child(mesh_inst)

func _generate_frozen_lake() -> void:
	var lake_node := Node3D.new()
	lake_node.name = "FrozenAlpineLake"
	add_child(lake_node)

	var lake_mat := StandardMaterial3D.new()
	lake_mat.albedo_color = Color(0.48, 0.66, 0.78)
	lake_mat.roughness = 0.14
	lake_mat.metallic = 0.32
	lake_mat.rim_enabled = true
	lake_mat.rim = 0.75
	lake_mat.rim_tint = 0.6

	# Broad frozen lake plane nestled at Y = -24.5m in the deep valley basin
	var lake_plane := PlaneMesh.new()
	lake_plane.size = Vector2(130.0, 190.0)
	lake_plane.material = lake_mat

	var lake_inst := MeshInstance3D.new()
	lake_inst.name = "LakeIceSurface"
	lake_inst.mesh = lake_plane
	lake_inst.position = Vector3(-78.0, -24.5, -35.0)
	lake_node.add_child(lake_inst)

func _generate_valley_mist() -> void:
	var mist_node := Node3D.new()
	mist_node.name = "ValleyInversionClouds"
	add_child(mist_node)

	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.albedo_color = Color(0.85, 0.91, 0.97, 0.48)
	mist_mat.roughness = 0.95
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var cloud_positions := [
		[Vector3(-72.0, -17.5, 10.0), Vector3(85.0, 1.2, 60.0), Vector3(1.5, 12.0, -1.8)],
		[Vector3(-85.0, -16.0, -45.0), Vector3(110.0, 1.5, 75.0), Vector3(-1.2, -18.0, 1.4)],
		[Vector3(-65.0, -14.5, -95.0), Vector3(90.0, 1.4, 65.0), Vector3(2.0, 8.0, -1.0)],
		[Vector3(-95.0, -15.5, -135.0), Vector3(80.0, 1.3, 55.0), Vector3(-1.0, -25.0, 2.0)]
	]

	for i in range(cloud_positions.size()):
		var cp = cloud_positions[i]
		var cmesh := BoxMesh.new()
		cmesh.size = cp[1]
		cmesh.material = mist_mat

		var cinst := MeshInstance3D.new()
		cinst.name = "CloudMist_%d" % i
		cinst.mesh = cmesh
		cinst.position = cp[0]
		cinst.rotation_degrees = cp[2]
		mist_node.add_child(cinst)

func _generate_distant_peaks() -> void:
	var peaks_node := Node3D.new()
	peaks_node.name = "DistantMountainRanges"
	add_child(peaks_node)

	# Grand Alpine Massifs along the northern and north-western horizon (Z = -220 to -340)
	var peak_data = [
		["Massif_NorthHorn", Vector3(-15.0, 28.0, -260.0), 95.0, 145.0, 7, Vector3(1.25, 1.0, 0.85), -12.0],
		["Massif_NorthWestA", Vector3(-105.0, 22.0, -250.0), 85.0, 135.0, 6, Vector3(1.2, 1.0, 0.9), 24.0],
		["Massif_NorthWestB", Vector3(-180.0, 15.0, -240.0), 90.0, 125.0, 7, Vector3(1.3, 1.0, 0.8), -35.0],
		["Massif_NorthEastA", Vector3(85.0, 25.0, -265.0), 90.0, 140.0, 6, Vector3(1.2, 1.0, 0.85), 18.0],
		["Massif_NorthEastB", Vector3(160.0, 18.0, -250.0), 88.0, 130.0, 7, Vector3(1.25, 1.0, 0.9), -22.0],
		["Massif_FarHorizonA", Vector3(-45.0, 35.0, -350.0), 120.0, 180.0, 6, Vector3(1.3, 1.0, 0.8), 8.0],
		["Massif_FarHorizonB", Vector3(55.0, 32.0, -360.0), 115.0, 175.0, 7, Vector3(1.25, 1.0, 0.85), -15.0]
	]

	for pd in peak_data:
		_create_alpine_peak(peaks_node, pd[0], pd[1], pd[2], pd[3], pd[4], pd[5], pd[6])

func _create_alpine_peak(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, sides: int, stretch: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	# Build an irregular alpine massif rather than a primitive cone. The profile
	# keeps a broad glacial shoulder, then breaks into a sharp, offset summit.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var segments := maxi(sides * 6, 36)
	var summit_offset := Vector2(_noise_base.get_noise_2d(pos.x, pos.z) * radius * 0.22,
		_noise_base.get_noise_2d(pos.x + 41.0, pos.z - 19.0) * radius * 0.18)
	for ring in range(rings):
		var t0 := float(ring) / float(rings)
		var t1 := float(ring + 1) / float(rings)
		for segment in range(segments):
			var a0 := TAU * float(segment) / float(segments)
			var a1 := TAU * float(segment + 1) / float(segments)
			var p00 := _peak_vertex(a0, t0, radius, height, summit_offset, pos)
			var p10 := _peak_vertex(a1, t0, radius, height, summit_offset, pos)
			var p01 := _peak_vertex(a0, t1, radius, height, summit_offset, pos)
			var p11 := _peak_vertex(a1, t1, radius, height, summit_offset, pos)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	st.generate_normals()
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "PeakMesh"
	mi.mesh = mesh
	mi.scale = stretch
	mi.material_override = _terrain_material
	root.add_child(mi)

	# Two offset subsidiary summits add broken alpine skyline silhouettes.
	for spur in 2:
		var spur_mesh := _build_spur_mesh(radius * 0.34, height * (0.48 if spur == 0 else 0.38), pos, spur)
		var spur_instance := MeshInstance3D.new()
		spur_instance.name = "ShoulderPeak_%d" % spur
		spur_instance.mesh = spur_mesh
		spur_instance.position = Vector3((-0.38 if spur == 0 else 0.36) * radius, -height * 0.17, (0.25 if spur == 0 else -0.28) * radius)
		spur_instance.rotation_degrees.y = 90.0 * spur
		spur_instance.scale = stretch * Vector3(1.0, 1.0, 0.82)
		spur_instance.material_override = _terrain_material
		root.add_child(spur_instance)

func _peak_vertex(angle: float, t: float, radius: float, height: float, summit_offset: Vector2, world_pos: Vector3) -> Vector3:
	var broad_shoulder := 1.0 - pow(t, 0.82)
	var angular_noise := _noise_ridge.get_noise_2d(world_pos.x + cos(angle) * radius, world_pos.z + sin(angle) * radius)
	var ridge_breakup := 1.0 + angular_noise * 0.19 + sin(angle * 5.0 + world_pos.x * 0.01) * 0.06
	var r := radius * broad_shoulder * ridge_breakup
	var drift := t * t
	return Vector3(cos(angle) * r + summit_offset.x * drift, (t - 0.5) * height, sin(angle) * r + summit_offset.y * drift)

func _build_spur_mesh(radius: float, height: float, world_pos: Vector3, seed_offset: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segments := 24
	for ring in range(rings):
		var t0 := float(ring) / float(rings)
		var t1 := float(ring + 1) / float(rings)
		for segment in range(segments):
			var a0 := TAU * float(segment) / float(segments)
			var a1 := TAU * float(segment + 1) / float(segments)
			var p00 := _peak_vertex(a0, t0, radius, height, Vector2.ZERO, world_pos + Vector3(seed_offset * 80.0, 0, 0))
			var p10 := _peak_vertex(a1, t0, radius, height, Vector2.ZERO, world_pos + Vector3(seed_offset * 80.0, 0, 0))
			var p01 := _peak_vertex(a0, t1, radius, height, Vector2.ZERO, world_pos + Vector3(seed_offset * 80.0, 0, 0))
			var p11 := _peak_vertex(a1, t1, radius, height, Vector2.ZERO, world_pos + Vector3(seed_offset * 80.0, 0, 0))
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
			st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	st.generate_normals()
	return st.commit()

func _generate_alpine_forest() -> void:
	var forest_node := Node3D.new()
	forest_node.name = "AlpineConiferForest"
	add_child(forest_node)

	# Pine Materials
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.22, 0.16, 0.12)
	trunk_mat.roughness = 0.95

	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.10, 0.20, 0.13)
	foliage_mat.roughness = 0.88

	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.96, 0.97, 0.99)
	snow_mat.roughness = 0.78
	snow_mat.rim_enabled = true
	snow_mat.rim = 0.6

	# Tree distribution: shoreline forest in deep valley + slopes framing the mountain pass
	var tree_data = [
		# Deep Valley Lake Shore
		[Vector3(-42.0, -24.0, 22.0), 2.4, 15.0],
		[Vector3(-50.0, -24.0, 5.0), 2.8, -25.0],
		[Vector3(-58.0, -24.0, -15.0), 3.0, 40.0],
		[Vector3(-45.0, -24.0, -35.0), 2.6, -10.0],
		[Vector3(-68.0, -24.0, -55.0), 3.2, 32.0],
		[Vector3(-82.0, -24.0, -75.0), 2.9, -40.0],
		[Vector3(-60.0, -24.0, -95.0), 3.1, 20.0],
		[Vector3(-48.0, -24.0, -115.0), 2.7, 45.0],
		[Vector3(-85.0, -24.0, -125.0), 2.8, -18.0],
		# Lower Valley Flanks (framing player view)
		[Vector3(-14.0, 0.5, 46.0), 1.25, 12.0],
		[Vector3(-18.0, 1.2, 42.0), 1.45, -30.0],
		[Vector3(-16.0, 1.5, 34.0), 1.15, 25.0],
		[Vector3(14.0, 0.6, 44.0), 1.20, -15.0],
		[Vector3(18.0, 1.4, 40.0), 1.50, 35.0],
		[Vector3(15.0, 1.8, 32.0), 1.10, -40.0],
		# Mid-Ridge Flanks
		[Vector3(-17.0, 7.2, -12.0), 1.35, 20.0],
		[Vector3(-19.0, 8.0, -24.0), 1.50, -35.0],
		[Vector3(16.0, 7.5, -14.0), 1.30, -22.0],
		[Vector3(18.0, 8.2, -26.0), 1.40, 42.0]
	]

	for td in tree_data:
		_create_pine_tree(forest_node, td[0], td[1], td[2], trunk_mat, foliage_mat, snow_mat)

func _create_pine_tree(parent: Node3D, pos: Vector3, s: float, yaw: float, t_mat: Material, f_mat: Material, s_mat: Material) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation_degrees.y = yaw
	parent.add_child(tree)

	# Trunk
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18 * s
	trunk.bottom_radius = 0.32 * s
	trunk.height = 2.8 * s
	trunk.radial_segments = 6
	trunk.material = t_mat

	var ti := MeshInstance3D.new()
	ti.mesh = trunk
	ti.position = Vector3(0.0, 1.4 * s, 0.0)
	tree.add_child(ti)

	# 3 Stepped Conical Tiers with Snow Skirts
	var tiers = [
		[2.2 * s, 2.5 * s, 2.0 * s],
		[1.7 * s, 2.2 * s, 3.4 * s],
		[1.2 * s, 2.0 * s, 4.7 * s]
	]

	for tier in tiers:
		var r: float = tier[0]
		var h: float = tier[1]
		var y: float = tier[2]

		var f_mesh := CylinderMesh.new()
		f_mesh.top_radius = 0.05 * s
		f_mesh.bottom_radius = r
		f_mesh.height = h
		f_mesh.radial_segments = 7
		f_mesh.material = f_mat

		var fi := MeshInstance3D.new()
		fi.mesh = f_mesh
		fi.position = Vector3(0.0, y, 0.0)
		tree.add_child(fi)

		var s_mesh := CylinderMesh.new()
		s_mesh.top_radius = 0.0
		s_mesh.bottom_radius = r * 0.88
		s_mesh.height = h * 0.48
		s_mesh.radial_segments = 7
		s_mesh.material = s_mat

		var si := MeshInstance3D.new()
		si.mesh = s_mesh
		si.position = Vector3(0.0, y + h * 0.26, 0.0)
		tree.add_child(si)

func _generate_summit_radar_base() -> void:
	var base_node := Node3D.new()
	base_node.name = "SummitRadarInstallation"
	base_node.position = Vector3(0.0, 14.0, -78.0)
	add_child(base_node)

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.22, 0.25, 0.28)
	metal_mat.metallic = 0.75
	metal_mat.roughness = 0.45

	var dish_mat := StandardMaterial3D.new()
	dish_mat.albedo_color = Color(0.78, 0.82, 0.86)
	dish_mat.metallic = 0.65
	dish_mat.roughness = 0.35

	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.44, 0.47, 0.50)
	concrete_mat.roughness = 0.85

	# Concrete Plinth & Command Bunker
	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = Vector3(16.0, 1.2, 16.0)
	plinth_mesh.material = concrete_mat
	var pi := MeshInstance3D.new()
	pi.mesh = plinth_mesh
	pi.position = Vector3(0.0, -0.6, 0.0)
	base_node.add_child(pi)

	var bunker_mesh := BoxMesh.new()
	bunker_mesh.size = Vector3(10.0, 5.0, 12.0)
	bunker_mesh.material = concrete_mat
	var bi := MeshInstance3D.new()
	bi.mesh = bunker_mesh
	bi.position = Vector3(-14.0, 2.5, 0.0)
	base_node.add_child(bi)

	# Main Steel Lattice Tower
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(2.4, 18.0, 2.4)
	mast_mesh.material = metal_mat
	var mi := MeshInstance3D.new()
	mi.mesh = mast_mesh
	mi.position = Vector3(0.0, 9.0, 0.0)
	base_node.add_child(mi)

	# Primary Parabolic Radar Dish facing southwest across the valley
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 4.8
	dish_mesh.bottom_radius = 4.8
	dish_mesh.height = 0.75
	dish_mesh.radial_segments = 24
	dish_mesh.material = dish_mat

	var di := MeshInstance3D.new()
	di.mesh = dish_mesh
	di.position = Vector3(0.0, 16.5, 0.0)
	di.rotation_degrees = Vector3(65.0, 25.0, 0.0)
	base_node.add_child(di)

	# Red Aviation Safety Beacon
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.15, 0.15)
	beacon.light_energy = 3.0
	beacon.omni_range = 24.0
	beacon.position = Vector3(0.0, 19.5, 0.0)
	base_node.add_child(beacon)
