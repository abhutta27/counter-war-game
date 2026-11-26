class_name Stage08IronPeak
extends "res://scripts/LevelBase3D.gd"
## Stage 08 — OPERATION IRON PEAK
## High-altitude alpine mountain battlefield, rugged rocky terrain, central combat valley,
## military radar outpost, 18 tactical enemy hostiles, and CW-08 assault rifle integration.

const CW08_WEAPON_SCENE := preload("res://scenes/weapons/CW08AssaultRifle.tscn")
const TERRAIN_SHADER := preload("res://shaders/stage08_iron_peak_terrain.gdshader")

# UI Scenes
const HUD_SCENE := preload("res://scenes/stages/ui/Stage08IronPeakHUD.tscn")
const PAUSE_SCENE := preload("res://scenes/stages/ui/Stage08IronPeakPauseMenu.tscn")
const SUCCESS_SCENE := preload("res://scenes/stages/ui/Stage08IronPeakSuccess.tscn")
const FAILED_SCENE := preload("res://scenes/stages/ui/Stage08IronPeakFailed.tscn")

# Texture Paths
const ROCK_DIFFUSE_PATH := "res://assets/prototypes/stage08_iron_peak/textures/dark_rock/dark_rock_diffuse.jpg"
const ROCK_NORMAL_PATH := "res://assets/prototypes/stage08_iron_peak/textures/dark_rock/dark_rock_nor_gl.jpg"
const ROCK_ROUGH_PATH := "res://assets/prototypes/stage08_iron_peak/textures/dark_rock/dark_rock_rough.jpg"
const SNOW_DIFFUSE_PATH := "res://assets/prototypes/stage08_iron_peak/textures/snow_02/snow_02_diffuse.jpg"
const SNOW_NORMAL_PATH := "res://assets/prototypes/stage08_iron_peak/textures/snow_02/snow_02_nor_gl.jpg"
const SNOW_ROUGH_PATH := "res://assets/prototypes/stage08_iron_peak/textures/snow_02/snow_02_rough.jpg"

# GLTF Model Paths
const BOULDER_GLTF_PATH := "res://assets/prototypes/stage08_iron_peak/models/boulder_01/boulder_01_2k.gltf"
const PINE_GLTF_PATH := "res://assets/prototypes/stage08_iron_peak/models/pine_sapling_small/pine_sapling_small_2k.gltf"
const FIR_GLTF_PATH := "res://assets/prototypes/stage08_iron_peak/models/fir_sapling/fir_sapling_2k.gltf"

var _terrain_material: ShaderMaterial = null
var _materials_cache: Dictionary = {}

# Stage 08 UI References
var iron_hud: CanvasLayer = null
var pause_menu: Control = null
var success_screen: Control = null
var failed_screen: Control = null

# Radar & Extraction
var radar_dish_mesh: Node3D = null
var extraction_zone: Area3D = null
var is_radar_active: bool = true
var is_extraction_ready: bool = false
var extraction_beacon_light: OmniLight3D = null

# Enemy tracking
var total_enemy_count: int = 18
var enemies_killed_count: int = 0

func _ready() -> void:
	stage_id = 8
	stage_name = "OPERATION IRON PEAK"
	out_of_bounds_y = -15.0
	recovery_bounds_enabled = true
	recovery_bounds_min = Vector2(-55.0, -75.0)
	recovery_bounds_max = Vector2(55.0, 105.0)
	physical_boundaries_enabled = true
	physical_boundary_height = 36.0
	physical_boundary_center_y = 12.0

	_build_materials()
	_build_mountain_environment()
	_setup_outpost_structures()
	_setup_tactical_cover()
	_setup_natural_vegetation()
	_setup_extraction_zone()

	super._ready()

	if not player:
		player = get_node_or_null("Player3D")

	_setup_player_loadout()
	_setup_custom_ui()
	_bind_enemy_events()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_materials() -> void:
	# Terrain Shader Material
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	if ResourceLoader.exists(ROCK_DIFFUSE_PATH):
		_terrain_material.set_shader_parameter("rock_diffuse", load(ROCK_DIFFUSE_PATH))
	if ResourceLoader.exists(ROCK_NORMAL_PATH):
		_terrain_material.set_shader_parameter("rock_normal", load(ROCK_NORMAL_PATH))
	if ResourceLoader.exists(ROCK_ROUGH_PATH):
		_terrain_material.set_shader_parameter("rock_roughness", load(ROCK_ROUGH_PATH))
	if ResourceLoader.exists(SNOW_DIFFUSE_PATH):
		_terrain_material.set_shader_parameter("snow_diffuse", load(SNOW_DIFFUSE_PATH))
	if ResourceLoader.exists(SNOW_NORMAL_PATH):
		_terrain_material.set_shader_parameter("snow_normal", load(SNOW_NORMAL_PATH))
	if ResourceLoader.exists(SNOW_ROUGH_PATH):
		_terrain_material.set_shader_parameter("snow_roughness", load(SNOW_ROUGH_PATH))
	_terrain_material.set_shader_parameter("uv_scale", 0.08)
	_terrain_material.set_shader_parameter("snow_height_threshold", 7.0)
	_terrain_material.set_shader_parameter("snow_blend_softness", 2.5)
	_terrain_material.set_shader_parameter("slope_snow_cutoff", 0.65)

	# Concrete Material
	var mat_concrete := StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.38, 0.40, 0.42, 1.0)
	mat_concrete.roughness = 0.85
	_materials_cache["concrete"] = mat_concrete

	# Dark Metal Material
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.18, 0.22, 0.26, 1.0)
	mat_metal.metallic = 0.8
	mat_metal.roughness = 0.35
	_materials_cache["metal"] = mat_metal

	# Military Green Paint Material
	var mat_mil_green := StandardMaterial3D.new()
	mat_mil_green.albedo_color = Color(0.24, 0.32, 0.22, 1.0)
	mat_mil_green.roughness = 0.75
	_materials_cache["mil_green"] = mat_mil_green

	# Sandbag Material
	var mat_sandbag := StandardMaterial3D.new()
	mat_sandbag.albedo_color = Color(0.55, 0.50, 0.38, 1.0)
	mat_sandbag.roughness = 0.95
	_materials_cache["sandbag"] = mat_sandbag

	# Beacon Glow Material
	var mat_beacon := StandardMaterial3D.new()
	mat_beacon.albedo_color = Color(0.1, 0.9, 0.3, 1.0)
	mat_beacon.emission_enabled = true
	mat_beacon.emission = Color(0.1, 0.9, 0.3, 1.0)
	mat_beacon.emission_energy_multiplier = 4.0
	_materials_cache["beacon"] = mat_beacon

func _build_mountain_environment() -> void:
	var env_root = get_node_or_null("Environment")
	if not env_root:
		env_root = Node3D.new()
		env_root.name = "Environment"
		add_child(env_root)

	var terrain_node = Node3D.new()
	terrain_node.name = "AlpineTerrain"
	env_root.add_child(terrain_node)

	# Sector 0: Entry Valley (Z: 65 to 100, Y: 0)
	_create_terrain_block(terrain_node, Vector3(0, -1.0, 82.5), Vector3(70, 2.0, 35))

	# Ramp 1: Entry to Mid Pass (Z: 65 to 50, Y: 0 to 2.5, angle ~ 9.5 deg)
	_create_terrain_ramp(terrain_node, Vector3(0, 1.25, 57.5), Vector3(36, 1.0, 16), -9.5)

	# Sector 1: Mid Pass Defile (Z: 35 to 50, Y: 2.5)
	_create_terrain_block(terrain_node, Vector3(0, 1.5, 42.5), Vector3(65, 2.0, 16))

	# Ramp 2: Mid Pass to Outpost Plateau (Z: 35 to 20, Y: 2.5 to 5.5, angle ~ 11 deg)
	_create_terrain_ramp(terrain_node, Vector3(0, 4.0, 27.5), Vector3(40, 1.0, 16), -11.0)

	# Sector 2: Outpost Plateau (Z: -10 to 20, Y: 5.5)
	_create_terrain_block(terrain_node, Vector3(0, 4.5, 5.0), Vector3(75, 2.0, 32))

	# Ramp 3: Outpost to Radar Summit (Z: -10 to -25, Y: 5.5 to 9.5, angle ~ 15 deg)
	_create_terrain_ramp(terrain_node, Vector3(0, 7.5, -17.5), Vector3(32, 1.0, 16), -15.0)

	# Sector 3: Radar Summit (Z: -25 to -40, Y: 9.5)
	_create_terrain_block(terrain_node, Vector3(0, 8.5, -32.5), Vector3(60, 2.0, 16))

	# Ramp 4: Summit to Evac Peak (Z: -40 to -52, Y: 9.5 to 13.0, angle ~ 16 deg)
	_create_terrain_ramp(terrain_node, Vector3(0, 11.25, -46.0), Vector3(26, 1.0, 13), -16.0)

	# Sector 4: Evac Helipad Peak (Z: -52 to -68, Y: 13.0)
	_create_terrain_block(terrain_node, Vector3(0, 12.0, -60.0), Vector3(50, 2.0, 17))

	# Surrounding Alpine Cliffs & Mountain Walls
	# Left Mountain Ridge (X: -40 to -55)
	_create_terrain_block(terrain_node, Vector3(-45, 12.0, 20.0), Vector3(25, 30.0, 160))
	# Right Mountain Ridge (X: 40 to 55)
	_create_terrain_block(terrain_node, Vector3(45, 12.0, 20.0), Vector3(25, 30.0, 160))
	# Rear Ridge (Z: 102)
	_create_terrain_block(terrain_node, Vector3(0, 14.0, 102.0), Vector3(100, 32.0, 20))
	# Far North Summit Ridge (Z: -72)
	_create_terrain_block(terrain_node, Vector3(0, 24.0, -72.0), Vector3(100, 40.0, 20))

func _create_terrain_block(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = _terrain_material
	body.add_child(mesh_inst)

	parent.add_child(body)
	return body

func _create_terrain_ramp(parent: Node3D, pos: Vector3, size: Vector3, rot_deg_x: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.x = rot_deg_x
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = _terrain_material
	body.add_child(mesh_inst)

	parent.add_child(body)
	return body

func _setup_outpost_structures() -> void:
	var outpost = Node3D.new()
	outpost.name = "OutpostStructures"
	get_node("Environment").add_child(outpost)

	# 1. Main Command Bunker Building at Outpost Plateau: (0, 5.5, 6)
	_build_bunker_building(outpost, Vector3(-12.0, 5.5, 6.0), Vector3(14.0, 5.0, 12.0))

	# 2. High Military Watchtower at (18.0, 5.5, 12.0)
	_build_watchtower(outpost, Vector3(18.0, 5.5, 12.0))

	# 3. High-Altitude Radar Dish Array at Summit (0.0, 9.5, -32.0)
	_build_radar_station(outpost, Vector3(0.0, 9.5, -32.0))

	# 4. Outpost Perimeter Gates & Checkpoints
	_build_gate_barrier(outpost, Vector3(0.0, 5.5, 19.0))

func _build_bunker_building(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var building := StaticBody3D.new()
	building.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	building.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = _materials_cache["concrete"]
	building.add_child(mesh_inst)

	# Reinforced roof rim
	var rim_mesh := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(size.x + 0.4, 0.4, size.z + 0.4)
	rim_mesh.mesh = rim_box
	rim_mesh.position = Vector3(0, size.y * 0.5 + 0.2, 0)
	rim_mesh.material_override = _materials_cache["metal"]
	building.add_child(rim_mesh)

	parent.add_child(building)

func _build_watchtower(parent: Node3D, pos: Vector3) -> void:
	var tower := Node3D.new()
	tower.position = pos

	# 4 Steel Legs
	var leg_height: float = 8.0
	var leg_offsets = [Vector3(-2, leg_height * 0.5, -2), Vector3(2, leg_height * 0.5, -2),
	                   Vector3(-2, leg_height * 0.5, 2), Vector3(2, leg_height * 0.5, 2)]
	for off in leg_offsets:
		var leg := StaticBody3D.new()
		leg.position = off
		var col := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = 0.18
		cyl_shape.height = leg_height
		col.shape = cyl_shape
		leg.add_child(col)
		var m := MeshInstance3D.new()
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = 0.18
		cyl_mesh.bottom_radius = 0.18
		cyl_mesh.height = leg_height
		m.mesh = cyl_mesh
		m.material_override = _materials_cache["metal"]
		leg.add_child(m)
		tower.add_child(leg)

	# Observation Platform (Y: 8.0)
	var platform := StaticBody3D.new()
	platform.position = Vector3(0, leg_height, 0)
	var p_col := CollisionShape3D.new()
	var p_shape := BoxShape3D.new()
	p_shape.size = Vector3(5.5, 0.4, 5.5)
	p_col.shape = p_shape
	platform.add_child(p_col)

	var p_mesh := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(5.5, 0.4, 5.5)
	p_mesh.mesh = p_box
	p_mesh.material_override = _materials_cache["metal"]
	platform.add_child(p_mesh)

	# Waist Railing
	var rail := StaticBody3D.new()
	rail.position = Vector3(0, leg_height + 0.6, 0)
	var r_col := CollisionShape3D.new()
	var r_shape := BoxShape3D.new()
	r_shape.size = Vector3(5.5, 1.0, 5.5)
	r_col.shape = r_shape
	rail.add_child(r_col)
	tower.add_child(platform)
	tower.add_child(rail)

	# Access Ramp leading up to Platform
	var tower_ramp := StaticBody3D.new()
	tower_ramp.position = Vector3(-4.5, leg_height * 0.5, 0)
	tower_ramp.rotation_degrees.z = -35.0
	var tr_col := CollisionShape3D.new()
	var tr_shape := BoxShape3D.new()
	tr_shape.size = Vector3(10.0, 0.25, 2.0)
	tr_col.shape = tr_shape
	tower_ramp.add_child(tr_col)
	var tr_mesh := MeshInstance3D.new()
	var tr_box := BoxMesh.new()
	tr_box.size = Vector3(10.0, 0.25, 2.0)
	tr_mesh.mesh = tr_box
	tr_mesh.material_override = _materials_cache["metal"]
	tower_ramp.add_child(tr_mesh)
	tower.add_child(tower_ramp)

	parent.add_child(tower)

func _build_radar_station(parent: Node3D, pos: Vector3) -> void:
	var station := Node3D.new()
	station.position = pos

	# Base housing
	var base_housing := StaticBody3D.new()
	base_housing.position = Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 3.0, 8.0)
	col.shape = shape
	base_housing.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 3.0, 8.0)
	mesh_inst.mesh = box
	mesh_inst.material_override = _materials_cache["concrete"]
	base_housing.add_child(mesh_inst)
	station.add_child(base_housing)

	# Rotating Radar Dish Mount
	radar_dish_mesh = Node3D.new()
	radar_dish_mesh.position = Vector3(0, 3.8, 0)

	var mast := MeshInstance3D.new()
	var mast_cyl := CylinderMesh.new()
	mast_cyl.top_radius = 0.25
	mast_cyl.bottom_radius = 0.35
	mast_cyl.height = 1.8
	mast.mesh = mast_cyl
	mast.material_override = _materials_cache["metal"]
	radar_dish_mesh.add_child(mast)

	var dish := MeshInstance3D.new()
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 2.4
	dish_mesh.bottom_radius = 0.5
	dish_mesh.height = 0.5
	dish.mesh = dish_mesh
	dish.rotation_degrees.x = 65.0
	dish.position = Vector3(0, 1.0, 0)
	dish.material_override = _materials_cache["mil_green"]
	radar_dish_mesh.add_child(dish)

	station.add_child(radar_dish_mesh)
	parent.add_child(station)

func _build_gate_barrier(parent: Node3D, pos: Vector3) -> void:
	var gate := Node3D.new()
	gate.position = pos

	# Left sandbag post
	_create_cover_box(gate, Vector3(-5.0, 0.5, 0), Vector3(3.5, 1.0, 1.2), _materials_cache["sandbag"])
	# Right sandbag post
	_create_cover_box(gate, Vector3(5.0, 0.5, 0), Vector3(3.5, 1.0, 1.2), _materials_cache["sandbag"])
	# Concrete Jersey barriers
	_create_cover_box(gate, Vector3(-10.0, 0.6, 0), Vector3(4.0, 1.2, 0.8), _materials_cache["concrete"])
	_create_cover_box(gate, Vector3(10.0, 0.6, 0), Vector3(4.0, 1.2, 0.8), _materials_cache["concrete"])

	parent.add_child(gate)

func _setup_tactical_cover() -> void:
	var covers = Node3D.new()
	covers.name = "TacticalCovers"
	get_node("Environment").add_child(covers)

	# Valley defile sandbags and crates
	_create_cover_box(covers, Vector3(-4.0, 0.5, 75.0), Vector3(3.0, 1.0, 1.0), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(5.0, 0.5, 70.0), Vector3(3.0, 1.0, 1.0), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(-8.0, 0.8, 62.0), Vector3(1.8, 1.6, 1.8), _materials_cache["mil_green"])

	# Mid Pass defile rocks and sandbag revetment
	_create_cover_box(covers, Vector3(6.0, 3.0, 44.0), Vector3(4.0, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(-7.0, 3.0, 40.0), Vector3(3.5, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(0.0, 3.2, 36.0), Vector3(2.0, 1.8, 2.0), _materials_cache["mil_green"])

	# Outpost perimeter defenses
	_create_cover_box(covers, Vector3(-4.0, 6.0, 14.0), Vector3(4.0, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(4.0, 6.0, 14.0), Vector3(4.0, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(10.0, 6.0, 2.0), Vector3(5.0, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(-14.0, 6.0, -4.0), Vector3(4.0, 1.1, 1.2), _materials_cache["sandbag"])

	# Radar station defenses
	_create_cover_box(covers, Vector3(-6.0, 10.0, -26.0), Vector3(3.5, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(6.0, 10.0, -26.0), Vector3(3.5, 1.1, 1.2), _materials_cache["sandbag"])
	_create_cover_box(covers, Vector3(0.0, 10.0, -38.0), Vector3(4.0, 1.1, 1.2), _materials_cache["sandbag"])

func _create_cover_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	parent.add_child(body)
	return body

func _setup_natural_vegetation() -> void:
	var natural_root = Node3D.new()
	natural_root.name = "NaturalVegetation"
	get_node("Environment").add_child(natural_root)

	var boulder_scene = load(BOULDER_GLTF_PATH) if ResourceLoader.exists(BOULDER_GLTF_PATH) else null
	var pine_scene = load(PINE_GLTF_PATH) if ResourceLoader.exists(PINE_GLTF_PATH) else null
	var fir_scene = load(FIR_GLTF_PATH) if ResourceLoader.exists(FIR_GLTF_PATH) else null

	# Strategic boulder placements with non-obstructing, unscaled static collisions
	var boulder_coords = [
		Vector3(-14.0, 0.0, 78.0), Vector3(15.0, 0.0, 74.0),
		Vector3(-16.0, 2.5, 48.0), Vector3(17.0, 2.5, 45.0),
		Vector3(-22.0, 5.5, 16.0), Vector3(24.0, 5.5, 8.0),
		Vector3(-18.0, 9.5, -24.0), Vector3(19.0, 9.5, -28.0)
	]
	for pos in boulder_coords:
		var boulder_body := StaticBody3D.new()
		boulder_body.position = pos
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.6
		col.shape = sphere
		boulder_body.add_child(col)
		if boulder_scene:
			var b_inst = boulder_scene.instantiate()
			b_inst.scale = Vector3(1.2, 1.2, 1.2)
			boulder_body.add_child(b_inst)
		natural_root.add_child(boulder_body)

	# Alpine Pine & Fir trees along the ridge shoulders
	var tree_coords = [
		{"pos": Vector3(-20.0, 0.5, 85.0), "type": "pine"},
		{"pos": Vector3(22.0, 0.5, 82.0), "type": "fir"},
		{"pos": Vector3(-24.0, 3.0, 52.0), "type": "fir"},
		{"pos": Vector3(25.0, 3.0, 48.0), "type": "pine"},
		{"pos": Vector3(-28.0, 6.0, 22.0), "type": "pine"},
		{"pos": Vector3(28.0, 6.0, 18.0), "type": "fir"},
		{"pos": Vector3(-22.0, 10.0, -18.0), "type": "fir"},
		{"pos": Vector3(22.0, 10.0, -22.0), "type": "pine"},
		{"pos": Vector3(-16.0, 13.5, -54.0), "type": "fir"},
		{"pos": Vector3(16.0, 13.5, -56.0), "type": "pine"},
	]
	for t in tree_coords:
		var tree_node := Node3D.new()
		tree_node.position = t["pos"]
		if t["type"] == "pine" and pine_scene:
			var p = pine_scene.instantiate()
			p.scale = Vector3(1.5, 1.5, 1.5)
			tree_node.add_child(p)
		elif fir_scene:
			var f = fir_scene.instantiate()
			f.scale = Vector3(1.5, 1.5, 1.5)
			tree_node.add_child(f)
		natural_root.add_child(tree_node)

func _setup_extraction_zone() -> void:
	var lz = Node3D.new()
	lz.name = "ExtractionLZ"
	lz.position = Vector3(0.0, 13.0, -60.0)
	get_node("Environment").add_child(lz)

	# Helipad Pad Markings
	var pad := MeshInstance3D.new()
	var pad_cyl := CylinderMesh.new()
	pad_cyl.top_radius = 4.5
	pad_cyl.bottom_radius = 4.5
	pad_cyl.height = 0.1
	pad.mesh = pad_cyl
	pad.material_override = _materials_cache["metal"]
	lz.add_child(pad)

	# Beacon pillar
	var beacon := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.2
	b_cyl.bottom_radius = 0.2
	b_cyl.height = 1.4
	beacon.mesh = b_cyl
	beacon.position = Vector3(0, 0.7, 0)
	beacon.material_override = _materials_cache["beacon"]
	lz.add_child(beacon)

	extraction_beacon_light = OmniLight3D.new()
	extraction_beacon_light.position = Vector3(0, 2.0, 0)
	extraction_beacon_light.light_color = Color(0.12, 0.82, 0.32, 1.0)
	extraction_beacon_light.light_energy = 2.5
	extraction_beacon_light.omni_range = 12.0
	lz.add_child(extraction_beacon_light)

	# Extraction Area3D
	extraction_zone = Area3D.new()
	extraction_zone.name = "ExtractionArea"
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 4.5
	shape.height = 3.0
	col.shape = shape
	extraction_zone.add_child(col)
	extraction_zone.body_entered.connect(_on_extraction_body_entered)
	lz.add_child(extraction_zone)

func _setup_player_loadout() -> void:
	if not player:
		return
	# Set player position at valley entrance
	player.global_position = Vector3(0.0, 1.5, 85.0)

	# Equip CW-08 Tactical Assault Rifle
	var gun_model = player.get_node_or_null("Camera3D/WeaponRig/GunModel")
	if gun_model:
		# Hide original default assault rifle mesh
		var default_mesh = gun_model.get_node_or_null("Assault Rifle")
		if default_mesh:
			default_mesh.visible = false
		
		# Add CW-08 Assault Rifle visual model
		var cw08_inst = CW08_WEAPON_SCENE.instantiate()
		cw08_inst.name = "CW08Visual"
		gun_model.add_child(cw08_inst)
		
		if gun_model.data:
			gun_model.data.weapon_name = "CW-08 Tactical Assault Rifle"
			gun_model.data.magazine_size = 30
			gun_model.data.starting_reserve_ammo = 90

func _setup_custom_ui() -> void:
	iron_hud = get_node_or_null("HUD")
	if not iron_hud:
		iron_hud = HUD_SCENE.instantiate()
		iron_hud.name = "HUD"
		add_child(iron_hud)

	if iron_hud.has_signal("pause_requested") and not iron_hud.pause_requested.is_connected(_on_pause_requested):
		iron_hud.pause_requested.connect(_on_pause_requested)
	if player and iron_hud.has_method("track_player"):
		iron_hud.track_player(player)
		iron_hud.set_weapon_info("CW-08 ASSAULT RIFLE", "5.56 NATO // AUTO")
		iron_hud.set_ammo(30, 90)

	# Instantiate Pause Menu
	pause_menu = PAUSE_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	# Instantiate Success Screen
	success_screen = SUCCESS_SCENE.instantiate()
	success_screen.name = "SuccessScreen"
	add_child(success_screen)

	# Instantiate Failed Screen
	failed_screen = FAILED_SCENE.instantiate()
	failed_screen.name = "FailedScreen"
	add_child(failed_screen)

func _bind_enemy_events() -> void:
	total_enemy_count = 0
	enemies_killed_count = 0

	if enemies_container:
		for child in enemies_container.get_children():
			total_enemy_count += 1
			if child.has_signal("enemy_died"):
				child.enemy_died.connect(_on_enemy_killed.bind(child))
			elif child.has_signal("target_destroyed"):
				child.target_destroyed.connect(_on_enemy_killed.bind(child))
			if "target_player" in child:
				child.target_player = player

	_update_stage_objectives()

func _on_enemy_killed(enemy_node: Node) -> void:
	enemies_killed_count += 1
	_update_stage_objectives()

	if enemies_killed_count >= total_enemy_count:
		_trigger_all_enemies_neutralized()

func _update_stage_objectives() -> void:
	if not iron_hud:
		return
	var remaining: int = maxi(0, total_enemy_count - enemies_killed_count)
	if remaining > 0:
		iron_hud.set_objective("OBJECTIVE: SECURE RADAR OUTPOST [HOSTILES REMAINING: %d / %d]" % [remaining, total_enemy_count])
	else:
		iron_hud.set_objective("★ ALL HOSTILES ELIMINATED! PROCEED TO SUMMIT EVAC LZ")

func _trigger_all_enemies_neutralized() -> void:
	is_extraction_ready = true
	if iron_hud:
		iron_hud.show_banner("OUTPOST SECURED! EVAC HELIPAD IS ACTIVE", 5.0)
	if extraction_beacon_light:
		extraction_beacon_light.light_energy = 5.0

func _on_extraction_body_entered(body: Node3D) -> void:
	if not is_extraction_ready or is_stage_finished:
		return
	if body == player or (body and body.is_in_group("player")):
		is_stage_finished = true
		if success_screen:
			success_screen.display_success(elapsed_time, enemies_killed_count, total_enemy_count)

func _on_player_died() -> void:
	is_stage_finished = true
	if failed_screen:
		failed_screen.display_failure(elapsed_time, enemies_killed_count, total_enemy_count)

func _on_pause_requested() -> void:
	if pause_menu:
		pause_menu.open_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu and not pause_menu.visible and not is_stage_finished:
			pause_menu.open_menu()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	super._process(delta)
	
	# Rotate summit radar dish
	if radar_dish_mesh and is_radar_active:
		radar_dish_mesh.rotate_y(delta * 0.8)
	
	# Pulse extraction beacon when ready
	if is_extraction_ready and extraction_beacon_light:
		extraction_beacon_light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.005) * 1.5
