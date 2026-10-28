extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage07.tscn")
const OUTPUT_DIR := "res://verification_screenshots/stage07_signage"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("[Stage07SignageTest] START: Verifying Stage 07 Signage & Wayfinding...")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var stage = STAGE_SCENE.instantiate()
	stage.cinematic_enabled = false
	root.add_child(stage)
	current_scene = stage

	for _f in 15:
		await process_frame

	if stage.player:
		stage.player.visible = false
		stage.player.is_active = false

	var checks := [
		{
			"path": "Environment/EnemyCommandCenter/CommandSign",
			"expected_title": "COMMAND CENTER",
			"expected_sub": "SECTOR 07 // EMBARGO CONTROL BUNKER",
			"cam_pos": Vector3(34.0, 7.3, -15.0),
			"cam_target": Vector3(34.0, 7.3, -21.5),
			"shot": "01_command_center_sign.png"
		},
		{
			"path": "Environment/ExtractionHelipad/ExtractionSign",
			"expected_title": "LZ CHARLIE",
			"expected_sub": "TACTICAL EVACUATION HELIPAD",
			"cam_pos": Vector3(-36.0, 2.0, -29.0),
			"cam_target": Vector3(-36.0, 2.0, -35.6),
			"shot": "02_lz_charlie_sign.png"
		},
		{
			"path": "Environment/SecurityWatchtower/WatchtowerSign",
			"expected_title": "SECURITY WATCHTOWER",
			"expected_sub": "PERIMETER RADAR // SECTOR EAST",
			"cam_pos": Vector3(34.5, 3.2, 23.5),
			"cam_target": Vector3(39.75, 3.2, 23.5),
			"shot": "03_watchtower_sign.png"
		},
		{
			"path": "Environment/CargoWarehouse/WarehouseSign",
			"expected_title": "CARGO WAREHOUSE 07",
			"expected_sub": "NAVAL FREIGHT LOGISTICS // BAYS 01-03",
			"cam_pos": Vector3(-26.0, 6.5, 4.0),
			"cam_target": Vector3(-31.05, 8.6, 4.0),
			"shot": "04_cargo_warehouse_sign.png"
		},
		{
			"path": "Environment/ContainerYardAlpha/YardAlphaSign",
			"expected_title": "CONTAINER YARD ALPHA",
			"expected_sub": "FREIGHT MARSHALLING SECTOR",
			"cam_pos": Vector3(-16.0, 2.6, 55.0),
			"cam_target": Vector3(-16.0, 2.6, 48.46),
			"shot": "05_yard_alpha_sign.png"
		},
		{
			"path": "Environment/SecurityWatchtower/AlarmConsole/AlarmConsoleTag",
			"expected_title": "ALARM CONTROL",
			"expected_sub": "RADAR & BASE PERIMETER",
			"cam_pos": Vector3(38.0, 1.0, 27.2),
			"cam_target": Vector3(38.0, 0.7, 25.4),
			"shot": "06_alarm_control_tag.png"
		},
		{
			"path": "Environment/EnemyCommandCenter/DataTerminal/IntelTerminalTag",
			"expected_title": "INTEL TERMINAL",
			"expected_sub": "TACTICAL DATA ARCHIVE",
			"cam_pos": Vector3(30.0, 1.8, -19.2),
			"cam_target": Vector3(30.0, 1.9, -21.0),
			"shot": "07_intel_terminal_tag.png"
		}
	]

	var test_cam := Camera3D.new()
	test_cam.name = "SignageCaptureCamera"
	stage.add_child(test_cam)
	test_cam.make_current()

	for check in checks:
		var node = stage.get_node_or_null(check["path"])
		assert(node != null, "Sign node must exist: %s" % check["path"])
		assert(node.has_node("BackingBoard"), "Sign %s must have a physical BackingBoard" % check["path"])
		assert(node.has_node("PrimaryText"), "Sign %s must have PrimaryText" % check["path"])
		
		var primary = node.get_node("PrimaryText") as Label3D
		assert(primary.text == check["expected_title"], "Sign title match failed on %s: got '%s'" % [check["path"], primary.text])
		
		if not check["expected_sub"].is_empty():
			assert(node.has_node("SubText"), "Sign %s must have SubText" % check["path"])
			var sub = node.get_node("SubText") as Label3D
			assert(sub.text == check["expected_sub"], "Sign subtext match failed on %s" % check["path"])

		print("[Stage07SignageTest] PASS: Verified %s ('%s')" % [check["path"], check["expected_title"]])

		# Position camera and capture screenshot
		test_cam.global_position = check["cam_pos"]
		test_cam.look_at(check["cam_target"], Vector3.UP)

		for _f in 6:
			await process_frame

		var img = root.get_viewport().get_texture().get_image()
		var out_path = "%s/%s" % [OUTPUT_DIR, check["shot"]]
		img.save_png(out_path)
		print("[Stage07SignageTest] Saved screenshot: %s" % out_path)

	print("\n[Stage07SignageTest] ALL 7 SIGNAGE VERIFICATIONS PASSED SUCCESSFULLY.")
	quit(0)
