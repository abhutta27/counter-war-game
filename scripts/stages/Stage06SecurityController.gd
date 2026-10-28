class_name Stage06SecurityController
extends "res://scripts/LevelBase3D.gd"
## Stage06-only SEARCHLIGHT SECURITY LOCKDOWN controller and lightweight base
## builder. It owns local awareness, searchlight confirmation, group activation,
## final-stage presentation, and never changes shared Enemy3D/Player/HUD code.

enum SecurityState { STEALTH, SUSPICIOUS, LOCKDOWN }

const POLL_RATE := 0.10
const SEARCHLIGHT_CONFIRM_TIME := 1.20
const SUSPICIOUS_THRESHOLD := 0.22
const SEARCHLIGHT_RANGE := 31.0
const SEARCHLIGHT_HALF_ANGLE := 18.0
const LOCAL_VISION_RANGE := 17.0
const LOCAL_FOV_HALF_ANGLE := 68.0
const CLOSE_CONFIRM_RANGE := 6.0
const MAX_ACTIVE_GUARDS := 6

const GROUP_ORDER := ["checkpoint", "tower", "road", "maintenance", "final"]

var security_state := SecurityState.STEALTH
var searchlight_exposure := 0.0
var searchlight_time := 0.0
var _poll_time := 0.0
var _guard_visual_time: Dictionary = {}
var _pending_groups: Array[String] = []
var _materials: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _searchlight_pivots: Array[Node3D] = []
var _searchlight_lamps: Array[SpotLight3D] = []
var _alarm_lights: Array[OmniLight3D] = []
var _route_committed := ""
var _stage06_debrief_configured := false

func _ready() -> void:
	_create_materials()
	_build_night_base()
	_freeze_stage06_guards()
	super._ready()
	player.shot_fired.connect(_on_stage06_player_gunshot)
	for enemy in enemies_container.get_children():
		enemy.health_changed.connect(_on_stage06_guard_health_changed.bind(enemy))
		enemy.enemy_died.connect(_on_stage06_guard_died.bind(enemy))
	print("[Stage06Security] STEALTH: Searchlight Security Lockdown armed with 12 guards.")

func _physics_process(delta: float) -> void:
	if is_stage_finished or not player or not is_instance_valid(player):
		return
	_update_searchlight_sweeps(delta)
	_poll_time -= delta
	if _poll_time <= 0.0:
		_poll_time = POLL_RATE
		_poll_security()

func _freeze_stage06_guards() -> void:
	for enemy in $Enemies.get_children():
		if enemy.has_method("hold_position"):
			enemy.hold_position()
		_guard_visual_time[enemy.name] = 0.0

func _poll_security() -> void:
	_update_route_activation()
	_poll_local_guard_vision()
	_poll_searchlight_exposure()
	_process_pending_groups()

func _update_route_activation() -> void:
	var p: Vector3 = player.global_position
	# The checkpoint is the only initially local response and cannot wake the base.
	if p.z > 20.0:
		_request_group_activation("checkpoint", "outer checkpoint proximity")
	if p.z <= 24.0:
		_request_group_activation("tower", "security gate crossed")
	if p.z <= 17.0 and _route_committed.is_empty():
		_route_committed = "road" if p.x < 3.0 else "maintenance"
		_request_group_activation(_route_committed, "route contact")
	if p.z <= -11.0:
		_request_group_activation("final", "command perimeter reached")

func _poll_local_guard_vision() -> void:
	for child in enemies_container.get_children():
		var enemy := child as Stage06Enemy3D
		if not enemy:
			continue
		if enemy.is_dead or enemy.is_stage06_combat_active():
			continue
		var to_player: Vector3 = player.global_position - enemy.global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		var visible := false
		if distance <= LOCAL_VISION_RANGE and distance > 0.01 and _has_world_los(enemy.global_position + Vector3.UP * 1.35):
			var forward: Vector3 = -enemy.global_basis.z
			forward.y = 0.0
			visible = distance <= CLOSE_CONFIRM_RANGE or forward.normalized().dot(to_player.normalized()) >= cos(deg_to_rad(LOCAL_FOV_HALF_ANGLE))
		if visible:
			_guard_visual_time[enemy.name] = float(_guard_visual_time.get(enemy.name, 0.0)) + POLL_RATE
			if _guard_visual_time[enemy.name] >= 0.35:
				_request_group_activation(enemy.security_group, "confirmed local visual contact")
		else:
			_guard_visual_time[enemy.name] = 0.0

func _poll_searchlight_exposure() -> void:
	var exposed := false
	for lamp in _searchlight_lamps:
		if _is_player_inside_searchlight(lamp):
			exposed = true
			break
	if exposed:
		searchlight_exposure += POLL_RATE
		if searchlight_exposure >= SUSPICIOUS_THRESHOLD and security_state == SecurityState.STEALTH:
			_set_security_state(SecurityState.SUSPICIOUS)
			_investigate_near_searchlight()
		if searchlight_exposure >= SEARCHLIGHT_CONFIRM_TIME and security_state != SecurityState.LOCKDOWN:
			trigger_lockdown("confirmed searchlight exposure")
	else:
		searchlight_exposure = maxf(0.0, searchlight_exposure - POLL_RATE * 1.75)
		if searchlight_exposure <= 0.0 and security_state == SecurityState.SUSPICIOUS:
			_set_security_state(SecurityState.STEALTH)

func _is_player_inside_searchlight(lamp: SpotLight3D) -> bool:
	var origin := lamp.global_position
	var target := player.global_position + Vector3.UP * 1.1
	var to_player := target - origin
	var distance := to_player.length()
	if distance <= 0.01 or distance > SEARCHLIGHT_RANGE:
		return false
	var forward := -lamp.global_basis.z
	if forward.normalized().dot(to_player.normalized()) < cos(deg_to_rad(SEARCHLIGHT_HALF_ANGLE)):
		return false
	return _has_world_los(origin)

func _has_world_los(origin: Vector3) -> bool:
	var target := player.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func _investigate_near_searchlight() -> void:
	var preferred := "tower"
	for enemy in enemies_container.get_children():
		if enemy.security_group == preferred and not enemy.is_dead and not enemy.is_stage06_combat_active():
			enemy.investigate(player.global_position)

func trigger_lockdown(reason: String = "security alarm") -> void:
	if security_state == SecurityState.LOCKDOWN:
		return
	_set_security_state(SecurityState.LOCKDOWN)
	for light in _alarm_lights:
		light.light_color = Color(1.0, 0.12, 0.08)
		light.light_energy = 2.8
	_request_group_activation("tower", reason)
	var local_route := _route_committed if not _route_committed.is_empty() else ("road" if player.global_position.x < 3.0 else "maintenance")
	_request_group_activation(local_route, reason)
	print("[Stage06Security] LOCKDOWN: %s; distant final guard group remains gated." % reason)

func _set_security_state(new_state: SecurityState) -> void:
	security_state = new_state
	set_meta("stage06_security_state", SecurityState.keys()[new_state])
	print("[Stage06Security] State -> %s" % SecurityState.keys()[new_state])

func _request_group_activation(group_name: String, reason: String) -> void:
	var candidates: Array[Node] = []
	for enemy in enemies_container.get_children():
		if enemy.security_group == group_name and not enemy.is_dead and not enemy.is_stage06_combat_active():
			candidates.append(enemy)
	if candidates.is_empty():
		return
	if get_active_guard_count() + candidates.size() > MAX_ACTIVE_GUARDS:
		if not _pending_groups.has(group_name):
			_pending_groups.append(group_name)
		return
	for enemy in candidates:
		enemy.activate_combat(reason)
	print("[Stage06Security] Activated %s group (%d guards): %s" % [group_name, candidates.size(), reason])

func _process_pending_groups() -> void:
	if _pending_groups.is_empty():
		return
	var pending_copy := _pending_groups.duplicate()
	for group_name in pending_copy:
		var before := get_active_guard_count()
		_request_group_activation(group_name, "queued local response")
		if get_active_guard_count() > before or not _group_has_inactive_living_guards(group_name):
			_pending_groups.erase(group_name)

func _group_has_inactive_living_guards(group_name: String) -> bool:
	for enemy in enemies_container.get_children():
		if enemy.security_group == group_name and not enemy.is_dead and not enemy.is_stage06_combat_active():
			return true
	return false

func _on_stage06_player_gunshot() -> void:
	var nearest_group := ""
	var nearest_distance := 19.0
	for child in enemies_container.get_children():
		var enemy := child as Stage06Enemy3D
		if not enemy:
			continue
		if enemy.is_dead or enemy.is_stage06_combat_active():
			continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_group = enemy.security_group
			enemy.investigate(player.global_position)
	if not nearest_group.is_empty() and nearest_distance <= 12.0:
		_request_group_activation(nearest_group, "close gunfire")

func _on_stage06_guard_health_changed(current_hp: int, max_hp: int, enemy: Node) -> void:
	if current_hp > 0 and current_hp < max_hp:
		_request_group_activation(enemy.security_group, "guard took fire")

func _on_stage06_guard_died(_enemy: Node) -> void:
	call_deferred("_process_pending_groups")

func get_active_guard_count() -> int:
	var count := 0
	for enemy in enemies_container.get_children():
		if enemy.has_method("is_stage06_combat_active") and enemy.is_stage06_combat_active():
			count += 1
	return count

func get_security_state_name() -> String:
	return SecurityState.keys()[security_state]

func get_route_a_waypoints() -> Array[Vector3]:
	return [Vector3(0, 0, 36), Vector3(0, 0, 24), Vector3(-7, 0, 14), Vector3(-7, 0, 0), Vector3(-5, 0, -12), Vector3(0, 0, -22), Vector3(0, 0, -31)]

func get_route_b_waypoints() -> Array[Vector3]:
	return [Vector3(0, 0, 36), Vector3(0, 0, 24), Vector3(13, 0, 16), Vector3(20, 0, 8), Vector3(21, 0, 3), Vector3(22, 0, -2), Vector3(22, 0, -5), Vector3(7, 0, -5), Vector3(7, 0, -16), Vector3(0, 0, -22)]

func _update_searchlight_sweeps(delta: float) -> void:
	searchlight_time += delta
	for i in range(_searchlight_pivots.size()):
		var center := -18.0 if i == 0 else 18.0
		var phase := 0.0 if i == 0 else PI
		_searchlight_pivots[i].rotation_degrees.y = center + sin(searchlight_time * 0.55 + phase) * 42.0

func _complete_stage(is_victory: bool) -> void:
	super._complete_stage(is_victory)
	if is_victory:
		call_deferred("_configure_stage06_debrief")

func _configure_stage06_debrief() -> void:
	if _stage06_debrief_configured or not summary_dialog:
		return
	_stage06_debrief_configured = true
	summary_dialog.mission_status_label.text = "MISSION COMPLETE"
	summary_dialog.mission_status_label.modulate = Color(0.25, 1.0, 0.62)
	summary_dialog.stage_name_label.text = "SEARCHLIGHT SECURITY LOCKDOWN // HELIPAD EXTRACTION COMPLETE"
	var manager := get_node_or_null("/root/StageManager")
	var next_stage_id: int = manager.get_next_registered_stage_id(stage_id) if manager else -1
	summary_dialog.next_btn.visible = next_stage_id > 0 and manager.is_stage_unlocked(next_stage_id)
	summary_dialog.retry_btn.text = "REPLAY STAGE06"
	summary_dialog.menu_btn.text = "RETURN TO HQ"

func _on_main_menu_requested() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var return_stage_id := stage_id
	var manager := get_node_or_null("/root/StageManager")
	if manager:
		var next_stage_id: int = manager.get_next_registered_stage_id(stage_id)
		if next_stage_id > 0 and manager.is_stage_unlocked(next_stage_id):
			return_stage_id = next_stage_id
	get_tree().set_meta("hq_return_stage_id", return_stage_id)
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")

func _build_night_base() -> void:
	var environment_root := $Environment
	var terrain := _group(environment_root, "Terrain")
	_box(terrain, "OuterApproach", Vector3(0, -0.5, 33), Vector3(80, 1, 18), "ground")
	_box(terrain, "InnerBase", Vector3(0, -0.5, -8), Vector3(80, 1, 64), "ground")
	_box(terrain, "SecurityRoad", Vector3(-6.5, 0.015, 3), Vector3(10, 0.03, 47), "road", false)
	_box(terrain, "GateApron", Vector3(0, 0.02, 23), Vector3(21, 0.04, 8), "road", false)
	_box(terrain, "MaintenanceTrack", Vector3(14.5, 0.02, 2), Vector3(7, 0.04, 42), "gravel", false)
	for z in range(20, -19, -7):
		_box(terrain, "RoadMarking", Vector3(-6.5, 0.045, float(z)), Vector3(0.18, 0.03, 3.2), "marking", false)

	var perimeter := _group(environment_root, "Perimeter")
	_fence_line(perimeter, "WestFence", Vector3(-40, 1.5, 0), Vector3(0.35, 3.0, 80))
	_fence_line(perimeter, "EastFence", Vector3(40, 1.5, 0), Vector3(0.35, 3.0, 80))
	_fence_line(perimeter, "NorthFence", Vector3(0, 1.5, -40), Vector3(80, 3.0, 0.35))
	_fence_line(perimeter, "SouthFence", Vector3(0, 1.5, 40), Vector3(80, 3.0, 0.35))
	_fence_line(perimeter, "GateFenceWest", Vector3(-23, 1.5, 24), Vector3(34, 3.0, 0.35))
	_fence_line(perimeter, "GateFenceEast", Vector3(23, 1.5, 24), Vector3(34, 3.0, 0.35))
	_box(perimeter, "GatePillarWest", Vector3(-6, 2.2, 24), Vector3(1.1, 4.4, 1.1), "concrete")
	_box(perimeter, "GatePillarEast", Vector3(6, 2.2, 24), Vector3(1.1, 4.4, 1.1), "concrete")
	_box(perimeter, "GateHeader", Vector3(0, 4.2, 24), Vector3(13, 0.65, 0.8), "olive", false)
	_sign(perimeter, "GateSign", Vector3(0, 4.25, 23.5), "NIGHT BASE // CHECKPOINT")
	_box(perimeter, "BarrierLeft", Vector3(-3.8, 0.65, 27.0), Vector3(4.0, 1.3, 0.55), "concrete")
	_box(perimeter, "BarrierRight", Vector3(3.8, 0.65, 21.0), Vector3(4.0, 1.3, 0.55), "concrete")

	var checkpoint := _group(environment_root, "Checkpoint")
	_box(checkpoint, "CheckpointBooth", Vector3(11, 1.55, 29), Vector3(5, 3.1, 5), "olive")
	_box(checkpoint, "BoothWindowFront", Vector3(11, 1.9, 26.47), Vector3(2.8, 1.0, 0.08), "glass", false)
	_box(checkpoint, "BoothWindowSide", Vector3(8.47, 1.9, 29), Vector3(0.08, 1.0, 2.8), "glass", false)
	_box(checkpoint, "InspectionCanopy", Vector3(-4, 3.3, 29), Vector3(13, 0.35, 6), "metal", false)
	for x in [-9.5, 1.5]:
		_box(checkpoint, "CanopyPost", Vector3(x, 1.65, 29), Vector3(0.3, 3.3, 0.3), "metal")
	_light_pole(checkpoint, "CheckpointFloodlight", Vector3(-4, 0, 25.5), Color(1.0, 0.78, 0.48), 3.0, 12.0)

	var towers := _group(environment_root, "GuardTowers")
	_build_guard_tower(towers, "WestTower", Vector3(-18, 0, 18), true)
	_build_guard_tower(towers, "EastTower", Vector3(18, 0, 18), false)

	var utility := _group(environment_root, "UtilityArea")
	_box(utility, "GeneratorBlock", Vector3(15.5, 1.1, 3), Vector3(5.5, 2.2, 3.2), "olive")
	_box(utility, "GeneratorTop", Vector3(15.5, 2.45, 3), Vector3(4.2, 0.5, 2.4), "metal", false)
	for x in [12.8, 18.2]:
		_box(utility, "UtilityFencePost", Vector3(x, 1.5, -0.5), Vector3(0.25, 3, 0.25), "metal")
	_fence_line(utility, "UtilityFence", Vector3(15.5, 1.5, -0.5), Vector3(6, 3, 0.25))
	_box(utility, "EquipmentShelter", Vector3(-18, 1.8, -3), Vector3(8, 3.6, 6), "olive")
	_box(utility, "ShelterDoor", Vector3(-13.96, 1.35, -3), Vector3(0.08, 2.7, 2.2), "dark", false)
	_sign(utility, "RestrictedSign", Vector3(20, 2.0, 1.8), "RESTRICTED // POWER")

	var storage := _group(environment_root, "StorageArea")
	_container(storage, "ContainerA", Vector3(15, 1.25, -11), Color(0.22, 0.30, 0.23))
	_container(storage, "ContainerB", Vector3(22, 1.25, -14), Color(0.30, 0.22, 0.16))
	_box(storage, "PalletStack", Vector3(11, 0.65, -8), Vector3(3.0, 1.3, 2.2), "wood")
	for position in [Vector3(-13, 0.8, 8), Vector3(-10, 0.8, -7), Vector3(10, 0.8, -17), Vector3(-11, 0.8, -20)]:
		_box(storage, "SupplyCrates", position, Vector3(2.4, 1.6, 2.4), "wood")

	var cover := _group(environment_root, "CombatCover")
	for data in [
		[Vector3(-3, 0.65, 15), Vector3(4.5, 1.3, 0.8)],
		[Vector3(-10, 0.65, 5), Vector3(5.0, 1.3, 0.8)],
		[Vector3(-9, 0.65, -5), Vector3(4.0, 1.3, 0.8)],
		[Vector3(7, 0.65, 8), Vector3(4.0, 1.3, 0.8)],
		[Vector3(18, 0.65, -2), Vector3(4.5, 1.3, 0.8)],
		[Vector3(-8, 0.65, -23), Vector3(4.5, 1.3, 0.8)],
		[Vector3(8, 0.65, -23), Vector3(4.5, 1.3, 0.8)]
	]:
		_box(cover, "ConcreteBarrier", data[0], data[1], "concrete")
	for position in [Vector3(-4, 0.45, -15), Vector3(4, 0.45, -15), Vector3(-5, 0.45, -28), Vector3(5, 0.45, -28)]:
		_sandbag_wall(cover, position)

	var helipad := _group(environment_root, "Helipad")
	_cylinder(helipad, "HelipadDeck", Vector3(0, 0.06, -17), 7.0, 0.12, "helipad")
	_ring_markers(helipad, Vector3(0, 0.15, -17), 6.4)
	_sign(helipad, "HelipadH", Vector3(0, 0.18, -17), "H", true)
	for position in [Vector3(-7, 0, -17), Vector3(7, 0, -17), Vector3(0, 0, -10), Vector3(0, 0, -24)]:
		_beacon(helipad, position)

	var command := _group(environment_root, "CommandHangar")
	_box(command, "HangarBack", Vector3(0, 3.5, -37.5), Vector3(22, 7, 1), "hangar")
	_box(command, "HangarWest", Vector3(-10.5, 3.5, -32), Vector3(1, 7, 12), "hangar")
	_box(command, "HangarEast", Vector3(10.5, 3.5, -32), Vector3(1, 7, 12), "hangar")
	_box(command, "HangarRoof", Vector3(0, 7.0, -32), Vector3(22, 0.8, 12), "hangar", false)
	_box(command, "CommandBulkhead", Vector3(0, 2.3, -35.5), Vector3(8, 4.6, 0.7), "olive")
	_box(command, "HangarDoorWest", Vector3(-7.3, 3.0, -25.9), Vector3(5.5, 6, 0.5), "metal", false)
	_box(command, "HangarDoorEast", Vector3(7.3, 3.0, -25.9), Vector3(5.5, 6, 0.5), "metal", false)
	_sign(command, "CommandSign", Vector3(0, 5.5, -25.55), "COMMAND OPERATIONS")
	_light_pole(command, "HangarFloodlightWest", Vector3(-9, 0, -24.5), Color(1.0, 0.72, 0.42), 2.4, 10.0)
	_light_pole(command, "HangarFloodlightEast", Vector3(9, 0, -24.5), Color(1.0, 0.72, 0.42), 2.4, 10.0)

func _build_guard_tower(parent: Node3D, tower_name: String, base_position: Vector3, shadowed_searchlight: bool) -> void:
	var tower := _group(parent, tower_name)
	for offset in [Vector3(-1.5, 3.0, -1.5), Vector3(1.5, 3.0, -1.5), Vector3(-1.5, 3.0, 1.5), Vector3(1.5, 3.0, 1.5)]:
		_box(tower, "TowerLeg", base_position + offset, Vector3(0.35, 6.0, 0.35), "metal")
	_box(tower, "TowerPlatform", base_position + Vector3(0, 6.1, 0), Vector3(4.6, 0.45, 4.6), "concrete")
	_box(tower, "TowerCabin", base_position + Vector3(0, 7.25, 0), Vector3(3.7, 2.0, 3.4), "olive", false)
	for offset in [Vector3(-2.2, 7.0, 0), Vector3(2.2, 7.0, 0), Vector3(0, 7.0, -2.2), Vector3(0, 7.0, 2.2)]:
		_box(tower, "TowerRail", base_position + offset, Vector3(0.15 if offset.x != 0 else 4.4, 1.2, 4.4 if offset.x != 0 else 0.15), "metal", false)
	var pivot := Node3D.new()
	pivot.name = "SearchlightPivot"
	pivot.position = base_position + Vector3(0, 8.4, -1.5)
	tower.add_child(pivot)
	var lamp := SpotLight3D.new()
	lamp.name = "Searchlight"
	lamp.rotation_degrees.x = -27.0
	lamp.light_color = Color(1.0, 0.90, 0.68)
	lamp.light_energy = 4.0
	lamp.spot_range = SEARCHLIGHT_RANGE
	lamp.spot_angle = SEARCHLIGHT_HALF_ANGLE * 2.0
	lamp.shadow_enabled = shadowed_searchlight
	pivot.add_child(lamp)
	_searchlight_pivots.append(pivot)
	_searchlight_lamps.append(lamp)

func _light_pole(parent: Node3D, node_name: String, position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var pole := _group(parent, node_name)
	_box(pole, "Pole", position + Vector3.UP * 2.6, Vector3(0.22, 5.2, 0.22), "metal")
	_box(pole, "LampHead", position + Vector3(0, 5.15, -0.35), Vector3(0.8, 0.35, 0.7), "light_fixture", false)
	var light := OmniLight3D.new()
	light.name = "SecurityLight"
	light.position = position + Vector3(0, 4.8, -0.4)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	pole.add_child(light)
	_alarm_lights.append(light)

func _beacon(parent: Node3D, position: Vector3) -> void:
	var beacon := OmniLight3D.new()
	beacon.name = "HelipadBeacon"
	beacon.position = position + Vector3.UP * 0.35
	beacon.light_color = Color(0.2, 0.8, 1.0)
	beacon.light_energy = 1.15
	beacon.omni_range = 4.2
	beacon.shadow_enabled = false
	parent.add_child(beacon)

func _ring_markers(parent: Node3D, center: Vector3, radius: float) -> void:
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var position := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_box(parent, "HelipadRing", position, Vector3(1.5, 0.03, 0.22), "marking", false, Vector3(0, -rad_to_deg(angle), 0))

func _sandbag_wall(parent: Node3D, position: Vector3) -> void:
	for row in range(2):
		for column in range(4 - row):
			var offset_x := (float(column) - float(3 - row) * 0.5) * 0.95
			_box(parent, "Sandbag", position + Vector3(offset_x, row * 0.42, 0), Vector3(0.9, 0.38, 0.55), "sandbag")

func _container(parent: Node3D, node_name: String, position: Vector3, color: Color) -> void:
	var mat_name := "container_%s" % node_name
	_mat(mat_name, color, 0.78, 0.18)
	_box(parent, node_name, position, Vector3(5.8, 2.5, 2.5), mat_name)
	for x in [-2.5, -1.25, 0.0, 1.25, 2.5]:
		_box(parent, "ContainerRib", position + Vector3(x, 0, -1.27), Vector3(0.12, 2.25, 0.08), "metal", false)

func _fence_line(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> void:
	_box(parent, node_name, position, size, "fence")
	var horizontal := size.x > size.z
	var length := size.x if horizontal else size.z
	var count := int(length / 5.0)
	for i in range(count + 1):
		var offset := -length * 0.5 + minf(float(i) * 5.0, length)
		var post_position := position + (Vector3(offset, 0, 0) if horizontal else Vector3(0, 0, offset))
		_box(parent, "%sPost" % node_name, post_position, Vector3(0.18, 3.4, 0.18), "metal", false)

func _sign(parent: Node3D, node_name: String, position: Vector3, text: String, horizontal: bool = false) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.position = position
	label.text = text
	label.font_size = 48 if not horizontal else 96
	label.modulate = Color(0.82, 0.95, 1.0)
	label.outline_size = 6
	label.no_depth_test = false
	if horizontal:
		label.rotation_degrees.x = -90.0
	parent.add_child(label)

func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node

func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material_name: String, collision: bool = true, rotation_degrees_value: Vector3 = Vector3.ZERO) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = position
		body.rotation_degrees = rotation_degrees_value
		parent.add_child(body)
		var shape_node := CollisionShape3D.new()
		shape_node.shape = _shared_box_shape(size)
		body.add_child(shape_node)
		root = body
	else:
		root = Node3D.new()
		root.name = node_name
		root.position = position
		root.rotation_degrees = rotation_degrees_value
		parent.add_child(root)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _shared_box_mesh(size, material_name)
	root.add_child(mesh_node)
	return root

func _shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := "%0.3f:%0.3f:%0.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		_box_shape_cache[key] = shape
	return _box_shape_cache[key] as BoxShape3D

func _shared_box_mesh(size: Vector3, material_name: String) -> BoxMesh:
	var key := "%0.3f:%0.3f:%0.3f:%s" % [size.x, size.y, size.z, material_name]
	if not _box_mesh_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = _materials[material_name]
		_box_mesh_cache[key] = mesh
	return _box_mesh_cache[key] as BoxMesh

func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material_name: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	mesh_node.position = position
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = _materials[material_name]
	mesh_node.mesh = mesh
	parent.add_child(mesh_node)
	return mesh_node

func _create_materials() -> void:
	_mat("ground", Color(0.065, 0.075, 0.09), 0.92)
	_mat("road", Color(0.10, 0.11, 0.13), 0.82)
	_mat("gravel", Color(0.12, 0.14, 0.16), 0.96)
	_mat("concrete", Color(0.29, 0.32, 0.35), 0.88)
	_mat("olive", Color(0.20, 0.25, 0.18), 0.84)
	_mat("hangar", Color(0.18, 0.22, 0.27), 0.68, 0.20)
	_mat("metal", Color(0.14, 0.17, 0.20), 0.62, 0.35)
	_mat("dark", Color(0.055, 0.065, 0.08), 0.75, 0.18)
	_mat("wood", Color(0.28, 0.20, 0.11), 0.92)
	_mat("sandbag", Color(0.30, 0.29, 0.20), 0.96)
	_mat("helipad", Color(0.13, 0.15, 0.18), 0.76)
	_mat("marking", Color(0.82, 0.86, 0.72), 0.66)
	_mat("light_fixture", Color(0.62, 0.68, 0.72), 0.42, 0.25)
	_mat("glass", Color(0.12, 0.32, 0.42), 0.22, 0.45, 0.72)
	_mat("fence", Color(0.22, 0.29, 0.34), 0.72, 0.22, 0.55)

func _mat(material_name: String, color: Color, roughness: float, metallic: float = 0.0, alpha: float = 1.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = roughness
	material.metallic = metallic
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[material_name] = material
