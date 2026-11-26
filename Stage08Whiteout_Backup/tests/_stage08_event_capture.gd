extends SceneTree
## Stage 08 — Secret Signal Event Automated Visual Capture
## Renders the real Stage08 in GUI mode and captures all 4 phases of the event.

const STAGE08_SCENE_PATH := "res://scenes/stages/Stage08.tscn"
const SHOT_DIR := "res://verification_screenshots/stage08_secret_signal"

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	print("[CAPTURE] Starting Secret Signal Event visual capture...")
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	
	var packed := load(STAGE08_SCENE_PATH) as PackedScene
	if not packed:
		printerr("[CAPTURE ERROR] Failed to load Stage08 scene.")
		quit(1)
		return
		
	var stage := packed.instantiate()
	root.add_child(stage)
	current_scene = stage

	# Settle initial shaders and terrain
	for _i in range(30):
		await process_frame

	# Neutralize enemies for clean peaceful capture
	var enemies := stage.get_node_or_null("Enemies") as Node3D
	if enemies:
		for e in enemies.get_children():
			if "is_dead" in e:
				e.is_dead = true
			e.set_physics_process(false)

	var player = stage.get_node_or_null("Player3D")
	var camera: Camera3D = null
	if player:
		camera = player.get_node_or_null("Camera3D") as Camera3D

	# -------------------------------------------------------------------------
	# Shot 1: Approaching Radar Console at summit
	# -------------------------------------------------------------------------
	print("[CAPTURE] Phase 1: Radar Console approach...")
	var console_pos: Vector3 = stage.get_radar_console_position()
	player.global_position = console_pos + Vector3(0.0, 0.0, 2.0)
	if camera:
		camera.look_at(console_pos + Vector3(0.0, 0.7, 0.0), Vector3.UP)
	for _i in range(25):
		await process_frame
	_save_shot(SHOT_DIR + "/01_radar_terminal_active.png")

	# -------------------------------------------------------------------------
	# Shot 2: Trigger radar shutdown -> wait 1.8s for siren & secret signal popup
	# -------------------------------------------------------------------------
	print("[CAPTURE] Phase 2: Radar Shutdown and Secret Signal Intercept...")
	stage.trigger_radar_shutdown()
	await create_timer(1.8).timeout
	for _i in range(20):
		await process_frame
	_save_shot(SHOT_DIR + "/02_secret_signal_intercept_hud.png")

	# -------------------------------------------------------------------------
	# Shot 3: Dismiss overlay and move to anomalous signal source
	# -------------------------------------------------------------------------
	print("[CAPTURE] Phase 3: Vault Transducer Signal Source...")
	stage.dismiss_secret_signal_panel()
	var signal_pos: Vector3 = stage.get_signal_source_position()
	player.global_position = signal_pos + Vector3(0.0, 0.0, 2.4)
	if camera:
		camera.look_at(signal_pos + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	for _i in range(25):
		await process_frame
	_save_shot(SHOT_DIR + "/03_anomalous_signal_source_vault.png")

	# -------------------------------------------------------------------------
	# Shot 4: Investigate signal source -> Mission Victory Debrief
	# -------------------------------------------------------------------------
	print("[CAPTURE] Phase 4: Signal Decoded & Mission Victory Debrief...")
	stage.investigate_signal_source()
	for _i in range(30):
		await process_frame
	_save_shot(SHOT_DIR + "/04_stage08_victory_anomaly_debrief.png")

	print("[CAPTURE] All 4 event screenshots captured successfully.")
	quit(0)

func _save_shot(path: String) -> void:
	var vp := root.get_viewport()
	if not vp:
		printerr("[CAPTURE ERROR] Viewport is null for ", path)
		return
	var img := vp.get_texture().get_image()
	if img:
		var global_path := ProjectSettings.globalize_path(path)
		var err := img.save_png(global_path)
		print("[CAPTURE] Saved: ", global_path, " (status: ", err == OK, ")")
	else:
		printerr("[CAPTURE ERROR] Could not get viewport image for ", path)
