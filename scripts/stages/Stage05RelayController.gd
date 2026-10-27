class_name Stage05RelayController
extends "res://scripts/LevelBase3D.gd"
## Stage05-only high-pass controller. All defenders exist at scene start, but
## only observers can relay contact to explicitly linked terrace groups.

enum GuardMode { UNAWARE, ALERT, COMBAT }

const POLL_RATE := 0.10
const CONFIRM_TIME := 0.30
const OBSERVER_CONFIRM_TIME := 0.20
const ALERT_HOLD_TIME := 2.2
const NORMAL_VISION_RANGE := 23.0
const NORMAL_FOV_HALF_ANGLE := 72.0
const PERIPHERAL_RANGE := 8.0
const CLOSE_RANGE := 7.0
const GUNSHOT_RANGE := 30.0
const GUNSHOT_COMBAT_RANGE := 17.0
const SECTION_CHAIN_RANGE := 24.0

const GUARD_DATA := {
	"Enemy3D_1":{"role":"valley checkpoint guard","section":"valley"},
	"Enemy3D_2":{"role":"valley checkpoint guard","section":"valley"},
	"Enemy3D_3":{"role":"first terrace defender","section":"lower"},
	"Enemy3D_4":{"role":"first terrace defender","section":"lower"},
	"Enemy3D_5":{"role":"first terrace defender","section":"lower"},
	"Enemy3D_6":{"role":"lower ridge observer","section":"lower","observer":true},
	"Enemy3D_7":{"role":"upper ridge observer","section":"upper","observer":true},
	"Enemy3D_8":{"role":"upper road defender","section":"upper"},
	"Enemy3D_9":{"role":"upper road defender","section":"upper"},
	"Enemy3D_10":{"role":"service tunnel defender","section":"upper"},
	"Enemy3D_11":{"role":"service approach defender","section":"upper"},
	"Enemy3D_12":{"role":"summit relay defender","section":"summit"},
	"Enemy3D_13":{"role":"command bunker defender","section":"summit"},
	"Enemy3D_14":{"role":"command bunker defender","section":"summit"},
}

const OBSERVER_DATA := {
	"Enemy3D_6":{"range":30.0,"half_fov":52.0,"linked":["Enemy3D_3","Enemy3D_4","Enemy3D_5"]},
	"Enemy3D_7":{"range":29.0,"half_fov":50.0,"linked":["Enemy3D_8","Enemy3D_9"]},
}

const LOOK_TARGETS := {
	"Enemy3D_1":Vector3(0,0,52), "Enemy3D_2":Vector3(0,0,45),
	"Enemy3D_3":Vector3(0,4,11), "Enemy3D_4":Vector3(0,4,10), "Enemy3D_5":Vector3(7,4,-1),
	"Enemy3D_6":Vector3(2,4,7), "Enemy3D_7":Vector3(8,8,-25),
	"Enemy3D_8":Vector3(8,8,-31), "Enemy3D_9":Vector3(7,8,-35),
	"Enemy3D_10":Vector3(-12,8,-31), "Enemy3D_11":Vector3(-10,8,-38),
	"Enemy3D_12":Vector3(0,13,-65), "Enemy3D_13":Vector3(0,13,-69), "Enemy3D_14":Vector3(8,13,-72),
}

var guard_mode := {}
var alert_positions := {}
var alert_time_left := {}
var visual_time := {}
var observer_relayed := {"Enemy3D_6":false,"Enemy3D_7":false}
var _poll := 0.0
var _materials := {}
var _mesh_cache := {}
var _shape_cache := {}

func _ready() -> void:
	_build_high_pass()
	_freeze_defenders()
	super._ready()
	player.shot_fired.connect(_on_player_gunshot)
	for enemy in enemies_container.get_children():
		enemy.health_changed.connect(_on_guard_health_changed.bind(enemy))

func _physics_process(delta: float) -> void:
	_update_alert_guards(delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_RATE
		_poll_awareness()

func _freeze_defenders() -> void:
	for enemy in $Enemies.get_children():
		guard_mode[enemy.name] = GuardMode.UNAWARE
		visual_time[enemy.name] = 0.0
		alert_time_left[enemy.name] = 0.0
		enemy.set_meta("stage05_role", GUARD_DATA[enemy.name]["role"])
		enemy.set_meta("stage05_section", GUARD_DATA[enemy.name]["section"])
		enemy.set_meta("stage05_guard_mode", "unaware")
		enemy.set_physics_process(false)
		enemy.velocity = Vector3.ZERO
		_face_position(enemy, LOOK_TARGETS[enemy.name])

func _poll_awareness() -> void:
	if not player or not is_instance_valid(player):
		return
	for guard_name in GUARD_DATA:
		if guard_mode[guard_name] == GuardMode.COMBAT:
			continue
		var enemy := enemies_container.get_node_or_null(NodePath(guard_name)) as CharacterBody3D
		if not enemy or enemy.is_dead:
			continue
		if GUARD_DATA[guard_name].get("observer",false):
			_poll_observer(enemy)
		else:
			_poll_normal_guard(enemy)

func _poll_observer(enemy: CharacterBody3D) -> void:
	if observer_relayed.get(enemy.name,false):
		return
	var data: Dictionary = OBSERVER_DATA[enemy.name]
	var sight := _visual_contact(enemy,float(data["range"]),float(data["half_fov"]),PERIPHERAL_RANGE)
	if sight:
		set_guard_alert(enemy,player.global_position,"observer sighting")
		visual_time[enemy.name] += POLL_RATE
		if visual_time[enemy.name] >= OBSERVER_CONFIRM_TIME:
			trigger_observer_relay(enemy.name)
	else:
		visual_time[enemy.name] = 0.0

func _poll_normal_guard(enemy: CharacterBody3D) -> void:
	var sight := _visual_contact(enemy,NORMAL_VISION_RANGE,NORMAL_FOV_HALF_ANGLE,PERIPHERAL_RANGE)
	if sight:
		set_guard_alert(enemy,player.global_position,"local visual contact")
		var distance := enemy.global_position.distance_to(player.global_position)
		visual_time[enemy.name] += POLL_RATE
		if distance <= CLOSE_RANGE or visual_time[enemy.name] >= CONFIRM_TIME:
			activate_guard(enemy,"confirmed local contact")
	else:
		visual_time[enemy.name] = 0.0

func _visual_contact(enemy: CollisionObject3D, max_range: float, half_fov: float, peripheral_range: float) -> bool:
	var to_player := player.global_position - enemy.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance > max_range or distance <= 0.01 or not _has_line_of_sight(enemy):
		return false
	if distance <= peripheral_range:
		return true
	var forward := -enemy.global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(to_player.normalized()) >= cos(deg_to_rad(half_fov))

func _has_line_of_sight(enemy: CollisionObject3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP*1.35,player.global_position+Vector3.UP*1.25,1,[enemy.get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player

func trigger_observer_relay(observer_name: String) -> void:
	if not OBSERVER_DATA.has(observer_name) or observer_relayed.get(observer_name,false):
		return
	var observer := enemies_container.get_node_or_null(NodePath(observer_name))
	if not observer or observer.is_dead:
		return
	observer_relayed[observer_name] = true
	activate_guard(observer,"confirmed observation")
	for linked_name in OBSERVER_DATA[observer_name]["linked"]:
		var linked := enemies_container.get_node_or_null(NodePath(linked_name))
		if linked and not linked.is_dead:
			activate_guard(linked,"relay from %s"%observer_name,false)
	print("[Stage05Relay] %s relayed only to %s"%[observer_name,OBSERVER_DATA[observer_name]["linked"]])

func set_guard_alert(enemy: Node,position: Vector3,reason:="local alert") -> void:
	if not enemy or enemy.is_dead or guard_mode.get(enemy.name)==GuardMode.COMBAT:
		return
	var first_alert: bool = guard_mode.get(enemy.name)==GuardMode.UNAWARE
	guard_mode[enemy.name]=GuardMode.ALERT
	alert_positions[enemy.name]=position
	alert_time_left[enemy.name]=ALERT_HOLD_TIME
	enemy.velocity=Vector3.ZERO
	enemy.set_meta("stage05_guard_mode","alert")
	_face_position(enemy,position)
	enemy._update_locomotion_animation(false,false)
	if first_alert:
		print("[Stage05Relay] %s alert: %s"%[enemy.name,reason])

func _update_alert_guards(delta:float) -> void:
	for guard_name in guard_mode:
		if guard_mode[guard_name]!=GuardMode.ALERT:
			continue
		var enemy:=enemies_container.get_node_or_null(NodePath(String(guard_name))) as CharacterBody3D
		if not enemy or enemy.is_dead:
			continue
		alert_time_left[guard_name]=maxf(0.0,alert_time_left[guard_name]-delta)
		enemy.velocity=Vector3.ZERO
		_face_position(enemy,alert_positions.get(guard_name,enemy.global_position-enemy.global_basis.z))
		enemy._update_locomotion_animation(false,false)
		if alert_time_left[guard_name]<=0.0 and visual_time[guard_name]<=0.0:
			guard_mode[guard_name]=GuardMode.UNAWARE
			enemy.set_meta("stage05_guard_mode","unaware")

func activate_guard(enemy:Node,reason:="contact",share_section:=true) -> void:
	if not enemy or enemy.is_dead or guard_mode.get(enemy.name)==GuardMode.COMBAT:
		return
	guard_mode[enemy.name]=GuardMode.COMBAT
	enemy.set_meta("stage05_guard_mode","combat")
	enemy.velocity=Vector3.ZERO
	enemy.set_physics_process(true)
	print("[Stage05Relay] %s (%s) combat: %s"%[enemy.name,enemy.get_meta("stage05_role"),reason])
	if share_section:
		_alert_nearby_section(enemy)

func _alert_nearby_section(source:Node) -> void:
	var section:String=source.get_meta("stage05_section")
	for nearby in enemies_container.get_children():
		if nearby==source or nearby.is_dead or guard_mode.get(nearby.name)==GuardMode.COMBAT:
			continue
		if nearby.get_meta("stage05_section")!=section:
			continue
		if nearby.global_position.distance_to(source.global_position)<=SECTION_CHAIN_RANGE:
			set_guard_alert(nearby,source.global_position,"same-section combat")

func _on_player_gunshot() -> void:
	for enemy in enemies_container.get_children():
		if enemy.is_dead or guard_mode.get(enemy.name)==GuardMode.COMBAT:
			continue
		var distance:float=enemy.global_position.distance_to(player.global_position)
		var elevation_gap:float=absf(enemy.global_position.y-player.global_position.y)
		if distance>GUNSHOT_RANGE or elevation_gap>3.0:
			continue
		set_guard_alert(enemy,player.global_position,"same-terrace gunshot")
		if distance<=GUNSHOT_COMBAT_RANGE:
			activate_guard(enemy,"close same-terrace gunshot")

func _on_guard_health_changed(current_hp:int,max_hp:int,enemy:Node) -> void:
	if current_hp<=0:
		return
	if current_hp<max_hp:
		activate_guard(enemy,"incoming fire")

func _face_position(enemy:Node3D,target:Vector3) -> void:
	var flat:=target
	flat.y=enemy.global_position.y
	if enemy.global_position.distance_squared_to(flat)>0.01:
		enemy.look_at(flat,Vector3.UP)

func is_guard_active(guard_name:String)->bool:
	return guard_mode.get(guard_name)==GuardMode.COMBAT

func is_guard_alert(guard_name:String)->bool:
	return guard_mode.get(guard_name)==GuardMode.ALERT

func has_observer_relayed(observer_name:String)->bool:
	return observer_relayed.get(observer_name,false)

func get_guard_role(guard_name:String)->String:
	return GUARD_DATA.get(guard_name,{}).get("role","unknown")

func get_primary_route_waypoints()->Array[Vector3]:
	return [Vector3(0,0,52),Vector3(0,0,31),Vector3(0,4,8),Vector3(8,4,-13),Vector3(8,8,-35),Vector3(0,8,-50),Vector3(0,13,-69),Vector3(0,13,-84)]

func get_service_route_waypoints()->Array[Vector3]:
	return [Vector3(0,4,-11),Vector3(-12,4,-13),Vector3(-12,8,-35),Vector3(-7,8,-44)]

func _build_high_pass()->void:
	var e:Node3D=$Environment
	_create_materials()
	var terrain:=_group(e,"Terrain")
	_box(terrain,"ValleyFloor",Vector3(0,-.5,46),Vector3(52,1,32),"gravel")
	_box(terrain,"LowerAscent",Vector3(0,1.5,19),Vector3(38,1,24),"road",true,Vector3(10.3,0,0))
	_box(terrain,"FirstTerrace",Vector3(0,3.5,-3),Vector3(52,1,22),"gravel")
	_box(terrain,"ExposedUpperRoad",Vector3(8,5.6,-24),Vector3(18,1,27),"road",true,Vector3(10.3,0,0))
	_box(terrain,"ServiceRamp",Vector3(-12,5.6,-24),Vector3(11,1,27),"road",true,Vector3(10.3,0,0))
	_box(terrain,"UpperTerrace",Vector3(0,7.5,-42),Vector3(54,1,16),"gravel")
	_box(terrain,"SummitAscent",Vector3(0,10,-59),Vector3(34,1,20),"road",true,Vector3(15,0,0))
	_box(terrain,"SummitTerrace",Vector3(0,12.5,-79),Vector3(52,1,22),"gravel")
	# Safety is physical but visually open. The player sees a valley beyond these
	# limits rather than four giant perimeter meshes.
	_invisible_box(terrain,"WestSafetyLimit",Vector3(-27,3,-17),Vector3(2,12,142))
	_invisible_box(terrain,"EastSafetyLimit",Vector3(27,3,-17),Vector3(2,12,142))
	_invisible_box(terrain,"ValleyRearSafety",Vector3(0,2,64),Vector3(56,8,2))
	_invisible_box(terrain,"SummitRearSafety",Vector3(0,15,-94),Vector3(56,10,2))
	var valley_depth:=_group(e,"ValleyDepth")
	_box(valley_depth,"WestValleyFloor",Vector3(-58,-24,-12),Vector3(58,1,190),"valley",false,Vector3(0,0,-9))
	_box(valley_depth,"EastValleyFloor",Vector3(58,-28,-18),Vector3(58,1,190),"valley_far",false,Vector3(0,0,8))
	_distant_mountain(valley_depth,"WestValleyShoulder",Vector3(-43,-12,13),38,43,"mid_rock",7,Vector3(1.25,1.0,.8))
	_distant_mountain(valley_depth,"EastValleyShoulder",Vector3(48,-16,-20),42,47,"mid_rock",6,Vector3(1.15,1.0,.9))
	var cliffs:=_group(e,"Cliffs")
	_distant_mountain(cliffs,"LowerCliffLeft",Vector3(-31,-3,19),18,18,"rock",7,Vector3(1.0,1.0,1.5))
	_distant_mountain(cliffs,"LowerCliffRight",Vector3(32,-4,12),17,20,"rock",6,Vector3(1.1,1.0,1.4))
	_distant_mountain(cliffs,"UpperCliffFarLeft",Vector3(-33,0,-25),20,25,"rock",7,Vector3(1.1,1.0,1.45))
	_distant_mountain(cliffs,"UpperCliffCenter",Vector3(-1,1,-24),8,13,"rock",6,Vector3(1.0,1.0,1.3))
	_distant_mountain(cliffs,"UpperCliffRight",Vector3(33,1,-29),20,26,"rock",7,Vector3(1.0,1.0,1.5))
	_distant_mountain(cliffs,"SummitCliffLeft",Vector3(-34,3,-62),21,30,"rock",6,Vector3(1.1,1.0,1.45))
	_distant_mountain(cliffs,"SummitCliffRight",Vector3(35,2,-64),22,32,"rock",7,Vector3(1.0,1.0,1.4))
	var rock_faces:=_group(e,"RockFaces")
	var face_data=[
		["WestEntrance",Vector3(-25,-1,44),Vector3(12,8,14),-14],
		["EastLower",Vector3(28,0,23),Vector3(15,11,18),18],
		["WestTurn",Vector3(-28,2,4),Vector3(14,13,16),-9],
		["EastRidge",Vector3(29,3,-13),Vector3(16,14,18),13],
		["WestUpper",Vector3(-29,5,-43),Vector3(15,15,19),-12],
		["EastSummit",Vector3(29,7,-73),Vector3(15,17,18),17]
	]
	for data in face_data:
		_visual_rock(rock_faces,data[0],data[1],data[2],data[3],true)
	_build_mountain_backdrop(e)
	var retaining:=_group(e,"RetainingWalls")
	for data in [[Vector3(-19,5,-13),Vector3(14,2,.7)],[Vector3(21,5,-13),Vector3(10,2,.7)],[Vector3(-21,9,-50),Vector3(10,2,.7)],[Vector3(21,9,-50),Vector3(10,2,.7)]]:
		_box(retaining,"RetainingWall",data[0],data[1],"concrete")
	_box(retaining,"WestRoadRail",Vector3(-19,3,19),Vector3(.7,2,25),"concrete")
	_box(retaining,"EastRoadRail",Vector3(19,3,19),Vector3(.7,2,25),"concrete")
	_box(retaining,"SummitRailWest",Vector3(-17,12,-59),Vector3(.7,2,20),"concrete")
	_box(retaining,"SummitRailEast",Vector3(17,12,-59),Vector3(.7,2,20),"concrete")
	var checkpoint:=_group(e,"Checkpoint")
	_box(checkpoint,"GuardPost",Vector3(-17,1.4,44),Vector3(6,2.8,6),"olive")
	_box(checkpoint,"BarrierWest",Vector3(-7,.65,36),Vector3(8,1.3,.8),"concrete")
	_box(checkpoint,"BarrierEast",Vector3(8,.65,32),Vector3(8,1.3,.8),"concrete")
	_box(checkpoint,"SecurityFenceWest",Vector3(-22,1.5,34),Vector3(.3,3,18),"metal")
	_box(checkpoint,"SecurityFenceEast",Vector3(22,1.5,34),Vector3(.3,3,18),"metal")
	var buildings:=_group(e,"Buildings")
	var bunker:=_group(buildings,"CheckpointBunker")
	_box(bunker,"BunkerBody",Vector3(-16,15,-82),Vector3(13,4,10),"olive")
	_box(bunker,"BunkerDoor",Vector3(-9.4,14.3,-80),Vector3(.3,2.6,3),"metal",false)
	var tower:=_group(buildings,"SniperTower")
	_box(tower,"ObservationPost",Vector3(21,5.8,0),Vector3(5,3.6,5),"olive")
	_box(tower,"Support",Vector3(21,4.5,0),Vector3(1.2,2,1.2),"metal")
	var tunnel:=_group(e,"ServiceTunnel")
	_box(tunnel,"WestWall",Vector3(-17.1,8,-24),Vector3(.7,4.5,22),"dark",true,Vector3(10.3,0,0))
	_box(tunnel,"EastWall",Vector3(-6.9,8,-24),Vector3(.7,4.5,22),"dark",true,Vector3(10.3,0,0))
	_box(tunnel,"Roof",Vector3(-12,10,-24),Vector3(11,1,22),"dark",true,Vector3(10.3,0,0))
	_box(tunnel,"WarningBand",Vector3(-12,8.7,-34.8),Vector3(8,.35,.15),"warning",false,Vector3(10.3,0,0))
	for p in [Vector3(-12,8,-18),Vector3(-12,9,-30)]:
		var tunnel_light:=OmniLight3D.new();tunnel_light.name="TunnelSafetyLight";tunnel_light.position=p
		tunnel_light.light_color=Color(.62,.78,1);tunnel_light.light_energy=2.1;tunnel_light.omni_range=8;tunnel_light.shadow_enabled=false;tunnel.add_child(tunnel_light)
	var boulders:=_group(e,"Boulders")
	_rock(boulders,"Boulder1",Vector3(-17,2,27),Vector3(6,4,6))
	_rock(boulders,"Boulder2",Vector3(14,2,16),Vector3(7,4,6))
	_rock(boulders,"RidgeOccluderLower",Vector3(12,6.5,-1),Vector3(7,5,7))
	_rock(boulders,"UpperRidge",Vector3(19,10,-35),Vector3(7,5,8))
	_rock(boulders,"SummitRock",Vector3(-20,15,-70),Vector3(8,5,7))
	var cover:=_group(e,"Cover")
	for data in [[Vector3(-8,.7,45),Vector3(5,1.4,.8)],[Vector3(7,4.7,3),Vector3(5,1.4,.8)],[Vector3(-14,4.7,-7),Vector3(5,1.4,.8)],[Vector3(8,8.7,-42),Vector3(5,1.4,.8)],[Vector3(-9,8.7,-46),Vector3(5,1.4,.8)],[Vector3(7,13.7,-73),Vector3(5,1.4,.8)]]:
		_box(cover,"ConcreteBarrier",data[0],data[1],"concrete")
	var equipment:=_group(e,"Equipment")
	_box(equipment,"Generator",Vector3(-18,13.9,-72),Vector3(4,1.8,3),"olive")
	_box(equipment,"CrateStackLower",Vector3(-5,4.8,-8),Vector3(3,1.6,3),"wood")
	_box(equipment,"CrateStackUpper",Vector3(15,8.8,-38),Vector3(3,1.6,3),"wood")
	for p in [Vector3(-20,2,39),Vector3(17,6,-7),Vector3(-20,10,-45),Vector3(18,15,-76)]:
		_box(equipment,"UtilityPole",p,Vector3(.35,4,.35),"metal")
	var relay:=_group(e,"SummitRelay")
	_box(relay,"RelayBase",Vector3(5,13.6,-85),Vector3(9,1.2,7),"concrete")
	_box(relay,"Mast",Vector3(5,22,-85),Vector3(1,17,1),"metal")
	_box(relay,"CrossBeamA",Vector3(5,20,-85),Vector3(8,.45,.45),"metal",false)
	_box(relay,"CrossBeamB",Vector3(5,24,-85),Vector3(6,.45,.45),"metal",false)
	_cylinder(relay,"RadarDish",Vector3(5,26,-85),3,.55,"light_metal",Vector3(70,0,0),false)
	_box(relay,"AntennaTip",Vector3(5,29,-85),Vector3(.35,6,.35),"warning",false)
	var snow:=_group(e,"SnowPatches")
	_box(snow,"SnowUpperA",Vector3(-21,13.04,-85),Vector3(7,.08,4),"snow",false)
	_box(snow,"SnowUpperB",Vector3(19,13.04,-69),Vector3(6,.08,3),"snow",false)
	var alpine:=_group(e,"AlpineDetails")
	for p in [Vector3(-21,.4,31),Vector3(22,.5,9),Vector3(-20,4.4,-1),Vector3(20,8.4,-45),Vector3(-18,13.4,-65)]:
		_visual_rock(alpine,"GravelShoulder",p,Vector3(3,.7,2),17,false)
	for p in [Vector3(-18,.5,24),Vector3(20,.5,29),Vector3(-20,4.5,-7),Vector3(19,8.5,-39),Vector3(-21,13.5,-78)]:
		_box(alpine,"AlpineShrub",p,Vector3(.9,1.0,.9),"shrub",false,Vector3(0,23,12))
	_box(alpine,"WarningSignPost",Vector3(18,1.5,20),Vector3(.18,3,.18),"metal",false)
	_box(alpine,"WarningSign",Vector3(18,2.6,20),Vector3(2.4,1.1,.15),"warning",false,Vector3(0,-18,0))

func _create_materials()->void:
	_mat("gravel",Color(.28,.30,.31),.96);_mat("road",Color(.22,.24,.25),.92)
	_mat("rock",Color(.25,.28,.31),.94);_mat("concrete",Color(.40,.42,.43),.88)
	_mat("olive",Color(.25,.29,.20),.82);_mat("metal",Color(.15,.18,.20),.62,.3)
	_mat("dark",Color(.10,.12,.14),.75,.2);_mat("warning",Color(.75,.50,.08),.75)
	_mat("wood",Color(.30,.22,.12),.9);_mat("light_metal",Color(.55,.58,.60),.58,.35)
	_mat("snow",Color(.78,.84,.88),.9);_mat("shrub",Color(.18,.24,.17),.98)
	_mat("valley",Color(.10,.16,.20),1.0);_mat("valley_far",Color(.15,.22,.28),1.0)
	_mat("mid_rock",Color(.28,.34,.39),.98);_mat("far_mountain",Color(.34,.43,.52),1.0)
	_mat("horizon_mountain",Color(.47,.56,.64),1.0)

func _mat(key:String,color:Color,roughness:float,metallic:=0.0)->void:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=roughness;m.metallic=metallic;_materials[key]=m

func _group(parent:Node3D,node_name:String)->Node3D:
	var n:=Node3D.new();n.name=node_name;parent.add_child(n);return n

func _box(parent:Node3D,node_name:String,pos:Vector3,size:Vector3,mat:String,collision:=true,rot:=Vector3.ZERO)->Node3D:
	var root:Node3D=StaticBody3D.new() if collision else Node3D.new();root.name=node_name;root.position=pos;root.rotation_degrees=rot;parent.add_child(root)
	var key:="%s:%s"%[size,mat];var mesh:BoxMesh=_mesh_cache.get(key)
	if not mesh:mesh=BoxMesh.new();mesh.size=size;mesh.material=_materials[mat];_mesh_cache[key]=mesh
	var mi:=MeshInstance3D.new();mi.name="Mesh";mi.mesh=mesh;root.add_child(mi)
	if collision:
		var skey:=str(size);var shape:BoxShape3D=_shape_cache.get(skey)
		if not shape:shape=BoxShape3D.new();shape.size=size;_shape_cache[skey]=shape
		var cs:=CollisionShape3D.new();cs.name="Collision";cs.shape=shape;root.add_child(cs)
	return root

func _invisible_box(parent:Node3D,node_name:String,pos:Vector3,size:Vector3)->StaticBody3D:
	var root:=StaticBody3D.new();root.name=node_name;root.position=pos;parent.add_child(root)
	var shape:=BoxShape3D.new();shape.size=size
	var cs:=CollisionShape3D.new();cs.name="Collision";cs.shape=shape;root.add_child(cs)
	return root

func _visual_rock(parent:Node3D,node_name:String,pos:Vector3,size:Vector3,yaw:float,collision:=false)->Node3D:
	var root:Node3D=StaticBody3D.new() if collision else Node3D.new();root.name=node_name;root.position=pos;root.rotation_degrees.y=yaw;parent.add_child(root)
	var mesh:=SphereMesh.new();mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=8;mesh.rings=4;mesh.material=_materials["rock"]
	var mi:=MeshInstance3D.new();mi.name="Mesh";mi.mesh=mesh;mi.scale=Vector3(size.x*.5,size.y*.5,size.z*.5);root.add_child(mi)
	if collision:
		var shape:=BoxShape3D.new();shape.size=Vector3(size.x*.82,size.y*.82,size.z*.82)
		var cs:=CollisionShape3D.new();cs.name="Collision";cs.shape=shape;root.add_child(cs)
	return root

func _distant_mountain(parent:Node3D,node_name:String,pos:Vector3,radius:float,height:float,mat:String,sides:int,stretch:=Vector3.ONE)->Node3D:
	var root:=Node3D.new();root.name=node_name;root.position=pos;root.rotation_degrees.y=float(node_name.hash()%37);parent.add_child(root)
	var mesh:=CylinderMesh.new();mesh.top_radius=0.0;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=sides;mesh.rings=1;mesh.material=_materials[mat]
	var mi:=MeshInstance3D.new();mi.name="Silhouette";mi.mesh=mesh;mi.scale=stretch;root.add_child(mi)
	return root

func _build_mountain_backdrop(parent:Node3D)->void:
	var backdrop:=_group(parent,"MountainBackdrop")
	# Mid-distance ridges frame the road but leave large gaps of sky and horizon.
	var mid=[
		["MidWestA",Vector3(-78,-11,42),34.0,58.0,Vector3(1.35,1.0,.9)],
		["MidWestB",Vector3(-92,-15,-35),42.0,68.0,Vector3(1.15,1.0,1.0)],
		["MidEastA",Vector3(82,-13,25),37.0,62.0,Vector3(1.25,1.0,.9)],
		["MidEastB",Vector3(96,-17,-58),46.0,74.0,Vector3(1.1,1.0,1.0)],
		["MidSummitA",Vector3(-48,-12,-142),40.0,72.0,Vector3(1.2,1.0,.8)],
		["MidSummitB",Vector3(48,-15,-153),45.0,78.0,Vector3(1.25,1.0,.85)]
	]
	for d in mid:_distant_mountain(backdrop,d[0],d[1],d[2],d[3],"mid_rock",7,d[4])
	# Far and horizon layers are visual-only, low-poly silhouettes lightened by distance.
	var far=[
		["FarWest",Vector3(-175,-25,-35),70.0,112.0],
		["FarNorthWest",Vector3(-105,-30,-225),76.0,126.0],
		["FarNorth",Vector3(5,-35,-250),88.0,142.0],
		["FarNorthEast",Vector3(118,-31,-218),78.0,123.0],
		["FarEast",Vector3(185,-28,-15),74.0,116.0],
		["FarSouthEast",Vector3(135,-36,155),84.0,128.0],
		["FarSouth",Vector3(0,-42,210),92.0,136.0],
		["FarSouthWest",Vector3(-140,-34,150),80.0,124.0]
	]
	for d in far:_distant_mountain(backdrop,d[0],d[1],d[2],d[3],"far_mountain",6,Vector3(1.25,1.0,.85))
	for d in [["HorizonNW",Vector3(-250,-45,-260)],["HorizonN",Vector3(0,-52,-330)],["HorizonNE",Vector3(250,-44,-245)],["HorizonS",Vector3(0,-58,320)]]:
		_distant_mountain(backdrop,d[0],d[1],115,165,"horizon_mountain",5,Vector3(1.45,1.0,.8))

func _cylinder(parent:Node3D,node_name:String,pos:Vector3,radius:float,height:float,mat:String,rot:=Vector3.ZERO,collision:=true)->Node3D:
	var root:Node3D=StaticBody3D.new() if collision else Node3D.new();root.name=node_name;root.position=pos;root.rotation_degrees=rot;parent.add_child(root)
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12;mesh.material=_materials[mat]
	var mi:=MeshInstance3D.new();mi.name="Mesh";mi.mesh=mesh;root.add_child(mi)
	if collision:
		var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height;var cs:=CollisionShape3D.new();cs.name="Collision";cs.shape=shape;root.add_child(cs)
	return root

func _rock(parent:Node3D,node_name:String,pos:Vector3,size:Vector3)->void:
	_cylinder(parent,node_name,pos,maxf(size.x,size.z)*.5,size.y,"rock",Vector3(0,17,8))
