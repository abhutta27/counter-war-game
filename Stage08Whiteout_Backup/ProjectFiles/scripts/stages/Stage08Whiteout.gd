class_name Stage08Whiteout
extends "res://scripts/LevelBase3D.gd"
## Stage 08 — OPERATION WHITEOUT
## Sub-zero alpine mountain valley tactical assault environment.
## Features three readable elevation tiers (Lower Valley, Mid-Ridge, High Summit),
## a commanding summit radar station, switchback mountain pass ramps, solid cover,
## and authentic winter whiteout atmospheric fog.

const TIER_ELEVATIONS: Dictionary = {
	"lower_valley": 2.2,
	"mid_ridge": 8.0,
	"high_summit": 16.8
}

const RADAR_POSITION := Vector3(0.0, 16.8, -78.0)

# Tactical Guard Deployment & Awareness
const GUARD_DATA := {
	"Enemy3D_1": {"role": "valley east patrol", "tier": "lower_valley", "zone": "valley"},
	"Enemy3D_2": {"role": "valley generator guard", "tier": "lower_valley", "zone": "valley"},
	"Enemy3D_3": {"role": "valley east forward sentry", "tier": "lower_valley", "zone": "valley"},
	"Enemy3D_4": {"role": "valley west ramp sentry", "tier": "lower_valley", "zone": "valley"},
	"Enemy3D_5": {"role": "mid-ridge outpost shack guard", "tier": "mid_ridge", "zone": "mid_ridge"},
	"Enemy3D_6": {"role": "mid-ridge depot sentry", "tier": "mid_ridge", "zone": "mid_ridge"},
	"Enemy3D_7": {"role": "mid-ridge terrace patrol", "tier": "mid_ridge", "zone": "mid_ridge"},
	"Enemy3D_8": {"role": "mid-ridge pass defender", "tier": "mid_ridge", "zone": "mid_ridge"},
	"Enemy3D_9": {"role": "summit perimeter west sentry", "tier": "high_summit", "zone": "summit"},
	"Enemy3D_10": {"role": "summit perimeter east guard", "tier": "high_summit", "zone": "summit"},
	"Enemy3D_11": {"role": "radar bunker sentinel", "tier": "high_summit", "zone": "summit"},
	"Enemy3D_12": {"role": "radar facility guard", "tier": "high_summit", "zone": "summit"}
}

const GUARD_LOOK_TARGETS := {
	"Enemy3D_1": Vector3(10.0, 7.12, 20.0),
	"Enemy3D_2": Vector3(-11.0, 6.87, 20.0),
	"Enemy3D_3": Vector3(8.0, 7.67, 15.0),
	"Enemy3D_4": Vector3(0.0, 8.03, 20.0),
	"Enemy3D_5": Vector3(0.0, 7.66, -10.0),
	"Enemy3D_6": Vector3(12.0, 7.63, -26.0),
	"Enemy3D_7": Vector3(0.0, 8.16, -20.0),
	"Enemy3D_8": Vector3(-8.0, 8.88, -38.0),
	"Enemy3D_9": Vector3(0.0, 16.68, -67.0),
	"Enemy3D_10": Vector3(8.0, 16.78, -80.0),
	"Enemy3D_11": Vector3(0.0, 17.02, -78.0),
	"Enemy3D_12": Vector3(0.0, 16.85, -76.0)
}

const VISION_RANGE := 26.0
const CLOSE_RANGE := 6.0
const VISION_HALF_FOV := 65.0
const GUNSHOT_HEARING_RANGE := 28.0
const POLL_RATE := 0.2

const TERRAIN_SHADER := preload("res://shaders/stage08_alpine_hybrid.gdshader")
const TEXTURE_ROOT := "res://assets/prototypes/stage08/textures/"
const MODEL_ROOT := "res://assets/prototypes/stage08/models/"

@export var terrain_width: float = 240.0
@export var terrain_depth: float = 280.0
@export var grid_resolution_x: int = 120
@export var grid_resolution_z: int = 140

var _noise_macro: FastNoiseLite
var _noise_detail: FastNoiseLite
var _terrain_material: ShaderMaterial

var guard_active: Dictionary = {}
var _poll_time: float = 0.0
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}

# -----------------------------------------------------------------------------
# Radar Shutdown & Secret Signal Gameplay Event State
# -----------------------------------------------------------------------------
var is_radar_shutdown: bool = false
var is_secret_signal_active: bool = false
var is_signal_investigated: bool = false
var _radar_event_triggered: bool = false
var _radar_dish_active: bool = true
var _radar_strobe_timer: float = 0.0
var _current_directive: String = "NEUTRALIZE SENTRIES & SEIZE SUMMIT RADAR"

const RADAR_CONSOLE_POSITION := Vector3(-5.5, 17.6, -73.5)
const SIGNAL_SOURCE_POSITION := Vector3(-15.0, 18.0, -86.0)
const INTERACTION_RADIUS := 3.8

var _radar_console_node: Node3D = null
var _radar_console_label: Label3D = null
var _radar_console_light: OmniLight3D = null

var _signal_source_node: Node3D = null
var _signal_source_label: Label3D = null
var _signal_source_light: OmniLight3D = null

var _interaction_prompt_label: Label = null
var _hud_toast_label: Label = null
var _secret_signal_overlay: Control = null

# Stage 08 Dedicated UI Reference Integrations
const STAGE08_HUD_SCENE := preload("res://scenes/stages/ui/Stage08HUD.tscn")
const STAGE08_PAUSE_SCENE := preload("res://scenes/stages/ui/Stage08PauseMenu.tscn")
const STAGE08_SUCCESS_SCENE := preload("res://scenes/stages/ui/Stage08MissionSuccess.tscn")
const STAGE08_FAILED_SCENE := preload("res://scenes/stages/ui/Stage08MissionFailed.tscn")

var stage08_hud: Stage08HUD = null
var stage08_pause_menu: Stage08PauseMenu = null
var stage08_mission_success: Stage08MissionSuccess = null
var stage08_mission_failed: Stage08MissionFailed = null

# Stage 08 Dedicated Tactical HUD Extensions
var _compass_container: PanelContainer = null
var _compass_heading_label: Label = null
var _compass_tape_label: Label = null


var _waypoint_container: PanelContainer = null
var _waypoint_desc_label: Label = null
var _waypoint_dist_label: Label = null

var _checklist_panel: PanelContainer = null
var _checklist_items: Array[Label] = []
var _last_calculated_heading: float = 0.0
var _last_waypoint_dist: int = 0

var _alarm_audio_player: AudioStreamPlayer = null
var _static_audio_player: AudioStreamPlayer = null
var _chime_audio_player: AudioStreamPlayer = null
var _cached_alarm_stream: AudioStream = null
var _cached_static_stream: AudioStream = null
var _cached_chime_stream: AudioStream = null


func _ready() -> void:
	_init_noises()
	_build_terrain_material()
	_create_materials()
	_build_environment()
	super._ready()
	_ground_characters()
	_freeze_guards()
	_init_event_audio()
	_setup_radar_event_hud()
	_setup_stage08_dedicated_hud()
	_update_objective_display()
	if player and not player.shot_fired.is_connected(_on_player_gunshot_alert):
		player.shot_fired.connect(_on_player_gunshot_alert)

func _ground_characters() -> void:
	if player and is_instance_valid(player):
		var p_x := player.global_position.x
		var p_z := player.global_position.z
		player.global_position.y = get_elevation(p_x, p_z) + 0.05
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO
	
	var enemies := get_node_or_null("Enemies") as Node3D
	if enemies:
		for enemy in enemies.get_children():
			var guard := enemy as CharacterBody3D
			if not guard or not is_instance_valid(guard):
				continue
			var g_x := guard.global_position.x
			var g_z := guard.global_position.z
			guard.global_position.y = get_elevation(g_x, g_z) + 0.02
			guard.velocity = Vector3.ZERO

func _process(delta: float) -> void:
	super._process(delta)
	if is_stage_finished or not player or not is_instance_valid(player):
		return
	_process_radar_event(delta)
	_update_interaction_prompts()
	_update_stage08_dedicated_hud(delta)
	_poll_time -= delta
	if _poll_time <= 0.0:
		_poll_time = POLL_RATE
		_poll_guard_contacts()

# -----------------------------------------------------------------------------
# Guard Combat and Awareness Methods
# -----------------------------------------------------------------------------

func _freeze_guards() -> void:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		var guard := enemy as CharacterBody3D
		if not guard:
			continue
		guard_active[guard.name] = false
		guard.set_physics_process(false)
		guard.velocity = Vector3.ZERO
		if guard.has_signal("health_changed") and not guard.health_changed.is_connected(_on_guard_health_changed):
			guard.health_changed.connect(_on_guard_health_changed.bind(guard))
		if GUARD_LOOK_TARGETS.has(guard.name):
			_face_position(guard, GUARD_LOOK_TARGETS[guard.name])

func _poll_guard_contacts() -> void:
	if not player or not is_instance_valid(player):
		return
	var p_pos: Vector3 = player.global_position
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		var guard := enemy as CharacterBody3D
		if not guard or guard.is_dead or guard_active.get(guard.name, false):
			continue
		var dist: float = guard.global_position.distance_to(p_pos)
		if dist > VISION_RANGE:
			continue

		# Elevation isolation: guard only detects player on same/accessible elevation tier
		var elevation_gap: float = absf(guard.global_position.y - p_pos.y)
		if elevation_gap > 6.5:
			continue

		if _has_line_of_sight(guard):
			if dist <= CLOSE_RANGE:
				activate_guard(guard, "close proximity contact")
			else:
				var to_player: Vector3 = p_pos - guard.global_position
				to_player.y = 0.0
				var forward: Vector3 = -guard.global_basis.z
				forward.y = 0.0
				var dot: float = forward.normalized().dot(to_player.normalized())
				if dot >= cos(deg_to_rad(VISION_HALF_FOV)):
					activate_guard(guard, "visual contact confirmed")

func activate_guard(guard: Node, reason := "contact") -> void:
	if not guard or guard.is_dead or guard_active.get(guard.name, false):
		return
	guard_active[guard.name] = true
	guard.velocity = Vector3.ZERO
	if "target_player" in guard and player:
		guard.target_player = player
	guard.set_physics_process(true)
	print("[Stage08Whiteout] Guard %s activated: %s" % [guard.name, reason])

func _on_guard_health_changed(current_hp: int, max_hp: int, guard: Node) -> void:
	if current_hp < max_hp and not guard.is_dead:
		activate_guard(guard, "incoming fire")
		_alert_nearby_guards(guard.global_position, 18.0)

func _on_player_gunshot_alert() -> void:
	if not player or not is_instance_valid(player):
		return
	var gunshot_pos: Vector3 = player.global_position
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		if enemy.is_dead or guard_active.get(enemy.name, false):
			continue
		var dist: float = enemy.global_position.distance_to(gunshot_pos)
		var elevation_gap: float = absf(enemy.global_position.y - gunshot_pos.y)
		if dist <= GUNSHOT_HEARING_RANGE and elevation_gap <= 7.0:
			activate_guard(enemy, "nearby gunshot")

func _alert_nearby_guards(contact_pos: Vector3, radius: float) -> void:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		if enemy.is_dead or guard_active.get(enemy.name, false):
			continue
		var elevation_gap: float = absf(enemy.global_position.y - contact_pos.y)
		if elevation_gap <= 6.5 and enemy.global_position.distance_to(contact_pos) <= radius:
			activate_guard(enemy, "nearby guard engaged")

func _has_line_of_sight(guard: CollisionObject3D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		guard.global_position + Vector3.UP * 1.35,
		player.global_position + Vector3.UP * 1.25,
		1,
		[guard.get_rid()]
	)
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func _face_position(node: Node3D, target: Vector3) -> void:
	var t := target
	t.y = node.global_position.y
	if node.global_position.distance_squared_to(t) > 0.1:
		node.look_at(t, Vector3.UP)

func get_guard_data() -> Dictionary:
	return GUARD_DATA

func get_guard_tier(guard_name: String) -> String:
	return GUARD_DATA.get(guard_name, {}).get("tier", "")

func is_guard_active(guard_name: String) -> bool:
	return guard_active.get(guard_name, false)

func count_living_guards() -> int:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return 0
	var count := 0
	for enemy in enemies.get_children():
		if is_instance_valid(enemy) and ("is_dead" in enemy) and not enemy.is_dead:
			count += 1
	return count

func get_tier_elevation(tier_name: String) -> float:
	return float(TIER_ELEVATIONS.get(tier_name.to_lower(), 0.0))

func get_radar_position() -> Vector3:
	return RADAR_POSITION

func is_radar_visible() -> bool:
	var radar_node := get_node_or_null("Environment/RadarInstallation")
	return radar_node != null and radar_node.visible

func get_primary_route_waypoints() -> Array[Vector3]:
	return [
		Vector3(0.0, 2.24, 85.0),     # Valley Approach Spawn
		Vector3(0.0, 4.63, 48.0),     # Lower Valley Checkpoint
		Vector3(0.0, 7.67, 24.0),     # Lower Ascent Approach
		Vector3(0.0, 8.20, 0.0),      # Mid-Ridge Forward Camp
		Vector3(8.0, 8.16, -20.0),    # Mid-Ridge Road Section
		Vector3(0.0, 13.5, -48.0),    # Summit Mountain Pass Approach
		Vector3(0.0, 16.7, -64.0),    # High Summit Approach
		Vector3(0.0, 16.8, -78.0)     # Radar Installation Core
	]

# -----------------------------------------------------------------------------
# Environment Construction
# -----------------------------------------------------------------------------

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
	var base_tier_y: float = 0.0
	var corridor_center_x: float = 0.0

	if z >= 65.0:
		# Tier 1: Lower Valley (Y ~ 1.5m to 2.2m)
		base_tier_y = 1.8 + sin(z * 0.04) * 0.6
		corridor_center_x = 0.0
	elif z >= 20.0:
		# Switchback 1: Climbing from Valley (Y=1.8m) to Mid-Ridge (Y=8.0m)
		var t := (65.0 - z) / 45.0
		var smooth_t := smoothstep(0.0, 1.0, t)
		base_tier_y = lerpf(1.8, 8.2, smooth_t)
		corridor_center_x = sin(t * PI) * -22.0
	elif z >= -15.0:
		# Tier 2: Mid-Ridge Tactical Plateau (Y ~ 8.2m to 9.0m)
		base_tier_y = 8.2 + sin(z * 0.06 + x * 0.03) * 0.5
		corridor_center_x = 6.0
	elif z >= -58.0:
		# Switchback 2: Climbing from Mid-Ridge (Y=8.2m) to High Summit (Y=17.0m)
		var t := (-15.0 - z) / 43.0
		var smooth_t := smoothstep(0.0, 1.0, t)
		base_tier_y = lerpf(8.2, 17.0, smooth_t)
		corridor_center_x = 6.0 + sin(t * PI) * 16.0 - (t * 8.0)
	else:
		# Tier 3: High Summit Crest (Y ~ 17.0m to 18.5m)
		base_tier_y = 17.2 + sin(z * 0.05) * 0.6
		corridor_center_x = 0.0

	# Walkable corridor cross-section
	var dist_from_path := absf(x - corridor_center_x)
	var road_half_width := 11.0
	var path_factor := 1.0 - clampf((dist_from_path - road_half_width) / 18.0, 0.0, 1.0)

	# Lateral Canyon Walls & Steep Mountain Flanks
	var canyon_dist := absf(x)
	var wall_factor := smoothstep(22.0, 95.0, canyon_dist)
	var wall_height := 0.0
	if wall_factor > 0.0:
		var ridge_crags := 0.0
		if _noise_macro:
			var n := _noise_macro.get_noise_2d(x * 1.5, z * 0.7)
			ridge_crags = pow(1.0 - absf(n), 2.2) * 32.0
		wall_height = (54.0 + ridge_crags) * wall_factor + pow(wall_factor, 1.8) * 48.0

	# Natural organic undulations
	var macro_noise := 0.0
	var detail_noise := 0.0
	if _noise_macro:
		macro_noise = _noise_macro.get_noise_2d(x, z) * 6.5
	if _noise_detail:
		detail_noise = _noise_detail.get_noise_2d(x, z) * 1.8
	var natural_noise := (macro_noise + detail_noise) * (1.0 - path_factor * 0.85)

	# Terrace benches on valley and ridge shoulders
	var shoulder_bench := 0.0
	if absf(x) > 16.0 and absf(x) < 38.0:
		shoulder_bench = sin(z * 0.05 + x * 0.08) * 1.5

	return base_tier_y + wall_height + natural_noise + shoulder_bench

func _build_environment() -> void:
	var env_root: Node3D = $Environment
	if not env_root:
		return

	_build_sculpted_terrain(env_root)
	_build_distant_mountain_ranges(env_root)
	_build_natural_props(env_root)
	_build_cover_and_structures(env_root)
	_build_radar_installation(env_root)
	_build_safety_perimeters(env_root)

func _build_sculpted_terrain(parent: Node3D) -> void:
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
	parent.add_child(terrain_inst)

	# Generate precise physical trimesh collision
	terrain_inst.create_trimesh_collision()

func _build_distant_mountain_ranges(parent: Node3D) -> void:
	var ranges := [
		{
			"name": "DistantMountainRange_01",
			"base_z": -175.0,
			"depth": 70.0,
			"width": 540.0,
			"max_h": 165.0,
			"seed": 14.0,
			"seg_x": 60,
			"seg_z": 12,
			"peaks": [
				{"x": -180.0, "w": 50.0, "h": 1.10},
				{"x": -115.0, "w": 42.0, "h": 1.25},
				{"x": -55.0, "w": 38.0, "h": 1.35},
				{"x": 0.0, "w": 45.0, "h": 1.22},
				{"x": 58.0, "w": 38.0, "h": 1.38},
				{"x": 120.0, "w": 44.0, "h": 1.25},
				{"x": 185.0, "w": 50.0, "h": 1.10}
			]
		},
		{
			"name": "DistantMountainRange_02",
			"base_z": -255.0,
			"depth": 95.0,
			"width": 750.0,
			"max_h": 240.0,
			"seed": 48.0,
			"seg_x": 64,
			"seg_z": 12,
			"peaks": [
				{"x": -250.0, "w": 55.0, "h": 1.15},
				{"x": -150.0, "w": 48.0, "h": 1.28},
				{"x": -85.0, "w": 42.0, "h": 1.35},
				{"x": -15.0, "w": 40.0, "h": 1.28},
				{"x": 35.0, "w": 44.0, "h": 1.36},
				{"x": 95.0, "w": 42.0, "h": 1.32},
				{"x": 170.0, "w": 50.0, "h": 1.25},
				{"x": 260.0, "w": 55.0, "h": 1.10}
			]
		},
		{
			"name": "DistantMountainRange_03",
			"base_z": -370.0,
			"depth": 130.0,
			"width": 980.0,
			"max_h": 330.0,
			"seed": 89.0,
			"seg_x": 70,
			"seg_z": 14,
			"peaks": [
				{"x": -350.0, "w": 70.0, "h": 1.10},
				{"x": -210.0, "w": 60.0, "h": 1.25},
				{"x": -100.0, "w": 52.0, "h": 1.38},
				{"x": 0.0, "w": 58.0, "h": 1.45},
				{"x": 110.0, "w": 52.0, "h": 1.40},
				{"x": 220.0, "w": 60.0, "h": 1.28},
				{"x": 360.0, "w": 70.0, "h": 1.10}
			]
		}
	]

	for data in ranges:
		var seg_x: int = data["seg_x"]
		var seg_z: int = data["seg_z"]
		var range_w: float = data["width"]
		var depth: float = data["depth"]
		var base_z: float = data["base_z"]
		var max_h: float = data["max_h"]
		var seed_val: float = data["seed"]
		var peaks: Array = data["peaks"]

		var count_x := seg_x + 1
		var count_z := seg_z + 1
		var total_verts := count_x * count_z
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		vertices.resize(total_verts)
		uvs.resize(total_verts)

		var half_w := range_w * 0.5
		var half_d := depth * 0.5
		var step_x := range_w / float(seg_x)
		var step_z := depth / float(seg_z)

		for iz in range(count_z):
			var fz := float(iz) / float(seg_z)
			var vz := base_z - half_d + float(iz) * step_z
			var z_profile: float = clampf(1.0 - pow(absf(fz - 0.55) / 0.55, 1.4), 0.0, 1.0)

			for ix in range(count_x):
				var vx := -half_w + float(ix) * step_x

				var peak_profile := 0.0
				for p in peaks:
					var p_x: float = p["x"]
					var p_w: float = p["w"]
					var p_h: float = p["h"]
					var dist := absf(vx - p_x) / p_w
					if dist < 1.0:
						var horn := pow(1.0 - dist, 1.6) * p_h
						peak_profile = maxf(peak_profile, horn)

				var ridged := 0.0
				if _noise_macro:
					var n1 := _noise_macro.get_noise_2d(vx * 1.4 + seed_val, vz * 1.4)
					var n2 := _noise_macro.get_noise_2d(vx * 3.2 + seed_val * 2.0, vz * 3.2) * 0.4
					ridged = (pow(1.0 - absf(n1), 2.2) + pow(1.0 - absf(n2), 2.0) * 0.3) * 32.0

				var y_crest := 26.0 + (peak_profile * max_h + ridged) * z_profile
				var y_base := -8.0
				var vy := lerpf(y_base, y_crest, z_profile)

				var idx := iz * count_x + ix
				vertices[idx] = Vector3(vx, vy, vz)
				uvs[idx] = Vector2(vx, vz) * 0.024

		for iz in range(seg_z):
			for ix in range(seg_x):
				var a := iz * count_x + ix
				var b := a + count_x
				indices.append_array(PackedInt32Array([a, b + 1, b, a, a + 1, b + 1]))

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
		distant_mesh.name = data["name"]
		distant_mesh.mesh = surface.commit()
		distant_mesh.material_override = _terrain_material
		parent.add_child(distant_mesh)

func _build_natural_props(parent: Node3D) -> void:
	var props_root := Node3D.new()
	props_root.name = "NaturalProps"
	parent.add_child(props_root)

	# 1. Exposed rocky mountainside cliff formations along the canyon walls
	var cliffs := [
		[Vector3(-52.0, get_elevation(-52.0, 75.0), 75.0), 52.0, 45.0],
		[Vector3(55.0, get_elevation(55.0, 70.0), 70.0), 50.0, 195.0],
		[Vector3(-58.0, get_elevation(-58.0, 35.0), 35.0), 54.0, 35.0],
		[Vector3(60.0, get_elevation(60.0, 20.0), 20.0), 50.0, 180.0],
		[Vector3(-62.0, get_elevation(-62.0, -10.0), -10.0), 55.0, 60.0],
		[Vector3(65.0, get_elevation(65.0, -25.0), -25.0), 52.0, 200.0],
		[Vector3(-55.0, get_elevation(-55.0, -70.0), -70.0), 52.0, 30.0],
		[Vector3(58.0, get_elevation(58.0, -75.0), -75.0), 50.0, 175.0]
	]
	for c in cliffs:
		_place_model(props_root, "mountainside", c[0], c[1], c[2], false)

	# 2. Tactical Boulders along trail shoulders and valley edges
	var boulders := [
		[Vector3(-14.0, get_elevation(-14.0, 85.0), 85.0), 9.0, 30.0],
		[Vector3(15.0, get_elevation(15.0, 76.0), 76.0), 10.5, 115.0],
		[Vector3(-24.0, get_elevation(-24.0, 50.0), 50.0), 11.0, 210.0],
		[Vector3(16.0, get_elevation(16.0, 32.0), 32.0), 10.0, 45.0],
		[Vector3(-15.0, get_elevation(-15.0, 5.0), 5.0), 10.5, 290.0],
		[Vector3(22.0, get_elevation(22.0, -8.0), -8.0), 12.0, 160.0],
		[Vector3(12.0, get_elevation(12.0, -32.0), -32.0), 11.0, 80.0],
		[Vector3(-16.0, get_elevation(-16.0, -68.0), -68.0), 11.5, 320.0],
		[Vector3(18.0, get_elevation(18.0, -72.0), -72.0), 10.0, 195.0]
	]
	for b in boulders:
		_place_model(props_root, "boulder_01", b[0], b[1], b[2], true)

	# 3. Alpine Conifers (Fir and Pine) framing valley flanks and defiles
	var conifers := [
		["fir_sapling", Vector3(-24.0, get_elevation(-24.0, 65.0), 65.0), 16.0, 15.0],
		["pine_sapling_small", Vector3(24.0, get_elevation(24.0, 60.0), 60.0), 17.0, 70.0],
		["fir_sapling", Vector3(-26.0, get_elevation(-26.0, 48.0), 48.0), 17.0, -35.0],
		["pine_sapling_small", Vector3(26.0, get_elevation(26.0, 42.0), 42.0), 18.0, 145.0],
		["fir_sapling", Vector3(-28.0, get_elevation(-28.0, 30.0), 30.0), 18.0, 45.0],
		["pine_sapling_small", Vector3(22.0, get_elevation(22.0, 20.0), 20.0), 16.0, 110.0],
		["fir_sapling", Vector3(-24.0, get_elevation(-24.0, 8.0), 8.0), 17.0, 95.0],
		["pine_sapling_small", Vector3(20.0, get_elevation(20.0, -5.0), -5.0), 16.0, 180.0],
		["fir_sapling", Vector3(24.0, get_elevation(24.0, -22.0), -22.0), 17.0, 310.0],
		["pine_sapling_small", Vector3(-24.0, get_elevation(-24.0, -42.0), -42.0), 18.0, 60.0]
	]
	for c in conifers:
		_place_model(props_root, c[0], c[1], c[2], c[3], false)

func _place_model(parent: Node3D, asset_name: String, world_pos: Vector3, target_size: float, yaw_deg: float, add_collision: bool) -> void:
	var path := MODEL_ROOT + asset_name + "/" + asset_name + "_2k.gltf"
	var packed := load(path) as PackedScene
	if not packed:
		return
	var inst := packed.instantiate() as Node3D
	if not inst:
		return
	var aabb := _compute_node_aabb(inst)
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim <= 0.001:
		max_dim = 1.0
	var scale_factor := target_size / max_dim
	inst.scale = Vector3.ONE * scale_factor
	inst.position = world_pos
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(inst)

	if add_collision:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = target_size * 0.42
		col.shape = shape
		col.position = Vector3(0.0, target_size * 0.35, 0.0)
		sb.add_child(col)
		inst.add_child(sb)

func _compute_node_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and cur.mesh:
			var m_aabb: AABB = cur.mesh.get_aabb()
			if first:
				aabb = m_aabb
				first = false
			else:
				aabb = aabb.merge(m_aabb)
		for child in cur.get_children():
			stack.append(child)
	if first:
		return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	return aabb

func _build_cover_and_structures(parent: Node3D) -> void:
	var cover := _group(parent, "TacticalCover")

	# --- Tier 1: Lower Valley Cover ---
	var y1 := get_elevation(-6.0, 32.0)
	_box(cover, "ValleyBarrier_West", Vector3(-6.0, y1 + 0.7, 32.0), Vector3(4.5, 1.4, 0.8), "concrete")
	_box(cover, "ValleyBarrier_West_Snow", Vector3(-6.0, y1 + 1.45, 32.0), Vector3(4.7, 0.18, 0.9), "snow", false)

	var y2 := get_elevation(6.0, 30.0)
	_box(cover, "ValleyBarrier_East", Vector3(6.0, y2 + 0.7, 30.0), Vector3(4.5, 1.4, 0.8), "concrete")
	_box(cover, "ValleyBarrier_East_Snow", Vector3(6.0, y2 + 1.45, 30.0), Vector3(4.7, 0.18, 0.9), "snow", false)

	var y3 := get_elevation(-12.0, 26.0)
	_box(cover, "ValleyBarrier_FarWest", Vector3(-12.0, y3 + 0.7, 26.0), Vector3(4.5, 1.4, 0.8), "concrete")
	_box(cover, "ValleyBarrier_FarWest_Snow", Vector3(-12.0, y3 + 1.45, 26.0), Vector3(4.7, 0.18, 0.9), "snow", false)

	var y4 := get_elevation(-8.0, 42.0)
	_box(cover, "ValleyCrateStack_A", Vector3(-8.0, y4 + 1.0, 42.0), Vector3(2.4, 2.0, 2.4), "wood")
	_box(cover, "ValleyCrateStack_A_Snow", Vector3(-8.0, y4 + 2.05, 42.0), Vector3(2.5, 0.16, 2.5), "snow", false)

	var y5 := get_elevation(8.0, 38.0)
	_box(cover, "ValleyCrateStack_B", Vector3(8.0, y5 + 0.8, 38.0), Vector3(2.0, 1.6, 3.0), "wood")
	_box(cover, "ValleyCrateStack_B_Snow", Vector3(8.0, y5 + 1.65, 38.0), Vector3(2.1, 0.16, 3.1), "snow", false)

	var y6 := get_elevation(-14.0, 36.0)
	_box(cover, "ValleyGenerator", Vector3(-14.0, y6 + 1.2, 36.0), Vector3(3.2, 2.4, 2.4), "metal")

	# --- Tier 2: Mid-Ridge Cover & Outpost ---
	var y_shack := get_elevation(-14.0, -12.0)
	var shack := _group(cover, "MidRidgeShack")
	_box(shack, "ShackBody", Vector3(-14.0, y_shack + 2.0, -12.0), Vector3(6.0, 4.0, 5.0), "bunker")
	_box(shack, "ShackRoofSnow", Vector3(-14.0, y_shack + 4.1, -12.0), Vector3(6.4, 0.25, 5.4), "snow", false)
	_box(shack, "ShackDoor", Vector3(-10.9, y_shack + 1.5, -12.0), Vector3(0.2, 3.0, 1.8), "metal", false)

	var y7 := get_elevation(-6.0, -14.0)
	_box(cover, "RidgeBarrier_West", Vector3(-6.0, y7 + 0.7, -14.0), Vector3(4.5, 1.4, 0.8), "concrete")
	_box(cover, "RidgeBarrier_West_Snow", Vector3(-6.0, y7 + 1.45, -14.0), Vector3(4.7, 0.18, 0.9), "snow", false)

	var y8 := get_elevation(6.0, -18.0)
	_box(cover, "RidgeBarrier_East", Vector3(6.0, y8 + 0.7, -18.0), Vector3(4.5, 1.4, 0.8), "concrete")
	_box(cover, "RidgeBarrier_East_Snow", Vector3(6.0, y8 + 1.45, -18.0), Vector3(4.7, 0.18, 0.9), "snow", false)

	var y9 := get_elevation(-6.0, -26.0)
	_box(cover, "RidgeBarrier_North", Vector3(-6.0, y9 + 0.7, -26.0), Vector3(5.0, 1.4, 0.8), "concrete")
	_box(cover, "RidgeBarrier_North_Snow", Vector3(-6.0, y9 + 1.45, -26.0), Vector3(5.2, 0.18, 0.9), "snow", false)

	var y10 := get_elevation(14.0, -16.0)
	_box(cover, "RidgeCrates", Vector3(14.0, y10 + 1.2, -16.0), Vector3(3.2, 2.4, 3.2), "wood")
	_box(cover, "RidgeCrates_Snow", Vector3(14.0, y10 + 2.45, -16.0), Vector3(3.3, 0.16, 3.3), "snow", false)

	var y11 := get_elevation(12.0, -28.0)
	_box(cover, "RidgeSubstation", Vector3(12.0, y11 + 1.5, -28.0), Vector3(4.0, 3.0, 2.5), "metal")

	# --- Tier 3: High Summit Outpost Cover ---
	var y12 := get_elevation(-6.0, -66.0)
	_box(cover, "SummitBarrier_West", Vector3(-6.0, y12 + 0.7, -66.0), Vector3(5.0, 1.4, 0.8), "concrete")
	_box(cover, "SummitBarrier_West_Snow", Vector3(-6.0, y12 + 1.45, -66.0), Vector3(5.2, 0.18, 0.9), "snow", false)

	var y13 := get_elevation(6.0, -68.0)
	_box(cover, "SummitBarrier_East", Vector3(6.0, y13 + 0.7, -68.0), Vector3(5.0, 1.4, 0.8), "concrete")
	_box(cover, "SummitBarrier_East_Snow", Vector3(6.0, y13 + 1.45, -68.0), Vector3(5.2, 0.18, 0.9), "snow", false)

	var y14 := get_elevation(14.0, -74.0)
	_box(cover, "SummitSupplyStack", Vector3(14.0, y14 + 1.2, -74.0), Vector3(3.6, 2.4, 3.6), "wood")
	_box(cover, "SummitSupplyStack_Snow", Vector3(14.0, y14 + 2.45, -74.0), Vector3(3.7, 0.16, 3.7), "snow", false)

	var y15 := get_elevation(-12.0, -88.0)
	_box(cover, "SummitPowerUnit", Vector3(-12.0, y15 + 1.5, -88.0), Vector3(4.0, 3.0, 3.0), "metal")

func _build_radar_installation(parent: Node3D) -> void:
	var radar := _group(parent, "RadarInstallation")
	var sy := get_elevation(0.0, -78.0)

	# Concrete Radar Sub-Base (Plinth) - flush with summit floor
	_box(radar, "RadarPlinth", Vector3(0.0, sy - 0.5, -78.0), Vector3(14.0, 1.0, 14.0), "concrete", true)

	# Control Station Bunker
	_box(radar, "CommandBunker", Vector3(-15.0, sy + 2.5, -78.0), Vector3(10.0, 5.0, 12.0), "bunker")
	_box(radar, "BunkerBlastDoor", Vector3(-9.9, sy + 1.5, -78.0), Vector3(0.2, 3.0, 2.4), "metal", false)
	_box(radar, "BunkerRoofAntenna", Vector3(-15.0, sy + 6.0, -78.0), Vector3(0.3, 3.0, 0.3), "metal", false)

	# Main Radar Steel Lattice Tower
	_box(radar, "RadarTowerMast", Vector3(0.0, sy + 9.5, -78.0), Vector3(2.2, 17.0, 2.2), "metal")
	_box(radar, "TowerGantryA", Vector3(0.0, sy + 6.0, -78.0), Vector3(7.0, 0.4, 7.0), "metal", false)
	_box(radar, "TowerGantryB", Vector3(0.0, sy + 13.0, -78.0), Vector3(6.0, 0.4, 6.0), "metal", false)

	# Primary Parabolic Radar Dish (Angled toward the valley)
	_cylinder(radar, "PrimaryRadarDish", Vector3(0.0, sy + 15.5, -78.0), 4.5, 0.7, "radar_dish", Vector3(68.0, 0.0, 0.0), true)
	_box(radar, "RadarFeedArm", Vector3(0.0, sy + 16.2, -76.2), Vector3(0.4, 3.5, 0.4), "metal", false, Vector3(68.0, 0.0, 0.0))

	# Secondary Communications Dome
	_cylinder(radar, "SecondaryDomeBase", Vector3(12.0, sy + 1.0, -84.0), 3.0, 2.0, "concrete")
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 2.6
	dome_mesh.height = 3.6
	dome_mesh.radial_segments = 16
	dome_mesh.rings = 8
	dome_mesh.material = _materials["radar_dish"]
	var dome_inst := MeshInstance3D.new()
	dome_inst.name = "WeatherDomeMesh"
	dome_inst.mesh = dome_mesh
	dome_inst.position = Vector3(12.0, sy + 2.5, -84.0)
	radar.add_child(dome_inst)

	# High-Altitude Aviation Safety Beacon
	var beacon_light := OmniLight3D.new()
	beacon_light.name = "RadarTopBeacon"
	beacon_light.position = Vector3(0.0, sy + 19.0, -78.0)
	beacon_light.light_color = Color(1.0, 0.2, 0.2)
	beacon_light.light_energy = 2.5
	beacon_light.omni_range = 16.0
	beacon_light.shadow_enabled = false
	radar.add_child(beacon_light)

	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.35
	beacon_mesh.height = 0.7
	beacon_mesh.material = _materials["beacon_red"]
	var beacon_inst := MeshInstance3D.new()
	beacon_inst.name = "BeaconMesh"
	beacon_inst.mesh = beacon_mesh
	beacon_inst.position = Vector3(0.0, sy + 18.8, -78.0)
	radar.add_child(beacon_inst)

	# Radar Shutdown Terminal / Console
	_build_radar_console(radar, sy)

	# Sub-Surface Anomalous Signal Source
	_build_signal_source(radar, sy)

func _build_craggy_cliffs(parent: Node3D) -> void:
	var mountains := _group(parent, "MountainPeaks")

	# Close Valley Wall Outcrops (Retains exact collision nodes required by verification tests)
	var valley_cliffs = [
		["CliffWest_Lower", Vector3(-28.0, 4.0, 36.0), Vector3(14.0, 10.0, 28.0)],
		["CliffEast_Lower", Vector3(28.0, 4.0, 36.0), Vector3(14.0, 10.0, 28.0)],
		["CliffWest_Mid", Vector3(-29.0, 10.0, -18.0), Vector3(14.0, 14.0, 36.0)],
		["CliffEast_Mid", Vector3(29.0, 10.0, -18.0), Vector3(14.0, 14.0, 36.0)],
		["CliffWest_Summit", Vector3(-28.0, 18.0, -78.0), Vector3(14.0, 16.0, 40.0)],
		["CliffEast_Summit", Vector3(28.0, 18.0, -78.0), Vector3(14.0, 16.0, 40.0)],
		["CliffNorth_Rear", Vector3(0.0, 20.0, -100.0), Vector3(56.0, 18.0, 12.0)]
	]
	for c in valley_cliffs:
		_invisible_wall(mountains, c[0], c[1], c[2])

	# Layered Irregular Rocky Bluff Formations & Snow Mantles Dressing the Valley
	# West Valley Wall Natural Formations
	_craggy_rock(mountains, "WestBluffA", Vector3(-22.0, 3.5, 42.0), Vector3(12.0, 8.0, 18.0), -18.0)
	_craggy_rock(mountains, "WestBluffB", Vector3(-23.0, 5.5, 26.0), Vector3(14.0, 10.0, 20.0), 12.0)
	_craggy_rock(mountains, "WestBluffC", Vector3(-24.0, 9.5, -8.0), Vector3(14.0, 13.0, 22.0), -8.0)
	_craggy_rock(mountains, "WestBluffD", Vector3(-23.0, 12.0, -28.0), Vector3(13.0, 12.0, 20.0), 25.0)

	# East Valley Wall Natural Formations
	_craggy_rock(mountains, "EastBluffA", Vector3(22.0, 3.5, 38.0), Vector3(12.0, 8.5, 18.0), 20.0)
	_craggy_rock(mountains, "EastBluffB", Vector3(23.0, 5.8, 22.0), Vector3(13.0, 9.5, 20.0), -15.0)
	_craggy_rock(mountains, "EastBluffC", Vector3(24.0, 10.0, -12.0), Vector3(14.0, 13.5, 22.0), 14.0)
	_craggy_rock(mountains, "EastBluffD", Vector3(23.0, 12.5, -32.0), Vector3(13.5, 12.5, 20.0), -22.0)

	# Summit Ridge Shoulder (Rock foundation under the Radar Station)
	_craggy_rock(mountains, "SummitCragEast", Vector3(22.0, 16.0, -74.0), Vector3(16.0, 15.0, 28.0), 16.0)
	_craggy_rock(mountains, "SummitCragWest", Vector3(-22.0, 16.0, -78.0), Vector3(15.0, 15.0, 26.0), -12.0)

func _build_mountain_backdrop(parent: Node3D) -> void:
	var backdrop := _group(parent, "MountainBackdrop")

	# --- Layer 1: Proximate Flanking Alpine Massifs (Z = -20 to -160) ---
	# Massive West Shoulder overlooking the deep frozen valley
	_mountain_peak(backdrop, "WestShoulderMassif", Vector3(-95.0, 8.0, 15.0), 48.0, 75.0, 6, Vector3(1.3, 1.0, 0.85), -20.0)
	_mountain_peak(backdrop, "WestValleyCragA", Vector3(-120.0, 4.0, -45.0), 55.0, 88.0, 7, Vector3(1.2, 1.0, 0.9), 15.0)
	_mountain_peak(backdrop, "WestValleyCragB", Vector3(-110.0, 12.0, -115.0), 58.0, 96.0, 6, Vector3(1.15, 1.0, 0.95), -10.0)

	# East Mountain Ridge flanking the Radar Base
	_mountain_peak(backdrop, "EastShoulderMassif", Vector3(92.0, 6.0, 10.0), 46.0, 72.0, 6, Vector3(1.25, 1.0, 0.9), 25.0)
	_mountain_peak(backdrop, "EastSummitCragA", Vector3(105.0, 14.0, -55.0), 54.0, 92.0, 7, Vector3(1.2, 1.0, 0.85), -18.0)
	_mountain_peak(backdrop, "EastSummitCragB", Vector3(98.0, 18.0, -125.0), 56.0, 98.0, 6, Vector3(1.15, 1.0, 0.9), 12.0)

	# --- Layer 2: Mid-Distance Jagged Alpine Horns & Couloirs (Z = -140 to -240) ---
	_mountain_peak(backdrop, "MidAlpineHornNW", Vector3(-75.0, 20.0, -185.0), 65.0, 115.0, 7, Vector3(1.2, 1.0, 0.8), -35.0)
	_mountain_peak(backdrop, "MidAlpineHornN", Vector3(0.0, 22.0, -195.0), 70.0, 125.0, 6, Vector3(1.25, 1.0, 0.85), 10.0)
	_mountain_peak(backdrop, "MidAlpineHornNE", Vector3(80.0, 22.0, -190.0), 68.0, 120.0, 7, Vector3(1.15, 1.0, 0.85), 40.0)

	# --- Layer 3: Grand Far Horizon Alpine Mountain Chain (Z = -280 to -380) ---
	# Towering snow-capped mountain massifs stretching across the entire horizon
	_mountain_peak(backdrop, "FarRangeNW_A", Vector3(-180.0, 15.0, -320.0), 95.0, 155.0, 6, Vector3(1.3, 1.0, 0.8), -15.0)
	_mountain_peak(backdrop, "FarRangeNW_B", Vector3(-95.0, 25.0, -310.0), 90.0, 160.0, 7, Vector3(1.25, 1.0, 0.85), 25.0)
	_mountain_peak(backdrop, "FarRangeNorth_Peak", Vector3(-10.0, 30.0, -330.0), 105.0, 175.0, 6, Vector3(1.2, 1.0, 0.8), -8.0)
	_mountain_peak(backdrop, "FarRangeNE_A", Vector3(85.0, 28.0, -315.0), 92.0, 165.0, 7, Vector3(1.25, 1.0, 0.85), 32.0)
	_mountain_peak(backdrop, "FarRangeNE_B", Vector3(175.0, 20.0, -325.0), 98.0, 158.0, 6, Vector3(1.3, 1.0, 0.8), -20.0)

	# Far Southern & Lateral Horizon Silhouettes (Enclosing the mountain pass)
	_mountain_peak(backdrop, "HorizonSouthWest", Vector3(-160.0, 5.0, 120.0), 85.0, 130.0, 6, Vector3(1.2, 1.0, 0.9), 18.0)
	_mountain_peak(backdrop, "HorizonSouthEast", Vector3(160.0, 5.0, 120.0), 85.0, 130.0, 6, Vector3(1.2, 1.0, 0.9), -18.0)

func _build_alpine_trees(parent: Node3D) -> void:
	var foliage := _group(parent, "AlpineFoliage")

	# --- Lower Valley Trees (Framing player spawn, kept outside central walking corridor) ---
	var valley_trees = [
		[Vector3(-14.0, 0.2, 47.0), 1.15, 12.0],
		[Vector3(-18.0, 0.3, 44.0), 1.35, -25.0],
		[Vector3(-16.0, 0.4, 38.0), 1.05, 45.0],
		[Vector3(-15.0, 0.4, 28.0), 1.25, -10.0],
		[Vector3(14.0, 0.2, 45.0), 1.20, -18.0],
		[Vector3(18.0, 0.3, 41.0), 1.40, 30.0],
		[Vector3(15.0, 0.4, 34.0), 1.10, -42.0],
		[Vector3(16.0, 0.4, 24.0), 1.30, 15.0]
	]
	for t in valley_trees:
		_pine_tree(foliage, t[0], t[1], t[2])

	# --- Mid-Ridge Terrace Trees ---
	var ridge_trees = [
		[Vector3(-15.0, 6.3, -8.0), 1.30, 22.0],
		[Vector3(-18.0, 6.4, -20.0), 1.45, -33.0],
		[Vector3(-14.0, 6.4, -32.0), 1.20, 18.0],
		[Vector3(15.0, 6.3, -10.0), 1.25, -14.0],
		[Vector3(18.0, 6.4, -24.0), 1.35, 40.0],
		[Vector3(16.0, 6.4, -34.0), 1.15, -28.0]
	]
	for t in ridge_trees:
		_pine_tree(foliage, t[0], t[1], t[2])

	# --- Deep Valley Frozen Lake Shoreline Forest (Visible far below in the valley) ---
	var deep_lake_trees = [
		[Vector3(-38.0, -24.0, 20.0), 2.2, 14.0],
		[Vector3(-45.0, -24.0, 10.0), 2.5, -20.0],
		[Vector3(-52.0, -24.0, -5.0), 2.8, 35.0],
		[Vector3(-40.0, -24.0, -25.0), 2.4, -12.0],
		[Vector3(-60.0, -24.0, -40.0), 3.0, 48.0],
		[Vector3(-75.0, -24.0, -60.0), 2.8, -30.0],
		[Vector3(-55.0, -24.0, -85.0), 3.2, 18.0],
		[Vector3(-80.0, -24.0, -105.0), 2.9, -42.0],
		[Vector3(-42.0, -24.0, -120.0), 2.6, 25.0],
		[Vector3(2.0, -21.0, -15.0), 2.0, -16.0],
		[Vector3(5.0, -21.0, -45.0), 2.2, 32.0],
		[Vector3(0.0, -21.0, -80.0), 2.4, -22.0]
	]
	for t in deep_lake_trees:
		_pine_tree(foliage, t[0], t[1], t[2])

func _build_safety_perimeters(parent: Node3D) -> void:
	var safety := _group(parent, "SafetyPerimeter")

	# Invisible safety collision barriers preventing the player from ever escaping the playable valley
	_invisible_wall(safety, "SafetyWest", Vector3(-32.0, 15.0, -10.0), Vector3(2.0, 40.0, 220.0))
	_invisible_wall(safety, "SafetyEast", Vector3(32.0, 15.0, -10.0), Vector3(2.0, 40.0, 220.0))
	_invisible_wall(safety, "SafetySouth", Vector3(0.0, 15.0, 102.0), Vector3(64.0, 40.0, 2.0))
	_invisible_wall(safety, "SafetyNorth", Vector3(0.0, 25.0, -102.0), Vector3(64.0, 40.0, 2.0))

# -----------------------------------------------------------------------------
# Procedural Geometry & Material Helpers
# -----------------------------------------------------------------------------

func _create_materials() -> void:
	# Crisp winter snow with specular rim lighting
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.96, 0.97, 0.99)
	snow_mat.roughness = 0.82
	snow_mat.rim_enabled = true
	snow_mat.rim = 0.55
	snow_mat.rim_tint = 0.45
	_materials["snow"] = snow_mat

	# Packed snow along roads and treads
	var packed_mat := StandardMaterial3D.new()
	packed_mat.albedo_color = Color(0.86, 0.89, 0.93)
	packed_mat.roughness = 0.88
	packed_mat.rim_enabled = true
	packed_mat.rim = 0.35
	_materials["packed_snow"] = packed_mat

	# Dark jagged alpine rock
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.15, 0.17, 0.21)
	rock_mat.roughness = 0.94
	_materials["dark_rock"] = rock_mat
	_materials["mountain_rock"] = rock_mat

	# Mid-elevation cold rock
	var ice_rock_mat := StandardMaterial3D.new()
	ice_rock_mat.albedo_color = Color(0.26, 0.30, 0.37)
	ice_rock_mat.roughness = 0.82
	_materials["ice_rock"] = ice_rock_mat

	# Distant mountain silhouettes (faded by atmospheric perspective)
	var far_peak_mat := StandardMaterial3D.new()
	far_peak_mat.albedo_color = Color(0.48, 0.56, 0.68)
	far_peak_mat.roughness = 0.88
	_materials["far_peak"] = far_peak_mat

	# Glistening frozen alpine lake
	var lake_mat := StandardMaterial3D.new()
	lake_mat.albedo_color = Color(0.52, 0.68, 0.80)
	lake_mat.roughness = 0.16
	lake_mat.metallic = 0.28
	lake_mat.rim_enabled = true
	lake_mat.rim = 0.65
	_materials["frozen_lake"] = lake_mat

	# Semi-transparent low-lying valley fog cloud mist
	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.albedo_color = Color(0.82, 0.88, 0.95, 0.52)
	mist_mat.roughness = 0.95
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["cloud_mist"] = mist_mat

	# Conifer evergreen needle foliage
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.10, 0.20, 0.13)
	foliage_mat.roughness = 0.90
	_materials["pine_foliage"] = foliage_mat

	# Pine tree bark trunk
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.22, 0.16, 0.12)
	trunk_mat.roughness = 0.95
	_materials["pine_trunk"] = trunk_mat

	# Tactical base structures
	_mat("road", Color(0.28, 0.30, 0.33), 0.92)
	_mat("concrete", Color(0.44, 0.47, 0.50), 0.85)
	_mat("metal", Color(0.22, 0.25, 0.28), 0.45, 0.70)
	_mat("radar_dish", Color(0.78, 0.82, 0.86), 0.35, 0.65)
	_mat("bunker", Color(0.25, 0.29, 0.27), 0.85)
	_mat("wood", Color(0.32, 0.24, 0.16), 0.92)
	_mat("warning", Color(0.85, 0.52, 0.10), 0.70)

	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.15, 0.15)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.2, 0.2)
	beacon_mat.emission_energy_multiplier = 2.5
	_materials["beacon_red"] = beacon_mat

	var beacon_green_mat := StandardMaterial3D.new()
	beacon_green_mat.albedo_color = Color(0.2, 0.95, 0.4)
	beacon_green_mat.emission_enabled = true
	beacon_green_mat.emission = Color(0.2, 0.95, 0.4)
	beacon_green_mat.emission_energy_multiplier = 2.2
	_materials["beacon_green"] = beacon_green_mat

	var beacon_amber_mat := StandardMaterial3D.new()
	beacon_amber_mat.albedo_color = Color(1.0, 0.7, 0.15)
	beacon_amber_mat.emission_enabled = true
	beacon_amber_mat.emission = Color(1.0, 0.7, 0.15)
	beacon_amber_mat.emission_energy_multiplier = 2.5
	_materials["beacon_amber"] = beacon_amber_mat

	var beacon_cyan_mat := StandardMaterial3D.new()
	beacon_cyan_mat.albedo_color = Color(0.15, 0.8, 1.0)
	beacon_cyan_mat.emission_enabled = true
	beacon_cyan_mat.emission = Color(0.15, 0.8, 1.0)
	beacon_cyan_mat.emission_energy_multiplier = 2.2
	_materials["beacon_cyan"] = beacon_cyan_mat

	var screen_cyan_mat := StandardMaterial3D.new()
	screen_cyan_mat.albedo_color = Color(0.04, 0.14, 0.22)
	screen_cyan_mat.emission_enabled = true
	screen_cyan_mat.emission = Color(0.1, 0.5, 0.85)
	screen_cyan_mat.emission_energy_multiplier = 1.2
	_materials["screen_cyan"] = screen_cyan_mat

func _mat(key: String, color: Color, roughness: float, metallic: float = 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_materials[key] = m

func _group(parent: Node3D, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	return n

func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: String, collision: bool = true, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees = rot
	parent.add_child(root)

	var key := "%s:%s" % [size, mat]
	var mesh: BoxMesh = _mesh_cache.get(key)
	if not mesh:
		mesh = BoxMesh.new()
		mesh.size = size
		mesh.material = _materials.get(mat)
		_mesh_cache[key] = mesh

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)

	if collision:
		var skey := str(size)
		var shape: BoxShape3D = _shape_cache.get(skey)
		if not shape:
			shape = BoxShape3D.new()
			shape.size = size
			_shape_cache[skey] = shape
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = shape
		root.add_child(cs)

	return root

func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat: String, rot: Vector3 = Vector3.ZERO, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees = rot
	parent.add_child(root)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = _materials.get(mat)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)

	if collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = shape
		root.add_child(cs)

	return root

func _invisible_wall(parent: Node3D, node_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)

	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	root.add_child(cs)
	return root

func _snow_mound(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = _materials["snow"]

	var mi := MeshInstance3D.new()
	mi.name = "MoundMesh"
	mi.mesh = mesh
	mi.scale = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	root.add_child(mi)
	return root

func _craggy_rock(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	# Main angular faceted rock boulder
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	rock_mesh.material = _materials["dark_rock"]

	var mi := MeshInstance3D.new()
	mi.name = "RockMesh"
	mi.mesh = rock_mesh
	mi.scale = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	root.add_child(mi)

	# Snow blanket resting on the top of the rock
	var snow_mesh := SphereMesh.new()
	snow_mesh.radius = 0.95
	snow_mesh.height = 1.0
	snow_mesh.radial_segments = 7
	snow_mesh.rings = 3
	snow_mesh.material = _materials["snow"]

	var smi := MeshInstance3D.new()
	smi.name = "SnowCap"
	smi.mesh = snow_mesh
	smi.position = Vector3(0.0, size.y * 0.35, 0.0)
	smi.scale = Vector3(size.x * 0.48, size.y * 0.28, size.z * 0.48)
	root.add_child(smi)

	return root

func _mountain_peak(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, sides: int, stretch: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	# Lower dark rock mass of the mountain
	var rock_mesh := CylinderMesh.new()
	rock_mesh.top_radius = 0.0
	rock_mesh.bottom_radius = radius
	rock_mesh.height = height
	rock_mesh.radial_segments = sides
	rock_mesh.rings = 2
	rock_mesh.material = _materials["mountain_rock"]

	var rock_inst := MeshInstance3D.new()
	rock_inst.name = "RockBody"
	rock_inst.mesh = rock_mesh
	rock_inst.scale = stretch
	root.add_child(rock_inst)

	# Brilliant alpine snow cap covering the upper 55% of the mountain peak
	var snow_height := height * 0.55
	var snow_radius := radius * 0.55
	var snow_mesh := CylinderMesh.new()
	snow_mesh.top_radius = 0.0
	snow_mesh.bottom_radius = snow_radius
	snow_mesh.height = snow_height
	snow_mesh.radial_segments = sides
	snow_mesh.rings = 2
	snow_mesh.material = _materials["snow"]

	var snow_inst := MeshInstance3D.new()
	snow_inst.name = "SnowCrown"
	snow_inst.mesh = snow_mesh
	snow_inst.position = Vector3(0.0, height * 0.23 * stretch.y, 0.0)
	snow_inst.scale = stretch
	root.add_child(snow_inst)

	# Flanking subsidiary spur ridge at the mountain base
	var spur_mesh := CylinderMesh.new()
	spur_mesh.top_radius = 0.0
	spur_mesh.bottom_radius = radius * 0.45
	spur_mesh.height = height * 0.42
	spur_mesh.radial_segments = sides - 1
	spur_mesh.rings = 1
	spur_mesh.material = _materials["dark_rock"]

	var spur_inst := MeshInstance3D.new()
	spur_inst.name = "SpurRidge"
	spur_inst.mesh = spur_mesh
	spur_inst.position = Vector3(radius * 0.35 * stretch.x, -height * 0.28 * stretch.y, radius * 0.25 * stretch.z)
	spur_inst.rotation_degrees = Vector3(10.0, 35.0, -8.0)
	spur_inst.scale = stretch
	root.add_child(spur_inst)

	# Alpine Arête Knife-Edge Ridge 1 (Sun-facing snow couloir ridge)
	var ridge_a := PrismMesh.new()
	ridge_a.left_to_right = 0.5
	ridge_a.size = Vector3(radius * 0.22, height * 0.85, radius * 1.05)
	ridge_a.material = _materials["snow"]
	var r_inst1 := MeshInstance3D.new()
	r_inst1.name = "AreteRidgeA"
	r_inst1.mesh = ridge_a
	r_inst1.position = Vector3(0.0, -height * 0.15 * stretch.y, radius * 0.42 * stretch.z)
	r_inst1.rotation_degrees = Vector3(-30.0, 15.0, 8.0)
	r_inst1.scale = stretch
	root.add_child(r_inst1)

	# Alpine Arête Knife-Edge Ridge 2 (Shadowed dark rock rib)
	var ridge_b := PrismMesh.new()
	ridge_b.left_to_right = 0.5
	ridge_b.size = Vector3(radius * 0.25, height * 0.72, radius * 0.95)
	ridge_b.material = _materials["dark_rock"]
	var r_inst2 := MeshInstance3D.new()
	r_inst2.name = "AreteRidgeB"
	r_inst2.mesh = ridge_b
	r_inst2.position = Vector3(-radius * 0.36 * stretch.x, -height * 0.20 * stretch.y, -radius * 0.2 * stretch.z)
	r_inst2.rotation_degrees = Vector3(25.0, -42.0, -10.0)
	r_inst2.scale = stretch
	root.add_child(r_inst2)

	return root

func _pine_tree(parent: Node3D, pos: Vector3, scale_mult: float, yaw: float) -> Node3D:
	var tree := Node3D.new()
	tree.name = "PineTree"
	tree.position = pos
	tree.rotation_degrees.y = yaw
	parent.add_child(tree)

	# Trunk
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_mult
	trunk_mesh.bottom_radius = 0.32 * scale_mult
	trunk_mesh.height = 2.8 * scale_mult
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _materials["pine_trunk"]
	var t_inst := MeshInstance3D.new()
	t_inst.mesh = trunk_mesh
	t_inst.position = Vector3(0.0, 1.4 * scale_mult, 0.0)
	tree.add_child(t_inst)

	# 3 Stepped Conical Tiers with Snow Skirts
	var tiers := [
		[2.2 * scale_mult, 2.5 * scale_mult, 2.0 * scale_mult], # bottom tier: [radius, height, y_offset]
		[1.7 * scale_mult, 2.2 * scale_mult, 3.4 * scale_mult], # middle tier
		[1.2 * scale_mult, 2.0 * scale_mult, 4.7 * scale_mult]  # top tier
	]

	for i in range(tiers.size()):
		var tier = tiers[i]
		var r: float = tier[0]
		var h: float = tier[1]
		var y: float = tier[2]

		# Foliage cone
		var f_mesh := CylinderMesh.new()
		f_mesh.top_radius = 0.05 * scale_mult
		f_mesh.bottom_radius = r
		f_mesh.height = h
		f_mesh.radial_segments = 7
		f_mesh.material = _materials["pine_foliage"]
		var f_inst := MeshInstance3D.new()
		f_inst.mesh = f_mesh
		f_inst.position = Vector3(0.0, y, 0.0)
		tree.add_child(f_inst)

		# Snow mantle skirt on top of foliage
		var s_mesh := CylinderMesh.new()
		s_mesh.top_radius = 0.0
		s_mesh.bottom_radius = r * 0.88
		s_mesh.height = h * 0.48
		s_mesh.radial_segments = 7
		s_mesh.material = _materials["snow"]
		var s_inst := MeshInstance3D.new()
		s_inst.mesh = s_mesh
		s_inst.position = Vector3(0.0, y + h * 0.26, 0.0)
		tree.add_child(s_inst)

	return tree


# -----------------------------------------------------------------------------
# Radar Shutdown & Secret Signal Gameplay Event Implementation
# -----------------------------------------------------------------------------

func _build_radar_console(parent: Node3D, sy: float) -> void:
	_radar_console_node = _group(parent, "RadarControlConsole")
	var pos := Vector3(-5.5, sy, -73.5)
	_radar_console_node.position = pos

	# Pedestal & Housing
	_box(_radar_console_node, "TerminalBase", Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.8), "metal")
	_box(_radar_console_node, "TerminalDesk", Vector3(0, 0.85, 0.15), Vector3(1.2, 0.1, 0.5), "metal")
	_box(_radar_console_node, "TerminalScreen", Vector3(0, 1.2, -0.15), Vector3(1.0, 0.65, 0.12), "screen_cyan")

	# Status indicator bulb
	var bulb := _box(_radar_console_node, "StatusLight", Vector3(0, 1.65, -0.15), Vector3(0.2, 0.2, 0.2), "beacon_green", false)
	_radar_console_light = OmniLight3D.new()
	_radar_console_light.name = "ConsoleLight"
	_radar_console_light.light_color = Color(0.2, 1.0, 0.5)
	_radar_console_light.light_energy = 1.6
	_radar_console_light.omni_range = 4.0
	bulb.add_child(_radar_console_light)

	# 3D floating tag
	_radar_console_label = Label3D.new()
	_radar_console_label.name = "ConsoleLabel3D"
	_radar_console_label.position = Vector3(0, 2.1, 0)
	_radar_console_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_radar_console_label.font_size = 26
	_radar_console_label.outline_size = 6
	_radar_console_label.modulate = Color(0.3, 1.0, 0.6)
	_radar_console_label.text = "[RADAR CONTROL CONSOLE]\n[E] SHUTDOWN AVAILABLE"
	_radar_console_node.add_child(_radar_console_label)


func _build_signal_source(parent: Node3D, sy: float) -> void:
	_signal_source_node = _group(parent, "AnomalousSignalSource")
	var pos := Vector3(-15.0, sy, -86.0)
	_signal_source_node.position = pos
	_signal_source_node.visible = false

	# Sub-glacial bunker vault transducer pedestal
	_box(_signal_source_node, "TransducerPlinth", Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2), "concrete")
	_box(_signal_source_node, "VaultTerminalHousing", Vector3(0, 1.0, 0), Vector3(1.6, 1.4, 1.2), "bunker")
	_cylinder(_signal_source_node, "ResonatorCoilA", Vector3(0, 1.9, 0), 0.7, 0.3, "beacon_amber", Vector3.ZERO, false)
	_cylinder(_signal_source_node, "ResonatorCoilB", Vector3(0, 2.3, 0), 0.5, 0.3, "beacon_cyan", Vector3.ZERO, false)
	_box(_signal_source_node, "SubGlacialConduit", Vector3(0, 0.8, -1.0), Vector3(0.4, 0.4, 2.0), "metal", false)

	# Pulsing signal beacon
	_signal_source_light = OmniLight3D.new()
	_signal_source_light.name = "TransducerBeacon"
	_signal_source_light.position = Vector3(0, 2.6, 0)
	_signal_source_light.light_color = Color(1.0, 0.65, 0.15)
	_signal_source_light.light_energy = 3.5
	_signal_source_light.omni_range = 10.0
	_signal_source_node.add_child(_signal_source_light)

	# 3D floating tag
	_signal_source_label = Label3D.new()
	_signal_source_label.name = "SignalSourceLabel3D"
	_signal_source_label.position = Vector3(0, 3.2, 0)
	_signal_source_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_signal_source_label.font_size = 28
	_signal_source_label.outline_size = 8
	_signal_source_label.modulate = Color(1.0, 0.7, 0.2)
	_signal_source_label.text = "[ANOMALOUS SIGNAL SOURCE]\n[E] SCAN & DECODE ORIGIN"
	_signal_source_node.add_child(_signal_source_label)


func _setup_radar_event_hud() -> void:
	var hud_node := get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return

	# 1. Interaction prompt at screen bottom center
	_interaction_prompt_label = Label.new()
	_interaction_prompt_label.name = "Stage08InteractionPrompt"
	_interaction_prompt_label.anchor_left = 0.5
	_interaction_prompt_label.anchor_right = 0.5
	_interaction_prompt_label.anchor_top = 0.72
	_interaction_prompt_label.anchor_bottom = 0.72
	_interaction_prompt_label.offset_left = -320.0
	_interaction_prompt_label.offset_right = 320.0
	_interaction_prompt_label.offset_top = -24.0
	_interaction_prompt_label.offset_bottom = 24.0
	_interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_prompt_label.add_theme_font_size_override("font_size", 16)
	_interaction_prompt_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	_interaction_prompt_label.visible = false
	hud_node.add_child(_interaction_prompt_label)

	# 2. Toast banner for mission feedback
	_hud_toast_label = Label.new()
	_hud_toast_label.name = "Stage08ToastLabel"
	_hud_toast_label.anchor_left = 0.5
	_hud_toast_label.anchor_right = 0.5
	_hud_toast_label.anchor_top = 0.22
	_hud_toast_label.anchor_bottom = 0.22
	_hud_toast_label.offset_left = -360.0
	_hud_toast_label.offset_right = 360.0
	_hud_toast_label.offset_top = -20.0
	_hud_toast_label.offset_bottom = 20.0
	_hud_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_toast_label.add_theme_font_size_override("font_size", 18)
	_hud_toast_label.visible = false
	hud_node.add_child(_hud_toast_label)

	# 3. Secret Signal Cinematic Overlay
	_secret_signal_overlay = _build_secret_signal_overlay()
	hud_node.add_child(_secret_signal_overlay)


func _build_secret_signal_overlay() -> Control:
	var root_ctrl := Control.new()
	root_ctrl.name = "SecretSignalOverlay"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 270)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.96)
	sb.border_color = Color(0.95, 0.22, 0.15, 0.95)
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.85, 0.1, 0.1, 0.35)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "▲ PRIORITY INTERCEPT // ANOMALOUS TRANSMISSION DETECTED"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var telemetry := Label.new()
	telemetry.text = "FREQ: 448.92 MHz [SUB-SURFACE CARRIER]  ·  STATUS: FORCED OVERRIDE  ·  SECTOR 08-SUB"
	telemetry.add_theme_font_size_override("font_size", 11)
	telemetry.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	vbox.add_child(telemetry)

	var body := Label.new()
	body.text = "TACTICAL ADVISORY:\n" + \
		"Radar dish shutdown was forcibly intercepted by an external underground signal relay.\n" + \
		"Unregistered telemetry is transmitting from beneath the command bunker.\n" + \
		"Mission directive updated: Locate the sub-glacial transducer behind the bunker and investigate."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
	vbox.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	var prompt := Label.new()
	prompt.text = "PRESS [E] TO ACKNOWLEDGE & PROCEED TO SIGNAL SOURCE"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(prompt)

	return root_ctrl


func _process_radar_event(delta: float) -> void:
	# Subtle radar dish movement
	var dish := get_node_or_null("Environment/RadarInstallation/PrimaryRadarDish") as Node3D
	if dish and _radar_dish_active:
		var rot_speed := 1.4 if is_secret_signal_active else 0.35
		dish.rotate_y(delta * rot_speed)

	# Active emergency strobe flashing when secret signal event is triggered
	if is_secret_signal_active:
		_radar_strobe_timer += delta * 14.0
		var strobe_val: float = (sin(_radar_strobe_timer) * 0.5 + 0.5)
		var beacon := get_node_or_null("Environment/RadarInstallation/RadarTopBeacon") as OmniLight3D
		if beacon:
			beacon.light_energy = 1.0 + strobe_val * 6.5
			beacon.light_color = Color(1.0, 0.05, 0.05)
		if _signal_source_light:
			_signal_source_light.light_energy = 1.5 + strobe_val * 4.0


func _update_interaction_prompts() -> void:
	if not _interaction_prompt_label or not player or not is_instance_valid(player) or is_stage_finished:
		if _interaction_prompt_label:
			_interaction_prompt_label.visible = false
		return

	var p_pos := player.global_position
	var console_dist := p_pos.distance_to(RADAR_CONSOLE_POSITION)
	var signal_dist := p_pos.distance_to(SIGNAL_SOURCE_POSITION)

	if not is_radar_shutdown and console_dist <= INTERACTION_RADIUS:
		_interaction_prompt_label.text = "[E] INITIATE RADAR SHUTDOWN"
		_interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		_interaction_prompt_label.visible = true
	elif is_secret_signal_active and not is_signal_investigated and signal_dist <= INTERACTION_RADIUS:
		_interaction_prompt_label.text = "[E] SCAN & DECODE ANOMALOUS SIGNAL ORIGIN"
		_interaction_prompt_label.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
		_interaction_prompt_label.visible = true
	else:
		_interaction_prompt_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var is_escape: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if (event.is_action_pressed("pause") or is_escape) and not is_stage_finished:
		if stage08_pause_menu:
			stage08_pause_menu.toggle()
			get_viewport().set_input_as_handled()
			return

	if is_stage_finished or not player or not is_instance_valid(player):
		return
	var is_interact := false
	if event.is_action_pressed("interact"):
		is_interact = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		is_interact = true

	if is_interact:
		if _secret_signal_overlay and _secret_signal_overlay.visible:
			dismiss_secret_signal_panel()
			get_viewport().set_input_as_handled()
			return
		if _try_player_interaction():
			get_viewport().set_input_as_handled()


func _try_player_interaction() -> bool:
	if not player or not is_instance_valid(player):
		return false
	var p_pos := player.global_position
	if not is_radar_shutdown and p_pos.distance_to(RADAR_CONSOLE_POSITION) <= INTERACTION_RADIUS:
		return trigger_radar_shutdown()
	if is_secret_signal_active and not is_signal_investigated and p_pos.distance_to(SIGNAL_SOURCE_POSITION) <= INTERACTION_RADIUS:
		return investigate_signal_source()
	return false


func trigger_radar_shutdown() -> bool:
	if _radar_event_triggered or is_radar_shutdown or is_stage_finished:
		return false
	_radar_event_triggered = true
	is_radar_shutdown = true
	_radar_dish_active = false

	_play_chime_sound()

	if _radar_console_label:
		_radar_console_label.text = "[SHUTDOWN EXECUTING] // RADAR OFF"
		_radar_console_label.modulate = Color(0.5, 0.5, 0.5)
	if _radar_console_light:
		_radar_console_light.light_energy = 0.2
		_radar_console_light.light_color = Color(0.3, 0.3, 0.3)

	_show_hud_toast("RADAR TRANSMISSION TERMINATED // SUMMIT SECURED", Color(0.3, 1.0, 0.5))
	_update_objective_display("SECURING RADAR FACILITY...")
	print("[Stage08Whiteout] Radar shutdown initiated. Brief quiet pause before anomalous signal...")

	# Brief pause giving impression of mission completion (1.6 seconds)
	get_tree().create_timer(1.6).timeout.connect(_on_secret_signal_burst)
	return true


func _on_secret_signal_burst() -> void:
	if is_stage_finished:
		return
	is_secret_signal_active = true

	var beacon := get_node_or_null("Environment/RadarInstallation/RadarTopBeacon") as OmniLight3D
	if beacon:
		beacon.light_color = Color(1.0, 0.05, 0.05)
		beacon.light_energy = 5.0

	_start_alarm_audio()
	_play_static_burst()

	if _signal_source_node:
		_signal_source_node.visible = true

	_show_secret_signal_panel()
	_update_objective_display("INVESTIGATE ANOMALOUS SIGNAL ORIGIN")
	print("[Stage08Whiteout] CRITICAL EVENT: Anomalous signal intercepted! Forced radar override active.")


func _show_secret_signal_panel() -> void:
	if not _secret_signal_overlay:
		return
	_secret_signal_overlay.visible = true
	_secret_signal_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_secret_signal_overlay, "modulate:a", 1.0, 0.35)
	# Auto dismiss fallback after 6.0 seconds if operative does not press E
	get_tree().create_timer(6.0).timeout.connect(func():
		if _secret_signal_overlay and _secret_signal_overlay.visible:
			dismiss_secret_signal_panel()
	)


func dismiss_secret_signal_panel() -> void:
	if not _secret_signal_overlay or not _secret_signal_overlay.visible:
		return
	_secret_signal_overlay.visible = false
	_secret_signal_overlay.modulate.a = 0.0


func investigate_signal_source() -> bool:
	if not is_secret_signal_active or is_signal_investigated or is_stage_finished:
		return false
	is_signal_investigated = true
	_stop_alarm_audio()
	_play_chime_sound()

	if _signal_source_label:
		_signal_source_label.text = "[TRANSMISSION DECODED] // BLACK ARCHIVE LOCATED"
		_signal_source_label.modulate = Color(0.3, 1.0, 0.6)

	_show_hud_toast("SIGNAL INTERCEPT DECODED // OPERATION WHITEOUT COMPLETE", Color(0.25, 1.0, 0.6))
	_update_objective_display("TRANSMISSION ARCHIVED // MISSION ACCOMPLISHED")
	_update_stage08_dedicated_hud(0.0)
	print("[Stage08Whiteout] Secret signal investigated and decoded. Completing mission.")

	call_deferred("_complete_stage", true)
	return true


func _complete_stage_if_all_targets_eliminated() -> void:
	# In Stage 08, eliminating guards secures the ascent, but completing the mission
	# strictly requires radar shutdown and anomalous signal investigation!
	_update_objective_display()
	_update_stage08_checklist()


func _complete_stage(is_victory: bool) -> void:
	if is_victory and not is_signal_investigated:
		print("[Stage08Whiteout] Victory deferred: Radar shutdown and anomalous signal investigation required.")
		return
	_stop_alarm_audio()
	super._complete_stage(is_victory)

	# Suppress generic dialog and HUD so only dedicated Stage 08 UI appears
	if summary_dialog:
		summary_dialog.visible = false
	if stage08_hud:
		stage08_hud.visible = false

	if is_victory:
		if stage08_mission_success:
			var sc = get_node_or_null("/root/ScoreCalculator")
			var remaining_hp: int = player.current_health if player else 0
			var maximum_hp: int = player.max_health if player else 100
			var breakdown: Dictionary = {}
			if sc and sc.has_method("get_mission_score_breakdown"):
				breakdown = sc.get_mission_score_breakdown(
					kills, headshots, shots_fired, shots_hit,
					remaining_hp, maximum_hp, true
				)
			else:
				breakdown = {"final_score": current_mission_score}
			breakdown["elapsed_time"] = elapsed_time
			breakdown["kills"] = kills
			breakdown["shots_fired"] = shots_fired
			breakdown["shots_hit"] = shots_hit
			stage08_mission_success.display_results(8, breakdown)
	else:
		if stage08_mission_failed:
			var dist: int = 37
			if player and _has_safe_position:
				dist = maxi(10, int(player.global_position.distance_to(last_safe_position)))
			stage08_mission_failed.display_failure("Killed by hostile fire", dist)


func _on_player_health_changed(current_hp: int, max_hp: int) -> void:
	super._on_player_health_changed(current_hp, max_hp)
	if stage08_hud:
		stage08_hud.update_health(current_hp, max_hp)


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	super._on_player_ammo_changed(current_ammo, max_ammo)
	if stage08_hud:
		var weapon_name: String = "M4A1"
		var reserve: int = 180
		if player and player.has_method("get_weapon_manager"):
			var wm = player.get_weapon_manager()
			if wm and wm.has_method("get_current_weapon"):
				var cur = wm.get_current_weapon()
				if cur and cur.data:
					weapon_name = cur.data.weapon_name.to_upper()
					reserve = cur.reserve_ammo
		stage08_hud.update_ammo(current_ammo, reserve, weapon_name)



func _update_hud() -> void:
	super._update_hud()
	_update_objective_display()
	_update_live_enemy_counter()


func _update_objective_display(override_text: String = "") -> void:
	var directive := ""
	if not override_text.is_empty():
		directive = override_text
	elif is_signal_investigated:
		directive = "TRANSMISSION ARCHIVED // MISSION ACCOMPLISHED"
	elif is_secret_signal_active:
		directive = "INVESTIGATE ANOMALOUS SIGNAL ORIGIN"
	elif is_radar_shutdown:
		directive = "SECURING RADAR ARRAY..."
	elif targets_eliminated >= total_targets:
		directive = "PROCEED TO SUMMIT & SHUT DOWN RADAR"
	else:
		directive = "NEUTRALIZE SENTRIES & SEIZE SUMMIT RADAR"

	_current_directive = directive

	if targets_label:
		var remaining_targets := maxi(0, total_targets - targets_eliminated)
		targets_label.text = "[STAGE 08: OPERATION WHITEOUT] HOSTILES: %d/%d | %s" % [remaining_targets, total_targets, directive]

	if hud and "compact_objective_label" in hud and hud.compact_objective_label:
		hud.compact_objective_label.text = "DIRECTIVE: %s" % directive.to_upper()
	if hud and "objective_banner_text" in hud and hud.objective_banner_text:
		hud.objective_banner_text.text = directive.to_upper()


func _show_hud_toast(message: String, color: Color = Color(0.25, 0.9, 1.0)) -> void:
	if not _hud_toast_label:
		return
	_hud_toast_label.text = message
	_hud_toast_label.add_theme_color_override("font_color", color)
	_hud_toast_label.visible = true
	_hud_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_hud_toast_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		if _hud_toast_label:
			_hud_toast_label.visible = false
	)


# -----------------------------------------------------------------------------
# Audio & Procedural Sound Synthesis
# -----------------------------------------------------------------------------

func _init_event_audio() -> void:
	_alarm_audio_player = AudioStreamPlayer.new()
	_alarm_audio_player.name = "AlarmAudioPlayer"
	_alarm_audio_player.bus = "Master"
	_alarm_audio_player.volume_db = -4.0
	_alarm_audio_player.stream = _get_alarm_stream()
	add_child(_alarm_audio_player)

	_static_audio_player = AudioStreamPlayer.new()
	_static_audio_player.name = "StaticAudioPlayer"
	_static_audio_player.bus = "Master"
	_static_audio_player.volume_db = -3.0
	_static_audio_player.stream = _get_static_stream()
	add_child(_static_audio_player)

	_chime_audio_player = AudioStreamPlayer.new()
	_chime_audio_player.name = "ChimeAudioPlayer"
	_chime_audio_player.bus = "Master"
	_chime_audio_player.volume_db = -2.0
	_chime_audio_player.stream = _get_chime_stream()
	add_child(_chime_audio_player)


func _get_alarm_stream() -> AudioStream:
	if _cached_alarm_stream:
		return _cached_alarm_stream
	_cached_alarm_stream = _synthesize_alarm_siren()
	return _cached_alarm_stream


func _get_static_stream() -> AudioStream:
	if _cached_static_stream:
		return _cached_static_stream
	_cached_static_stream = _synthesize_radio_static()
	return _cached_static_stream


func _get_chime_stream() -> AudioStream:
	if _cached_chime_stream:
		return _cached_chime_stream
	_cached_chime_stream = _synthesize_terminal_chime()
	return _cached_chime_stream


func _synthesize_alarm_siren() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.2
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var cycle: float = sin(t / duration * TAU * 2.0)
		var freq: float = 880.0 + 240.0 * cycle
		phase += (freq / float(sample_rate)) * TAU
		var sample_val: float = sin(phase) * 0.42 + sin(phase * 2.0) * 0.12
		sample_val = clampf(sample_val, -1.0, 1.0)
		data[i] = int((sample_val * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	stream.data = data
	return stream


func _synthesize_radio_static() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.4
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Digital telemetry chirp on top of static burst
		var chirp_freq: float = 1400.0 + sin(t * 35.0) * 400.0
		phase += (chirp_freq / float(sample_rate)) * TAU
		var white_noise: float = (randf() * 2.0 - 1.0) * 0.35
		var chirp: float = sin(phase) * 0.3
		var envelope: float = 1.0 - (t / duration)
		var sample_val: float = clampf((white_noise + chirp) * envelope, -1.0, 1.0)
		data[i] = int((sample_val * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


func _synthesize_terminal_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.35
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var freq: float = 1046.0 if t < 0.15 else 1318.0
		phase += (freq / float(sample_rate)) * TAU
		var env: float = 1.0 - (t / duration)
		var sample_val: float = sin(phase) * 0.45 * env
		data[i] = int((clampf(sample_val, -1.0, 1.0) * 0.5 + 0.5) * 255.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


func _start_alarm_audio() -> void:
	if _alarm_audio_player and not _alarm_audio_player.playing:
		_alarm_audio_player.play()


func _stop_alarm_audio() -> void:
	if _alarm_audio_player and _alarm_audio_player.playing:
		_alarm_audio_player.stop()


func _play_static_burst() -> void:
	if _static_audio_player:
		_static_audio_player.play()


func _play_chime_sound() -> void:
	if _chime_audio_player:
		_chime_audio_player.play()


# -----------------------------------------------------------------------------
# Public Getters & Verification Helpers
# -----------------------------------------------------------------------------

func is_radar_shutdown_done() -> bool:
	return is_radar_shutdown

func is_secret_signal_active_state() -> bool:
	return is_secret_signal_active

func is_secret_signal_panel_open() -> bool:
	return _secret_signal_overlay != null and _secret_signal_overlay.visible

func is_signal_source_investigated_done() -> bool:
	return is_signal_investigated

func get_radar_console_position() -> Vector3:
	return RADAR_CONSOLE_POSITION

func get_signal_source_position() -> Vector3:
	return SIGNAL_SOURCE_POSITION

func get_current_directive() -> String:
	return _current_directive


# -----------------------------------------------------------------------------
# Stage 08 Dedicated Gameplay HUD (Compass, Waypoint Distance, Objective Checklist)
# -----------------------------------------------------------------------------

func _setup_stage08_dedicated_hud() -> void:
	var hud_node := get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return

	# Hide generic duplicate TacticalHUD bars so only the designed Stage08 UI appears
	for child_name in ["TopBar", "BottomLeft", "BottomRight", "BottomBar", "StageSummaryDialog"]:
		if hud_node.has_node(child_name):
			var node := hud_node.get_node(child_name) as Control
			if node:
				node.visible = false

	# 1. Instantiate designed Stage08HUD (matching 03_gameplay_hud.png)
	stage08_hud = STAGE08_HUD_SCENE.instantiate() as Stage08HUD
	stage08_hud.name = "Stage08HUD"
	hud_node.add_child(stage08_hud)
	stage08_hud.set_target_player(player)

	# 2. Instantiate designed Stage08PauseMenu (matching 04_pause_menu.png)
	stage08_pause_menu = STAGE08_PAUSE_SCENE.instantiate() as Stage08PauseMenu
	stage08_pause_menu.name = "Stage08PauseMenu"
	stage08_pause_menu.visible = false
	hud_node.add_child(stage08_pause_menu)
	if hud_node.has_node("PauseMenu"):
		var old_pause = hud_node.get_node("PauseMenu") as Control
		if old_pause:
			old_pause.visible = false
			old_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if "pause_menu" in hud_node:
		hud_node.pause_menu = stage08_pause_menu

	# 3. Instantiate designed Stage08MissionSuccess (matching 05_mission_success.png)
	stage08_mission_success = STAGE08_SUCCESS_SCENE.instantiate() as Stage08MissionSuccess
	stage08_mission_success.name = "Stage08MissionSuccess"
	stage08_mission_success.visible = false
	hud_node.add_child(stage08_mission_success)

	# 4. Instantiate designed Stage08MissionFailed (matching 06_mission_failed.png)
	stage08_mission_failed = STAGE08_FAILED_SCENE.instantiate() as Stage08MissionFailed
	stage08_mission_failed.name = "Stage08MissionFailed"
	stage08_mission_failed.visible = false
	hud_node.add_child(stage08_mission_failed)

	# Initial player health & ammo updates
	if player:
		stage08_hud.update_health(player.current_health, player.max_health)
		_on_player_ammo_changed(30, 30)

	# Initial live enemy counter update
	_update_live_enemy_counter()

	# Legacy tracker proxies preserved for automated QA assertions
	_setup_legacy_trackers(hud_node)


func _setup_legacy_trackers(hud_node: CanvasLayer) -> void:
	# 1. Compass Ribbon (Top Center)
	_compass_container = PanelContainer.new()
	_compass_container.name = "Stage08CompassBar"
	_compass_container.anchor_left = 0.5
	_compass_container.anchor_right = 0.5
	_compass_container.offset_left = -180.0
	_compass_container.offset_right = 180.0
	_compass_container.offset_top = 70.0
	_compass_container.offset_bottom = 98.0
	_compass_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass_container.modulate.a = 0.0 # Kept active but visually deferring to Stage08HUD tape

	var sb_comp := StyleBoxFlat.new()
	sb_comp.bg_color = Color(0.04, 0.07, 0.11, 0.88)
	sb_comp.border_color = Color(0.25, 0.55, 0.80, 0.85)
	sb_comp.set_border_width_all(1)
	sb_comp.border_width_bottom = 2
	sb_comp.set_corner_radius_all(3)
	_compass_container.add_theme_stylebox_override("panel", sb_comp)

	var comp_hbox := HBoxContainer.new()
	comp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	comp_hbox.add_theme_constant_override("separation", 12)
	_compass_container.add_child(comp_hbox)

	_compass_heading_label = Label.new()
	_compass_heading_label.name = "CompassHeading"
	_compass_heading_label.text = "▲ 000° N"
	_compass_heading_label.add_theme_font_size_override("font_size", 13)
	_compass_heading_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	comp_hbox.add_child(_compass_heading_label)

	var vsep := VSeparator.new()
	comp_hbox.add_child(vsep)

	_compass_tape_label = Label.new()
	_compass_tape_label.name = "CompassTape"
	_compass_tape_label.text = "W  ·  NW  ·  [N]  ·  NE  ·  E"
	_compass_tape_label.add_theme_font_size_override("font_size", 11)
	_compass_tape_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98, 0.9))
	comp_hbox.add_child(_compass_tape_label)

	hud_node.add_child(_compass_container)

	# 2. Dynamic Waypoint Distance Indicator (Centered beneath Compass)
	_waypoint_container = PanelContainer.new()
	_waypoint_container.name = "Stage08WaypointBar"
	_waypoint_container.anchor_left = 0.5
	_waypoint_container.anchor_right = 0.5
	_waypoint_container.offset_left = -190.0
	_waypoint_container.offset_right = 190.0
	_waypoint_container.offset_top = 101.0
	_waypoint_container.offset_bottom = 125.0
	_waypoint_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waypoint_container.modulate.a = 0.0

	var sb_wp := StyleBoxFlat.new()
	sb_wp.bg_color = Color(0.03, 0.06, 0.09, 0.85)
	sb_wp.border_color = Color(0.2, 0.45, 0.65, 0.6)
	sb_wp.set_border_width_all(1)
	sb_wp.set_corner_radius_all(3)
	_waypoint_container.add_theme_stylebox_override("panel", sb_wp)

	var wp_hbox := HBoxContainer.new()
	wp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wp_hbox.add_theme_constant_override("separation", 8)
	_waypoint_container.add_child(wp_hbox)

	var wp_icon := Label.new()
	wp_icon.text = "◆"
	wp_icon.add_theme_font_size_override("font_size", 11)
	wp_icon.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	wp_hbox.add_child(wp_icon)

	_waypoint_desc_label = Label.new()
	_waypoint_desc_label.name = "WaypointDesc"
	_waypoint_desc_label.text = "WAYPOINT: SUMMIT APPROACH SENTRIES"
	_waypoint_desc_label.add_theme_font_size_override("font_size", 10)
	_waypoint_desc_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
	wp_hbox.add_child(_waypoint_desc_label)

	var dot := Label.new()
	dot.text = "·"
	dot.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	wp_hbox.add_child(dot)

	_waypoint_dist_label = Label.new()
	_waypoint_dist_label.name = "WaypointDist"
	_waypoint_dist_label.text = "0 m"
	_waypoint_dist_label.add_theme_font_size_override("font_size", 11)
	_waypoint_dist_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	wp_hbox.add_child(_waypoint_dist_label)

	hud_node.add_child(_waypoint_container)

	# 3. Objective Progress Checklist (Top Right below TopBar)
	_checklist_panel = PanelContainer.new()
	_checklist_panel.name = "Stage08ChecklistPanel"
	_checklist_panel.anchor_left = 1.0
	_checklist_panel.anchor_right = 1.0
	_checklist_panel.offset_left = -310.0
	_checklist_panel.offset_right = -24.0
	_checklist_panel.offset_top = 74.0
	_checklist_panel.offset_bottom = 205.0
	_checklist_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checklist_panel.modulate.a = 0.0

	var sb_check := StyleBoxFlat.new()
	sb_check.bg_color = Color(0.04, 0.07, 0.11, 0.9)
	sb_check.border_color = Color(0.2, 0.55, 0.80, 0.8)
	sb_check.set_border_width_all(1)
	sb_check.border_width_left = 3
	sb_check.set_corner_radius_all(3)
	_checklist_panel.add_theme_stylebox_override("panel", sb_check)

	var check_margin := MarginContainer.new()
	check_margin.add_theme_constant_override("margin_left", 12)
	check_margin.add_theme_constant_override("margin_right", 12)
	check_margin.add_theme_constant_override("margin_top", 8)
	check_margin.add_theme_constant_override("margin_bottom", 8)
	_checklist_panel.add_child(check_margin)

	var check_vbox := VBoxContainer.new()
	check_vbox.add_theme_constant_override("separation", 4)
	check_margin.add_child(check_vbox)

	var check_header := Label.new()
	check_header.text = "// MISSION OBJECTIVES //"
	check_header.add_theme_font_size_override("font_size", 11)
	check_header.add_theme_color_override("font_color", Color(0.35, 0.8, 1.0))
	check_vbox.add_child(check_header)

	var hsep := HSeparator.new()
	check_vbox.add_child(hsep)

	_checklist_items.clear()
	var obj_titles := [
		"SECURE APPROACH SENTRIES",
		"SEIZE SUMMIT RADAR STATION",
		"INTERCEPT ANOMALOUS TELEMETRY",
		"DECODE SUB-GLACIAL VAULT ORIGIN"
	]
	for i in range(4):
		var lbl := Label.new()
		lbl.name = "ObjectiveItem_%d" % i
		lbl.text = " [  ] %d. %s" % [i + 1, obj_titles[i]]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.7))
		check_vbox.add_child(lbl)
		_checklist_items.append(lbl)

	hud_node.add_child(_checklist_panel)


func _update_stage08_dedicated_hud(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	_update_stage08_compass()
	_update_stage08_waypoint()
	_update_stage08_checklist()

	if stage08_hud:
		stage08_hud.update_objective(_current_directive)
		if player.global_position.z <= 0.0:
			stage08_hud.set_task_completed("ridge", true)
		if targets_eliminated >= 4:
			stage08_hud.set_task_completed("snipers", true)
		if is_radar_shutdown:
			stage08_hud.set_task_completed("facility", true)
		if is_signal_investigated:
			stage08_hud.set_task_completed("extract", true)



func _update_stage08_compass() -> void:
	if not _compass_heading_label or not _compass_tape_label or not player:
		return
	var cam: Camera3D = null
	if player.has_node("Camera3D"):
		cam = player.get_node("Camera3D") as Camera3D
	elif player.has_node("Head/Camera3D"):
		cam = player.get_node("Head/Camera3D") as Camera3D

	if not cam:
		return

	var forward := -cam.global_transform.basis.z
	var angle_rad := atan2(forward.x, -forward.z)
	var deg := fposmod(rad_to_deg(angle_rad), 360.0)
	_last_calculated_heading = deg

	var cardinal := _get_cardinal_tag(deg)
	_compass_heading_label.text = "▲ %03d° %s" % [int(deg), cardinal]
	_compass_tape_label.text = _build_compass_tape_string(deg)


func _get_cardinal_tag(deg: float) -> String:
	if deg >= 337.5 or deg < 22.5:
		return "N"
	elif deg < 67.5:
		return "NE"
	elif deg < 112.5:
		return "E"
	elif deg < 157.5:
		return "SE"
	elif deg < 202.5:
		return "S"
	elif deg < 247.5:
		return "SW"
	elif deg < 292.5:
		return "W"
	else:
		return "NW"


func _build_compass_tape_string(deg: float) -> String:
	var offsets := [-60.0, -30.0, 0.0, 30.0, 60.0]
	var parts: Array[String] = []
	for offset in offsets:
		var tick_deg := fposmod(roundf((deg + offset) / 15.0) * 15.0, 360.0)
		var label_str := ""
		if is_equal_approx(tick_deg, 0.0) or is_equal_approx(tick_deg, 360.0):
			label_str = "N"
		elif is_equal_approx(tick_deg, 45.0):
			label_str = "NE"
		elif is_equal_approx(tick_deg, 90.0):
			label_str = "E"
		elif is_equal_approx(tick_deg, 135.0):
			label_str = "SE"
		elif is_equal_approx(tick_deg, 180.0):
			label_str = "S"
		elif is_equal_approx(tick_deg, 225.0):
			label_str = "SW"
		elif is_equal_approx(tick_deg, 270.0):
			label_str = "W"
		elif is_equal_approx(tick_deg, 315.0):
			label_str = "NW"
		else:
			label_str = "%03d" % int(tick_deg)

		if is_equal_approx(offset, 0.0):
			parts.append("[%s]" % label_str)
		else:
			parts.append(label_str)
	return "  ·  ".join(parts)


func _update_stage08_waypoint() -> void:
	if not _waypoint_desc_label or not _waypoint_dist_label or not player or not is_instance_valid(player):
		return

	var active_name := ""
	var active_pos := Vector3.ZERO

	if not is_radar_shutdown:
		if targets_eliminated < total_targets:
			active_name = "APPROACH SENTRIES"
			var nearest_pos := RADAR_CONSOLE_POSITION
			var min_dist := 9999.0
			var enemies := get_node_or_null("Enemies") as Node3D
			if enemies:
				for e in enemies.get_children():
					if e is CharacterBody3D and is_instance_valid(e):
						if not ("is_dead" in e and e.is_dead):
							var d := player.global_position.distance_to(e.global_position)
							if d < min_dist:
								min_dist = d
								nearest_pos = e.global_position
			active_pos = nearest_pos
		else:
			active_name = "SUMMIT RADAR TERMINAL"
			active_pos = RADAR_CONSOLE_POSITION
	elif not is_signal_investigated:
		active_name = "ANOMALOUS SIGNAL ORIGIN"
		active_pos = SIGNAL_SOURCE_POSITION
	else:
		active_name = "OBJECTIVE SECURED // EXTRACTION"
		active_pos = player.global_position

	var dist_m := int(player.global_position.distance_to(active_pos))
	_last_waypoint_dist = dist_m

	_waypoint_desc_label.text = "WAYPOINT: %s" % active_name
	if is_signal_investigated:
		_waypoint_dist_label.text = "SECURED"
		_waypoint_dist_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		_waypoint_dist_label.text = "%d m" % dist_m
		_waypoint_dist_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))


func _update_stage08_checklist() -> void:
	if _checklist_items.size() < 4:
		return

	# Objective 1: SECURE APPROACH SENTRIES
	if targets_eliminated >= total_targets:
		_checklist_items[0].text = " [✓] 1. SECURE SENTRIES (12/12)"
		_checklist_items[0].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		_checklist_items[0].text = " [▶] 1. SECURE SENTRIES (%d/12)" % targets_eliminated
		_checklist_items[0].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	# Objective 2: SEIZE SUMMIT RADAR STATION
	if is_radar_shutdown:
		_checklist_items[1].text = " [✓] 2. SEIZE SUMMIT RADAR"
		_checklist_items[1].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif targets_eliminated >= total_targets:
		_checklist_items[1].text = " [▶] 2. SEIZE SUMMIT RADAR"
		_checklist_items[1].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	else:
		_checklist_items[1].text = " [  ] 2. SEIZE SUMMIT RADAR"
		_checklist_items[1].add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.7))

	# Objective 3: INTERCEPT ANOMALOUS TELEMETRY
	if is_secret_signal_active:
		_checklist_items[2].text = " [✓] 3. INTERCEPT TELEMETRY"
		_checklist_items[2].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif is_radar_shutdown:
		_checklist_items[2].text = " [▶] 3. INTERCEPT TELEMETRY"
		_checklist_items[2].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	else:
		_checklist_items[2].text = " [  ] 3. INTERCEPT TELEMETRY"
		_checklist_items[2].add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.7))

	# Objective 4: DECODE SUB-GLACIAL VAULT ORIGIN
	if is_signal_investigated:
		_checklist_items[3].text = " [✓] 4. DECODE VAULT ORIGIN"
		_checklist_items[3].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif is_secret_signal_active:
		_checklist_items[3].text = " [▶] 4. DECODE VAULT ORIGIN"
		_checklist_items[3].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	else:
		_checklist_items[3].text = " [  ] 4. DECODE VAULT ORIGIN"
		_checklist_items[3].add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.7))


# Public Getters for HUD Verification
func get_compass_heading_degrees() -> float:
	return _last_calculated_heading

func get_waypoint_distance_meters() -> int:
	return _last_waypoint_dist

func get_active_waypoint_name() -> String:
	if _waypoint_desc_label:
		return _waypoint_desc_label.text
	return ""

func get_objective_checklist_texts() -> Array[String]:
	var result: Array[String] = []
	for item in _checklist_items:
		if item:
			result.append(item.text)
	return result


# -----------------------------------------------------------------------------
# Live Mission Enemy Counting & HUD Synchronization
# -----------------------------------------------------------------------------
func get_live_enemy_count() -> int:
	var count := 0
	var enemies_node := get_node_or_null("Enemies") as Node3D
	if enemies_node:
		for e in enemies_node.get_children():
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				var is_dead: bool = e.get("is_dead") == true
				var hp: int = int(e.get("current_health")) if "current_health" in e else 1
				if not is_dead and hp > 0:
					count += 1
	return count

func _update_live_enemy_counter() -> void:
	var remaining := get_live_enemy_count()
	if stage08_hud and stage08_hud.has_method("update_enemies_remaining"):
		stage08_hud.update_enemies_remaining(remaining)

func _on_enemy_destroyed(enemy: Node = null) -> void:
	super._on_enemy_destroyed(enemy)
	_update_live_enemy_counter()


