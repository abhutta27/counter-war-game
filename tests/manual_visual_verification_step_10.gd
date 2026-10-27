extends SceneTree
## manual_visual_verification_step_10.gd
## Executes manual visual gameplay verification scenarios and captures high-resolution screenshots:
## 1. Tactical HUD Overview (Top HUD, Health HUD, Ammo HUD, Centered Reticle)
## 2. Weapon Switch Toast & Secondary Slot
## 3. Hostile Detection "CONTACT" Banner
## 4. Combat Feedback (Hitmarker, Recoil Spread, Kill Toast)
## 5. Directional Damage Feedback & Edge Vignette
## 6. Tactical Pause Menu Suspend Screen
## 7. Mission Complete Debriefing Modal (Accomplished, Stats, Next Mission)
## 8. Mission Failed Debriefing Modal (KIA, Stats, Replay)
## 9. Stage 02 HUD Dynamic Updating

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_visual_verification")

func _run_visual_verification() -> void:
	print("\n=================================================================")
	print("  BEGIN STEP 10 MANUAL GAMEPLAY VISUAL VERIFICATION              ")
	print("=================================================================")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("verification_screenshots"):
		dir.make_dir("verification_screenshots")
		
	var level_scene = load("res://scenes/stages/Stage01.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(15):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	var hud = level.get_node("HUD")
	var gm = root.get_node("GameManager")
	var stg_mgr = root.get_node("StageManager")

	# 1. Capture Tactical HUD Overview (after intro banner auto-compacts)
	print("[SCREENSHOT 1] Waiting for intro directive to auto-compact into Top HUD...")
	for i in range(160):
		await process_frame
	print("[SCREENSHOT 1] Capturing Tactical HUD Overview...")
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://verification_screenshots/step_10_01_hud_tactical_layout.png")
	print("  -> Saved res://verification_screenshots/step_10_01_hud_tactical_layout.png")

	# 2. Capture Weapon Switch Toast & Secondary Slot
	print("[SCREENSHOT 2] Capturing Weapon Switch Toast...")
	player.weapon_manager.switch_next_weapon()
	for i in range(10):
		await process_frame
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://verification_screenshots/step_10_02_weapon_switch_toast.png")
	print("  -> Saved res://verification_screenshots/step_10_02_weapon_switch_toast.png")

	# 3. Capture Enemy Contact Alert Banner
	print("[SCREENSHOT 3] Capturing Enemy Contact Alert Banner...")
	hud.show_contact_alert("CONTACT // HOSTILE DETECTED")
	for i in range(10):
		await process_frame
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://verification_screenshots/step_10_03_enemy_contact_alert.png")
	print("  -> Saved res://verification_screenshots/step_10_03_enemy_contact_alert.png")

	# 4. Capture Combat Feedback (Hitmarker, Recoil Spread, Kill Toast)
	print("[SCREENSHOT 4] Capturing Combat Feedback...")
	hud.combat_feedback.on_weapon_fired()
	hud.combat_feedback.on_shot_hit(true) # Red headshot hitmarker
	hud.combat_feedback.on_enemy_eliminated("HOSTILE SCOUT", 500)
	for i in range(8):
		await process_frame
	var img4 = root.get_viewport().get_texture().get_image()
	img4.save_png("res://verification_screenshots/step_10_04_combat_feedback_hitmarker.png")
	print("  -> Saved res://verification_screenshots/step_10_04_combat_feedback_hitmarker.png")

	# 5. Capture Directional Damage Indicator & Edge Vignette
	print("[SCREENSHOT 5] Capturing Directional Damage Indicator & Edge Vignette...")
	hud.combat_feedback.on_player_damaged(35, Vector3(15.0, 0.0, 5.0), player.global_position, player.camera_mount.global_transform)
	for i in range(8):
		await process_frame
	var img5 = root.get_viewport().get_texture().get_image()
	img5.save_png("res://verification_screenshots/step_10_05_directional_damage_indicator.png")
	print("  -> Saved res://verification_screenshots/step_10_05_directional_damage_indicator.png")

	# 6. Capture Tactical Pause Menu Suspend Screen
	print("[SCREENSHOT 6] Capturing Tactical Pause Menu...")
	hud.pause_menu.open_menu()
	for i in range(12):
		await process_frame
	var img6 = root.get_viewport().get_texture().get_image()
	img6.save_png("res://verification_screenshots/step_10_06_tactical_pause_menu.png")
	print("  -> Saved res://verification_screenshots/step_10_06_tactical_pause_menu.png")
	hud.pause_menu.close_menu()
	for i in range(5):
		await process_frame

	# 7. Capture Mission Complete Debriefing Modal
	print("[SCREENSHOT 7] Capturing Mission Complete Debriefing Modal...")
	var victory_breakdown = {
		"targets_eliminated": 5,
		"target_score": 2500,
		"accuracy_percent": 92.5,
		"accuracy_score": 9250,
		"time_seconds": 38.6,
		"time_remaining_bonus_seconds": 261.4,
		"time_score": 2614,
		"remaining_health": 75,
		"health_score": 1500,
		"final_score": 15864
	}
	hud.stage_summary_dialog.display_summary(1, victory_breakdown, true)
	for i in range(12):
		await process_frame
	var img7 = root.get_viewport().get_texture().get_image()
	img7.save_png("res://verification_screenshots/step_10_07_mission_complete_debrief.png")
	print("  -> Saved res://verification_screenshots/step_10_07_mission_complete_debrief.png")

	# 8. Capture Mission Failed / Game Over Debriefing Modal
	print("[SCREENSHOT 8] Capturing Mission Failed Debriefing Modal...")
	hud.stage_summary_dialog.display_summary(1, victory_breakdown, false)
	for i in range(12):
		await process_frame
	var img8 = root.get_viewport().get_texture().get_image()
	img8.save_png("res://verification_screenshots/step_10_08_mission_failed_game_over.png")
	print("  -> Saved res://verification_screenshots/step_10_08_mission_failed_game_over.png")
	hud.stage_summary_dialog.visible = false

	# 9. Capture Stage 02 HUD Progression
	print("[SCREENSHOT 9] Capturing Stage 02 HUD Progression...")
	stg_mgr.load_stage(2)
	for i in range(25):
		await process_frame
	var img9 = root.get_viewport().get_texture().get_image()
	img9.save_png("res://verification_screenshots/step_10_09_stage_02_hud_progression.png")
	print("  -> Saved res://verification_screenshots/step_10_09_stage_02_hud_progression.png")

	print("\n=================================================================")
	print("  ALL 9 STEP 10 VERIFICATION SCREENSHOTS CAPTURED SUCCESSFULLY!  ")
	print("=================================================================\n")
	
	quit(0)
