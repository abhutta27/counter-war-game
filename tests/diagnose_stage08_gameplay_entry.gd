extends SceneTree
## Diagnostic script for Stage 08 Gameplay Entry Failure
## Traces the complete flow:
## StageSelection -> Stage08 Intro -> Briefing -> Loadout -> Gameplay (Stage08.tscn)

const TIMEOUT_SECONDS: float = 20.0

var _timer: float = 0.0

func _init() -> void:
	print("\n=======================================================")
	print("=== STAGE 08 GAMEPLAY ENTRY DIAGNOSTIC TRACE START ===")
	print("=======================================================\n")
	call_deferred("_run_diagnosis")

func _process(delta: float) -> bool:
	_timer += delta
	if _timer >= TIMEOUT_SECONDS:
		push_error("[DIAGNOSTIC TIMEOUT] Diagnostic hung or exceeded timeout!")
		quit(1)
		return true
	return false

func _run_diagnosis() -> void:
	for _f in range(3):
		await process_frame

	var stage_mgr = root.get_node_or_null("StageManager")
	var profile_mgr = root.get_node_or_null("ProfileManager")
	var game_mgr = root.get_node_or_null("GameManager")

	print("[Step 1: Autoload & Profile State Inspection]")
	print("  - StageManager present: %s" % str(stage_mgr != null))
	print("  - ProfileManager present: %s" % str(profile_mgr != null))
	print("  - GameManager present: %s" % str(game_mgr != null))

	if profile_mgr:
		print("  - Valid profile: %s" % str(profile_mgr.has_valid_profile()))
		print("  - Highest unlocked stage in ProfileManager: %d" % profile_mgr.get_highest_unlocked_stage())

	if stage_mgr:
		var s8_info = stage_mgr.get_stage_info(8)
		print("  - Stage 8 registered in StageManager: %s" % str(not s8_info.is_empty()))
		print("  - Stage 8 info: %s" % str(s8_info))
		print("  - Is Stage 8 unlocked via is_stage_unlocked(8): %s" % str(stage_mgr.is_stage_unlocked(8)))

	print("\n[Step 2: Testing Stage Selection -> Stage 8 Launch]")
	# Test opening StageSelection scene
	var hq_scene = load("res://scenes/StageSelection.tscn")
	var hq_inst = hq_scene.instantiate()
	root.add_child(hq_inst)
	for _f in range(3):
		await process_frame

	print("  - HQ Scene instantiated successfully.")
	# Check whether Stage 8 button / row is unlocked in HQ
	if hq_inst.has_method("get_selected_stage_id"):
		print("  - HQ initial selected stage: %d" % hq_inst.get_selected_stage_id())

	# Test what happens when StageManager.load_stage(8) is called
	print("\n[Step 3: Testing StageManager.load_stage(8) (Production Call)]")
	var load_success = stage_mgr.load_stage(8)
	print("  - StageManager.load_stage(8) returned: %s" % str(load_success))
	if not load_success:
		print("  ! ATTENTION: load_stage(8) was rejected by StageManager! Testing load_stage_for_testing(8)...")
		var test_load = stage_mgr.load_stage_for_testing(8)
		print("  - StageManager.load_stage_for_testing(8) returned: %s" % str(test_load))

	hq_inst.queue_free()
	for _f in range(5):
		await process_frame

	# What scene is now active in root?
	var current_scene = root.get_child(root.get_child_count() - 1)
	print("  - Current active scene name: %s, class: %s" % [current_scene.name, current_scene.get_class()])

	print("\n[Step 4: Testing Intro -> Briefing -> Loadout -> Stage08 Flow]")
	# Check Intro scene
	print("  4a. Loading Intro scene: res://scenes/stages/Stage08IronPeakIntro.tscn")
	var intro_scn = load("res://scenes/stages/Stage08IronPeakIntro.tscn")
	var intro_inst = intro_scn.instantiate()
	root.add_child(intro_inst)
	for _f in range(3):
		await process_frame
	print("    ✔ Intro instantiated. Testing start button navigation target...")
	var intro_start = intro_inst.get_node_or_null("AspectContainer/Background/StartButton")
	print("    - Intro StartButton found: %s" % str(intro_start != null))
	intro_inst.queue_free()

	# Check Briefing scene
	print("  4b. Loading Briefing scene: res://scenes/stages/Stage08IronPeakBriefing.tscn")
	var briefing_scn = load("res://scenes/stages/Stage08IronPeakBriefing.tscn")
	var briefing_inst = briefing_scn.instantiate()
	root.add_child(briefing_inst)
	for _f in range(3):
		await process_frame
	print("    ✔ Briefing instantiated.")
	briefing_inst.queue_free()

	# Check Loadout scene
	print("  4c. Loading Loadout scene: res://scenes/stages/Stage08IronPeakLoadout.tscn")
	var loadout_scn = load("res://scenes/stages/Stage08IronPeakLoadout.tscn")
	var loadout_inst = loadout_scn.instantiate()
	root.add_child(loadout_inst)
	for _f in range(3):
		await process_frame
	print("    ✔ Loadout instantiated.")
	var loadout_confirm = loadout_inst.get_node_or_null("Margin/Card/Margin/VBox/FooterHBox/ConfirmButton")
	print("    - Loadout ConfirmButton found: %s" % str(loadout_confirm != null))
	loadout_inst.queue_free()

	print("\n[Step 5: Testing Direct Instantiation of Gameplay Scene: Stage08.tscn]")
	var stage8_scn = load("res://scenes/stages/Stage08.tscn")
	assert(stage8_scn != null, "FATAL: Could not load res://scenes/stages/Stage08.tscn!")
	var stage8_inst = stage8_scn.instantiate()
	root.add_child(stage8_inst)
	print("  - Stage08 added to tree.")

	# Process 30 physics/process frames to observe player, camera, physics, terrain collision
	print("\n[Step 6: Simulating 30 Gameplay Frames in Stage08.tscn]")
	for frame_num in range(1, 31):
		await process_frame
		if frame_num in [1, 5, 10, 20, 30]:
			var player = stage8_inst.get_node_or_null("Player3D")
			if player:
				var pos = player.global_position
				var vel = player.velocity
				var on_floor = player.is_on_floor()
				var cam = player.get_node_or_null("Camera3D")
				var cam_current = cam.current if cam else false
				print("    Frame %2d: Player pos=(%.2f, %.2f, %.2f) vel=(%.2f, %.2f, %.2f) on_floor=%s cam_current=%s hp=%d" % [
					frame_num, pos.x, pos.y, pos.z, vel.x, vel.y, vel.z, str(on_floor), str(cam_current), player.current_health
				])
			else:
				print("    Frame %2d: Player is NULL!" % frame_num)

	# Check player input handling
	var player_node = stage8_inst.get_node_or_null("Player3D")
	if player_node:
		print("\n[Step 7: Testing Player Input & Movement Action]")
		# Simulate moving forward
		var move_ev = InputEventAction.new()
		move_ev.action = "move_forward"
		move_ev.pressed = true
		Input.parse_input_event(move_ev)
		for _f in range(5):
			await process_frame
		var pos_after = player_node.global_position
		var vel_after = player_node.velocity
		print("    - Position after move_forward: (%.2f, %.2f, %.2f), velocity: (%.2f, %.2f, %.2f)" % [
			pos_after.x, pos_after.y, pos_after.z, vel_after.x, vel_after.y, vel_after.z
		])
		# Release move_forward
		move_ev.pressed = false
		Input.parse_input_event(move_ev)

	# Capture actual runtime screenshot of gameplay in Stage08.tscn
	print("\n[Step 8: Capturing Runtime Gameplay Screenshot]")
	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var screenshot_file = "res://verification_screenshots/stage08_iron_peak/diagnostic_gameplay_entry.png"
		var abs_path = ProjectSettings.globalize_path(screenshot_file)
		img.save_png(abs_path)
		print("  ✔ Gameplay screenshot saved to: %s" % abs_path)

	# Check Game State Machine
	if game_mgr:
		print("\n[Step 9: GameManager State Inspection]")
		print("  - Current Game State: %d (0=BOOT, 1=MAIN_MENU, 2=PLAYING, 3=PAUSED, 4=GAME_OVER)" % game_mgr.current_state)

	stage8_inst.queue_free()

	print("\n=======================================================")
	print("=== STAGE 08 GAMEPLAY ENTRY DIAGNOSTIC TRACE COMPLETE ==")
	print("=======================================================\n")
	quit(0)
