extends SceneTree

func _init() -> void:
	call_deferred("_trace_transition_flow")

func _trace_transition_flow() -> void:
	print("\n=======================================================")
	print("=== RUNTIME TRANSITION TRACE: HQ -> GAMEPLAY ===")
	print("=======================================================\n")

	var dir = DirAccess.open("res://")
	if not dir.dir_exists("verification_screenshots/stage08_iron_peak/transition_trace"):
		dir.make_dir_recursive("verification_screenshots/stage08_iron_peak/transition_trace")

	# Step 1: Boot into HQ (StageSelection.tscn)
	print("[1/5] Loading HQ Scene: res://scenes/StageSelection.tscn")
	var hq_scene = load("res://scenes/StageSelection.tscn")
	assert(hq_scene != null)
	var hq_inst = hq_scene.instantiate()
	root.add_child(hq_inst)
	current_scene = hq_inst

	for i in range(10):
		await process_frame

	print("  - Current active scene: %s (path: %s)" % [current_scene.name, current_scene.scene_file_path])
	_save_screenshot("verification_screenshots/stage08_iron_peak/transition_trace/01_hq.png")

	# Select Stage 8 in HQ
	if hq_inst.has_method("select_stage"):
		hq_inst.select_stage(8)
	elif "selected_stage_id" in hq_inst:
		hq_inst.selected_stage_id = 8
	print("  - HQ selected stage: %d" % (hq_inst.get_selected_stage_id() if hq_inst.has_method("get_selected_stage_id") else 8))

	# Click Action Button in HQ
	var action_btn = hq_inst.get_node_or_null("Margin/MainLayout/RightColumn/ActionPanel/ActionButton")
	if action_btn:
		print("  - Action button found. Emitting pressed signal...")
		action_btn.emit_signal("pressed")
	else:
		print("  - Action button not found at path, calling StageManager.load_stage(8)")
		var sm = root.get_node_or_null("/root/StageManager")
		if sm:
			sm.load_stage(8)

	for i in range(15):
		await process_frame

	# Step 2: In Intro Scene
	print("\n[2/5] After HQ Action Button:")
	print("  - Current active scene: %s (path: %s)" % [current_scene.name, current_scene.scene_file_path])
	_save_screenshot("verification_screenshots/stage08_iron_peak/transition_trace/02_intro.png")

	# In Intro, click Briefing Button
	var intro_inst = current_scene
	var briefing_btn = intro_inst.get_node_or_null("AspectContainer/Background/BriefingButton")
	if briefing_btn:
		print("  - Intro BriefingButton found. Emitting pressed...")
		briefing_btn.emit_signal("pressed")
	else:
		print("  - BriefingButton not found, attempting change_scene_to_file")
		change_scene_to_file("res://scenes/stages/Stage08IronPeakBriefing.tscn")

	for i in range(15):
		await process_frame

	# Step 3: In Briefing Scene
	print("\n[3/5] After Briefing Button:")
	print("  - Current active scene: %s (path: %s)" % [current_scene.name, current_scene.scene_file_path])
	_save_screenshot("verification_screenshots/stage08_iron_peak/transition_trace/03_briefing.png")

	# In Briefing, click Continue Button
	var briefing_inst = current_scene
	var continue_btn = briefing_inst.get_node_or_null("Margin/Card/Margin/VBox/FooterHBox/ContinueButton")
	if continue_btn:
		print("  - Briefing ContinueButton found. Emitting pressed...")
		continue_btn.emit_signal("pressed")
	else:
		print("  - ContinueButton not found, attempting change_scene_to_file")
		change_scene_to_file("res://scenes/stages/Stage08IronPeakLoadout.tscn")

	for i in range(15):
		await process_frame

	# Step 4: In Loadout Scene
	print("\n[4/5] After Briefing Continue:")
	print("  - Current active scene: %s (path: %s)" % [current_scene.name, current_scene.scene_file_path])
	_save_screenshot("verification_screenshots/stage08_iron_peak/transition_trace/04_loadout.png")

	# In Loadout, click Confirm Button (Start Mission)
	var loadout_inst = current_scene
	var confirm_btn = loadout_inst.get_node_or_null("Margin/Card/Margin/VBox/FooterHBox/ConfirmButton")
	if confirm_btn:
		print("  - Loadout ConfirmButton (Start Mission) found. Emitting pressed...")
		confirm_btn.emit_signal("pressed")
	else:
		print("  - ConfirmButton not found, attempting change_scene_to_file")
		change_scene_to_file("res://scenes/stages/Stage08.tscn")

	for i in range(25):
		await process_frame

	# Step 5: In Gameplay Scene
	print("\n[5/5] After Loadout Confirm (Gameplay Entry):")
	print("  - Current active scene: %s (path: %s)" % [current_scene.name, current_scene.scene_file_path])
	print("  - Scene script: %s" % (current_scene.get_script().resource_path if current_scene.get_script() else "NONE"))
	
	# Inspect Player, Environment, and HUD
	var player = current_scene.get_node_or_null("Player3D")
	if player:
		print("  - Player3D found: pos=Vector3(%.2f, %.2f, %.2f), hp=%d" % [player.global_position.x, player.global_position.y, player.global_position.z, player.current_health])
		var gun_model = player.get_node_or_null("Camera3D/WeaponRig/GunModel")
		if gun_model:
			print("  - GunModel children: %s" % str(gun_model.get_children().map(func(c): return c.name)))
	else:
		print("  - Player3D: NOT FOUND!")

	var env = current_scene.get_node_or_null("Environment")
	if env:
		print("  - Environment children: %s" % str(env.get_children().map(func(c): return c.name)))
	else:
		print("  - Environment: NOT FOUND!")

	var hud = current_scene.get_node_or_null("HUD")
	if hud:
		print("  - HUD found: %s (script: %s)" % [hud.name, hud.get_script().resource_path if hud.get_script() else "NONE"])
	else:
		print("  - HUD: NOT FOUND!")

	_save_screenshot("verification_screenshots/stage08_iron_peak/transition_trace/05_actual_gameplay.png")

	print("\n=======================================================")
	print("=== RUNTIME TRANSITION TRACE COMPLETE ===")
	print("=======================================================\n")
	quit(0)

func _save_screenshot(file_path: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(file_path)
		print("  [Screenshot] Saved: %s" % file_path)
	else:
		print("  [Screenshot] FAILED: null image")
