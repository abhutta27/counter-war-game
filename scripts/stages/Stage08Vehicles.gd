class_name Stage08Vehicles
extends RefCounted

static func create_battle_tank(tank_name: String, pos: Vector3, yaw_deg: float) -> StaticBody3D:
	var tank := StaticBody3D.new()
	tank.name = tank_name
	tank.position = pos
	tank.rotation_degrees.y = yaw_deg
	tank.collision_layer = 3
	tank.collision_mask = 3
	tank.add_to_group("enemy_tank")

	# Main Collision Box
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.8, 2.7, 6.4)
	col.shape = box
	col.position = Vector3(0.0, 1.35, 0.0)
	tank.add_child(col)

	var mat_olive: StandardMaterial3D = _make_mat(Color(0.24, 0.30, 0.20), 0.25, 0.72)
	var mat_dark_olive: StandardMaterial3D = _make_mat(Color(0.17, 0.22, 0.14), 0.30, 0.75)
	var mat_era: StandardMaterial3D = _make_mat(Color(0.21, 0.26, 0.18), 0.32, 0.68)
	var mat_track: StandardMaterial3D = _make_mat(Color(0.10, 0.10, 0.11), 0.45, 0.85)
	var mat_steel: StandardMaterial3D = _make_mat(Color(0.28, 0.30, 0.32), 0.75, 0.40)
	var mat_headlight: StandardMaterial3D = _make_emissive_mat(Color(0.95, 0.92, 0.72), Color(1.0, 0.95, 0.75), 2.2)

	# Left & Right Tracks, 7 Pairs of Road Wheels, Sprockets & Ballistic Side Skirts
	for side: float in [-1.0, 1.0]:
		var side_x: float = side * 1.52
		_add_box(tank, "TrackBottom_%s" % side, Vector3(0.68, 0.18, 5.5), Vector3(side_x, 0.10, 0.0), mat_track)
		_add_box(tank, "TrackTop_%s" % side, Vector3(0.68, 0.16, 5.7), Vector3(side_x, 0.86, 0.0), mat_track)
		_add_box(tank, "TrackFrontSlope_%s" % side, Vector3(0.68, 0.18, 0.85), Vector3(side_x, 0.48, 2.85), mat_track).rotation_degrees.x = -42.0
		_add_box(tank, "TrackRearSlope_%s" % side, Vector3(0.68, 0.18, 0.85), Vector3(side_x, 0.48, -2.85), mat_track).rotation_degrees.x = 42.0

		# 7 Road Wheels per side
		for w: int in range(7):
			var z_off: float = -2.25 + float(w) * 0.75
			var wheel: MeshInstance3D = _add_cylinder(tank, "RoadWheel_%s_%d" % [side, w], 0.32, 0.64, Vector3(side_x, 0.36, z_off), mat_steel)
			wheel.rotation_degrees.z = 90.0
			var hub: MeshInstance3D = _add_cylinder(tank, "WheelHub_%s_%d" % [side, w], 0.12, 0.68, Vector3(side_x, 0.36, z_off), mat_dark_olive)
			hub.rotation_degrees.z = 90.0

		# Drive Sprocket (rear) & Idler Wheel (front)
		var idler: MeshInstance3D = _add_cylinder(tank, "Idler_%s" % side, 0.34, 0.66, Vector3(side_x, 0.66, 2.85), mat_track)
		idler.rotation_degrees.z = 90.0
		var sprocket: MeshInstance3D = _add_cylinder(tank, "Sprocket_%s" % side, 0.35, 0.66, Vector3(side_x, 0.66, -2.85), mat_track)
		sprocket.rotation_degrees.z = 90.0

		# Segmented Ballistic Side Skirts
		for s: int in range(5):
			var skirt_z: float = -2.1 + float(s) * 1.05
			_add_box(tank, "BallisticSkirt_%s_%d" % [side, s], Vector3(0.14, 0.62, 1.00), Vector3(side * 1.88, 0.76, skirt_z), mat_dark_olive)
		var fender: MeshInstance3D = _add_box(tank, "Fender_%s" % side, Vector3(0.78, 0.12, 6.2), Vector3(side_x, 1.02, 0.0), mat_olive)
		fender.rotation_degrees.z = -side * 5.0

		# Front Headlights
		_add_box(tank, "HeadlightHousing_%s" % side, Vector3(0.24, 0.18, 0.22), Vector3(side * 1.25, 1.22, 2.88), mat_steel)
		_add_box(tank, "HeadlightLens_%s" % side, Vector3(0.18, 0.12, 0.04), Vector3(side * 1.25, 1.22, 2.99), mat_headlight)

	# Lower & Upper Hull
	_add_box(tank, "LowerHull", Vector3(2.35, 0.70, 5.6), Vector3(0.0, 0.62, 0.0), mat_dark_olive)
	_add_box(tank, "UpperHull", Vector3(2.85, 0.56, 5.8), Vector3(0.0, 1.18, -0.05), mat_olive)

	# Sloped Front Glacis + Explosive Reactive Armor (ERA) Blocks
	var glacis: MeshInstance3D = _add_box(tank, "FrontGlacis", Vector3(2.78, 0.42, 1.55), Vector3(0.0, 1.10, 2.58), mat_olive)
	glacis.rotation_degrees.x = 24.0
	for row: int in range(2):
		for col_idx: int in range(5):
			var era_x: float = -1.0 + float(col_idx) * 0.5
			var era_y: float = 1.05 + float(row) * 0.18
			var era_z: float = 2.92 - float(row) * 0.42
			var era: MeshInstance3D = _add_box(tank, "FrontERA_%d_%d" % [row, col_idx], Vector3(0.44, 0.14, 0.34), Vector3(era_x, era_y, era_z), mat_era)
			era.rotation_degrees.x = 24.0

	# Rear Engine Deck & Dual Fuel Drums
	_add_box(tank, "EngineDeck", Vector3(2.2, 0.14, 1.65), Vector3(0.0, 1.48, -2.05), mat_track)
	for side: float in [-1.0, 1.0]:
		var drum: MeshInstance3D = _add_cylinder(tank, "FuelDrum_%s" % side, 0.32, 0.96, Vector3(side * 0.72, 1.38, -3.18), mat_dark_olive)
		drum.rotation_degrees.z = 90.0
		_add_box(tank, "DrumMount_%s" % side, Vector3(0.16, 0.25, 0.45), Vector3(side * 0.72, 1.18, -3.02), mat_steel)

	# Sculpted Turret
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.48, -0.15)
	tank.add_child(turret)

	_add_box(turret, "TurretCore", Vector3(2.15, 0.74, 2.75), Vector3(0.0, 0.37, 0.0), mat_olive)
	_add_box(turret, "TurretBustle", Vector3(1.90, 0.56, 1.05), Vector3(0.0, 0.42, -1.72), mat_dark_olive)
	for side: float in [-1.0, 1.0]:
		var cheek: MeshInstance3D = _add_box(turret, "TurretCheek_%s" % side, Vector3(0.86, 0.66, 1.15), Vector3(side * 0.74, 0.36, 1.45), mat_era)
		cheek.rotation_degrees.x = 20.0
		cheek.rotation_degrees.y = -side * 16.0
		var side_armor: MeshInstance3D = _add_box(turret, "TurretSideArmor_%s" % side, Vector3(0.24, 0.62, 2.35), Vector3(side * 1.16, 0.36, -0.15), mat_dark_olive)
		side_armor.rotation_degrees.z = -side * 10.0

		# Smoke Grenade Launcher Tubes (4 per side)
		for g: int in range(4):
			var tube: MeshInstance3D = _add_cylinder(turret, "SmokeTube_%s_%d" % [side, g], 0.045, 0.28, Vector3(side * 1.24, 0.44 + float(g % 2) * 0.09, 0.72 + float(g) * 0.11), mat_steel)
			tube.rotation_degrees = Vector3(58.0, side * 32.0, 0.0)

		# Dual Whip Antennas
		_add_cylinder(turret, "AntennaBase_%s" % side, 0.055, 0.16, Vector3(side * 0.82, 0.78, -1.85), mat_track)
		_add_cylinder(turret, "AntennaWhip_%s" % side, 0.018, 2.25, Vector3(side * 0.82, 1.92, -1.85), mat_track)

	# Commander Cupola & Roof .50 Cal Machine Gun
	_add_cylinder(turret, "CommanderCupola", 0.38, 0.18, Vector3(-0.52, 0.80, -0.25), mat_steel)
	var mg_mount := Node3D.new()
	mg_mount.name = "RoofMG"
	mg_mount.position = Vector3(-0.45, 0.96, -0.10)
	turret.add_child(mg_mount)
	_add_cylinder(mg_mount, "MGPintle", 0.04, 0.24, Vector3(0.0, 0.08, 0.0), mat_steel)
	_add_box(mg_mount, "MGReceiver", Vector3(0.14, 0.16, 0.48), Vector3(0.0, 0.22, 0.12), mat_track)
	_add_box(mg_mount, "MGAmmoBox", Vector3(0.18, 0.20, 0.24), Vector3(0.16, 0.18, 0.10), mat_dark_olive)
	var mg_barrel: MeshInstance3D = _add_cylinder(mg_mount, "MGBarrel", 0.024, 0.78, Vector3(0.0, 0.24, 0.72), mat_steel)
	mg_barrel.rotation_degrees.x = 90.0

	# 120mm Main Cannon Barrel + Bore Evacuator + Muzzle Brake
	_add_box(turret, "Mantlet", Vector3(0.72, 0.46, 0.58), Vector3(0.0, 0.38, 1.85), mat_steel)
	var barrel: MeshInstance3D = _add_cylinder(turret, "MainBarrel", 0.11, 3.95, Vector3(0.0, 0.38, 3.95), mat_steel)
	barrel.rotation_degrees.x = 90.0
	var evacuator: MeshInstance3D = _add_cylinder(turret, "BoreEvacuator", 0.17, 0.68, Vector3(0.0, 0.38, 3.60), mat_dark_olive)
	evacuator.rotation_degrees.x = 90.0
	_add_box(turret, "MuzzleBrake", Vector3(0.34, 0.28, 0.44), Vector3(0.0, 0.38, 5.95), mat_track)

	return tank


static func create_military_helicopter(heli_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var heli := Node3D.new()
	heli.name = heli_name
	heli.position = pos
	heli.rotation_degrees.y = yaw_deg

	var mat_body: StandardMaterial3D = _make_mat(Color(0.18, 0.23, 0.18), 0.35, 0.60)
	var mat_trim: StandardMaterial3D = _make_mat(Color(0.12, 0.15, 0.12), 0.40, 0.65)
	var mat_glass: StandardMaterial3D = _make_mat(Color(0.28, 0.45, 0.56, 0.25), 0.85, 0.12)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mat_rotor: StandardMaterial3D = _make_mat(Color(0.09, 0.09, 0.10), 0.60, 0.45)
	var mat_tip: StandardMaterial3D = _make_mat(Color(0.88, 0.74, 0.12), 0.20, 0.50)
	var mat_nav_red: StandardMaterial3D = _make_emissive_mat(Color(0.95, 0.15, 0.12), Color(1.0, 0.15, 0.10), 3.0)
	var mat_nav_green: StandardMaterial3D = _make_emissive_mat(Color(0.15, 0.95, 0.25), Color(0.15, 1.0, 0.30), 3.0)
	var mat_gauge_green: StandardMaterial3D = _make_emissive_mat(Color(0.15, 0.85, 0.35), Color(0.15, 0.95, 0.35), 1.4)
	var mat_gauge_amber: StandardMaterial3D = _make_emissive_mat(Color(0.95, 0.68, 0.15), Color(1.0, 0.70, 0.15), 1.4)
	var mat_switch_red: StandardMaterial3D = _make_emissive_mat(Color(0.95, 0.12, 0.10), Color(1.0, 0.15, 0.10), 2.6)
	var mat_vest: StandardMaterial3D = _make_mat(Color(0.22, 0.25, 0.19), 0.15, 0.78)
	var mat_uniform: StandardMaterial3D = _make_mat(Color(0.28, 0.30, 0.23), 0.08, 0.85)
	var mat_visor: StandardMaterial3D = _make_emissive_mat(Color(0.12, 0.24, 0.36), Color(0.15, 0.45, 0.65), 0.6)

	# Tubular Landing Skids
	for side: float in [-1.0, 1.0]:
		var skid: MeshInstance3D = _add_cylinder(heli, "SkidRail_%s" % side, 0.065, 4.9, Vector3(side * 1.24, 0.10, 0.35), mat_rotor)
		skid.rotation_degrees.x = 90.0
		var skid_tip: MeshInstance3D = _add_cylinder(heli, "SkidTip_%s" % side, 0.062, 0.55, Vector3(side * 1.24, 0.24, 2.95), mat_rotor)
		skid_tip.rotation_degrees.x = 58.0
		for z_strut: float in [-1.15, 1.45]:
			var strut: MeshInstance3D = _add_cylinder(heli, "SkidStrut_%s_%s" % [side, z_strut], 0.05, 0.88, Vector3(side * 1.10, 0.50, z_strut), mat_rotor)
			strut.rotation_degrees.z = side * 18.0

	# Aerodynamic Curved Fuselage (open front cockpit bay at Z = 0.7..2.7)
	_add_box(heli, "CabinCenter", Vector3(2.05, 1.62, 2.85), Vector3(0.0, 1.56, -0.72), mat_body)
	_add_box(heli, "CockpitFloor", Vector3(1.90, 0.14, 2.10), Vector3(0.0, 0.98, 1.72), mat_trim)
	_add_box(heli, "CockpitRoof", Vector3(1.70, 0.12, 1.60), Vector3(0.0, 2.34, 1.48), mat_trim)
	var belly_keel: MeshInstance3D = _add_box(heli, "BellyKeel", Vector3(1.55, 0.42, 4.6), Vector3(0.0, 0.80, 0.25), mat_trim)
	belly_keel.rotation_degrees.x = -3.0
	var nose_lower: MeshInstance3D = _add_box(heli, "NoseLower", Vector3(1.55, 0.62, 1.65), Vector3(0.0, 1.08, 2.85), mat_body)
	nose_lower.rotation_degrees.x = -12.0
	var nose_cap: MeshInstance3D = _add_box(heli, "NoseCap", Vector3(1.15, 0.44, 0.85), Vector3(0.0, 1.06, 3.72), mat_trim)
	nose_cap.rotation_degrees.x = 18.0

	# Clear / Lightly-Tinted Cockpit Canopy + Struts
	var windshield: MeshInstance3D = _add_box(heli, "CanopyWindshield", Vector3(1.68, 0.06, 1.55), Vector3(0.0, 1.88, 2.65), mat_glass)
	windshield.rotation_degrees.x = 46.0
	for side: float in [-1.0, 1.0]:
		_add_box(heli, "SideCanopy_%s" % side, Vector3(0.05, 0.78, 1.55), Vector3(side * 0.92, 1.78, 1.65), mat_glass)
		_add_box(heli, "CockpitSill_%s" % side, Vector3(0.14, 0.36, 1.95), Vector3(side * 0.94, 1.22, 1.68), mat_body)
		var pillar: MeshInstance3D = _add_box(heli, "CanopyPillar_%s" % side, Vector3(0.08, 0.08, 1.55), Vector3(side * 0.84, 1.88, 2.65), mat_trim)
		pillar.rotation_degrees.x = 46.0

	# Pilot Seat & Cyclic Control Stick
	_add_box(heli, "PilotSeatBase", Vector3(0.56, 0.14, 0.54), Vector3(0.0, 1.12, 1.42), mat_rotor)
	var seat_back: MeshInstance3D = _add_box(heli, "PilotSeatBack", Vector3(0.54, 0.74, 0.12), Vector3(0.0, 1.52, 1.14), mat_rotor)
	seat_back.rotation_degrees.x = -10.0
	_add_box(heli, "PilotHeadrest", Vector3(0.32, 0.24, 0.12), Vector3(0.0, 1.96, 1.08), mat_trim)
	var stick: MeshInstance3D = _add_cylinder(heli, "ControlStick", 0.032, 0.42, Vector3(-0.08, 1.32, 1.92), mat_rotor)
	stick.rotation_degrees.x = -16.0

	# Instrument Dashboard (ControlPanel) & Prominent Red IgnitionSwitch
	var control_panel := Node3D.new()
	control_panel.name = "ControlPanel"
	control_panel.position = Vector3(0.0, 1.48, 2.48)
	heli.add_child(control_panel)
	var dash_body: MeshInstance3D = _add_box(control_panel, "DashHousing", Vector3(1.28, 0.34, 0.44), Vector3(0.0, 0.0, 0.0), mat_rotor)
	dash_body.rotation_degrees.x = -26.0
	_add_box(control_panel, "Gauge_0", Vector3(0.24, 0.14, 0.04), Vector3(-0.34, 0.04, -0.22), mat_gauge_green)
	_add_box(control_panel, "Gauge_1", Vector3(0.26, 0.14, 0.04), Vector3(-0.04, 0.04, -0.22), mat_gauge_amber)
	_add_box(control_panel, "Gauge_2", Vector3(0.20, 0.14, 0.04), Vector3(0.24, 0.04, -0.22), mat_gauge_green)
	var ignition_switch: MeshInstance3D = _add_cylinder(control_panel, "IgnitionSwitch", 0.055, 0.08, Vector3(0.42, 0.08, -0.24), mat_switch_red)
	ignition_switch.name = "IgnitionSwitch"
	ignition_switch.rotation_degrees.x = 64.0

	# Seated Operative (initially hidden; shown during Phase 3 boarding cinematic)
	var operative := Node3D.new()
	operative.name = "SeatedOperative"
	operative.position = Vector3(0.0, 1.18, 1.44)
	operative.visible = false
	heli.add_child(operative)
	# Legs & Boots
	for side: float in [-1.0, 1.0]:
		var thigh: MeshInstance3D = _add_box(operative, "Thigh_%s" % side, Vector3(0.16, 0.16, 0.44), Vector3(side * 0.14, 0.06, 0.22), mat_uniform)
		thigh.rotation_degrees.x = -8.0
		var shin: MeshInstance3D = _add_box(operative, "Shin_%s" % side, Vector3(0.14, 0.36, 0.15), Vector3(side * 0.14, -0.10, 0.46), mat_uniform)
		shin.rotation_degrees.x = 18.0
		_add_box(operative, "Boot_%s" % side, Vector3(0.15, 0.10, 0.24), Vector3(side * 0.14, -0.22, 0.56), mat_rotor)
	# Torso, Armored Vest, Helmet & Visor
	_add_box(operative, "Torso", Vector3(0.42, 0.52, 0.26), Vector3(0.0, 0.34, 0.02), mat_uniform)
	_add_box(operative, "ArmorVest", Vector3(0.46, 0.42, 0.30), Vector3(0.0, 0.36, 0.03), mat_vest)
	_add_cylinder(operative, "Helmet", 0.15, 0.24, Vector3(0.0, 0.72, 0.05), mat_vest)
	_add_box(operative, "HelmetVisor", Vector3(0.24, 0.11, 0.10), Vector3(0.0, 0.72, 0.16), mat_visor)
	# Left Arm holding cyclic stick
	var left_arm := Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.27, 0.52, 0.04)
	left_arm.rotation_degrees = Vector3(-42.0, -18.0, 0.0)
	operative.add_child(left_arm)
	_add_box(left_arm, "UpperArm", Vector3(0.11, 0.26, 0.11), Vector3(0.0, -0.12, 0.0), mat_uniform)
	_add_box(left_arm, "Forearm", Vector3(0.10, 0.26, 0.10), Vector3(0.0, -0.32, 0.10), mat_uniform).rotation_degrees.x = -38.0
	# Articulated Right Arm (animates forward to press IgnitionSwitch)
	var right_arm := Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.27, 0.52, 0.04)
	right_arm.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	operative.add_child(right_arm)
	_add_box(right_arm, "UpperArm", Vector3(0.11, 0.28, 0.11), Vector3(0.0, -0.12, 0.0), mat_uniform)
	var r_forearm: MeshInstance3D = _add_box(right_arm, "Forearm", Vector3(0.10, 0.28, 0.10), Vector3(0.0, -0.26, 0.14), mat_uniform)
	r_forearm.rotation_degrees.x = -52.0
	_add_box(right_arm, "GlovedHand", Vector3(0.09, 0.09, 0.12), Vector3(0.0, -0.34, 0.28), mat_rotor)

	# Twin Turbine Engine Nacelles (mounted on upper deck flanks)
	_add_box(heli, "UpperTransmission", Vector3(1.35, 0.62, 3.0), Vector3(0.0, 2.52, -0.25), mat_trim)
	for side: float in [-1.0, 1.0]:
		var nacelle: MeshInstance3D = _add_cylinder(heli, "TurbineNacelle_%s" % side, 0.36, 2.45, Vector3(side * 0.74, 2.52, -0.35), mat_body)
		nacelle.rotation_degrees.x = 90.0
		var intake: MeshInstance3D = _add_cylinder(heli, "TurbineIntake_%s" % side, 0.30, 0.16, Vector3(side * 0.74, 2.52, 0.92), mat_rotor)
		intake.rotation_degrees.x = 90.0
		var exhaust: MeshInstance3D = _add_cylinder(heli, "TurbineExhaust_%s" % side, 0.24, 0.38, Vector3(side * 0.74, 2.52, -1.65), mat_rotor)
		exhaust.rotation_degrees.x = 90.0

	# Stub Wings, Rocket Pods, Hellfire Missiles & Red/Green Navigation Lights
	for side: float in [-1.0, 1.0]:
		var wing: MeshInstance3D = _add_box(heli, "StubWing_%s" % side, Vector3(1.85, 0.14, 0.98), Vector3(side * 1.78, 1.54, 0.20), mat_trim)
		wing.rotation_degrees.z = -side * 6.0

		# Inner Pylon: Multi-tube Rocket Pod
		var pod: MeshInstance3D = _add_cylinder(heli, "RocketPod_%s" % side, 0.24, 1.48, Vector3(side * 1.68, 1.24, 0.30), mat_rotor)
		pod.rotation_degrees.x = 90.0

		# Outer Pylon: Dual Hellfire Missiles
		_add_box(heli, "MissileRack_%s" % side, Vector3(0.24, 0.16, 0.75), Vector3(side * 2.38, 1.36, 0.25), mat_trim)
		for m: int in range(2):
			var missile_y: float = 1.24 - float(m) * 0.16
			var missile: MeshInstance3D = _add_cylinder(heli, "Hellfire_%s_%d" % [side, m], 0.055, 1.45, Vector3(side * 2.38, missile_y, 0.35), mat_body)
			missile.rotation_degrees.x = 90.0
			var seeker: MeshInstance3D = _add_cylinder(heli, "HellfireSeeker_%s_%d" % [side, m], 0.045, 0.12, Vector3(side * 2.38, missile_y, 1.12), mat_rotor)
			seeker.rotation_degrees.x = 90.0

		# Navigation Lights (Red on Port -X, Green on Starboard +X)
		var nav_mat: StandardMaterial3D = mat_nav_red if side < 0.0 else mat_nav_green
		_add_box(heli, "NavLight_%s" % side, Vector3(0.14, 0.12, 0.20), Vector3(side * 2.74, 1.48, 0.22), nav_mat)

	# Tapered Tail Boom & Vertical Fin
	var tail_boom_fwd: MeshInstance3D = _add_box(heli, "TailBoomFwd", Vector3(0.72, 0.74, 2.8), Vector3(0.0, 1.78, -3.25), mat_body)
	tail_boom_fwd.rotation_degrees.x = 2.0
	var tail_boom_aft: MeshInstance3D = _add_box(heli, "TailBoomAft", Vector3(0.44, 0.50, 2.7), Vector3(0.0, 1.92, -5.85), mat_body)
	tail_boom_aft.rotation_degrees.x = 3.0
	var tail_fin: MeshInstance3D = _add_box(heli, "TailFin", Vector3(0.16, 1.85, 0.92), Vector3(0.0, 2.65, -7.15), mat_trim)
	tail_fin.rotation_degrees.x = -22.0
	_add_box(heli, "TailBeacon", Vector3(0.12, 0.12, 0.16), Vector3(0.0, 3.55, -7.45), mat_nav_red)
	_add_box(heli, "HorizontalStabilizer", Vector3(2.25, 0.10, 0.56), Vector3(0.0, 1.92, -6.35), mat_trim)

	# Main Rotor Hub + 4 Blades
	_add_cylinder(heli, "RotorMast", 0.14, 0.65, Vector3(0.0, 3.05, 0.1), mat_rotor)
	var main_rotor := Node3D.new()
	main_rotor.name = "MainRotor"
	main_rotor.position = Vector3(0.0, 3.35, 0.1)
	heli.add_child(main_rotor)
	_add_cylinder(main_rotor, "Hub", 0.32, 0.22, Vector3.ZERO, mat_rotor)
	for b: int in range(4):
		var pivot := Node3D.new()
		pivot.rotation_degrees.y = float(b) * 90.0
		main_rotor.add_child(pivot)
		_add_box(pivot, "Blade_%d" % b, Vector3(0.28, 0.04, 5.4), Vector3(0.0, 0.0, 2.85), mat_rotor)
		_add_box(pivot, "Tip_%d" % b, Vector3(0.29, 0.045, 0.35), Vector3(0.0, 0.0, 5.45), mat_tip)

	# Tail Rotor
	var tail_rotor := Node3D.new()
	tail_rotor.name = "TailRotor"
	tail_rotor.position = Vector3(0.24, 2.90, -7.25)
	heli.add_child(tail_rotor)
	for b: int in range(2):
		var t_pivot := Node3D.new()
		t_pivot.rotation_degrees.x = float(b) * 90.0
		tail_rotor.add_child(t_pivot)
		_add_box(t_pivot, "TailBlade_%d" % b, Vector3(0.04, 1.55, 0.16), Vector3.ZERO, mat_rotor)

	return heli


static func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _make_mat(albedo: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func _make_emissive_mat(albedo: Color, emission_col: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission_col
	mat.emission_energy_multiplier = energy
	return mat
