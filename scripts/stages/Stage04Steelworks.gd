class_name Stage04Steelworks
extends "res://scripts/LevelBase3D.gd"
## Stage04-local steelworks controller. Inactive guards have no Player target;
## patrol motion is local. Contact hands control to the existing Enemy3D AI.

const PATROL_SPEED := 1.35
const NORMAL_VISION_DISTANCE := 21.0
const NORMAL_FOV_HALF_ANGLE_DEGREES := 70.0
const PERIPHERAL_VISION_DISTANCE := 9.0
const CLOSE_AWARENESS_DISTANCE := 6.5
const VISUAL_CONFIRM_TIME := 0.36
const GUNSHOT_HEARING_DISTANCE := 24.0
const GUNSHOT_DIRECT_CONTACT_DISTANCE := 12.0
const LOCAL_ALERT_RADIUS := 20.0
const SUSPICIOUS_HOLD_TIME := 2.5
enum AwarenessState { UNAWARE, SUSPICIOUS, COMBAT }
const GUARD_DATA := {
	"Enemy3D_1": {"role":"patrol", "awareness":15.0, "route":[Vector3(-14,0,21), Vector3(-6,0,21)]},
	"Enemy3D_2": {"role":"patrol", "awareness":15.0, "route":[Vector3(13,0,9), Vector3(20,0,3)]},
	"Enemy3D_3": {"role":"patrol", "awareness":14.0, "route":[Vector3(-18,0,-10), Vector3(-11,0,-18)]},
	"Enemy3D_4": {"role":"patrol", "awareness":14.0, "route":[Vector3(9,0,-22), Vector3(17,0,-22)]},
	"Enemy3D_5": {"role":"defensive", "awareness":14.0},
	"Enemy3D_6": {"role":"defensive", "awareness":14.0},
	"Enemy3D_7": {"role":"defensive", "awareness":13.0},
	"Enemy3D_8": {"role":"defensive", "awareness":13.0},
	"Enemy3D_9": {"role":"deep", "awareness":12.0},
	"Enemy3D_10": {"role":"deep", "awareness":12.0},
	"Enemy3D_11": {"role":"deep", "awareness":11.0},
	"Enemy3D_12": {"role":"deep", "awareness":11.0},
}
const GUARD_LOOK_TARGETS := {
	"Enemy3D_5": Vector3(0,0,24), "Enemy3D_6": Vector3(8,0,2),
	"Enemy3D_7": Vector3(-8,0,-20), "Enemy3D_8": Vector3(0,0,-27),
	"Enemy3D_9": Vector3(-7,0,-35), "Enemy3D_10": Vector3(7,0,-36),
	"Enemy3D_11": Vector3(-3,0,-48), "Enemy3D_12": Vector3(4,0,-49),
}

var guard_active := {}
var guard_awareness := {}
var patrol_targets := {}
var suspicious_positions := {}
var suspicious_time_left := {}
var visual_confirmation := {}
var _contact_poll := 0.0
var _materials := {}
var _mesh_cache := {}
var _shape_cache := {}

func _ready() -> void:
	_build_steelworks()
	_freeze_guards()
	super._ready()
	player.shot_fired.connect(_on_stage04_player_gunshot)
	for enemy in enemies_container.get_children():
		enemy.health_changed.connect(_on_guard_health_changed.bind(enemy))

func _physics_process(delta: float) -> void:
	_update_suspicious_guards(delta)
	_update_patrols()
	_contact_poll -= delta
	if _contact_poll <= 0.0:
		_contact_poll = 0.12
		_check_contacts()

func _freeze_guards() -> void:
	for enemy in $Enemies.get_children():
		guard_active[enemy.name] = false
		guard_awareness[enemy.name] = AwarenessState.UNAWARE
		visual_confirmation[enemy.name] = 0.0
		suspicious_time_left[enemy.name] = 0.0
		enemy.set_meta("stage04_role", GUARD_DATA[enemy.name]["role"])
		enemy.set_meta("stage04_contact_active", false)
		enemy.set_meta("stage04_awareness", "unaware")
		enemy.set_physics_process(false)
		enemy.velocity = Vector3.ZERO
		if GUARD_DATA[enemy.name]["role"] == "patrol":
			patrol_targets[enemy.name] = 1
		elif GUARD_LOOK_TARGETS.has(enemy.name):
			_face_position(enemy, GUARD_LOOK_TARGETS[enemy.name])

func _on_guard_health_changed(current_hp: int, max_hp: int, enemy: Node) -> void:
	if current_hp < max_hp:
		activate_guard(enemy, "incoming fire")

func _on_stage04_player_gunshot() -> void:
	var gunshot_position := player.global_position
	for enemy in enemies_container.get_children():
		if enemy.is_dead or guard_awareness.get(enemy.name) == AwarenessState.COMBAT:
			continue
		var distance: float = enemy.global_position.distance_to(gunshot_position)
		if distance > GUNSHOT_HEARING_DISTANCE:
			continue
		make_guard_suspicious(enemy, gunshot_position, "nearby gunshot", SUSPICIOUS_HOLD_TIME)
		if distance <= GUNSHOT_DIRECT_CONTACT_DISTANCE and _has_line_of_sight(enemy):
			activate_guard(enemy, "visible nearby gunshot")

func _update_suspicious_guards(delta: float) -> void:
	for guard_name in guard_awareness:
		if guard_awareness[guard_name] != AwarenessState.SUSPICIOUS:
			continue
		var enemy := enemies_container.get_node_or_null(NodePath(String(guard_name))) as CharacterBody3D
		if not enemy or enemy.is_dead:
			continue
		suspicious_time_left[guard_name] = maxf(0.0, suspicious_time_left[guard_name] - delta)
		enemy.velocity = Vector3.ZERO
		_face_position(enemy, suspicious_positions.get(guard_name, enemy.global_position - enemy.global_basis.z))
		enemy._update_locomotion_animation(false, false)
		if suspicious_time_left[guard_name] <= 0.0 and visual_confirmation[guard_name] <= 0.0:
			guard_awareness[guard_name] = AwarenessState.UNAWARE
			enemy.set_meta("stage04_awareness", "unaware")

func _update_patrols() -> void:
	for guard_name in patrol_targets:
		if guard_awareness[guard_name] != AwarenessState.UNAWARE:
			continue
		var enemy := enemies_container.get_node_or_null(NodePath(String(guard_name))) as CharacterBody3D
		if not enemy or enemy.is_dead:
			continue
		var route: Array = GUARD_DATA[guard_name]["route"]
		var index: int = patrol_targets[guard_name]
		var offset: Vector3 = route[index] - enemy.global_position
		offset.y = 0.0
		if offset.length() < 0.55:
			index = 1 - index
			patrol_targets[guard_name] = index
			offset = route[index] - enemy.global_position
			offset.y = 0.0
		var direction := offset.normalized()
		enemy.look_at(enemy.global_position + direction, Vector3.UP)
		enemy.velocity = Vector3(direction.x * PATROL_SPEED, -0.1, direction.z * PATROL_SPEED)
		enemy.move_and_slide()
		enemy._update_locomotion_animation(true, false)

func _check_contacts() -> void:
	if not player or not is_instance_valid(player):
		return
	for guard_name in GUARD_DATA:
		if guard_awareness[guard_name] == AwarenessState.COMBAT:
			continue
		var enemy := enemies_container.get_node_or_null(NodePath(String(guard_name))) as CharacterBody3D
		if not enemy or enemy.is_dead:
			continue
		var to_player := player.global_position - enemy.global_position
		to_player.y = 0.0
		var distance := to_player.length()
		var visible := distance <= NORMAL_VISION_DISTANCE and _has_line_of_sight(enemy)
		var forward := -enemy.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var in_normal_fov := visible and distance > 0.01 and forward.dot(to_player.normalized()) >= cos(deg_to_rad(NORMAL_FOV_HALF_ANGLE_DEGREES))
		var in_peripheral_range := visible and distance <= PERIPHERAL_VISION_DISTANCE
		var extremely_close := visible and distance <= CLOSE_AWARENESS_DISTANCE
		if extremely_close:
			make_guard_suspicious(enemy, player.global_position, "close visual contact", SUSPICIOUS_HOLD_TIME)
			activate_guard(enemy, "close visual contact")
		elif in_normal_fov or in_peripheral_range:
			make_guard_suspicious(enemy, player.global_position, "visual suspicion", SUSPICIOUS_HOLD_TIME)
			visual_confirmation[guard_name] += 0.12
			if visual_confirmation[guard_name] >= VISUAL_CONFIRM_TIME:
				activate_guard(enemy, "confirmed visual contact")
		else:
			visual_confirmation[guard_name] = 0.0

func _has_line_of_sight(enemy: CollisionObject3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 1.35, player.global_position + Vector3.UP * 1.25, 1, [enemy.get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func activate_guard(enemy: Node, reason := "contact") -> void:
	if not enemy or guard_active.get(enemy.name, false) or enemy.is_dead:
		return
	guard_active[enemy.name] = true
	guard_awareness[enemy.name] = AwarenessState.COMBAT
	enemy.set_meta("stage04_contact_active", true)
	enemy.set_meta("stage04_awareness", "combat")
	enemy.velocity = Vector3.ZERO
	enemy.set_physics_process(true)
	print("[Stage04Steelworks] %s (%s) activated by %s" % [enemy.name, enemy.get_meta("stage04_role"), reason])
	_share_local_alert(enemy.global_position, enemy)

func make_guard_suspicious(enemy: Node, contact_position: Vector3, reason := "local alert", hold_time := SUSPICIOUS_HOLD_TIME) -> void:
	if not enemy or enemy.is_dead or guard_awareness.get(enemy.name) == AwarenessState.COMBAT:
		return
	var was_unaware: bool = guard_awareness.get(enemy.name) == AwarenessState.UNAWARE
	guard_awareness[enemy.name] = AwarenessState.SUSPICIOUS
	suspicious_positions[enemy.name] = contact_position
	suspicious_time_left[enemy.name] = maxf(suspicious_time_left.get(enemy.name, 0.0), hold_time)
	enemy.velocity = Vector3.ZERO
	enemy.set_meta("stage04_awareness", "suspicious")
	_face_position(enemy, contact_position)
	enemy._update_locomotion_animation(false, false)
	if was_unaware:
		print("[Stage04Steelworks] %s became suspicious: %s" % [enemy.name, reason])

func _share_local_alert(contact_position: Vector3, source_enemy: Node) -> void:
	for nearby in enemies_container.get_children():
		if nearby == source_enemy or nearby.is_dead or guard_awareness.get(nearby.name) == AwarenessState.COMBAT:
			continue
		if nearby.global_position.distance_to(contact_position) <= LOCAL_ALERT_RADIUS:
			make_guard_suspicious(nearby, contact_position, "nearby guard contact", 2.0)

func _face_position(enemy: Node3D, contact_position: Vector3) -> void:
	var flat_target := contact_position
	flat_target.y = enemy.global_position.y
	if enemy.global_position.distance_squared_to(flat_target) > 0.01:
		enemy.look_at(flat_target, Vector3.UP)

func is_guard_active(guard_name: String) -> bool:
	return guard_active.get(guard_name, false)

func is_guard_suspicious(guard_name: String) -> bool:
	return guard_awareness.get(guard_name) == AwarenessState.SUSPICIOUS

func get_guard_role(guard_name: String) -> String:
	return GUARD_DATA.get(guard_name, {}).get("role", "unknown")

func get_patrol_route(guard_name: String) -> Array:
	return GUARD_DATA.get(guard_name, {}).get("route", []).duplicate()

func _build_steelworks() -> void:
	var e: Node3D = $Environment
	_create_materials()
	_box(e,"Ground",Vector3(0,-0.5,-6),Vector3(58,1,116),"asphalt")
	var perimeter := _group(e,"Perimeter")
	_box(perimeter,"WestWall",Vector3(-29,2,-6),Vector3(1,4,116),"concrete")
	_box(perimeter,"EastWall",Vector3(29,2,-6),Vector3(1,4,116),"concrete")
	_box(perimeter,"NorthWall",Vector3(0,2,-64),Vector3(58,4,1),"concrete")
	_box(perimeter,"EntryFenceLeft",Vector3(-19,1.4,51),Vector3(20,2.8,.25),"steel")
	_box(perimeter,"EntryFenceRight",Vector3(19,1.4,51),Vector3(20,2.8,.25),"steel")
	_box(perimeter,"SecurityGateLeft",Vector3(-5.5,1.6,49.8),Vector3(.35,3.2,4),"yellow")
	_box(perimeter,"SecurityGateRight",Vector3(5.5,1.6,49.8),Vector3(.35,3.2,4),"yellow")
	var entry := _group(e,"SecurityArea")
	_box(entry,"SecurityBooth",Vector3(-20,1.5,42),Vector3(6,3,7),"steel")
	_box(entry,"BoothWindow",Vector3(-16.95,1.8,42),Vector3(.12,1.1,3.2),"window",false)
	_box(entry,"CheckpointBarrierA",Vector3(-7,.55,36),Vector3(7,1.1,.7),"concrete")
	_box(entry,"CheckpointBarrierB",Vector3(8,.55,32),Vector3(7,1.1,.7),"concrete")
	_box(entry,"Generator",Vector3(20,.9,36),Vector3(4,1.8,2.5),"rust")
	_box(entry,"GeneratorStripe",Vector3(20,1.25,34.72),Vector3(2.5,.35,.08),"yellow",false)
	var containers := _group(e,"Containers")
	_box(containers,"ContainerRed1",Vector3(-20,1.5,25),Vector3(4,3,11),"red")
	_box(containers,"ContainerBlue1",Vector3(-10,1.5,13),Vector3(4,3,11),"blue")
	_box(containers,"ContainerBlue2",Vector3(19,1.5,19),Vector3(4,3,11),"blue")
	_box(containers,"ContainerRed2",Vector3(10,1.5,1),Vector3(4,3,11),"red")
	_box(containers,"ContainerGray",Vector3(-21,1.5,2),Vector3(4,3,10),"steel")
	var freight := _group(e,"FreightYard")
	_box(freight,"LoadingPlatform",Vector3(0,.6,24),Vector3(13,1.2,5),"concrete")
	_box(freight,"PlatformRamp",Vector3(0,.3,20.8),Vector3(5,.6,1.5),"steel")
	_box(freight,"ForkliftBody",Vector3(15,.7,31),Vector3(2.2,1.4,3),"yellow")
	_box(freight,"ForkliftMast",Vector3(15,1.8,29.4),Vector3(2.1,3,.25),"steel")
	_box(freight,"PalletStackA",Vector3(-3,.55,10),Vector3(3.5,1.1,2.5),"wood")
	_box(freight,"PalletStackB",Vector3(21,.55,8),Vector3(3,1.1,3),"wood")
	for i in 4:
		_box(freight,"LaneBarrier%d"%(i+1),Vector3(-6+i*4.0,.45,-4),Vector3(2.8,.9,.6),"concrete")
	var buildings := _group(e,"Buildings")
	var warehouse := _group(buildings,"Warehouse")
	_box(warehouse,"WestWall",Vector3(-23,3.2,-19),Vector3(1,6.4,28),"dark")
	_box(warehouse,"EastWall",Vector3(23,3.2,-19),Vector3(1,6.4,28),"dark")
	_box(warehouse,"Roof",Vector3(0,6.3,-19),Vector3(47,.5,28),"steel",false)
	_box(warehouse,"FrontLintel",Vector3(0,5.1,-5),Vector3(47,2.4,.7),"dark")
	_box(warehouse,"RearLintel",Vector3(0,5.1,-33),Vector3(47,2.4,.7),"dark")
	var machinery := _group(e,"Machinery")
	_box(machinery,"RollingMillA",Vector3(-13,1.25,-13),Vector3(7,2.5,4),"rust")
	_box(machinery,"RollingMillB",Vector3(13,1.25,-15),Vector3(7,2.5,4),"steel")
	_box(machinery,"PressHousing",Vector3(0,1.8,-24),Vector3(8,3.6,5),"dark")
	_box(machinery,"PressHazardBand",Vector3(0,2.4,-21.45),Vector3(6,.45,.08),"yellow",false)
	_box(machinery,"MaintenanceBench",Vector3(-12,.8,-27),Vector3(5,1.6,2),"steel")
	_box(machinery,"MotorBank",Vector3(15,.9,-28),Vector3(5,1.8,3),"blue")
	var silos := _group(e,"Silos")
	_cylinder(silos,"Silo1",Vector3(-17,3.4,-39),3.2,6.8,"tank")
	_cylinder(silos,"Silo2",Vector3(17,3.4,-39),3.2,6.8,"tank")
	var pipes := _group(e,"Pipes")
	_cylinder(pipes,"OverheadPipe",Vector3(0,4.8,-36),.38,34,"pipe",Vector3(0,0,90),false)
	_box(pipes,"PipeSupportWest",Vector3(-17,2.5,-36),Vector3(.7,5,.7),"dark")
	_box(pipes,"PipeSupportEast",Vector3(17,2.5,-36),Vector3(.7,5,.7),"dark")
	var catwalk := _group(e,"Catwalk")
	_box(catwalk,"MaintenancePlatform",Vector3(0,3.5,-31),Vector3(14,.45,2.2),"steel",false)
	_box(catwalk,"RailLeft",Vector3(0,4.2,-32),Vector3(14,.12,.12),"yellow",false)
	_box(catwalk,"RailRight",Vector3(0,4.2,-30),Vector3(14,.12,.12),"yellow",false)
	var ops := _group(e,"Operations")
	_box(ops,"ControlFloor",Vector3(0,.15,-52),Vector3(35,.3,21),"concrete")
	_box(ops,"ControlRoomRear",Vector3(0,2.7,-61),Vector3(35,5.4,1),"dark")
	_box(ops,"ControlRoomWest",Vector3(-17,2.7,-52),Vector3(1,5.4,18),"dark")
	_box(ops,"ControlRoomEast",Vector3(17,2.7,-52),Vector3(1,5.4,18),"dark")
	_box(ops,"ConsoleWest",Vector3(-9,1,-52),Vector3(5,2,2),"blue")
	_box(ops,"ConsoleEast",Vector3(9,1,-52),Vector3(5,2,2),"blue")
	_box(ops,"SupervisorDesk",Vector3(0,.8,-58),Vector3(5,1.6,2.2),"rust")
	_box(ops,"BlastBarrierWest",Vector3(-9,.7,-43),Vector3(5,1.4,.8),"concrete")
	_box(ops,"BlastBarrierEast",Vector3(9,.7,-43),Vector3(5,1.4,.8),"concrete")
	for p in [Vector3(-18,4.8,35),Vector3(18,4.8,12),Vector3(-12,4.8,-13),Vector3(12,4.8,-13),Vector3(-12,4.8,-27),Vector3(12,4.8,-27),Vector3(0,4.8,-54)]:
		var lamp := OmniLight3D.new()
		lamp.name="IndustrialLamp"; lamp.position=p; lamp.light_color=Color(1,.72,.46); lamp.light_energy=4.0; lamp.omni_range=15; lamp.shadow_enabled=false
		e.add_child(lamp)

func _create_materials() -> void:
	_mat("asphalt",Color(.105,.11,.12),.95); _mat("concrete",Color(.30,.31,.31),.9)
	_mat("steel",Color(.27,.29,.30),.72,.18); _mat("dark",Color(.12,.14,.15),.68,.25)
	_mat("rust",Color(.36,.17,.09),.88); _mat("red",Color(.43,.105,.07),.82)
	_mat("blue",Color(.075,.17,.25),.78); _mat("yellow",Color(.78,.53,.08),.72)
	_mat("wood",Color(.31,.20,.10),.92); _mat("tank",Color(.46,.48,.47),.62,.25)
	_mat("pipe",Color(.22,.24,.25),.58,.32); _mat("window",Color(.08,.16,.19),.28,.18)

func _mat(key:String,color:Color,roughness:float,metallic:=0.0) -> void:
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=roughness; m.metallic=metallic; _materials[key]=m

func _group(parent:Node3D,node_name:String) -> Node3D:
	var n:=Node3D.new(); n.name=node_name; parent.add_child(n); return n

func _box(parent:Node3D,node_name:String,pos:Vector3,size:Vector3,material_key:String,collision:=true) -> Node3D:
	var root:Node3D = StaticBody3D.new() if collision else Node3D.new(); root.name=node_name; root.position=pos; parent.add_child(root)
	var key:="%s:%s"%[size,material_key]; var mesh:BoxMesh=_mesh_cache.get(key)
	if not mesh: mesh=BoxMesh.new(); mesh.size=size; mesh.material=_materials[material_key]; _mesh_cache[key]=mesh
	var mi:=MeshInstance3D.new(); mi.name="Mesh"; mi.mesh=mesh; root.add_child(mi)
	if collision:
		var skey:=str(size); var shape:BoxShape3D=_shape_cache.get(skey)
		if not shape: shape=BoxShape3D.new(); shape.size=size; _shape_cache[skey]=shape
		var cs:=CollisionShape3D.new(); cs.name="Collision"; cs.shape=shape; root.add_child(cs)
	return root

func _cylinder(parent:Node3D,node_name:String,pos:Vector3,radius:float,height:float,material_key:String,rot:=Vector3.ZERO,collision:=true) -> Node3D:
	var root:Node3D = StaticBody3D.new() if collision else Node3D.new(); root.name=node_name; root.position=pos; root.rotation_degrees=rot; parent.add_child(root)
	var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=16; mesh.material=_materials[material_key]
	var mi:=MeshInstance3D.new(); mi.name="Mesh"; mi.mesh=mesh; root.add_child(mi)
	if collision:
		var shape:=CylinderShape3D.new(); shape.radius=radius; shape.height=height
		var cs:=CollisionShape3D.new(); cs.name="Collision"; cs.shape=shape; root.add_child(cs)
	return root
