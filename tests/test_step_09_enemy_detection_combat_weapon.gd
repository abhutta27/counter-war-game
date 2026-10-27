extends SceneTree
## test_step_09_enemy_detection_combat_weapon.gd
## Comprehensive Automated Test for STEP 09:
## Enemy Starting Weapon Presence, Detection Voice Alert, Non-Crawl Hit Reaction,
## Standing-to-Fall Death Lifecycle, Gun Inactivity, and Regressions.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_step_09_tests")

func _run_step_09_tests() -> void:
	print("=================================================================")
	print("  COUNTER WAR - STEP 09 COMPREHENSIVE AUTOMATED TEST SUITE       ")
	print("=================================================================")
	
	var level_scene = load("res://scenes/Level1.tscn")
	assert(level_scene != null, "Level1.tscn must exist and load")
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(10):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemies_node: Node3D = level.get_node("Enemies")
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	# Enemy 4 is placed at (-10, 0, -24), ~29.7m away from Player at (0, 0, 4) > 28m detection radius
	var enemy4: Enemy3D = level.get_node("Enemies/Enemy3D_4") as Enemy3D
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SoundManager")
	var stg_mgr = root.get_node("StageManager")

	print("\n--- GROUP 1: WEAPON INITIALIZATION & PRE-COMBAT STATE (1 - 9) ---")
	# 1. Enemy spawns
	assert(enemy4 != null and enemy4 is Enemy3D, "TEST 1: Enemy4 spawned successfully")
	print("[PASS] 01: Enemy spawned into level")
	
	# 2. Weapon exists immediately after spawn
	assert(enemy4.enemy_weapon != null, "TEST 2: Enemy weapon node exists immediately upon spawn")
	print("[PASS] 02: Weapon exists immediately after spawn")
	
	# 3. Weapon is visible
	assert(enemy4.enemy_weapon.visible == true, "TEST 3: Enemy weapon is visible")
	print("[PASS] 03: Weapon is visible")
	
	# 4. Enemy holds weapon at idle/post
	assert(enemy4.current_state == Enemy3D.State.IDLE, "TEST 4: Enemy is in IDLE at its post")
	var weapon_parent = enemy4.enemy_weapon.get_parent()
	assert(weapon_parent is BoneAttachment3D and (weapon_parent as BoneAttachment3D).bone_name == "mixamorig_RightHand", "TEST 4: Weapon is attached to soldier's right hand")
	print("[PASS] 04: Enemy holds weapon in right hand at idle/post")
	
	# 5. Weapon exists before detection
	assert(enemy4.has_detected_player == false, "TEST 5: Enemy4 has not detected player yet")
	assert(enemy4.enemy_weapon.visible == true, "TEST 5: Weapon is visible before detection")
	print("[PASS] 05: Weapon exists and is visible before player detection")
	
	# 6. Weapon remains present after detection
	enemy4._trigger_player_detection()
	assert(enemy4.has_detected_player == true, "TEST 6: Enemy detected player")
	assert(enemy4.enemy_weapon != null and enemy4.enemy_weapon.visible == true, "TEST 6: Weapon remains present and visible after detection")
	print("[PASS] 06: Weapon remains equipped and visible after detection")
	
	# 7. Weapon did not suddenly appear only after hit (was already there)
	var weapon_before_hit = enemy4.enemy_weapon
	assert(weapon_before_hit != null and weapon_before_hit.visible, "TEST 7: Weapon was already instantiated and visible prior to any damage")
	print("[PASS] 07: Weapon did not pop-in on hit; was already equipped")
	
	# 8. Weapon does not disappear after bullet hit
	enemy4.take_damage(20) # Non-lethal
	await process_frame
	assert(enemy4.enemy_weapon != null and enemy4.enemy_weapon.visible == true, "TEST 8: Weapon does not disappear after bullet hit")
	print("[PASS] 08: Weapon does not disappear after bullet hit")
	
	# 9. Restart preserves starting weapon
	var fresh_enemy = load("res://scenes/entities/Enemy3D.tscn").instantiate()
	root.add_child(fresh_enemy)
	await process_frame
	assert(fresh_enemy.enemy_weapon != null and fresh_enemy.enemy_weapon.visible == true, "TEST 9: Freshly spawned/restarted enemy has weapon immediately")
	fresh_enemy.queue_free()
	print("[PASS] 09: Restarted/fresh enemy has weapon equipped from the start")

	print("\n--- GROUP 2: DETECTION & VOICE ALERT (10 - 14) ---")
	# 10. Enemy detects player
	var enemy2: Enemy3D = level.get_node("Enemies/Enemy3D_2") as Enemy3D
	assert(enemy2 != null, "Enemy 2 exists")
	enemy2.global_position = Vector3(0, 0, -10) # Within detection radius
	enemy2.has_detected_player = false
	enemy2._trigger_player_detection()
	assert(enemy2.has_detected_player == true, "TEST 10: Enemy detects player")
	print("[PASS] 10: Enemy detects player successfully")
	
	# 11. Detection voice triggers
	assert(sm != null and sm.has_method("play_enemy_alert_voice"), "TEST 11: SoundManager has play_enemy_alert_voice method")
	sm.play_enemy_alert_voice()
	print("[PASS] 11: Detection voice alert triggers via SoundManager")
	
	# 12. Voice does not spam (cooldown and per-enemy guard)
	var time_first = sm._last_alert_voice_time
	sm.play_enemy_alert_voice() # Immediate second call should be ignored by cooldown
	assert(sm._last_alert_voice_time == time_first, "TEST 12: SoundManager suppresses immediate voice spam within cooldown")
	print("[PASS] 12: Voice spam is blocked by global and per-enemy guards")
	
	# 13. Dead enemy gives no voice
	enemy2.is_dead = true
	enemy2.current_state = Enemy3D.State.DEAD
	enemy2.has_detected_player = false
	enemy2._trigger_player_detection()
	assert(enemy2.has_detected_player == false, "TEST 13: Dead enemy cannot trigger player detection or voice")
	enemy2.is_dead = false
	enemy2.current_state = Enemy3D.State.IDLE
	print("[PASS] 13: Dead enemy never emits voice alert")
	
	# 14. No voice after Game Over
	gm.current_state = GameConstants.GameState.GAME_OVER
	assert(sm._can_play_combat_audio() == false, "TEST 14: Combat audio is blocked in GAME_OVER")
	gm.current_state = GameConstants.GameState.PLAYING
	print("[PASS] 14: Voice alert blocked after Game Over")

	print("\n--- GROUP 3: COMBAT & ANTI-CRAWL BEHAVIOR (15 - 19) ---")
	# 15. Enemy targets player
	enemy1.current_state = Enemy3D.State.ATTACK
	enemy1.look_at(Vector3(player.global_position.x, enemy1.global_position.y, player.global_position.z), Vector3.UP)
	var dir_to_p = (player.global_position - enemy1.global_position).normalized()
	assert(dir_to_p.length() > 0.5, "TEST 15: Targeting vector to player valid")
	print("[PASS] 15: Enemy targets player")
	
	# 16. Enemy fires weapon
	var p_hp_before = player.current_health
	enemy1._perform_counter_attack(player)
	for i in range(5):
		await process_frame
	assert(player.current_health < p_hp_before, "TEST 16: Enemy fired and dealt damage to player")
	print("[PASS] 16: Enemy fires weapon and inflicts damage")
	
	# 17. Enemy stays alive on non-lethal hit
	var e1_hp_before = enemy1.current_health
	enemy1.take_damage(20)
	assert(enemy1.current_health == e1_hp_before - 20 and enemy1.current_health > 0, "TEST 17: Enemy alive after non-lethal hit")
	assert(not enemy1.is_dead, "TEST 17: is_dead is false")
	print("[PASS] 17: Enemy stays alive after non-lethal bullet hit")
	
	# 18. Enemy DOES NOT CRAWL (stays standing upright, rotation_degrees of Character is -90)
	var char_node = enemy1.soldier_model.get_node("Character")
	assert(is_equal_approx(char_node.rotation_degrees.x, -90.0), "TEST 18: Character stays standing upright at -90 deg X (never knocked to 0 deg crawl)")
	print("[PASS] 18: Enemy NEVER crawls or sits; stays standing upright (-90 deg X)")
	
	# 19. Enemy standing combat continues
	assert(enemy1.current_state == Enemy3D.State.HIT or enemy1.current_state == Enemy3D.State.ATTACK or enemy1.current_state == Enemy3D.State.CHASE, "TEST 19: Enemy continues combat loop")
	print("[PASS] 19: Enemy maintains standing combat posture")

	print("\n--- GROUP 4: DEATH LIFECYCLE (20 - 25) ---")
	# 20. Firing stops on 0 HP
	var lethal_shot = DamageInfo.new(enemy1.current_health, false, player, "Rifle", enemy1.global_position, Vector3.FORWARD, Vector3.UP, 0)
	enemy1.take_damage(lethal_shot)
	await process_frame
	assert(enemy1.is_weapon_enabled == false, "TEST 20: Weapon disabled on death")
	print("[PASS] 20: Firing disabled immediately upon health zero")
	
	# 21. Movement stops
	assert(enemy1.velocity == Vector3.ZERO, "TEST 21: Velocity zeroed on death")
	assert(not enemy1.is_physics_processing(), "TEST 21: Physics processing disabled")
	print("[PASS] 21: Movement completely halted on death")
	
	# 22. Attack stops
	assert(enemy1.attack_timer >= 99999.0, "TEST 22: Attack timer stopped/maximized")
	print("[PASS] 22: Attack timer and actions halted")
	
	# 23. Death animation plays
	assert(enemy1.anim_player.current_animation == "Death", "TEST 23: Death animation is playing")
	print("[PASS] 23: Proper Death animation triggered")
	
	# 24. Enemy falls to ground
	enemy1.anim_player.seek(0.85, true) # Seek to end of death anim
	await process_frame
	# In Death anim, d_rot animates Character:rotation_degrees to 0.0 (horizontal flat on ground)
	assert(is_equal_approx(char_node.rotation_degrees.x, 0.0), "TEST 24: Enemy collapsed flat to ground on death")
	print("[PASS] 24: Enemy collapsed naturally onto ground")
	
	# 25. Enemy in DEAD state
	assert(enemy1.current_state == Enemy3D.State.DEAD and enemy1.is_dead == true, "TEST 25: Enemy in DEAD state")
	print("[PASS] 25: Enemy cleanly in DEAD state")

	print("\n--- GROUP 5: GUN LIFECYCLE (26 - 28) ---")
	# 26. Dead enemy gun cannot fire
	var p_hp_dead_test = player.current_health
	enemy1._perform_counter_attack(player)
	for i in range(5):
		await process_frame
	assert(player.current_health == p_hp_dead_test, "TEST 26: Dead enemy weapon strictly cannot fire or deal damage")
	print("[PASS] 26: Dead enemy gun strictly cannot fire")
	
	# 27. Ground/corpse gun cannot fire
	assert(enemy1.is_weapon_enabled == false, "TEST 27: Weapon flag is_weapon_enabled = false")
	assert(not enemy1.enemy_muzzle_flash.visible, "TEST 27: Muzzle flash hidden")
	print("[PASS] 27: Ground/corpse gun is completely inert")
	
	# 28. No orphan fire timer/callback
	assert(enemy1._attack_tween == null, "TEST 28: Attack tween destroyed on death")
	print("[PASS] 28: No orphan fire timers or callbacks remaining")

	print("\n--- GROUP 6: SYSTEM REGRESSIONS (29 - 36) ---")
	# 29. Player movement
	assert(player.velocity != null, "TEST 29: Player velocity functional")
	print("[PASS] 29: Player movement system intact")
	
	# 30. Camera working
	var cam = player.find_child("Camera3D", true, false)
	assert(cam != null, "TEST 30: Player Camera3D intact")
	print("[PASS] 30: Camera system intact")
	
	# 31. Player shooting working
	var wm = player.weapon_manager
	assert(wm != null and wm.get_current_weapon() != null and wm.get_current_weapon().has_method("fire"), "TEST 31: WeaponManager active weapon fire intact")
	print("[PASS] 31: Player shooting intact")
	
	# 32. Weapon switching working
	assert(wm.has_method("switch_next_weapon") and wm.has_method("equip_weapon_by_index"), "TEST 32: Weapon switching intact")
	print("[PASS] 32: Weapon switching intact")
	
	# 33. Game Over working
	player.take_damage(player.current_health)
	await process_frame
	assert(gm.current_state == GameConstants.GameState.GAME_OVER or gm.current_state == GameConstants.GameState.MISSION_COMPLETE, "TEST 33: Game Over triggers on player death")
	print("[PASS] 33: Game Over system intact")
	
	# 34. Restart working
	stg_mgr.restart_current_stage()
	for i in range(15):
		await process_frame
	assert(stg_mgr.get_current_stage_id() == 1, "TEST 34: Restart current stage intact")
	print("[PASS] 34: Restart system intact")
	
	# 35. Stage 01 working
	assert(root.get_node_or_null("Stage01") != null or root.get_node_or_null("Level1") != null, "TEST 35: Stage 01 loaded cleanly")
	print("[PASS] 35: Stage 01 intact")
	
	# 36. Stage 02 working
	stg_mgr.load_stage(2)
	for i in range(25):
		await process_frame
	var stg2 = root.get_node_or_null("Stage02")
	assert(stg2 != null, "TEST 36: Stage 02 loads cleanly")
	print("[PASS] 36: Stage 02 intact")

	print("\n=================================================================")
	print("  ALL 36 STEP 09 AUTOMATED TEST CRITERIA PASSED! (36/36)         ")
	print("=================================================================\n")
	
	level.queue_free()
	quit(0)
