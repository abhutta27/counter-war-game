extends "res://scripts/LevelBase3D.gd"
## Stage08IronPeak.gd
## Stage 08 — OPERATION IRON PEAK
## 3-Phase Tactical Finale:
##   Phase 1: Eliminate 18-soldier cantonment garrison.
##   Phase 2: Equip Anti-Tank RPG and destroy 2 Enemy Tanks (2 hits each).
##   Phase 3: Board the Enemy Helicopter at the north helipad for extraction cinematic.

const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/Enemy3D.tscn")
const ASSAULT_RIFLE_GLB: PackedScene = preload("res://assets/weapons/Assault Rifle-MdbcTe6hH3.glb")
const Stage08Vehicles = preload("res://scripts/stages/Stage08Vehicles.gd")

const PROP_BARRIER_GLB: PackedScene = preload("res://assets/stage08_military/barrier.glb")
const PROP_CRATE_GLB: PackedScene = preload("res://assets/stage08_military/cargo_crate.glb")
const PROP_CARGO_TRUCK_GLB: PackedScene = preload("res://assets/stage08_military/cargo_truck.glb")
const PROP_HANGAR_GLB: PackedScene = preload("res://assets/stage08_military/hangar.glb")
const PROP_MILITARY_TRUCK_GLB: PackedScene = preload("res://assets/stage08_military/military_truck.glb")

const PLAYER_SPAWN_POS := Vector3(0.0, 0.2, 92.0)
const HELIPAD_POS := Vector3(0.0, 0.01, -30.0)
const TANK_SPLASH_RADIUS := 5.5
const EXTRACTION_RADIUS := 5.0
const RPG_COOLDOWN := 0.85
const ROCKET_SPEED := 55.0
const EXTRACTION_CINEMATIC_DURATION := 6.5

enum MissionPhase { INFANTRY, TANK_ASSAULT, EXTRACTION, CINEMATIC }

# 18 Tactical Garrison Soldiers across 4 defensive zones
const ENEMY_SPAWNS: Array[Dictionary] = [
	# Zone 1: Gate & Outer Perimeter (4 soldiers)
	{"name": "Enemy3D_1", "pos": Vector3(-6.5, 0.01, 64.0), "yaw": 0.0},
	{"name": "Enemy3D_2", "pos": Vector3(6.5, 0.01, 63.0), "yaw": 0.0},
	{"name": "Enemy3D_3", "pos": Vector3(-3.5, 0.01, 56.0), "yaw": 8.0},
	{"name": "Enemy3D_4", "pos": Vector3(5.0, 0.01, 57.0), "yaw": -8.0},
	# Zone 2: Watchtowers & Flanks (4 soldiers)
	{"name": "Enemy3D_5", "pos": Vector3(-26.0, 0.01, 44.0), "yaw": 15.0},
	{"name": "Enemy3D_6", "pos": Vector3(26.0, 0.01, 42.0), "yaw": -15.0},
	{"name": "Enemy3D_7", "pos": Vector3(-26.0, 0.01, 22.0), "yaw": 20.0},
	{"name": "Enemy3D_8", "pos": Vector3(26.0, 0.01, 20.0), "yaw": -20.0},
	# Zone 3: Central Plaza & Barracks/Armory (6 soldiers)
	{"name": "Enemy3D_9", "pos": Vector3(-16.0, 0.01, 14.0), "yaw": 18.0},
	{"name": "Enemy3D_10", "pos": Vector3(-19.0, 0.01, -4.0), "yaw": 25.0},
	{"name": "Enemy3D_11", "pos": Vector3(-3.0, 0.01, 10.0), "yaw": 0.0},
	{"name": "Enemy3D_12", "pos": Vector3(4.0, 0.01, 2.0), "yaw": 0.0},
	{"name": "Enemy3D_13", "pos": Vector3(16.0, 0.01, 12.0), "yaw": -18.0},
	{"name": "Enemy3D_14", "pos": Vector3(18.0, 0.01, -8.0), "yaw": -25.0},
	# Zone 4: Tank & HQ Defense Guard (4 soldiers)
	{"name": "Enemy3D_15", "pos": Vector3(-15.0, 0.01, -29.0), "yaw": 10.0},
	{"name": "Enemy3D_16", "pos": Vector3(15.0, 0.01, -29.0), "yaw": -10.0},
	{"name": "Enemy3D_17", "pos": Vector3(-9.0, 0.01, -45.0), "yaw": 12.0},
	{"name": "Enemy3D_18", "pos": Vector3(9.0, 0.01, -45.0), "yaw": -12.0},
]

const TANK_SPECS: Array[Dictionary] = [
	{"name": "EnemyTank_West", "pos": Vector3(-12.0, 0.01, -14.0), "yaw": 165.0},
	{"name": "EnemyTank_East", "pos": Vector3(12.0, 0.01, -14.0), "yaw": -165.0},
]

var current_phase: MissionPhase = MissionPhase.INFANTRY
var tanks: Array[Dictionary] = []
var tanks_destroyed: int = 0
var _active_rockets: Array[Dictionary] = []
var _rpg_node: Node3D = null
var _rpg_muzzle: Marker3D = null
var _rpg_cooldown_timer: float = 0.0
var _rpg_shots_fired: int = 0

var _helicopter_root: Node3D = null
var _main_rotor: Node3D = null
var _tail_rotor: Node3D = null
var _seated_operative: Node3D = null
var _operative_right_arm: Node3D = null
var _control_panel: Node3D = null
var _ignition_switch: MeshInstance3D = null
var _ignition_switched: bool = false
var _extraction_beacon: Node3D = null
var _extraction_camera: Camera3D = null
var _cinematic_elapsed: float = 0.0
var _heli_start_pos: Vector3 = HELIPAD_POS
var _heli_rotor_speed: float = 0.0
var _beacon_pulse_time: float = 0.0
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0
var _camera_base_pos: Vector3 = Vector3(0.0, 1.55, 0.0)

var _sfx_player: AudioStreamPlayer = null
var _rotor_player: AudioStreamPlayer3D = null
var _rocket_sfx: AudioStreamWAV = null
var _explosion_sfx: AudioStreamWAV = null
var _rotor_sfx: AudioStreamWAV = null

var _materials: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}
var _cyl_shape_cache: Dictionary = {}


func _ready() -> void:
	stage_id = 8
	stage_name = "OPERATION IRON PEAK"

	_create_materials()
	_init_synthesized_audio()
	_build_cantonment()
	_build_enemy_tanks()
	_build_helipad_and_helicopter()
	_configure_player_spawn_and_weapon()
	_spawn_enemies()

	# Register all 18 Enemy3D targets and connect enemy_died in LevelBase3D.
	super._ready()
	_set_objective_text("ELIMINATE THE CANTONMENT GARRISON (18 HOSTILES)", false)


func _process(delta: float) -> void:
	super._process(delta)

	if _rpg_cooldown_timer > 0.0:
		_rpg_cooldown_timer = maxf(0.0, _rpg_cooldown_timer - delta)

	_update_screen_shake(delta)

	if current_phase == MissionPhase.EXTRACTION:
		_beacon_pulse_time += delta
		_update_extraction_beacon()
		_check_helicopter_boarding()
	elif current_phase == MissionPhase.CINEMATIC:
		_update_extraction_cinematic(delta)


func _physics_process(delta: float) -> void:
	_update_active_rockets(delta)


func _input(event: InputEvent) -> void:
	if current_phase != MissionPhase.TANK_ASSAULT:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or get_tree().paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fire_rpg()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
# PHASE PROGRESSION OVERRIDES
# ------------------------------------------------------------------------------

func _complete_stage_if_all_targets_eliminated() -> void:
	if current_phase != MissionPhase.INFANTRY:
		return
	if not is_stage_finished and total_targets > 0 and targets_eliminated >= total_targets:
		_start_phase_2_tank_assault()


func _start_phase_2_tank_assault() -> void:
	if current_phase != MissionPhase.INFANTRY:
		return
	current_phase = MissionPhase.TANK_ASSAULT
	tanks_destroyed = 0
	_equip_rpg_launcher()
	_set_objective_text("OBJECTIVE UPDATED: DESTROY BOTH ENEMY TANKS (0 / 2)", true)


func _start_phase_3_extraction() -> void:
	if current_phase != MissionPhase.TANK_ASSAULT:
		return
	current_phase = MissionPhase.EXTRACTION
	if _extraction_beacon:
		_extraction_beacon.visible = true
	_set_objective_text("BOARD THE ENEMY HELICOPTER TO EXTRACT", true)


func _set_objective_text(text: String, show_banner: bool) -> void:
	if not hud:
		return
	if "compact_objective_label" in hud and hud.compact_objective_label:
		hud.compact_objective_label.text = "OBJ: " + text
	if "objective_banner_text" in hud and hud.objective_banner_text:
		hud.objective_banner_text.text = text
	if show_banner and "objective_banner" in hud and hud.objective_banner:
		hud.objective_banner.visible = true
		hud.objective_banner.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(3.5)
		tw.tween_property(hud.objective_banner, "modulate:a", 0.0, 0.6)
		tw.tween_callback(func():
			if is_instance_valid(hud.objective_banner):
				hud.objective_banner.visible = false
		)


# ------------------------------------------------------------------------------
# PLAYER SPAWN, RIFLE & PHASE 2 RPG
# ------------------------------------------------------------------------------

func _configure_player_spawn_and_weapon() -> void:
	var spawn_marker := get_node_or_null("PlayerSpawn") as Node3D
	var spawn_pos := spawn_marker.global_position if spawn_marker else PLAYER_SPAWN_POS
	if player and is_instance_valid(player):
		player.global_position = spawn_pos
		player.rotation_degrees = Vector3.ZERO
		player.velocity = Vector3.ZERO
		player.is_active = true
		if "camera" in player and player.camera:
			_camera_base_pos = player.camera.position
			player.camera.make_current()
		_attach_stage08_assault_rifle()


func _attach_stage08_assault_rifle() -> void:
	if not player or not is_instance_valid(player):
		return
	var gun_model := player.get_node_or_null("Camera3D/WeaponRig/GunModel")
	if not gun_model:
		return

	var old_mesh := gun_model.get_node_or_null("Assault Rifle")
	if old_mesh:
		old_mesh.queue_free()
	var prev_custom := gun_model.get_node_or_null("Stage08AssaultRifle")
	if prev_custom:
		prev_custom.queue_free()

	if "data" in gun_model and gun_model.data:
		gun_model.data = gun_model.data.duplicate()
		gun_model.data.weapon_model = ASSAULT_RIFLE_GLB

	var rifle_inst := ASSAULT_RIFLE_GLB.instantiate() as Node3D
	if rifle_inst:
		rifle_inst.name = "Stage08AssaultRifle"
		rifle_inst.scale = Vector3(0.14, 0.14, 0.14)
		gun_model.add_child(rifle_inst)


func _equip_rpg_launcher() -> void:
	if not player or not is_instance_valid(player) or not player.camera:
		return

	if "can_shoot" in player:
		player.can_shoot = false
	player.is_firing_held = false
	var weapon_rig := player.get_node_or_null("Camera3D/WeaponRig") as Node3D
	if weapon_rig:
		weapon_rig.visible = false
		weapon_rig.set_process(false)

	if _rpg_node and is_instance_valid(_rpg_node):
		_rpg_node.visible = true
	else:
		_build_rpg_viewmodel(player.camera)

	if hud:
		if hud.has_method("update_ammo"):
			hud.update_ammo(1, 1, "RPG-7 LAUNCHER", false, 99)
		if "weapon_name_label" in hud and hud.weapon_name_label:
			hud.weapon_name_label.text = "RPG-7 LAUNCHER"


func _build_rpg_viewmodel(cam: Camera3D) -> void:
	_rpg_node = Node3D.new()
	_rpg_node.name = "Stage08RPG"
	_rpg_node.position = Vector3(0.26, -0.22, -0.35)
	cam.add_child(_rpg_node)

	# Main launch tube along -Z
	_cylinder(_rpg_node, "LaunchTube", Vector3(0.0, 0.0, -0.25), 0.045, 0.95, "olive_metal", Vector3(90.0, 0.0, 0.0), false)
	# Flared rear venturi & front collar
	_cylinder(_rpg_node, "RearVenturi", Vector3(0.0, 0.0, 0.25), 0.06, 0.14, "steel", Vector3(90.0, 0.0, 0.0), false)
	_cylinder(_rpg_node, "FrontCollar", Vector3(0.0, 0.0, -0.72), 0.055, 0.08, "steel", Vector3(90.0, 0.0, 0.0), false)
	# Wooden heatshield & pistol grip
	_box(_rpg_node, "HeatShield", Vector3(0.0, -0.01, -0.15), Vector3(0.095, 0.05, 0.34), "wood_grip", false)
	_box(_rpg_node, "PistolGrip", Vector3(0.0, -0.09, -0.22), Vector3(0.035, 0.12, 0.05), "wood_grip", false)
	# Iron/Optical sight bracket on left side
	_box(_rpg_node, "SightMount", Vector3(-0.055, 0.05, -0.32), Vector3(0.025, 0.07, 0.12), "steel", false)
	# Loaded PG-7 Warhead protruding from front
	_cylinder(_rpg_node, "WarheadBody", Vector3(0.0, 0.0, -0.86), 0.052, 0.22, "olive_concrete", Vector3(90.0, 0.0, 0.0), false)
	_cylinder(_rpg_node, "WarheadCone", Vector3(0.0, 0.0, -1.01), 0.025, 0.12, "steel", Vector3(90.0, 0.0, 0.0), false)

	_rpg_muzzle = Marker3D.new()
	_rpg_muzzle.name = "RPGMuzzle"
	_rpg_muzzle.position = Vector3(0.0, 0.0, -1.08)
	_rpg_node.add_child(_rpg_muzzle)


func _fire_rpg() -> void:
	if _rpg_cooldown_timer > 0.0 or not player or not player.camera:
		return
	_rpg_cooldown_timer = RPG_COOLDOWN
	_rpg_shots_fired += 1

	var cam := player.camera
	var aim_dir := (-cam.global_transform.basis.z).normalized()
	var spawn_pos := _rpg_muzzle.global_position if (_rpg_muzzle and is_instance_valid(_rpg_muzzle)) else (cam.global_position + aim_dir * 0.9)

	# Recoil kick on RPG viewmodel
	if _rpg_node and is_instance_valid(_rpg_node):
		_rpg_node.position = Vector3(0.26, -0.20, -0.24)
		var tw := create_tween()
		tw.tween_property(_rpg_node, "position", Vector3(0.26, -0.22, -0.35), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _sfx_player and _rocket_sfx:
		_sfx_player.volume_db = 6.0
		_sfx_player.stream = _rocket_sfx
		_sfx_player.play()

	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_weapon_fired()

	_spawn_rocket_projectile(spawn_pos, aim_dir)


func _spawn_rocket_projectile(origin: Vector3, direction: Vector3) -> void:
	var rocket := Node3D.new()
	rocket.name = "RPGRocket_%d" % _rpg_shots_fired
	rocket.position = origin
	add_child(rocket)
	rocket.look_at(origin + direction, Vector3.UP)

	_cylinder(rocket, "Body", Vector3(0.0, 0.0, 0.0), 0.06, 0.45, "olive_metal", Vector3(90.0, 0.0, 0.0), false)
	_cylinder(rocket, "Tip", Vector3(0.0, 0.0, -0.28), 0.03, 0.14, "steel", Vector3(90.0, 0.0, 0.0), false)
	_box(rocket, "ThrusterGlow", Vector3(0.0, 0.0, 0.26), Vector3(0.16, 0.16, 0.24), "explosion_fire", false)

	var rocket_light := OmniLight3D.new()
	rocket_light.name = "RocketGlowLight"
	rocket_light.position = Vector3(0.0, 0.0, 0.26)
	rocket_light.light_color = Color(1.0, 0.62, 0.18)
	rocket_light.light_energy = 5.0
	rocket_light.omni_range = 9.0
	rocket.add_child(rocket_light)

	var trail := CPUParticles3D.new()
	trail.name = "SmokeTrail"
	trail.position = Vector3(0.0, 0.0, 0.28)
	trail.amount = 36
	trail.lifetime = 0.55
	trail.emitting = true
	trail.local_coords = false
	trail.direction = Vector3(0.0, 0.2, 1.0)
	trail.spread = 12.0
	trail.initial_velocity_min = 1.5
	trail.initial_velocity_max = 3.5
	trail.gravity = Vector3(0.0, 1.2, 0.0)
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.65
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.18
	trail_mesh.height = 0.36
	trail_mesh.material = _materials.get("smoke_mat")
	trail.mesh = trail_mesh
	rocket.add_child(trail)

	_active_rockets.append({
		"node": rocket,
		"dir": direction.normalized(),
		"dist": 0.0,
	})


func _update_active_rockets(delta: float) -> void:
	if _active_rockets.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var remaining: Array[Dictionary] = []

	for r in _active_rockets:
		var node: Node3D = r["node"]
		if not is_instance_valid(node):
			continue
		var dir: Vector3 = r["dir"]
		var step := ROCKET_SPEED * delta
		var from_pos := node.global_position
		var to_pos := from_pos + dir * step

		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos, 3)
		if player and is_instance_valid(player):
			query.exclude = [player.get_rid()]
		query.collide_with_bodies = true
		query.collide_with_areas = true

		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var impact_pos: Vector3 = hit.get("position", to_pos)
			var collider: Node = hit.get("collider", null)
			_on_rocket_impact(impact_pos, collider)
			node.queue_free()
			continue
		if to_pos.y <= 0.01:
			_on_rocket_impact(Vector3(to_pos.x, 0.01, to_pos.z), null)
			node.queue_free()
			continue

		node.global_position = to_pos
		r["dist"] = float(r["dist"]) + step
		if float(r["dist"]) > 180.0:
			node.queue_free()
			continue
		remaining.append(r)

	_active_rockets = remaining


func _on_rocket_impact(impact_pos: Vector3, collider: Node) -> void:
	var hit_tank := _find_tank_from_collider(collider)
	if hit_tank.is_empty():
		hit_tank = _find_tank_within_splash(impact_pos)
	var is_tank_kill := false
	if not hit_tank.is_empty() and not bool(hit_tank["destroyed"]):
		hit_tank["hp"] = int(hit_tank["hp"]) - 1
		if hud and "combat_feedback" in hud and hud.combat_feedback:
			hud.combat_feedback.on_shot_hit(true)

		if int(hit_tank["hp"]) <= 0:
			is_tank_kill = true
			_destroy_tank(hit_tank)
		else:
			var smoke := hit_tank.get("smoke") as CPUParticles3D
			if smoke:
				smoke.emitting = true
			_set_objective_text("OBJECTIVE UPDATED: DESTROY BOTH ENEMY TANKS (%d / 2)" % tanks_destroyed, false)

	_spawn_tank_explosion(impact_pos, is_tank_kill)
	_trigger_screen_shake(0.38 if is_tank_kill else 0.22, 0.22 if is_tank_kill else 0.12)

	if _sfx_player and _explosion_sfx:
		_sfx_player.volume_db = 10.0
		_sfx_player.stream = _explosion_sfx
		_sfx_player.play()

	if tanks_destroyed >= tanks.size() and current_phase == MissionPhase.TANK_ASSAULT:
		call_deferred("_start_phase_3_extraction")


func _find_tank_from_collider(collider: Node) -> Dictionary:
	if not collider:
		return {}
	for t in tanks:
		var root_body: Node = t["root"]
		if collider == root_body or root_body.is_ancestor_of(collider):
			return t
	return {}


func _find_tank_within_splash(impact_pos: Vector3) -> Dictionary:
	var closest: Dictionary = {}
	var best_dist := TANK_SPLASH_RADIUS
	for t in tanks:
		if bool(t["destroyed"]):
			continue
		var root_body := t["root"] as Node3D
		if not root_body:
			continue
		var d := impact_pos.distance_to(root_body.global_position)
		if d <= best_dist:
			best_dist = d
			closest = t
	return closest


func _destroy_tank(tank: Dictionary) -> void:
	if bool(tank["destroyed"]):
		return
	tank["destroyed"] = true
	tanks_destroyed += 1
	current_mission_score += 250

	var root_body: Node3D = tank["root"]
	for child in root_body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = _materials.get("charred")
		elif child is Node3D and child.name == "Turret":
			child.rotation_degrees += Vector3(6.0, 22.0, -8.0)
			child.position.y -= 0.12
			for t_child in child.get_children():
				if t_child is MeshInstance3D:
					(t_child as MeshInstance3D).material_override = _materials.get("charred")

	var smoke := tank.get("smoke") as CPUParticles3D
	if smoke:
		smoke.emitting = true
		smoke.amount = 48

	if hud and "combat_feedback" in hud and hud.combat_feedback:
		hud.combat_feedback.on_enemy_eliminated("ENEMY TANK", 250)

	_set_objective_text("OBJECTIVE UPDATED: DESTROY BOTH ENEMY TANKS (%d / 2)" % tanks_destroyed, false)


func _spawn_tank_explosion(pos: Vector3, large: bool) -> void:
	var exp_root := Node3D.new()
	exp_root.name = "ExplosionFX"
	exp_root.position = pos
	add_child(exp_root)

	# Flash light
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.62, 0.2)
	flash.light_energy = 10.0 if large else 6.0
	flash.omni_range = 24.0 if large else 14.0
	exp_root.add_child(flash)

	# Fireball sphere
	var fireball := MeshInstance3D.new()
	var fb_mesh := SphereMesh.new()
	fb_mesh.radius = 1.6 if large else 1.0
	fb_mesh.height = fb_mesh.radius * 2.0
	fb_mesh.material = _materials.get("explosion_fire")
	fireball.mesh = fb_mesh
	fireball.scale = Vector3.ONE * 0.3
	exp_root.add_child(fireball)

	# Fire particles
	var fire_fx := CPUParticles3D.new()
	fire_fx.amount = 40 if large else 22
	fire_fx.lifetime = 0.75
	fire_fx.one_shot = true
	fire_fx.explosiveness = 0.92
	fire_fx.emitting = true
	fire_fx.direction = Vector3.UP
	fire_fx.spread = 85.0
	fire_fx.initial_velocity_min = 4.0
	fire_fx.initial_velocity_max = 11.0 if large else 7.0
	fire_fx.gravity = Vector3(0.0, -3.5, 0.0)
	var f_mesh := SphereMesh.new()
	f_mesh.radius = 0.35
	f_mesh.height = 0.7
	f_mesh.material = _materials.get("explosion_fire")
	fire_fx.mesh = f_mesh
	exp_root.add_child(fire_fx)

	# Smoke plume
	var smoke_fx := CPUParticles3D.new()
	smoke_fx.amount = 36 if large else 18
	smoke_fx.lifetime = 1.6
	smoke_fx.one_shot = true
	smoke_fx.explosiveness = 0.8
	smoke_fx.emitting = true
	smoke_fx.direction = Vector3.UP
	smoke_fx.spread = 65.0
	smoke_fx.initial_velocity_min = 2.5
	smoke_fx.initial_velocity_max = 7.0
	smoke_fx.gravity = Vector3(0.0, 2.2, 0.0)
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.55
	s_mesh.height = 1.1
	s_mesh.material = _materials.get("smoke_mat")
	smoke_fx.mesh = s_mesh
	exp_root.add_child(smoke_fx)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fireball, "scale", Vector3.ONE * (2.6 if large else 1.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "light_energy", 0.0, 0.55)
	tw.chain().tween_property(fireball, "scale", Vector3.ONE * 0.05, 0.35)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_callback(exp_root.queue_free)


func _trigger_screen_shake(duration: float, strength: float) -> void:
	_shake_timer = maxf(_shake_timer, duration)
	_shake_strength = maxf(_shake_strength, strength)


func _update_screen_shake(delta: float) -> void:
	if not player or not is_instance_valid(player) or not player.camera:
		return
	if _shake_timer <= 0.0:
		if current_phase != MissionPhase.CINEMATIC:
			player.camera.position.x = 0.0
		return
	_shake_timer = maxf(0.0, _shake_timer - delta)
	var offset := Vector3(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength),
		0.0
	)
	player.camera.position = _camera_base_pos + offset
	if _shake_timer <= 0.0:
		player.camera.position = _camera_base_pos


# ------------------------------------------------------------------------------
# PHASE 3: HELICOPTER EXTRACTION CINEMATIC
# ------------------------------------------------------------------------------

func _update_extraction_beacon() -> void:
	if not _extraction_beacon:
		return
	var pulse := 0.75 + 0.25 * sin(_beacon_pulse_time * 5.0)
	_extraction_beacon.scale = Vector3(pulse, 1.0, pulse)


func _check_helicopter_boarding() -> void:
	if not player or not is_instance_valid(player) or player.current_health <= 0:
		return
	var p_xz := Vector2(player.global_position.x, player.global_position.z)
	var h_xz := Vector2(HELIPAD_POS.x, HELIPAD_POS.z)
	if p_xz.distance_to(h_xz) <= EXTRACTION_RADIUS:
		_start_extraction_cinematic()


func _start_extraction_cinematic() -> void:
	if current_phase == MissionPhase.CINEMATIC:
		return
	current_phase = MissionPhase.CINEMATIC
	_cinematic_elapsed = 0.0
	_heli_rotor_speed = 0.0
	_ignition_switched = false
	_heli_start_pos = _helicopter_root.global_position if _helicopter_root else HELIPAD_POS

	if _extraction_beacon:
		_extraction_beacon.visible = false

	if player and is_instance_valid(player):
		player.is_active = false
		player.is_firing_held = false
		player.velocity = Vector3.ZERO
		player.visible = false
		var p_hud := player.get_node_or_null("PlayerHUD") as CanvasLayer
		if p_hud:
			p_hud.visible = false
		var weapon_rig := player.get_node_or_null("Camera3D/WeaponRig") as Node3D
		if weapon_rig:
			weapon_rig.visible = false
		if _rpg_node and is_instance_valid(_rpg_node):
			_rpg_node.visible = false

	if _seated_operative:
		_seated_operative.visible = true
	if _operative_right_arm:
		_operative_right_arm.rotation_degrees = Vector3(-18.0, 0.0, 0.0)

	if _extraction_camera and _helicopter_root:
		_extraction_camera.global_position = _helicopter_root.to_global(Vector3(-0.62, 1.98, 1.18))
		_extraction_camera.look_at(_helicopter_root.to_global(Vector3(0.14, 1.56, 2.38)), Vector3.UP)
		_extraction_camera.make_current()

	_set_objective_text("EXTRACTION IN PROGRESS — STARTING HELICOPTER", false)


func _update_extraction_cinematic(delta: float) -> void:
	_cinematic_elapsed += delta
	var e := _cinematic_elapsed

	# Step A (0.0s - 1.2s): Seated & Reaching inside cockpit
	if e < 1.2:
		var reach_a := clampf(e / 1.2, 0.0, 1.0)
		if _operative_right_arm:
			_operative_right_arm.rotation_degrees = Vector3(lerpf(-18.0, -34.0, reach_a), lerpf(0.0, 6.0, reach_a), 0.0)
		if _extraction_camera and _helicopter_root:
			_extraction_camera.global_position = _helicopter_root.to_global(Vector3(-0.62 + 0.08 * reach_a, 1.98, 1.18 + 0.06 * reach_a))
			_extraction_camera.look_at(_helicopter_root.to_global(Vector3(0.16, 1.55, 2.38)), Vector3.UP)

	# Step B (1.2s - 2.5s): Auto-Switch Ignition & Engine Spool-Up
	elif e < 2.5:
		var step_b := clampf((e - 1.2) / 1.3, 0.0, 1.0)
		if _operative_right_arm:
			var press_t := sin(step_b * PI)
			_operative_right_arm.rotation_degrees = Vector3(lerpf(-34.0, -76.0, press_t), lerpf(6.0, 16.0, press_t), 0.0)

		if e >= 1.55 and not _ignition_switched:
			_activate_helicopter_ignition()

		if _ignition_switched:
			var spool_t := clampf((e - 1.55) / 0.95, 0.0, 1.0)
			_heli_rotor_speed = lerpf(40.0, 1450.0, spool_t * spool_t)
			if _rotor_player and _rotor_player.playing:
				_rotor_player.pitch_scale = lerpf(0.75, 1.15, spool_t)

		if _extraction_camera and _helicopter_root:
			var cam_pos := _helicopter_root.to_global(Vector3(lerpf(-0.54, -0.45, step_b), lerpf(1.98, 2.04, step_b), lerpf(1.24, 1.10, step_b)))
			var cam_tgt := _helicopter_root.to_global(Vector3(lerpf(0.16, 0.08, step_b), lerpf(1.55, 1.66, step_b), lerpf(2.38, 3.20, step_b)))
			_extraction_camera.global_position = cam_pos
			_extraction_camera.look_at(cam_tgt, Vector3.UP)

	# Step C (2.5s - 6.5s): Exterior Chase View & Nose-First Takeoff
	else:
		if not _ignition_switched:
			_activate_helicopter_ignition()
		var fly_elapsed := clampf((e - 2.5) / maxf(0.1, EXTRACTION_CINEMATIC_DURATION - 2.5), 0.0, 1.0)
		_heli_rotor_speed = 1450.0
		if _rotor_player and _rotor_player.playing:
			_rotor_player.pitch_scale = lerpf(1.15, 1.5, clampf(fly_elapsed * 1.4, 0.0, 1.0))

		if _helicopter_root:
			var takeoff_offset := Vector3(-22.0, 0.0, -85.0)
			var target_yaw := 180.0 + wrapf(rad_to_deg(atan2(takeoff_offset.x, takeoff_offset.z)) - 180.0, -180.0, 180.0)
			if fly_elapsed < 0.28:
				var lift_t := fly_elapsed / 0.28
				var ease_lift := lift_t * lift_t * (3.0 - 2.0 * lift_t)
				_helicopter_root.global_position = _heli_start_pos + Vector3(0.0, 11.0 * ease_lift, 0.0)
				_helicopter_root.rotation_degrees = Vector3(4.0 * ease_lift, 180.0, 0.0)
			else:
				var move_t := (fly_elapsed - 0.28) / 0.72
				var ease_fly := move_t * move_t
				var turn_t := clampf(move_t * 2.0, 0.0, 1.0)
				var yaw_now := lerpf(180.0, target_yaw, turn_t)
				_helicopter_root.global_position = _heli_start_pos + Vector3(takeoff_offset.x * ease_fly, 11.0 + 18.0 * ease_fly, takeoff_offset.z * ease_fly)
				_helicopter_root.rotation_degrees = Vector3(lerpf(4.0, 12.0, turn_t), yaw_now, -8.0 * ease_fly)

		if _extraction_camera and _helicopter_root:
			var interior_pos := _helicopter_root.to_global(Vector3(-0.45, 2.04, 1.10))
			var chase_pos := HELIPAD_POS + Vector3(14.0 - 6.0 * fly_elapsed, 6.5 + 7.5 * fly_elapsed, 16.0 - 10.0 * fly_elapsed)
			var blend := clampf(fly_elapsed / 0.22, 0.0, 1.0)
			_extraction_camera.global_position = interior_pos.lerp(chase_pos, blend * blend * (3.0 - 2.0 * blend))
			_extraction_camera.look_at(_helicopter_root.global_position + Vector3(0.0, 1.6, 0.0), Vector3.UP)

	if _heli_rotor_speed > 0.0:
		if _main_rotor:
			_main_rotor.rotate_y(deg_to_rad(_heli_rotor_speed * delta))
		if _tail_rotor:
			_tail_rotor.rotate_x(deg_to_rad(_heli_rotor_speed * 1.8 * delta))

	if _cinematic_elapsed >= EXTRACTION_CINEMATIC_DURATION:
		if _rotor_player:
			_rotor_player.stop()
		super._complete_stage(true)


func _activate_helicopter_ignition() -> void:
	_ignition_switched = true
	if _ignition_switch:
		var green_mat := StandardMaterial3D.new()
		green_mat.albedo_color = Color(0.15, 1.0, 0.35)
		green_mat.emission_enabled = true
		green_mat.emission = Color(0.15, 1.0, 0.35)
		green_mat.emission_energy_multiplier = 4.5
		_ignition_switch.material_override = green_mat
	if _control_panel:
		for child in _control_panel.get_children():
			if child is MeshInstance3D and child.name.begins_with("Gauge_"):
				var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
				if mat:
					mat.emission_energy_multiplier = 3.2
	if _rotor_player and _rotor_sfx:
		_rotor_player.volume_db = 4.0
		_rotor_player.pitch_scale = 0.75
		_rotor_player.stream = _rotor_sfx
		_rotor_player.play()
	_set_objective_text("EXTRACTION IN PROGRESS — OPERATION IRON PEAK COMPLETE", false)


# ------------------------------------------------------------------------------
# ENEMY GARRISON SPAWNING (18 SOLDIERS)
# ------------------------------------------------------------------------------

func _spawn_enemies() -> void:
	var container := get_node_or_null("Enemies") as Node3D
	if not container:
		container = Node3D.new()
		container.name = "Enemies"
		add_child(container)

	for spec in ENEMY_SPAWNS:
		var enemy := ENEMY_SCENE.instantiate() as Enemy3D
		if not enemy:
			continue
		enemy.name = spec["name"]
		enemy.position = spec["pos"]
		enemy.rotation_degrees = Vector3(0.0, float(spec["yaw"]), 0.0)
		container.add_child(enemy)


# ------------------------------------------------------------------------------
# CANTONMENT, TANKS & HELICOPTER CONSTRUCTION
# ------------------------------------------------------------------------------

func _build_cantonment() -> void:
	var env_root := get_node_or_null("Environment") as Node3D
	if not env_root:
		env_root = Node3D.new()
		env_root.name = "Environment"
		add_child(env_root)

	_build_roads(env_root)
	_build_perimeter_walls_and_gate(env_root)
	_build_watchtowers(env_root)
	_build_hq_building(env_root)
	_build_barracks(env_root)
	_build_armory_and_hangar(env_root)
	_build_military_props(env_root)


func _build_roads(parent: Node3D) -> void:
	var roads := _group(parent, "Roads")
	_box(roads, "MainAvenue", Vector3(0.0, 0.005, 22.0), Vector3(14.0, 0.01, 152.0), "asphalt", false)
	_box(roads, "CrossRoadSouth", Vector3(0.0, 0.006, 20.0), Vector3(88.0, 0.01, 10.0), "asphalt", false)
	_box(roads, "HQParadePlaza", Vector3(0.0, 0.007, -28.0), Vector3(56.0, 0.012, 26.0), "concrete_dark", false)

	for z in range(90, -24, -8):
		_box(roads, "CenterLine_%d" % z, Vector3(0.0, 0.013, float(z)), Vector3(0.22, 0.005, 3.6), "yellow_marking", false)
	for side in [-1.0, 1.0]:
		_box(roads, "EdgeLine_%d" % int(side), Vector3(side * 6.6, 0.013, 22.0), Vector3(0.18, 0.005, 150.0), "white_marking", false)


func _build_perimeter_walls_and_gate(parent: Node3D) -> void:
	var perimeter := _group(parent, "Perimeter")
	# 18m south entrance gate at Z = 75 (X in [-9, 9])
	_box(perimeter, "SouthWallWest", Vector3(-32.5, 2.25, 75.0), Vector3(47.0, 4.5, 1.2), "concrete_wall")
	_box(perimeter, "SouthWallEast", Vector3(32.5, 2.25, 75.0), Vector3(47.0, 4.5, 1.2), "concrete_wall")

	_box(perimeter, "GatePillarWest", Vector3(-9.6, 3.2, 75.0), Vector3(1.6, 6.4, 2.0), "concrete_dark")
	_box(perimeter, "GatePillarEast", Vector3(9.6, 3.2, 75.0), Vector3(1.6, 6.4, 2.0), "concrete_dark")
	_box(perimeter, "GateArchBeam", Vector3(0.0, 6.0, 75.0), Vector3(20.8, 1.0, 1.6), "steel")
	_box(perimeter, "GateSignBoard", Vector3(0.0, 6.2, 75.85), Vector3(11.0, 1.2, 0.2), "olive_metal", false)

	var gate_label := Label3D.new()
	gate_label.name = "GateSignText"
	gate_label.text = "OPERATION IRON PEAK // CANTONMENT GATE"
	gate_label.position = Vector3(0.0, 6.2, 76.0)
	gate_label.font_size = 64
	gate_label.pixel_size = 0.008
	gate_label.modulate = Color(0.95, 0.85, 0.35, 1.0)
	perimeter.add_child(gate_label)

	_box(perimeter, "NorthWall", Vector3(0.0, 2.25, -78.0), Vector3(113.2, 4.5, 1.2), "concrete_wall")
	_box(perimeter, "WestWall", Vector3(-56.0, 2.25, -1.5), Vector3(1.2, 4.5, 153.0), "concrete_wall")
	_box(perimeter, "EastWall", Vector3(56.0, 2.25, -1.5), Vector3(1.2, 4.5, 153.0), "concrete_wall")


func _build_watchtowers(parent: Node3D) -> void:
	var towers := _group(parent, "Watchtowers")
	var positions := [
		Vector3(-14.5, 0.0, 71.0),
		Vector3(14.5, 0.0, 71.0),
		Vector3(-48.0, 0.0, -70.0),
		Vector3(48.0, 0.0, -70.0),
	]
	for i in range(positions.size()):
		_build_single_watchtower(towers, "Watchtower_%d" % (i + 1), positions[i])


func _build_single_watchtower(parent: Node3D, tower_name: String, base_pos: Vector3) -> void:
	var tower := _group(parent, tower_name)
	tower.position = base_pos
	for sx in [-1.5, 1.5]:
		for sz in [-1.5, 1.5]:
			_box(tower, "Leg_%d_%d" % [int(sx), int(sz)], Vector3(sx, 3.0, sz), Vector3(0.35, 6.0, 0.35), "steel")
	_box(tower, "Deck", Vector3(0.0, 6.1, 0.0), Vector3(4.2, 0.3, 4.2), "concrete_dark")
	_box(tower, "ParapetN", Vector3(0.0, 6.8, -1.95), Vector3(4.2, 1.1, 0.25), "olive_metal")
	_box(tower, "ParapetS", Vector3(0.0, 6.8, 1.95), Vector3(4.2, 1.1, 0.25), "olive_metal")
	_box(tower, "ParapetW", Vector3(-1.95, 6.8, 0.0), Vector3(0.25, 1.1, 3.7), "olive_metal")
	_box(tower, "ParapetE", Vector3(1.95, 6.8, 0.0), Vector3(0.25, 1.1, 3.7), "olive_metal")
	for sx in [-1.85, 1.85]:
		for sz in [-1.85, 1.85]:
			_box(tower, "Post_%d_%d" % [int(sx), int(sz)], Vector3(sx, 7.9, sz), Vector3(0.2, 2.2, 0.2), "steel")
	_box(tower, "Roof", Vector3(0.0, 9.1, 0.0), Vector3(4.6, 0.25, 4.6), "olive_metal")


func _build_hq_building(parent: Node3D) -> void:
	var hq := _group(parent, "HQBuilding")
	hq.position = Vector3(0.0, 0.0, -58.0)

	_box(hq, "MainBlock", Vector3(0.0, 4.0, 0.0), Vector3(32.0, 8.0, 18.0), "concrete_wall")
	_box(hq, "UpperCommandDeck", Vector3(0.0, 9.8, -2.0), Vector3(18.0, 3.6, 10.0), "concrete_dark")
	_box(hq, "RoofTrim", Vector3(0.0, 8.15, 0.0), Vector3(32.8, 0.35, 18.8), "steel")

	_box(hq, "EntranceSteps", Vector3(0.0, 0.2, 10.2), Vector3(10.0, 0.4, 2.4), "concrete_dark")
	_box(hq, "PorticoRoof", Vector3(0.0, 4.2, 10.2), Vector3(10.0, 0.4, 2.6), "steel")
	_box(hq, "PorticoPillarW", Vector3(-4.4, 2.1, 11.1), Vector3(0.6, 4.2, 0.6), "concrete_dark")
	_box(hq, "PorticoPillarE", Vector3(4.4, 2.1, 11.1), Vector3(0.6, 4.2, 0.6), "concrete_dark")
	_box(hq, "MainDoor", Vector3(0.0, 1.8, 9.05), Vector3(3.6, 3.2, 0.2), "steel", false)

	for wx in [-11.0, -7.0, 7.0, 11.0]:
		_box(hq, "WindowLower_%d" % int(wx), Vector3(wx, 2.8, 9.05), Vector3(2.4, 1.5, 0.12), "window_glow", false)
		_box(hq, "WindowUpper_%d" % int(wx), Vector3(wx, 6.0, 9.05), Vector3(2.4, 1.5, 0.12), "window_glow", false)

	_cylinder(hq, "CommsMast", Vector3(5.5, 14.2, -2.0), 0.22, 5.4, "steel")
	_box(hq, "RadarUnit", Vector3(-5.5, 12.6, -2.0), Vector3(2.2, 1.8, 1.6), "olive_metal")


func _build_barracks(parent: Node3D) -> void:
	var barracks := _group(parent, "BarracksSector")
	for i in range(2):
		var z_pos := 12.0 if i == 0 else -8.0
		var b := _group(barracks, "Barracks_%d" % (i + 1))
		b.position = Vector3(-34.0, 0.0, z_pos)
		_box(b, "Body", Vector3(0.0, 2.4, 0.0), Vector3(18.0, 4.8, 10.0), "olive_concrete")
		_box(b, "Roof", Vector3(0.0, 5.0, 0.0), Vector3(18.8, 0.45, 10.8), "olive_metal")
		_box(b, "Door", Vector3(9.05, 1.4, 0.0), Vector3(0.18, 2.6, 2.0), "steel", false)
		for wz in [-3.0, 3.0]:
			_box(b, "Window_%d" % int(wz), Vector3(9.05, 2.6, wz), Vector3(0.12, 1.2, 1.8), "window_glow", false)


func _build_armory_and_hangar(parent: Node3D) -> void:
	var armory := _group(parent, "ArmorySector")
	var arm := _group(armory, "ArmoryBuilding")
	arm.position = Vector3(34.0, 0.0, 12.0)
	_box(arm, "Body", Vector3(0.0, 2.6, 0.0), Vector3(16.0, 5.2, 12.0), "concrete_dark")
	_box(arm, "Roof", Vector3(0.0, 5.4, 0.0), Vector3(16.8, 0.45, 12.8), "steel")
	_box(arm, "BlastDoor", Vector3(-8.05, 1.7, 0.0), Vector3(0.25, 3.4, 3.2), "steel", false)

	var hangar := PROP_HANGAR_GLB.instantiate() as Node3D
	if hangar:
		hangar.name = "MotorPoolHangar"
		hangar.position = Vector3(24.0, 0.0, -24.0)
		hangar.scale = Vector3(6.0, 6.0, 6.0)
		armory.add_child(hangar)
		_box(armory, "HangarCollisionProxy", Vector3(36.0, 3.0, -15.0), Vector3(12.0, 6.0, 18.0), "steel", true).get_node("Mesh").visible = false


func _build_military_props(parent: Node3D) -> void:
	var props := _group(parent, "MilitaryProps")

	var barrier_specs := [
		{"pos": Vector3(-5.5, 0.0, 69.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"pos": Vector3(5.5, 0.0, 69.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"pos": Vector3(-4.0, 0.0, 42.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"pos": Vector3(4.0, 0.0, 34.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"pos": Vector3(-16.0, 0.0, 24.0), "rot": Vector3(0.0, 0.0, 0.0)},
		{"pos": Vector3(16.0, 0.0, 20.0), "rot": Vector3(0.0, 0.0, 0.0)},
		{"pos": Vector3(-9.0, 0.0, -16.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"pos": Vector3(9.0, 0.0, -16.0), "rot": Vector3(0.0, 90.0, 0.0)},
	]
	for i in range(barrier_specs.size()):
		_spawn_glb_prop(
			props, "Barrier_%d" % (i + 1), PROP_BARRIER_GLB,
			barrier_specs[i]["pos"], barrier_specs[i]["rot"],
			Vector3(10.0, 10.0, 11.0), Vector3(1.1, 1.2, 2.5), Vector3(0.0, 0.6, 0.0)
		)

	var crate_positions := [
		Vector3(-11.0, 0.9, 60.0),
		Vector3(-13.0, 0.9, 60.0),
		Vector3(-12.0, 2.7, 60.0),
		Vector3(12.0, 0.9, 48.0),
		Vector3(-22.0, 0.9, 14.0),
		Vector3(23.0, 0.9, 10.0),
		Vector3(23.0, 0.9, 12.2),
		Vector3(-21.0, 0.9, -28.0),
		Vector3(21.0, 0.9, -28.0),
	]
	for i in range(crate_positions.size()):
		_spawn_glb_prop(
			props, "CargoCrate_%d" % (i + 1), PROP_CRATE_GLB,
			crate_positions[i], Vector3(0.0, float(i * 15 % 90), 0.0),
			Vector3(1.8, 1.8, 1.8), Vector3(1.8, 1.8, 1.8), Vector3.ZERO
		)

	_spawn_glb_prop(
		props, "MilitaryTruck_1", PROP_MILITARY_TRUCK_GLB,
		Vector3(18.0, 0.069, 44.0), Vector3(0.0, -25.0, 0.0),
		Vector3.ONE, Vector3(2.8, 2.65, 4.9), Vector3(0.0, 1.32, 0.0)
	)
	_spawn_glb_prop(
		props, "MilitaryTruck_2", PROP_MILITARY_TRUCK_GLB,
		Vector3(-22.0, 0.069, -15.0), Vector3(0.0, 15.0, 0.0),
		Vector3.ONE, Vector3(2.8, 2.65, 4.9), Vector3(0.0, 1.32, 0.0)
	)
	_spawn_glb_prop(
		props, "CargoTruck_1", PROP_CARGO_TRUCK_GLB,
		Vector3(25.0, 0.0, -4.0), Vector3(0.0, 90.0, 0.0),
		Vector3(3.2, 3.2, 3.2), Vector3(2.65, 2.36, 3.74), Vector3(0.0, 1.18, 0.0)
	)
	_spawn_glb_prop(
		props, "CargoTruck_2", PROP_CARGO_TRUCK_GLB,
		Vector3(-12.0, 0.0, 82.0), Vector3(0.0, 18.0, 0.0),
		Vector3(3.2, 3.2, 3.2), Vector3(2.65, 2.36, 3.74), Vector3(0.0, 1.18, 0.0)
	)


func _build_enemy_tanks() -> void:
	var env_root := get_node_or_null("Environment") as Node3D
	var tanks_group := _group(env_root, "EnemyTanks")
	tanks.clear()

	for spec in TANK_SPECS:
		var body: StaticBody3D = Stage08Vehicles.create_battle_tank(spec["name"], spec["pos"], float(spec["yaw"]))
		tanks_group.add_child(body)

		# Damage Smoke (activates on Hit 1)
		var dmg_smoke := CPUParticles3D.new()
		dmg_smoke.name = "DamageSmoke"
		dmg_smoke.position = Vector3(0.0, 2.1, -0.8)
		dmg_smoke.amount = 24
		dmg_smoke.lifetime = 1.8
		dmg_smoke.emitting = false
		dmg_smoke.direction = Vector3.UP
		dmg_smoke.spread = 28.0
		dmg_smoke.initial_velocity_min = 1.5
		dmg_smoke.initial_velocity_max = 3.5
		dmg_smoke.gravity = Vector3(0.0, 1.8, 0.0)
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		sm.material = _materials.get("smoke_mat")
		dmg_smoke.mesh = sm
		body.add_child(dmg_smoke)

		tanks.append({
			"name": spec["name"],
			"root": body,
			"smoke": dmg_smoke,
			"hp": 2,
			"destroyed": false,
		})


func _build_helipad_and_helicopter() -> void:
	var env_root := get_node_or_null("Environment") as Node3D
	var heli_sector := _group(env_root, "HelipadAndHelicopter")

	# Marked Helipad at HELIPAD_POS (0, 0.01, -30)
	var pad := _group(heli_sector, "Helipad")
	pad.position = HELIPAD_POS
	_cylinder(pad, "PadBase", Vector3(0.0, 0.02, 0.0), 6.5, 0.04, "concrete_dark", Vector3.ZERO, false)
	_cylinder(pad, "OuterRing", Vector3(0.0, 0.042, 0.0), 6.2, 0.01, "yellow_marking", Vector3.ZERO, false)
	_cylinder(pad, "InnerCircle", Vector3(0.0, 0.045, 0.0), 5.7, 0.01, "asphalt", Vector3.ZERO, false)
	# Painted "H"
	_box(pad, "H_Left", Vector3(-1.3, 0.052, 0.0), Vector3(0.55, 0.01, 3.6), "yellow_marking", false)
	_box(pad, "H_Right", Vector3(1.3, 0.052, 0.0), Vector3(0.55, 0.01, 3.6), "yellow_marking", false)
	_box(pad, "H_Cross", Vector3(0.0, 0.052, 0.0), Vector3(2.6, 0.01, 0.55), "yellow_marking", false)

	# Glowing Green Extraction Beacon (hidden until Phase 3)
	_extraction_beacon = _group(heli_sector, "ExtractionBeacon")
	_extraction_beacon.position = HELIPAD_POS
	_extraction_beacon.visible = false
	_cylinder(_extraction_beacon, "BeaconBeam", Vector3(0.0, 9.0, 0.0), 0.35, 18.0, "beacon_green", Vector3.ZERO, false)
	_cylinder(_extraction_beacon, "BeaconRing", Vector3(0.0, 0.08, 0.0), EXTRACTION_RADIUS, 0.06, "beacon_green", Vector3.ZERO, false)
	var beacon_light := OmniLight3D.new()
	beacon_light.position = Vector3(0.0, 3.0, 0.0)
	beacon_light.light_color = Color(0.2, 1.0, 0.45)
	beacon_light.light_energy = 4.5
	beacon_light.omni_range = 14.0
	_extraction_beacon.add_child(beacon_light)

	# Detailed Military Helicopter from Stage08Vehicles
	_helicopter_root = Stage08Vehicles.create_military_helicopter("EnemyHelicopter", HELIPAD_POS, 180.0)
	heli_sector.add_child(_helicopter_root)
	_main_rotor = _helicopter_root.get_node_or_null("MainRotor")
	_tail_rotor = _helicopter_root.get_node_or_null("TailRotor")
	_seated_operative = _helicopter_root.get_node_or_null("SeatedOperative")
	_operative_right_arm = _helicopter_root.get_node_or_null("SeatedOperative/RightArm")
	_control_panel = _helicopter_root.get_node_or_null("ControlPanel")
	_ignition_switch = _helicopter_root.get_node_or_null("ControlPanel/IgnitionSwitch") as MeshInstance3D

	# Third-person Extraction Camera
	_extraction_camera = Camera3D.new()
	_extraction_camera.name = "ExtractionCamera"
	_extraction_camera.fov = 68.0
	add_child(_extraction_camera)


func _spawn_glb_prop(
	parent: Node3D,
	prop_name: String,
	scene: PackedScene,
	pos: Vector3,
	rot_deg: Vector3,
	model_scale: Vector3,
	col_size: Vector3,
	col_offset: Vector3
) -> Node3D:
	if not scene:
		return null
	var body := StaticBody3D.new()
	body.name = prop_name
	body.position = pos
	body.rotation_degrees = rot_deg
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)

	var model := scene.instantiate() as Node3D
	if model:
		model.name = "Model"
		model.scale = model_scale
		body.add_child(model)

	var shape := BoxShape3D.new()
	shape.size = col_size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.position = col_offset
	body.add_child(cs)
	return body


# ------------------------------------------------------------------------------
# SYNTHESIZED AUDIO & MATERIALS
# ------------------------------------------------------------------------------

func _init_synthesized_audio() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "Stage08SFX"
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = 8.0
	add_child(_sfx_player)

	_rotor_player = AudioStreamPlayer3D.new()
	_rotor_player.name = "HeliRotorAudio"
	_rotor_player.bus = "Master"
	_rotor_player.volume_db = 4.0
	_rotor_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if _helicopter_root:
		_helicopter_root.add_child(_rotor_player)
	else:
		add_child(_rotor_player)

	_rocket_sfx = _synth_rpg_launch(0.85)
	_explosion_sfx = _synth_heavy_explosion(2.4)
	_rotor_sfx = _synth_turbine_helicopter_loop(1.0)


func _synth_rpg_launch(duration: float = 0.85) -> AudioStreamWAV:
	var mix_rate := 22050
	var count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)

	var lp_hp := 0.0
	var lp_band_hi := 0.0
	var lp_band_lo := 0.0
	var alpha_hp := clampf(900.0 / float(mix_rate), 0.01, 0.95)
	var alpha_lo := clampf(120.0 / float(mix_rate), 0.01, 0.95)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var n := randf_range(-1.0, 1.0)

		# Stage A (0.0s - 0.12s): Sharp propellant blast (60 Hz punch + transient crack)
		var blast_env := minf(1.0, t / 0.004) * exp(-t * 26.0)
		var punch := sin(TAU * 60.0 * t) * blast_env * 0.95
		lp_hp = lp_hp + alpha_hp * (n - lp_hp)
		var crack := (n - lp_hp) * exp(-t * 42.0) * 0.85

		# Stage B (0.08s - 0.85s): Sustained rocket motor thruster whoosh sweeping downward
		var motor_t := clampf((t - 0.08) / maxf(0.01, duration - 0.08), 0.0, 1.0)
		var hi_cutoff := lerpf(1600.0, 260.0, motor_t)
		var alpha_hi := clampf(hi_cutoff / float(mix_rate), 0.01, 0.95)
		lp_band_hi = lp_band_hi + alpha_hi * (n - lp_band_hi)
		lp_band_lo = lp_band_lo + alpha_lo * (lp_band_hi - lp_band_lo)
		var thruster_band := lp_band_hi - lp_band_lo
		var motor_onset := clampf((t - 0.06) / 0.05, 0.0, 1.0)
		var motor_env := motor_onset * pow(1.0 - motor_t, 1.25)
		var whoosh := thruster_band * motor_env * 1.45

		var mixed := tanh((punch + crack + whoosh) * 1.25)
		var sample := clampi(int(mixed * 32767.0), -32767, 32767)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


func _synth_heavy_explosion(duration: float = 2.4) -> AudioStreamWAV:
	var mix_rate := 22050
	var count := int(duration * mix_rate)
	var dry := PackedFloat32Array()
	dry.resize(count)

	var sub_phase := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	# Two-stage low-pass (< 160 Hz) removes all high-frequency flutter/chirping.
	var alpha_rumble := clampf(140.0 / float(mix_rate), 0.01, 0.95)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var n := randf_range(-1.0, 1.0)

		# Layer 1: Pure deep sub-bass shockwave (85 Hz -> 24 Hz) with warm saturation
		var sub_freq := lerpf(85.0, 24.0, clampf(t / 0.80, 0.0, 1.0))
		sub_phase += TAU * sub_freq / float(mix_rate)
		var sub_env := minf(1.0, t / 0.014) * exp(-t * 1.65)
		var shockwave := tanh(sin(sub_phase) * 2.2) * sub_env * 1.05

		# Layer 2: Deep low-pass filtered cannon/artillery rumble (< 160 Hz)
		lp1 = lp1 + alpha_rumble * (n - lp1)
		lp2 = lp2 + alpha_rumble * (lp1 - lp2)
		var rumble_env := minf(1.0, t / 0.022) * exp(-t * 1.25)
		var deep_rumble := lp2 * rumble_env * 2.1

		dry[i] = shockwave + deep_rumble

	# Layer 3: Slow low-passed canyon echo decays (+0.25s, +0.55s)
	var taps := [
		{"delay": int(0.25 * mix_rate), "gain": 0.45},
		{"delay": int(0.55 * mix_rate), "gain": 0.25},
	]
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp_echo := 0.0
	var alpha_echo := clampf(135.0 / float(mix_rate), 0.01, 0.95)

	for i in range(count):
		var echo_sum := 0.0
		for tap in taps:
			var idx: int = i - int(tap["delay"])
			if idx >= 0:
				echo_sum += dry[idx] * float(tap["gain"])
		lp_echo = lp_echo + alpha_echo * (echo_sum - lp_echo)
		var mixed := tanh((dry[i] + lp_echo) * 1.3)
		var sample := clampi(int(mixed * 32767.0), -32767, 32767)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


func _synth_turbine_helicopter_loop(duration: float = 1.0) -> AudioStreamWAV:
	var mix_rate := 22050
	var count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)

	var lp_jet := 0.0
	var lp_chop := 0.0
	var alpha_jet := clampf(650.0 / float(mix_rate), 0.01, 0.95)
	var alpha_chop := clampf(380.0 / float(mix_rate), 0.01, 0.95)

	for i in range(count):
		var t := float(i) / float(mix_rate)
		var n := randf_range(-1.0, 1.0)

		# 1. Twin-Turbine Engine Whine & Rumble (85 Hz + 170 Hz + jet exhaust)
		lp_jet = lp_jet + alpha_jet * (n - lp_jet)
		var turbine_hum := sin(TAU * 85.0 * t) * 0.24 + sin(TAU * 170.0 * t) * 0.14
		var jet_exhaust := lp_jet * 0.38

		# 2. Crisp Rotor Blade Chop (12 Hz pulse rate; scales to 18 Hz via pitch_scale)
		lp_chop = lp_chop + alpha_chop * (n - lp_chop)
		var chop_pulse := pow(0.5 + 0.5 * sin(TAU * 12.0 * t), 6.0)
		var blade_slap := lp_chop * chop_pulse * 1.35 + sin(TAU * 12.0 * t) * chop_pulse * 0.22

		var mixed := tanh((turbine_hum + jet_exhaust + blade_slap) * 1.2)
		var sample := clampi(int(mixed * 32767.0), -32767, 32767)
		data.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	wav.data = data
	return wav


func _create_materials() -> void:
	_add_mat("asphalt", Color(0.14, 0.15, 0.16), 0.92)
	_add_mat("concrete_wall", Color(0.45, 0.46, 0.43), 0.88)
	_add_mat("concrete_dark", Color(0.28, 0.30, 0.31), 0.85)
	_add_mat("olive_concrete", Color(0.32, 0.35, 0.27), 0.86)
	_add_mat("olive_metal", Color(0.24, 0.28, 0.21), 0.65, 0.35)
	_add_mat("tank_armor", Color(0.29, 0.31, 0.24), 0.72, 0.28)
	_add_mat("wood_grip", Color(0.36, 0.22, 0.12), 0.82)
	_add_mat("steel", Color(0.22, 0.24, 0.27), 0.48, 0.7)
	_add_mat("charred", Color(0.08, 0.08, 0.08), 0.95, 0.1)
	_add_mat("yellow_marking", Color(0.88, 0.72, 0.18), 0.75)
	_add_mat("white_marking", Color(0.86, 0.88, 0.90), 0.75)
	_add_mat("window_glow", Color(0.82, 0.88, 0.72), 0.25, 0.0, Color(0.65, 0.72, 0.48), 0.75)
	_add_mat("explosion_fire", Color(1.0, 0.55, 0.12), 0.3, 0.0, Color(1.0, 0.45, 0.08), 3.2)

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.18, 0.18, 0.19, 0.75)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.roughness = 0.95
	_materials["smoke_mat"] = smoke_mat

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.18, 0.32, 0.42, 0.78)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.15
	glass_mat.metallic = 0.4
	_materials["heli_glass"] = glass_mat

	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(0.15, 0.95, 0.38, 0.32)
	beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(0.15, 1.0, 0.42)
	beacon_mat.emission_energy_multiplier = 2.2
	_materials["beacon_green"] = beacon_mat


func _add_mat(mat_name: String, albedo: Color, rough: float, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_energy: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = rough
	mat.metallic = metal
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_col
		mat.emission_energy_multiplier = emit_energy
	_materials[mat_name] = mat


func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat_name: String, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	if collision and root is StaticBody3D:
		(root as StaticBody3D).collision_layer = 1
		(root as StaticBody3D).collision_mask = 1
	parent.add_child(root)

	var mesh_key := "%0.2f:%0.2f:%0.2f:%s" % [size.x, size.y, size.z, mat_name]
	if not _box_mesh_cache.has(mesh_key):
		var b_mesh := BoxMesh.new()
		b_mesh.size = size
		b_mesh.material = _materials.get(mat_name)
		_box_mesh_cache[mesh_key] = b_mesh

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh_cache[mesh_key]
	root.add_child(mi)

	if collision:
		var shape_key := "%0.2f:%0.2f:%0.2f" % [size.x, size.y, size.z]
		if not _box_shape_cache.has(shape_key):
			var b_shape := BoxShape3D.new()
			b_shape.size = size
			_box_shape_cache[shape_key] = b_shape
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = _box_shape_cache[shape_key]
		root.add_child(cs)

	return root


func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat_name: String, rot_deg: Vector3 = Vector3.ZERO, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees = rot_deg
	if collision and root is StaticBody3D:
		(root as StaticBody3D).collision_layer = 1
		(root as StaticBody3D).collision_mask = 1
	parent.add_child(root)

	var mesh_key := "%0.2f:%0.2f:%s" % [radius, height, mat_name]
	if not _cyl_mesh_cache.has(mesh_key):
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = radius
		c_mesh.bottom_radius = radius
		c_mesh.height = height
		c_mesh.radial_segments = 16
		c_mesh.material = _materials.get(mat_name)
		_cyl_mesh_cache[mesh_key] = c_mesh

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _cyl_mesh_cache[mesh_key]
	root.add_child(mi)

	if collision:
		var shape_key := "%0.2f:%0.2f" % [radius, height]
		if not _cyl_shape_cache.has(shape_key):
			var c_shape := CylinderShape3D.new()
			c_shape.radius = radius
			c_shape.height = height
			_cyl_shape_cache[shape_key] = c_shape
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = _cyl_shape_cache[shape_key]
		root.add_child(cs)

	return root
