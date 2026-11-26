extends Node3D
## Indexed, smooth height-field terrain for the isolated Stage 08 hybrid study.

@export_range(64, 384, 1) var grid_resolution := 176
@export var terrain_width := 480.0
@export var terrain_depth := 540.0
var terrain_material: Material
var _broad := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()

func _ready() -> void:
	_init_noise()
	_build_main_terrain()
	_build_distant_ridges()

func _init_noise() -> void:
	_broad.seed = 8408
	_broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_broad.frequency = 0.005
	_broad.fractal_type = FastNoiseLite.FRACTAL_FBM
	_broad.fractal_octaves = 4
	_broad.fractal_gain = 0.48
	_ridge.seed = 1937
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.011
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 3
	_detail.seed = 2808
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.034
	_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail.fractal_octaves = 2

func get_elevation(x: float, z: float) -> float:
	var valley_axis := 17.0 * sin(z * 0.009) + _broad.get_noise_2d(x + 300.0, z) * 9.0
	var cross_valley := absf(x - valley_axis)
	var shoulder := smoothstep(27.0, 188.0, cross_valley)
	var broad_shape := _broad.get_noise_2d(x, z)
	var ridged_shape := _ridge.get_noise_2d(x, z)
	var fine_shape := _detail.get_noise_2d(x, z)
	var valley_floor := -17.0 + _broad.get_noise_2d(x * 0.72, z * 0.72) * 2.4
	var ridge_height := 101.0 + broad_shape * 24.0 + ridged_shape * 19.0 + fine_shape * 5.0
	var benches := sin(z * 0.018 + x * 0.01) * 5.0 * shoulder
	return valley_floor + shoulder * ridge_height + benches

func _build_main_terrain() -> void:
	var count := grid_resolution + 1
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(count * count)
	uvs.resize(count * count)
	for z_index in range(count):
		var z := -terrain_depth * 0.5 + terrain_depth * float(z_index) / float(grid_resolution)
		for x_index in range(count):
			var x := -terrain_width * 0.5 + terrain_width * float(x_index) / float(grid_resolution)
			var idx := z_index * count + x_index
			vertices[idx] = Vector3(x, get_elevation(x, z), z)
			uvs[idx] = Vector2(x, z) * 0.032
	for z_index in range(grid_resolution):
		for x_index in range(grid_resolution):
			var a := z_index * count + x_index
			var b := a + count
			indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	var terrain := MeshInstance3D.new()
	terrain.name = "ContinuousAlpineValley"
	terrain.mesh = _indexed_mesh(vertices, uvs, indices)
	terrain.material_override = terrain_material
	add_child(terrain)

func _build_distant_ridges() -> void:
	# Sparse, low-polygon skyline tiers replace heavy distant mountain meshes.
	var ranges := [
		{"z": -292.0, "height": 118.0, "seed": 15.0},
		{"z": -354.0, "height": 154.0, "seed": 57.0},
		{"z": -422.0, "height": 182.0, "seed": 93.0}
	]
	for range_index in range(ranges.size()):
		var data: Dictionary = ranges[range_index]
		var segments := 48
		var depth_steps := 4
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var base_z: float = data.z
		for depth_index in range(depth_steps + 1):
			var depth_t := float(depth_index) / float(depth_steps)
			for x_index in range(segments + 1):
				var x := -285.0 + 570.0 * float(x_index) / float(segments)
				var profile := 0.0
				for peak_index in range(7):
					var peak_x := -276.0 + float(peak_index) * 86.0 + sin(float(peak_index) * 2.1 + float(data.seed)) * 34.0
					var half_width := 64.0 + float((peak_index * 29) % 59)
					var relative_x := absf(x - peak_x) / half_width
					var peak_shape := exp(-pow(relative_x, 1.65) * 0.92)
					var peak_strength := 0.72 + 0.28 * absf(_broad.get_noise_2d(peak_x, base_z + float(peak_index) * 13.0))
					profile = maxf(profile, peak_shape * peak_strength)
				var jagged := absf(_ridge.get_noise_2d(x + float(data.seed) * 9.0, base_z))
				var height := 20.0 + profile * (float(data.height) + jagged * 22.0)
				var fore_slope := sin(depth_t * PI) * (12.0 + profile * 26.0)
				var y := lerpf(9.0, height, depth_t) + fore_slope
				var z := base_z - depth_t * 46.0 + _broad.get_noise_2d(x, base_z + depth_t * 20.0) * 3.0
				vertices.append(Vector3(x, y, z))
				uvs.append(Vector2(x, y) * 0.018)
		for depth_index in range(depth_steps):
			for x_index in range(segments):
				var a := depth_index * (segments + 1) + x_index
				var b := a + segments + 1
				indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
		var distant := MeshInstance3D.new()
		distant.name = "DistantRidge_%02d" % range_index
		distant.mesh = _indexed_mesh(vertices, uvs, indices)
		distant.material_override = terrain_material
		add_child(distant)

func _indexed_mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size()):
		surface.set_uv(uvs[i])
		surface.add_vertex(vertices[i])
	for index in indices:
		surface.add_index(index)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()
