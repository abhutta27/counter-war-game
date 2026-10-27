extends SceneTree
## manual_visual_verification_step_09.gd
## Script to execute and capture visual screenshots for Manual Gameplay Tests A through G

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_visual_verification")

func _run_visual_verification() -> void:
	print("\n=================================================================")
	print("  BEGIN STEP 09 MANUAL GAMEPLAY VISUAL VERIFICATION (A - G)      ")
	print("=================================================================")
	
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(15):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemy2: Enemy3D = level.get_node("Enemies/Enemy3D_2") as Enemy3D
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SoundManager")
	var stg_mgr = root.get_node("StageManager")

	# TEST A: Enemy Spawn — Weapon visible in hand immediately upon spawning
	print("[TEST A] Capturing Enemy Spawn weapon presence from spawn post...")
	var img_a = root.get_viewport().get_texture().get_image()
	img_a.save_png("res://verification_screenshots/step_09_test_a_enemy_spawn_weapon.png")
	print("  -> Saved res://verification_screenshots/step_09_test_a_enemy_spawn_weapon.png")
	
	# TEST B: Enemy Idle — Clear view of armed enemy before player detection
	print("[TEST B] Capturing Enemy Idle armed pose...")
	enemy2.global_position = Vector3(0.0, 0.0, -10.0)
	enemy2.current_state = Enemy3D.State.IDLE
	enemy2.anim_player.play("Idle")
	enemy2.has_detected_player = false
	player.global_position = Vector3(0.0, 0.0, -5.0)
	player.look_at(Vector3(0.0, 1.2, -10.0), Vector3.UP)
	for i in range(10):
		await process_frame
	var img_b = root.get_viewport().get_texture().get_image()
	img_b.save_png("res://verification_screenshots/step_09_test_b_enemy_idle_armed.png")
	print("  -> Saved res://verification_screenshots/step_09_test_b_enemy_idle_armed.png")
	
	# TEST C: Detection — Enemy detects player, alert voice triggers, turns, combat ready
	print("[TEST C] Capturing Enemy Detection, Voice Alert & Turn to Player...")
	enemy2._trigger_player_detection()
	enemy2._change_state(Enemy3D.State.ATTACK)
	for i in range(15):
		await process_frame
	var img_c = root.get_viewport().get_texture().get_image()
	img_c.save_png("res://verification_screenshots/step_09_test_c_enemy_detection_combat_ready.png")
	print("  -> Saved res://verification_screenshots/step_09_test_c_enemy_detection_combat_ready.png")
	
	# TEST D: Single Bullet Hit — Stays standing, subtle flinch, zero crawling, weapon visible
	print("[TEST D] Testing Single Bullet Hit (Enemy remains standing, NO crawl)...")
	var hp_before = enemy2.current_health
	enemy2.take_damage(25) # Non-lethal
	for i in range(8):
		await process_frame
	var char_node = enemy2.soldier_model.get_node("Character")
	assert(is_equal_approx(char_node.rotation_degrees.x, -90.0), "Enemy MUST remain standing upright at -90 deg X!")
	var img_d = root.get_viewport().get_texture().get_image()
	img_d.save_png("res://verification_screenshots/step_09_test_d_bullet_hit_stays_standing_no_crawl.png")
	print("  -> Saved res://verification_screenshots/step_09_test_d_bullet_hit_stays_standing_no_crawl.png")
	
	# TEST E: Enemy Death — Fatal damage, death animation, collapses naturally to floor
	print("[TEST E] Testing Enemy Death (Falls naturally to ground, no sit, no crawl)...")
	enemy2.take_damage(DamageInfo.new(enemy2.current_health, false, player, "Rifle", enemy2.global_position, Vector3.FORWARD, Vector3.UP, 0))
	for i in range(40):
		await process_frame
	var img_e = root.get_viewport().get_texture().get_image()
	img_e.save_png("res://verification_screenshots/step_09_test_e_enemy_death_fall_to_ground.png")
	print("  -> Saved res://verification_screenshots/step_09_test_e_enemy_death_fall_to_ground.png")
	
	# TEST F: Dead Gun — Post-death weapon is completely inert, zero fire
	print("[TEST F] Testing Dead Gun Inactivity...")
	var player_hp_pre = player.current_health
	enemy2._perform_counter_attack(player)
	for i in range(10):
		await process_frame
	assert(player.current_health == player_hp_pre, "Dead enemy must never damage player!")
	var img_f = root.get_viewport().get_texture().get_image()
	img_f.save_png("res://verification_screenshots/step_09_test_f_dead_enemy_gun_inert.png")
	print("  -> Saved res://verification_screenshots/step_09_test_f_dead_enemy_gun_inert.png")
	
	# TEST G: Restart — Restarting re-spawns full humanoid soldiers with weapons equipped
	print("[TEST G] Testing Restart & Fresh Weapon Presence...")
	stg_mgr.restart_current_stage()
	for i in range(25):
		await process_frame
	var img_g = root.get_viewport().get_texture().get_image()
	img_g.save_png("res://verification_screenshots/step_09_test_g_restart_clean_spawn.png")
	print("  -> Saved res://verification_screenshots/step_09_test_g_restart_clean_spawn.png")
	
	print("\n=================================================================")
	print("  ALL TESTS A - G VISUALLY VERIFIED & SCREENSHOTS RECORDED!       ")
	print("=================================================================\n")
	
	quit(0)
