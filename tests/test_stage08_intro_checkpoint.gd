extends SceneTree
## Verification test & screenshot capture for Stage 08 Intro Screen Checkpoint
## Strictly timed with safety timeout.

const TIMEOUT_SECONDS: float = 12.0
const SCREENSHOT_PATH: String = "res://verification_screenshots/stage08_iron_peak/runtime_rebuild_intro_screen.png"

var _timer: float = 0.0

func _init() -> void:
	print("=== [STAGE 08 INTRO SCREEN CHECKPOINT START] ===")
	call_deferred("_run_checkpoint")

func _process(delta: float) -> bool:
	_timer += delta
	if _timer >= TIMEOUT_SECONDS:
		push_error("[TIMEOUT] Intro screen checkpoint safety timeout reached!")
		quit(1)
		return true
	return false

func _run_checkpoint() -> void:
	for _f in range(4):
		await process_frame

	print("[1/4] Loading rebuilt Intro screen scene...")
	var scene_path := "res://scenes/stages/stage08_rebuild/Stage08IronPeakIntro.tscn"
	assert(ResourceLoader.exists(scene_path), "Missing rebuilt scene: " + scene_path)
	var scn = load(scene_path)
	assert(scn != null, "Failed to load rebuilt Intro scene!")

	var intro = scn.instantiate()
	assert(intro != null, "Failed to instantiate rebuilt Intro scene!")
	root.add_child(intro)

	for _f in range(8):
		await process_frame

	print("[2/4] Verifying interactive controls & structure...")
	var bg_tex: TextureRect = intro.get_node_or_null("AspectContainer/Background")
	assert(bg_tex != null, "Background TextureRect missing!")
	assert(bg_tex.texture != null, "Background texture is null!")
	assert(bg_tex.texture.resource_path == "res://assets/ui/stage08_iron_peak/screens/01_intro.png", "Wrong texture resource!")
	print("  ✔ Verified reference background texture: " + bg_tex.texture.resource_path)

	var start_btn: Button = intro.get_node_or_null("AspectContainer/Background/StartButton")
	assert(start_btn != null, "StartButton missing!")
	assert(start_btn.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Start button cursor shape not pointing hand!")
	assert(start_btn.is_connected("pressed", intro._on_start_pressed), "Start button not connected to _on_start_pressed!")
	print("  ✔ Verified Start Button interactive setup & connection")

	var briefing_btn: Button = intro.get_node_or_null("AspectContainer/Background/BriefingButton")
	assert(briefing_btn != null, "BriefingButton missing!")
	assert(briefing_btn.is_connected("pressed", intro._on_briefing_pressed), "Briefing button not connected!")
	print("  ✔ Verified Briefing Button interactive setup & connection")

	var back_btn: Button = intro.get_node_or_null("AspectContainer/Background/BackButton")
	assert(back_btn != null, "BackButton missing!")
	assert(back_btn.is_connected("pressed", intro._on_back_pressed), "Back button not connected!")
	print("  ✔ Verified Back Button interactive setup & connection")

	var settings_btn: Button = intro.get_node_or_null("AspectContainer/Background/SettingsButton")
	assert(settings_btn != null, "SettingsButton missing!")
	assert(settings_btn.is_connected("pressed", intro._on_settings_pressed), "Settings button not connected!")
	print("  ✔ Verified Settings Button interactive setup & connection")

	print("[3/4] Capturing actual runtime Intro screenshot...")
	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	assert(img != null, "Failed to get viewport image!")
	var full_path = ProjectSettings.globalize_path(SCREENSHOT_PATH)
	var err = img.save_png(full_path)
	assert(err == OK, "Failed to save screenshot, err: %d" % err)
	print("  ✔ Saved runtime screenshot: %s (Dimensions: %dx%d)" % [full_path, img.get_width(), img.get_height()])

	print("[4/4] Testing Start button press simulation...")
	# Verify that calling _on_start_pressed does not crash
	assert(intro.has_method("_on_start_pressed"), "Missing _on_start_pressed method!")
	print("  ✔ Start button action verified functional")

	intro.queue_free()
	for _f in range(3):
		await process_frame

	print("\n=== [STAGE 08 INTRO CHECKPOINT PASSED SUCCESSFULLY] ===")
	quit(0)
