class_name Stage03Blacksite
extends Node3D
## Performance-conscious modern communications blacksite used only by Stage 03.

var mat: Dictionary = {}

func _ready() -> void:
	_palette()
	_atmosphere()
	_terrain()
	_woodland()
	_security()
	_compound()
	_comms_landmark()
	_details()

func _palette() -> void:
	mat = {
		"ground": _material("#26382f", .98), "ground2": _material("#34483b", .96),
		"mud": _material("#4a4538", .99), "path": _material("#5b5647", .98),
		"moss": _material("#3f5943", .96), "trunk": _material("#40382d", .95),
		"pine": _material("#183a2c", .92), "pine2": _material("#28513b", .91),
		"bush": _material("#315842", .94), "rock": _material("#525c59", .97),
		"concrete": _material("#66716e", .9), "dark_concrete": _material("#414a49", .92),
		"blacksite": _material("#394743", .84, .08), "blacksite2": _material("#586965", .84, .06),
		"metal": _material("#263336", .66, .32), "metal2": _material("#657578", .62, .38),
		"glass": _material("#162b31", .34, .18), "cabinet": _material("#52645c", .78, .16),
		"generator": _material("#4b5744", .82, .12), "warning": _material("#c6a44a", .78),
		"signal": _material("#b84337", .7, .08), "crate": _material("#5b513d", .93),
		"sandbag": _material("#586052", .97), "water": _material("#263f43", .28, .1)
	}

func _material(hex: String, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = Color(hex)
	value.roughness = roughness
	value.metallic = metallic
	return value

func _atmosphere() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4d6870")
	sky_mat.sky_horizon_color = Color("#a7b8b5")
	sky_mat.ground_bottom_color = Color("#1e2c29")
	sky_mat.ground_horizon_color = Color("#667b72")
	sky_mat.sun_angle_max = 22.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#a7bfba")
	env.ambient_light_energy = .63
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#829b94")
	env.fog_light_energy = .46
	env.fog_density = .009
	env.fog_height = .5
	env.fog_height_density = .1
	env.fog_sky_affect = .42
	var world := WorldEnvironment.new()
	world.name = "BlacksiteWorldEnvironment"
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "OvercastSun"
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("#d8e5dd")
	sun.light_energy = .92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

func _terrain() -> void:
	var root := _group("ForestTerrain")
	_box(root, "ForestFloor", Vector3(0, -.55, 0), Vector3(84, 1.1, 96), mat.ground, true)
	for d in [
		[Vector3(0,.018,29),Vector3(7.5,.035,18),0], [Vector3(-1.2,.022,15),Vector3(7,.038,13),-8],
		[Vector3(.5,.024,3),Vector3(6.4,.04,13),9], [Vector3(2,.026,-10),Vector3(6,.04,15),-5],
		[Vector3(3,.028,-25),Vector3(5.5,.04,16),3]
	]: _box(root,"MainDirtPath",d[0],d[1],mat.path,false,d[2])
	for d in [
		[Vector3(-20,.021,14),Vector3(4.2,.035,35),-6], [Vector3(-23,.023,-15),Vector3(4,.035,25),5],
		[Vector3(22,.021,3),Vector3(4.2,.035,46),3], [Vector3(25,.023,-28),Vector3(4,.035,18),-4]
	]: _box(root,"SecondaryTrack",d[0],d[1],mat.mud,false,d[2])
	for d in [
		[Vector3(-31,-.15,27),Vector3(9,.7,8)], [Vector3(31,-.2,22),Vector3(8,.6,10)],
		[Vector3(-34,-.18,-6),Vector3(10,.65,13)], [Vector3(34,-.2,-17),Vector3(9,.7,12)],
		[Vector3(-17,-.25,-40),Vector3(13,.75,8)], [Vector3(18,-.22,-42),Vector3(14,.7,7)]
	]: _sphere(root,"ForestMound",d[0],d[1],mat.ground2)
	_box(root,"WestDrain",Vector3(-31,-.05,-17),Vector3(2.3,.08,30),mat.water,false,2)
	_box(root,"EastDrain",Vector3(33,-.05,-16),Vector3(1.8,.08,27),mat.water,false,-3)

func _woodland() -> void:
	var root := _group("Woodland")
	var trees := [
		[-35,31,1.12],[-29,34,.94],[-23,29,1.05],[25,33,1.08],[32,29,.96],[37,22,1.12],
		[-35,16,1.04],[-27,15,.91],[29,14,1.03],[36,7,1.1],[-37,0,1.12],[-29,-2,.98],
		[29,-4,1.0],[37,-8,1.08],[-36,-18,1.04],[-29,-25,.93],[39,-18,1.06],[38,-29,.98],
		[-34,-38,1.1],[-25,-40,.96],[-13,-42,1.03],[14,-43,1.08],[28,-41,.95],[38,-38,1.12],
		[-12,26,.88],[14,25,.91],[-16,8,.94],[16,4,.88],[-20,-7,.92],[24,-16,.9]
	]
	for d in trees: _pine(root,Vector3(d[0],0,d[1]),d[2],true)
	for d in [
		[Vector3(-9,0,29),1.0],[Vector3(10,0,28),1.15],[Vector3(-18,0,22),1.2],
		[Vector3(18,0,18),1.0],[Vector3(-13,0,13),1.15],[Vector3(14,0,10),1.1],
		[Vector3(-25,0,7),1.25],[Vector3(27,0,2),1.0],[Vector3(-26,0,-12),1.05],
		[Vector3(26,0,-10),1.15],[Vector3(-27,0,-30),1.2],[Vector3(29,0,-34),1.0]
	]: _bush(root,d[0],d[1])
	for d in [
		[Vector3(-11,0,20),Vector3(2.8,1.3,2.2),17], [Vector3(17,0,17),Vector3(2.1,1,1.8),-22],
		[Vector3(-27,0,4),Vector3(3.2,1.5,2.4),8], [Vector3(28,0,-6),Vector3(2.7,1.2,2),31],
		[Vector3(-30,0,-32),Vector3(3,1.3,2.5),-14]
	]: _rock(root,d[0],d[1],d[2])
	var backdrop := _group("DistantForestSilhouette")
	for d in [[-50,30,1.35],[-49,8,1.45],[-50,-15,1.4],[-48,-38,1.5],[50,32,1.4],[49,10,1.5],[50,-14,1.38],[48,-38,1.48],[-32,-54,1.4],[-10,-55,1.5],[13,-55,1.42],[35,-53,1.48]]:
		_pine(backdrop,Vector3(d[0],0,d[1]),d[2],false)

func _security() -> void:
	var root := _group("SecurityPerimeter")
	# Fencing is visual-only so the existing direct-steering AI keeps broad routes.
	_fence(root,Vector3(-24,0,7),25,true)
	_fence(root,Vector3(24,0,7),25,true)
	_fence(root,Vector3(-36.5,0,-18),50,false)
	_fence(root,Vector3(36.5,0,-18),50,false)
	_fence(root,Vector3(-22,0,-43),29,true)
	_fence(root,Vector3(22,0,-43),29,true)
	_guard_post(root,"WestCheckpoint",Vector3(-9.5,0,10.5),5)
	_guard_post(root,"EastCheckpoint",Vector3(10.5,0,9.5),-4)
	_box(root,"GateHeader",Vector3(0,4.5,7),Vector3(10,.35,.35),mat.metal)
	_box(root,"BlacksiteSign",Vector3(0,4.15,6.78),Vector3(5.6,.85,.08),mat.blacksite)
	for x in [-4.7,4.7]: _box(root,"GatePillar",Vector3(x,2.25,7),Vector3(.4,4.5,.4),mat.metal)

func _compound() -> void:
	var root := _group("CommunicationsCompound")
	_building(root,"CommandCommunicationsBuilding",Vector3(-13,0,-13),Vector3(14,5.2,10),-4)
	_building(root,"SignalsAnalysisAnnex",Vector3(15,0,-20),Vector3(10,4,7),3)
	_shelter(root,Vector3(-18,0,-31))
	_generator(root,Vector3(27,0,-19),-7)
	_generator(root,Vector3(27,0,-24),5)
	var platform := _group("MaintenancePlatform",root)
	platform.position = Vector3(11,0,-31)
	_box(platform,"PlatformDeck",Vector3(0,.38,0),Vector3(8,.35,4.5),mat.metal,true)
	for x in [-2.5,0.0,2.5]: _box(platform,"GratingSlot",Vector3(x,.57,0),Vector3(.08,.03,4),mat.dark_concrete)

func _comms_landmark() -> void:
	var root := _group("CommunicationsArray")
	var mast := _group("PrimarySignalMast",root)
	mast.position = Vector3(3,0,-34)
	for y in [2.5,7.5,12.5,17.5]: _box(mast,"MastSegment",Vector3(0,y,0),Vector3(.42,5,.42),mat.metal2)
	for y in [4.5,9.5,14.5,19.5]:
		_box(mast,"CrossArm",Vector3(0,y,0),Vector3(4.5,.18,.18),mat.metal)
		_box(mast,"CrossBrace",Vector3(0,y,0),Vector3(.18,.18,3.2),mat.metal)
	_box(mast,"Beacon",Vector3(0,20.35,0),Vector3(.38,.55,.38),mat.signal)
	_dish(root,"WestDish",Vector3(-7,0,-30),-28,16)
	_dish(root,"EastDish",Vector3(13,.6,-31),34,-8)
	for d in [[-4,-38,8],[9,-38,10],[18,-36,7]]:
		_cylinder(root,"WhipAntenna",Vector3(d[0],d[2]*.5,d[1]),.08,d[2],mat.metal2)

func _details() -> void:
	var root := _group("TacticalDetails")
	for d in [[Vector3(-5.5,0,2),18],[Vector3(7.5,0,-5),-14],[Vector3(-11,0,-24),8]]: _barrier(root,d[0],d[1])
	for d in [[Vector3(-21,0,16),8],[Vector3(22,0,-12),-12],[Vector3(23,0,-35),14]]: _sandbags(root,d[0],d[1])
	_crates(root,Vector3(-4,0,11),7)
	_crates(root,Vector3(23,0,-27),-9)
	_cabinets(root,Vector3(5,0,-16),2)
	_cabinets(root,Vector3(8,0,-18),-3)
	_box(root,"CableTrayA",Vector3(8,.18,-27),Vector3(9,.18,.28),mat.metal,false,-12)
	_box(root,"CableTrayB",Vector3(11.8,.18,-23.5),Vector3(7,.18,.28),mat.metal,false,68)

func _group(node_name: String, parent: Node3D = self) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node

func _pine(parent: Node3D, pos: Vector3, size: float, collide: bool) -> void:
	var tree := _group("PineTree",parent)
	tree.position = pos
	tree.scale = Vector3.ONE * size
	_cylinder(tree,"Trunk",Vector3(0,3.1,0),.42,6.2,mat.trunk,Vector3.ZERO,collide)
	_cone(tree,"LowerCanopy",Vector3(0,6,0),3.3,6.2,mat.pine)
	_cone(tree,"UpperCanopy",Vector3(0,8.7,0),2.4,5.5,mat.pine2)

func _bush(parent: Node3D, pos: Vector3, size: float) -> void:
	var bush := _group("VegetationCluster",parent)
	bush.position = pos
	bush.scale = Vector3.ONE * size
	for d in [[-.8,.55,.1,1.2],[.4,.7,0,1.45],[1.1,.48,.35,.95],[0,.42,-.8,1.0]]:
		_sphere(bush,"Bush",Vector3(d[0],d[1],d[2]),Vector3(d[3],.8,d[3]),mat.bush)

func _rock(parent: Node3D, pos: Vector3, size: Vector3, rot: float) -> void:
	var rock := _group("MossyRock",parent)
	rock.position = pos
	rock.rotation_degrees.y = rot
	_box(rock,"RockCore",Vector3(0,size.y*.34,0),size,mat.rock,true,7)
	_box(rock,"MossPatch",Vector3(0,size.y*.76,0),Vector3(size.x*.7,.08,size.z*.65),mat.moss,false,-5)

func _fence(parent: Node3D, center: Vector3, length: float, along_x: bool) -> void:
	var fence := _group("SecurityFence",parent)
	fence.position = center
	var count := maxi(2,int(length/3.0)+1)
	for i in count:
		var off := -length*.5+length*float(i)/float(count-1)
		_box(fence,"FencePost",Vector3(off,1.35,0) if along_x else Vector3(0,1.35,off),Vector3(.12,2.7,.12),mat.metal)
	var rail := Vector3(length,.08,.08) if along_x else Vector3(.08,.08,length)
	for y in [.45,1.35,2.25]: _box(fence,"FenceRail",Vector3(0,y,0),rail,mat.metal)

func _guard_post(parent: Node3D, title: String, pos: Vector3, rot: float) -> void:
	var post := _group(title,parent)
	post.position = pos
	post.rotation_degrees.y = rot
	_box(post,"PostBody",Vector3(0,1.6,0),Vector3(4.2,3.2,4.4),mat.blacksite,true)
	_box(post,"Roof",Vector3(0,3.35,0),Vector3(4.8,.3,5),mat.metal)
	_box(post,"Window",Vector3(0,2,2.23),Vector3(2.6,.85,.08),mat.glass)
	_box(post,"Door",Vector3(-1.3,1.2,2.24),Vector3(1,2.4,.09),mat.metal)

func _building(parent: Node3D, title: String, pos: Vector3, size: Vector3, rot: float) -> void:
	var b := _group(title,parent)
	b.position = pos
	b.rotation_degrees.y = rot
	_box(b,"MainBlock",Vector3(0,size.y*.5,0),size,mat.blacksite,true)
	_box(b,"RoofSlab",Vector3(0,size.y+.18,0),Vector3(size.x+.6,.36,size.z+.6),mat.metal)
	_box(b,"Foundation",Vector3(0,.18,0),Vector3(size.x+.5,.36,size.z+.5),mat.dark_concrete)
	_box(b,"SecureDoor",Vector3(-size.x*.25,1.35,size.z*.5+.05),Vector3(1.8,2.7,.1),mat.metal)
	for x in [-size.x*.18,size.x*.22]: _box(b,"DarkWindow",Vector3(x,size.y*.6,size.z*.5+.06),Vector3(2.5,1,.11),mat.glass)
	_box(b,"AntennaBase",Vector3(size.x*.28,size.y+.65,0),Vector3(1.5,1,1.5),mat.metal)
	_cylinder(b,"RoofAntenna",Vector3(size.x*.28,size.y+2.1,0),.08,2.2,mat.metal2)

func _shelter(parent: Node3D, pos: Vector3) -> void:
	var s := _group("EquipmentShelter",parent)
	s.position = pos
	_box(s,"ShelterBody",Vector3(0,1.65,0),Vector3(8,3.3,5.5),mat.blacksite2,true)
	_box(s,"Roof",Vector3(0,3.48,0),Vector3(8.6,.35,6.1),mat.metal)
	for x in [-2.3,0.0,2.3]: _box(s,"Vent",Vector3(x,2.15,2.79),Vector3(1.35,.55,.1),mat.metal)

func _generator(parent: Node3D, pos: Vector3, rot: float) -> void:
	var g := _group("FieldGenerator",parent)
	g.position = pos
	g.rotation_degrees.y = rot
	# Visual-only body keeps the narrow maintenance approach compatible with the
	# project's direct-steering enemies while retaining a believable generator bank.
	_box(g,"GeneratorBody",Vector3(0,1,0),Vector3(2.7,2,4.2),mat.generator)
	_box(g,"ControlPanel",Vector3(0,1.15,2.13),Vector3(1.8,.9,.08),mat.metal)
	_cylinder(g,"Exhaust",Vector3(.8,2.65,-1.1),.12,1.5,mat.metal)

func _dish(parent: Node3D, title: String, pos: Vector3, yaw: float, tilt: float) -> void:
	var d := _group(title,parent)
	d.position = pos
	d.rotation_degrees = Vector3(tilt,yaw,0)
	_box(d,"Pedestal",Vector3(0,.6,0),Vector3(1.8,1.2,1.8),mat.concrete,true)
	_cylinder(d,"Support",Vector3(0,2.25,0),.18,2.5,mat.metal2)
	var dish := SphereMesh.new()
	dish.radius = 2.35
	dish.height = .55
	dish.radial_segments = 16
	dish.rings = 4
	dish.material = mat.metal2
	_mesh(d,"ParabolicDish",Vector3(0,3.55,0),dish,Vector3(90,0,0))
	_cylinder(d,"ReceiverArm",Vector3(0,3.55,-1.4),.07,2.8,mat.metal,Vector3(90,0,0))

func _barrier(parent: Node3D, pos: Vector3, rot: float) -> void:
	var b := _group("ConcreteBarrier",parent)
	b.position = pos
	b.rotation_degrees.y = rot
	_box(b,"BarrierCore",Vector3(0,.55,0),Vector3(4.4,1.1,.72),mat.concrete,true)
	_box(b,"BarrierFoot",Vector3(0,.14,0),Vector3(4.8,.28,1.05),mat.dark_concrete)
	_box(b,"WarningBand",Vector3(0,.73,.37),Vector3(1.3,.15,.03),mat.warning)

func _sandbags(parent: Node3D, pos: Vector3, rot: float) -> void:
	var wall := _group("SandbagPosition",parent)
	wall.position = pos
	wall.rotation_degrees.y = rot
	_box(wall,"SandbagCollision",Vector3(0,.45,0),Vector3(5,.9,.75),mat.sandbag,true)
	for row in 2:
		for i in 6:
			_capsule(wall,Vector3(-2.1+i*.84+(.22 if row==1 else 0),.25+row*.43,0))

func _crates(parent: Node3D, pos: Vector3, rot: float) -> void:
	var root := _group("SupplyCrates",parent)
	root.position = pos
	root.rotation_degrees.y = rot
	for p in [Vector3(-.7,.6,0),Vector3(.7,.6,.1),Vector3(0,1.8,0)]: _box(root,"Crate",p,Vector3(1.25,1.2,1.25),mat.crate,true)

func _cabinets(parent: Node3D, pos: Vector3, rot: float) -> void:
	var root := _group("EquipmentCabinetBank",parent)
	root.position = pos
	root.rotation_degrees.y = rot
	for x in [-1.25,0.0,1.25]:
		_box(root,"EquipmentCabinet",Vector3(x,1.15,0),Vector3(1.05,2.3,1.1),mat.cabinet,true)
		_box(root,"StatusPanel",Vector3(x,1.35,.56),Vector3(.65,.45,.05),mat.glass)

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, material: Material, collide: bool = false, rot: float = 0.0) -> Node3D:
	var host: Node3D = StaticBody3D.new() if collide else MeshInstance3D.new()
	host.name = title
	host.position = pos
	host.rotation_degrees.y = rot
	parent.add_child(host)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	if collide:
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		host.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		host.add_child(collision)
	else: (host as MeshInstance3D).mesh = mesh
	return host

func _cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, material: Material, rot: Vector3 = Vector3.ZERO, collide: bool = false) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = material
	var host: Node3D = StaticBody3D.new() if collide else MeshInstance3D.new()
	host.name = title
	host.position = pos
	host.rotation_degrees = rot
	parent.add_child(host)
	if collide:
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		host.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		host.add_child(collision)
	else: (host as MeshInstance3D).mesh = mesh
	return host

func _cone(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = .12
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	_mesh(parent,title,pos,mesh)

func _sphere(parent: Node3D, title: String, pos: Vector3, scale_value: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh.material = material
	var node := _mesh(parent,title,pos,mesh)
	node.scale = scale_value

func _capsule(parent: Node3D, pos: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = .23
	mesh.height = .78
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = mat.sandbag
	_mesh(parent,"Sandbag",pos,mesh,Vector3(0,0,90))

func _mesh(parent: Node3D, title: String, pos: Vector3, mesh: PrimitiveMesh, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = pos
	node.rotation_degrees = rot
	node.mesh = mesh
	parent.add_child(node)
	return node
