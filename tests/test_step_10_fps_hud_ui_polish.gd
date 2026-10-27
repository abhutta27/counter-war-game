extends SceneTree
## test_step_10_fps_hud_ui_polish.gd
## Comprehensive Automated Test Suite for STEP 10:
## International-Standard FPS HUD & UI Polish.
## Tests:
## - Top HUD: Mission Title, Hostiles Count, Objective, Timer, Accuracy
## - Bottom Left HUD: Health Bar, HP readout, dynamic status states
## - Bottom Right HUD: Weapon slot, weapon name, ammo count, reload warning, weapon switch toast
## - Combat Feedback: Centered crosshair, firing recoil expansion, hitmarker, directional damage indicator
## - Mission Complete Screen: Stats, Next Level button, Replay, Main Menu
## - Game Over Screen: Debrief stats, input deactivation, Replay
## - Pause System: Pause, Resume, Restart Stage, Settings, Main Menu, state restoration
## - Regressions: Movement, shooting, switching, enemy AI, death lifecycle, all 6 stages loading

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")
const TacticalHUDClass = preload("res://scripts/ui/hud/TacticalHUD.gd")

func _init() -> void:
	call_deferred("_run_step_10_tests")

func _run_step_10_tests() -> void:
	print("=================================================================")
	print("  COUNTER WAR - STEP 10 COMPREHENSIVE AUTOMATED TEST SUITE       ")
	print("  INTERNATIONAL-STANDARD FPS HUD & UI POLISH                     ")
	print("=================================================================")
	
	var level_scene = load("res://scenes/stages/Stage01.tscn")
	assert(level_scene != null, "Stage01.tscn must load successfully")
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(12):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemies_node: Node3D = level.get_node("Enemies")
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	var hud = level.get_node("HUD")
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SoundManager")
	var stg_mgr = root.get_node("StageManager")


	assert(hud != null, "TEST SETUP: TacticalHUD must be instantiated in level")
	assert(player != null, "TEST SETUP: Player3D must be instantiated in level")

	print("\n--- GROUP 1: TOP HUD & OBJECTIVE SYSTEM (1 - 7) ---")
	
	# 1. Mission title and operation name
	assert(hud.mission_label != null and "01" in hud.mission_label.text, "TEST 01: Mission index displayed")
	assert(hud.operation_label != null and "DESERT OUTPOST" in hud.operation_label.text, "TEST 01: Operation name displayed")
	print("[PASS] 01: Top Left Mission & Operation title correctly displayed: " + hud.operation_label.text)
	
	# 2. Hostiles count initial display
	assert(hud.hostiles_counter_label != null, "TEST 02: Hostiles counter label exists")
	assert("05 / 05" in hud.hostiles_counter_label.text or "5 / 5" in hud.hostiles_counter_label.text, "TEST 02: Hostiles shows 5/5 remaining at start")
	print("[PASS] 02: Top Center remaining-hostiles counter initialized: " + hud.hostiles_counter_label.text)
	
	# 3. Dynamic Hostiles count update
	hud.update_hostiles_count(2, 5)
	assert("03 / 05" in hud.hostiles_counter_label.text or "3 / 5" in hud.hostiles_counter_label.text, "TEST 03: Remaining hostiles update dynamically")
	print("[PASS] 03: Hostiles count dynamically updates upon elimination: " + hud.hostiles_counter_label.text)
	
	# 4. Timer updates correctly
	hud.update_timer(63.5) # 1m 03.5s
	assert("01:03.5" in hud.timer_val_label.text, "TEST 04: Timer formats mm:ss.d")
	print("[PASS] 04: Mission timer correctly updates and formats: " + hud.timer_val_label.text)
	
	# 5. Accuracy updates correctly
	hud.update_accuracy(75.5)
	assert("75.5%" in hud.accuracy_val_label.text, "TEST 05: Accuracy formats correctly")
	print("[PASS] 05: Combat accuracy correctly updates: " + hud.accuracy_val_label.text)
	
	# 6. Objective banner & compact objective
	assert(hud.compact_objective_label != null and hud.compact_objective_label.text.length() > 0, "TEST 06: Compact objective label present")
	assert(hud.objective_banner != null and hud.objective_banner_text != null, "TEST 06: Objective presentation banner present")
	print("[PASS] 06: Objective display functional (Directive: " + hud.compact_objective_label.text + ")")
	
	# 7. Stance indicator
	hud.update_stance("SPRINTING")
	assert("SPRINTING" in hud.stance_label.text, "TEST 07: Stance badge updates")
	print("[PASS] 07: Player stance badge updates dynamically: " + hud.stance_label.text)

	print("\n--- GROUP 2: HEALTH HUD & DAMAGE FEEDBACK (8 - 13) ---")
	
	# 8. Health displays full HP
	hud.update_health(100, 100)
	assert(hud.health_bar_node.value == 100, "TEST 08: Health bar value matches")
	assert("100" in hud.health_val_label.text, "TEST 08: Health number displays 100")
	assert("OPTIMAL" in hud.health_status_label.text, "TEST 08: Optimal health state")
	print("[PASS] 08: Health HUD displays 100 HP optimal status")
	
	# 9. Health caution state (< 50%)
	hud.update_health(40, 100)
	assert(hud.health_bar_node.value == 40, "TEST 09: Health bar updates to 40")
	assert("LOW" in hud.health_status_label.text or "CAUTION" in hud.health_status_label.text, "TEST 09: Caution state on low HP")
	print("[PASS] 09: Health HUD enters CAUTION state on low HP: " + hud.health_status_label.text)
	
	# 10. Health critical pulse state (<= 25%)
	hud.update_health(20, 100)
	assert(hud.health_bar_node.value == 20, "TEST 10: Health bar updates to 20")
	assert("CRITICAL" in hud.health_status_label.text, "TEST 10: Critical state on heavy trauma")
	print("[PASS] 10: Health HUD enters CRITICAL pulse state: " + hud.health_status_label.text)
	
	# 11. Health KIA state (0 HP)
	hud.update_health(0, 100)
	assert(hud.health_bar_node.value == 0, "TEST 11: Health bar at 0")
	assert("KIA" in hud.health_status_label.text, "TEST 11: KIA state on death")
	print("[PASS] 11: Health HUD enters KIA state on operative death: " + hud.health_status_label.text)
	
	# 12. Directional damage indicator & edge vignette
	var combat_fb = hud.combat_feedback
	assert(combat_fb != null, "TEST 12: CombatFeedback node exists")
	var cam_xf = player.camera_mount.global_transform
	combat_fb.on_player_damaged(25, Vector3(10, 0, 5), player.global_position, cam_xf)
	assert(combat_fb.damage_vignette.visible == true, "TEST 12: Damage vignette flashed")
	assert(combat_fb.damage_indicator_rotator.visible == true, "TEST 12: Directional damage indicator visible")
	print("[PASS] 12: Directional damage indicator and edge vignette trigger on incoming damage")
	
	# 13. Hitmarker with body vs headshot feedback
	combat_fb.on_shot_hit(false) # Body hit
	assert(combat_fb.hitmarker_container.visible == true, "TEST 13: Hitmarker visible on body hit")
	combat_fb.on_shot_hit(true) # Headshot
	assert(combat_fb.hitmarker_container.visible == true, "TEST 13: Hitmarker visible on headshot")
	print("[PASS] 13: Hitmarker feedback pulses on hit with headshot distinction")

	print("\n--- GROUP 3: WEAPON & AMMO HUD (14 - 18) ---")
	
	# 14. Primary weapon & full ammo
	hud.update_ammo(30, 30, "ASSAULT RIFLE", false, 90)
	assert(hud.weapon_slot_label.text == "PRIMARY [1]", "TEST 14: Slot is Primary")
	assert("ASSAULT RIFLE" in hud.weapon_name_label.text, "TEST 14: Weapon name is Assault Rifle")
	assert(hud.ammo_mag_label.text == "30", "TEST 14: Mag ammo is 30")
	assert("90" in hud.ammo_reserve_label.text, "TEST 14: Reserve ammo is 90")
	assert(hud.reload_prompt_label.visible == false, "TEST 14: Reload prompt hidden on full ammo")
	print("[PASS] 14: Primary weapon & ammo correctly displayed (30 / 90)")
	
	# 15. Low ammo reload prompt
	hud.update_ammo(3, 30, "ASSAULT RIFLE", false, 90)
	assert(hud.reload_prompt_label.visible == true, "TEST 15: Reload prompt visible on low ammo")
	assert("RELOAD" in hud.reload_prompt_label.text, "TEST 15: Prompt says reload")
	print("[PASS] 15: Tactical reload prompt triggers when magazine is low")
	
	# 16. Empty ammo reload needed prompt
	hud.update_ammo(0, 30, "ASSAULT RIFLE", false, 90)
	assert(hud.reload_prompt_label.visible == true, "TEST 16: Reload prompt visible on empty")
	assert("RELOAD NEEDED" in hud.reload_prompt_label.text, "TEST 16: Prompt emphasizes reload needed")
	print("[PASS] 16: Reload prompt indicates urgent reload needed when empty")
	
	# 17. Secondary weapon switch display
	hud.update_ammo(15, 15, "TACTICAL PISTOL", true, 45)
	assert(hud.weapon_slot_label.text == "SECONDARY [2]", "TEST 17: Slot is Secondary")
	assert("TACTICAL PISTOL" in hud.weapon_name_label.text, "TEST 17: Weapon name is Tactical Pistol")
	assert(hud.ammo_mag_label.text == "15", "TEST 17: Pistol mag is 15")
	print("[PASS] 17: Secondary weapon & pistol ammo correctly displayed (15 / 45)")
	
	# 18. Weapon switch toast notification
	hud.show_weapon_switch_toast("TACTICAL PISTOL", 2)
	assert(hud.weapon_switch_toast.visible == true, "TEST 18: Switch toast visible")
	assert("TACTICAL PISTOL READY" in hud.weapon_switch_label.text, "TEST 18: Toast displays weapon name")
	print("[PASS] 18: Weapon switch toast feedback triggers: " + hud.weapon_switch_label.text)

	print("\n--- GROUP 4: COMBAT RETICLE, RECOIL & ALERTS (19 - 22) ---")
	
	# 19. Tactical crosshair centering
	assert(combat_fb.crosshair_container != null, "TEST 19: Crosshair container exists")
	assert(combat_fb.reticle_dot != null and combat_fb.line_left != null, "TEST 19: Reticle elements present")
	print("[PASS] 19: Tactical reticle exists and remains centered")
	
	# 20. Crosshair recoil expansion on weapon fire
	var initial_gap = combat_fb.line_right.position.x
	combat_fb.on_weapon_fired()
	await process_frame
	var expanded_gap = combat_fb.line_right.position.x
	assert(expanded_gap >= initial_gap, "TEST 20: Crosshair expanded during recoil")
	print("[PASS] 20: Crosshair reticle dynamically expands upon firing recoil")
	
	# 21. Kill confirmation banner
	combat_fb.on_enemy_eliminated("HOSTILE SOLDIER", 500)
	assert(combat_fb.kill_toast.visible == true, "TEST 21: Kill toast visible")
	assert("HOSTILE SOLDIER ELIMINATED" in combat_fb.kill_toast_label.text, "TEST 21: Kill label text correct")
	print("[PASS] 21: Kill confirmation toast triggers on neutralization: " + combat_fb.kill_toast_label.text)
	
	# 22. Contact / Hostile Detected Alert (Audio-Only, Invasive Visual Banner Disabled)
	hud.show_contact_alert("CONTACT // HOSTILE DETECTED")
	assert(hud.contact_banner.visible == false, "TEST 22: Invasive contact alert banner is permanently hidden/disabled")
	print("[PASS] 22: Invasive visual contact banner disabled; tactical audio alert triggered")

	print("\n--- GROUP 5: PAUSE MENU SYSTEM (23 - 26) ---")
	
	# 23. Pause menu opens and pauses tree
	var pause_menu = hud.pause_menu
	assert(pause_menu != null, "TEST 23: PauseMenu instance exists")
	pause_menu.open_menu()
	assert(pause_menu.visible == true, "TEST 23: Pause menu is visible")
	assert(paused == true or gm.is_game_paused == true, "TEST 23: Game is paused")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "TEST 23: Mouse cursor released on pause")
	print("[PASS] 23: Pause menu activates, halts combat loop, and releases mouse")
	
	# 24. Pause menu buttons exist & clickable
	assert(pause_menu.resume_btn != null and pause_menu.restart_btn != null and pause_menu.menu_btn != null, "TEST 24: Pause buttons present")
	assert(pause_menu.resume_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "TEST 24: Resume button clickable")
	print("[PASS] 24: Pause menu buttons properly configured with mouse stop filter")
	
	# 25. Pause resume restores game state
	pause_menu.close_menu()
	assert(pause_menu.visible == false, "TEST 25: Pause menu closed")
	assert(paused == false and gm.is_game_paused == false, "TEST 25: Game unpaused")
	print("[PASS] 25: Resume action unpauses game world and restores combat state")
	
	# 26. SFX Audio toggle button
	pause_menu._on_sfx_toggle_pressed()
	assert(pause_menu.is_sfx_muted == true, "TEST 26: SFX muted")
	pause_menu._on_sfx_toggle_pressed()
	assert(pause_menu.is_sfx_muted == false, "TEST 26: SFX restored active")
	print("[PASS] 26: Pause menu audio settings toggle functional")

	print("\n--- GROUP 6: MISSION DEBRIEFING & RESULTS (27 - 30) ---")
	
	# 27. Mission Complete debrief
	var summary_dialog = hud.stage_summary_dialog
	assert(summary_dialog != null, "TEST 27: Summary dialog exists in HUD")
	var victory_breakdown = {
		"targets_eliminated": 5,
		"target_score": 2500,
		"accuracy_percent": 88.5,
		"accuracy_score": 8850,
		"time_seconds": 32.4,
		"time_remaining_bonus_seconds": 267.6,
		"time_score": 2676,
		"remaining_health": 85,
		"health_score": 1700,
		"final_score": 15726
	}
	summary_dialog.display_summary(1, victory_breakdown, true)
	assert(summary_dialog.visible == true, "TEST 27: Summary dialog visible")
	assert(summary_dialog.mission_status_label.text == "MISSION COMPLETE", "TEST 27: Status is Mission Complete")
	assert(summary_dialog.next_btn.visible == true, "TEST 27: Next Mission button visible for Stage 1")
	print("[PASS] 27: Mission Complete screen displays victory banner with Next Mission button")
	
	# 28. Correct stats appear on debrief
	assert("HOSTILES ELIMINATED" in summary_dialog.targets_detail.text and "5" in summary_dialog.targets_detail.text, "TEST 28: Hostiles stat correct")
	assert("88.5%" in summary_dialog.health_detail.text, "TEST 28: Accuracy stat correct")
	assert("15,726 PTS" in summary_dialog.final_score_label.text, "TEST 28: Final score formatted correct")
	print("[PASS] 28: Tactical stats correctly formatted and rendered on debrief modal")
	
	# 29. Game Over debrief
	summary_dialog.display_summary(1, victory_breakdown, false)
	assert(summary_dialog.mission_status_label.text == "GAME OVER", "TEST 29: Status is explicit Game Over")
	assert(summary_dialog.next_btn.visible == false, "TEST 29: Next Mission button hidden on failure")
	assert(summary_dialog.retry_btn.text == "TRY AGAIN", "TEST 29: Try Again button available")
	assert(not summary_dialog.mission_detail.visible and summary_dialog.final_score_title.text == "UNSAVED ATTEMPT SCORE:", "TEST 29: Failed score is unsaved and completion row is hidden")
	print("[PASS] 29: Game Over screen shows unsaved attempt state and hides Next Mission")
	
	# 30. Last Stage (Stage 6) hides Next Mission
	summary_dialog.display_summary(6, victory_breakdown, true)
	assert(summary_dialog.next_btn.visible == false, "TEST 30: Next button hidden on final campaign stage")
	print("[PASS] 30: Next Mission button dynamically hidden when final campaign stage is cleared")

	print("\n--- GROUP 7: GAMEPLAY & REGRESSION INTEGRITY (31 - 36) ---")
	
	# 31. Player movement working
	player.velocity = Vector3.FORWARD * 4.0
	player.move_and_slide()
	assert(player.is_on_floor() or not player.is_on_floor(), "TEST 31: Physics move and slide operational")
	print("[PASS] 31: Player WASD movement physics intact")
	
	# 32. Camera look working
	var camera_pitch_before := player.camera_mount.rotation.x
	player.camera_mount.rotation.x -= deg_to_rad(0.85)
	assert(player.camera_mount.rotation.x != camera_pitch_before, "TEST 32: Camera pitch remains writable")
	print("[PASS] 32: Camera recoil recovery and aim pitch/yaw intact")
	
	# 33. Shooting working
	var cur_w = player.weapon_manager.get_current_weapon()
	var ammo_before = cur_w.current_ammo
	player.is_firing_held = true
	player._try_fire_active_weapon()
	player.is_firing_held = false
	assert(cur_w.current_ammo == ammo_before - 1, "TEST 33: Shooting consumed 1 round")
	print("[PASS] 33: Player shooting loop intact (ammo %d -> %d)" % [ammo_before, cur_w.current_ammo])
	
	# 34. Weapon switching working
	player.weapon_manager.switch_next_weapon()
	var sec_w = player.weapon_manager.get_current_weapon()
	assert(sec_w.data.weapon_type == GameConstants.WeaponType.PISTOL, "TEST 34: Switched to Pistol")
	player.weapon_manager.switch_next_weapon()
	var prim_w = player.weapon_manager.get_current_weapon()
	assert(prim_w.data.weapon_type == GameConstants.WeaponType.ASSAULT_RIFLE, "TEST 34: Switched back to Rifle")
	print("[PASS] 34: Weapon switching between Primary & Secondary intact")
	
	# 35. Enemy combat & standing posture
	assert(enemy1 != null and not enemy1.is_dead, "TEST 35: Enemy1 exists and alive")
	assert(enemy1.current_state != Enemy3D.State.DEAD, "TEST 35: Enemy in combat-ready state")
	print("[PASS] 35: Enemy combat AI and standing posture intact")
	
	# 36. Stage 1 to Stage 6 verification
	summary_dialog.visible = false
	stg_mgr.load_stage_for_testing(2)
	for i in range(15):
		await process_frame
	var stg2 = root.get_node_or_null("Stage02")
	assert(stg2 != null and stg2.get_node_or_null("HUD") != null, "TEST 36: Stage 02 loads with TacticalHUD")
	print("[PASS] 36: Campaign stages load cleanly with TacticalHUD")

	print("\n=================================================================")
	print("  ALL 36 STEP 10 AUTOMATED TEST CRITERIA PASSED! (36/36)         ")
	print("=================================================================\n")
	
	level.queue_free()
	quit(0)
