extends SceneTree
## Captures screenshots of Stage 08 UI and 3D gameplay into verification_screenshots/stage08_iron_peak/

const OUTPUT_DIR := "res://verification_screenshots/stage08_iron_peak/"
const TIMEOUT_SECONDS := 25.0

var _timeout_timer: float = 0.0

func _init() -> void:
	print("[CaptureScreenshots] Starting automated visual capture...")
	call_deferred("_run_captures")

func _process(delta: float) -> bool:
	_timeout_timer += delta
	if _timeout_timer >= TIMEOUT_SECONDS:
		push_error("[CaptureScreenshots] Timeout safety reached!")
		quit(1)
		return true
	return false

func _run_captures() -> void:
	for _f in range(5):
		await process_frame

	# Ensure output dir exists
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	# 1. Intro Screen
	print("[Capture 1/8] Capturing Intro Screen...")
	await _capture_screen("res://scenes/stages/Stage08IronPeakIntro.tscn", "01_stage08_intro.png")

	# 2. Briefing Screen
	print("[Capture 2/8] Capturing Briefing Screen...")
	await _capture_screen("res://scenes/stages/Stage08IronPeakBriefing.tscn", "02_stage08_briefing.png")

	# 3. Loadout Screen
	print("[Capture 3/8] Capturing Loadout Screen...")
	await _capture_screen("res://scenes/stages/Stage08IronPeakLoadout.tscn", "03_stage08_loadout.png")

	# 4. Settings Screen
	print("[Capture 4/8] Capturing Settings Screen...")
	await _capture_screen("res://scenes/stages/ui/Stage08IronPeakSettings.tscn", "08_stage08_settings.png")

	# 5. Success Screen
	print("[Capture 5/8] Capturing Success Screen...")
	var scn_success = load("res://scenes/stages/ui/Stage08IronPeakSuccess.tscn")
	var inst_success = scn_success.instantiate()
	root.add_child(inst_success)
	inst_success.display_success(185.0, 18, 18)
	for _f in range(6):
		await process_frame
	_save_viewport_image("06_stage08_mission_success.png")
	inst_success.queue_free()
	for _f in range(3):
		await process_frame

	# 6. Failed Screen
	print("[Capture 6/8] Capturing Failed Screen...")
	var scn_failed = load("res://scenes/stages/ui/Stage08IronPeakFailed.tscn")
	var inst_failed = scn_failed.instantiate()
	root.add_child(inst_failed)
	inst_failed.display_failure(95.0, 7, 18)
	for _f in range(6):
		await process_frame
	_save_viewport_image("07_stage08_mission_failed.png")
	inst_failed.queue_free()
	for _f in range(3):
		await process_frame

	# 7. 3D Battlefield & Gameplay HUD
	print("[Capture 7/8] Capturing 3D Battlefield & Gameplay HUD...")
	var scn_stage = load("res://scenes/stages/Stage08.tscn")
	var inst_stage = scn_stage.instantiate()
	root.add_child(inst_stage)
	for _f in range(12):
		await process_frame
	_save_viewport_image("04_stage08_gameplay_hud.png")

	# 8. Pause Menu in Gameplay
	print("[Capture 8/8] Capturing Pause Menu overlay...")
	var pause_menu = inst_stage.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.open_menu()
		for _f in range(6):
			await process_frame
		_save_viewport_image("05_stage08_pause_menu.png")
	
	inst_stage.queue_free()
	for _f in range(3):
		await process_frame

	print("[CaptureScreenshots] All visual captures saved successfully!")
	quit(0)

func _capture_screen(scene_path: String, filename: String) -> void:
	var scn = load(scene_path)
	var inst = scn.instantiate()
	root.add_child(inst)
	for _f in range(8):
		await process_frame
	_save_viewport_image(filename)
	inst.queue_free()
	for _f in range(3):
		await process_frame

func _save_viewport_image(filename: String) -> void:
	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var full_path = ProjectSettings.globalize_path(OUTPUT_DIR + filename)
		var err = img.save_png(full_path)
		if err == OK:
			print("  ✔ Saved: %s" % filename)
		else:
			push_error("Failed to save image: %s (err %d)" % [filename, err])
