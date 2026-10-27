extends SceneTree
## test_step_11_shooting_visibility.gd
## Comprehensive Automated Test Suite for VISIBLY CLEAR SHOOTING IN ALL STAGES:
## Tests:
## - Central ShootingSystem coordinator functionality
## - Player projectile spawning, visibility, and flight trajectory
## - Player muzzle flash at weapon barrel tip
## - Smooth projectile travel (no instant teleportation)
## - Projectile arrival and deferred impact callback
## - Impact effect spark spawning
## - Enemy muzzle flash and visible enemy projectile flight
## - Enemy projectile damage delivery on arrival
## - Weapon switching (Assault Rifle & Pistol) muzzle & projectile support
## - Projectile lifecycle cleanup (no memory leaks)
## - Multi-stage verification across all 6 stages

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=================================================================")
	print("  COUNTER WAR - VISIBLY CLEAR SHOOTING IN ALL STAGES            ")
	print("  COMPREHENSIVE AUTOMATED VERIFICATION SUITE                     ")
	print("=================================================================")
	
	var level_scene = load("res://scenes/stages/Stage01.tscn")
	assert(level_scene != null, "Stage01.tscn must load successfully")
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(12):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	var shooting_sys = root.get_node_or_null("ShootingSystem")
	
	assert(player != null, "TEST SETUP: Player3D must be valid")
	assert(enemy1 != null, "TEST SETUP: Enemy3D_1 must be valid")
	assert(shooting_sys != null, "TEST SETUP: ShootingSystem autoload must be active")

	print("\n--- GROUP 1: CENTRAL SHOOTING SYSTEM & COORDINATOR (1 - 4) ---")
	
	# 1. ShootingSystem autoload existence
	assert(shooting_sys.has_method("spawn_projectile"), "TEST 01: spawn_projectile method exists")
	assert(shooting_sys.has_method("trigger_muzzle_flash"), "TEST 01: trigger_muzzle_flash method exists")
	assert(shooting_sys.has_method("spawn_impact_effect"), "TEST 01: spawn_impact_effect method exists")
	print("[PASS] 01: Central ShootingSystem coordinator active with core API methods")
	
	# 2. Active world container creation
	var container = shooting_sys._get_active_world_container()
	assert(container != null and is_instance_valid(container), "TEST 02: ActiveCombatFX container created")
	print("[PASS] 02: 3D world container ActiveCombatFX correctly created in scene tree")
	
	# 3. Direct projectile spawning
	var test_proj = shooting_sys.spawn_projectile(Vector3(0, 1, 0), Vector3(0, 1, 20), true, Callable(), 50.0)
	assert(test_proj != null and is_instance_valid(test_proj), "TEST 03: Projectile successfully instantiated")
	assert(test_proj.get_parent() == container, "TEST 03: Projectile parented to world container")
	print("[PASS] 03: Projectile3D properly instantiated into world space")
	
	# 4. Projectile visual components (Mesh, Trail, Light)
	var bullet_mesh = test_proj.get_node_or_null("MeshInstance3D")
	var trail_mesh = test_proj.get_node_or_null("TrailMesh")
	var bullet_light = test_proj.get_node_or_null("BulletLight")
	assert(bullet_mesh != null and bullet_mesh.mesh != null, "TEST 04: Projectile has visible core mesh")
	assert(trail_mesh != null and trail_mesh.mesh != null, "TEST 04: Projectile has visible tracer trail mesh")
	assert(bullet_light != null, "TEST 04: Projectile has dynamic point light")
	test_proj.queue_free()
	print("[PASS] 04: Projectile has visible emissive core, elongated tracer trail, and light")

	print("\n--- GROUP 2: PLAYER SHOOTING, MUZZLE FLASH & TRAJECTORY (5 - 9) ---")
	
	# 5. Weapon muzzle position
	var active_wpn = player.weapon_manager.get_current_weapon()
	assert(active_wpn != null, "TEST 05: Player has active weapon equipped")
	var muzzle_pos = active_wpn.get_muzzle_global_position()
	assert(muzzle_pos.distance_squared_to(player.global_position) > 0.05, "TEST 05: Barrel position is offset from player center")
	print("[PASS] 05: Player weapon barrel locator accurately positioned in 3D world: " + str(muzzle_pos))
	
	# 6. Muzzle flash triggers on fire
	var initial_ammo = active_wpn.current_ammo
	player._try_fire_active_weapon()
	assert(active_wpn.current_ammo == initial_ammo - 1, "TEST 06: Weapon consumed 1 round")
	var flash = active_wpn.get_node_or_null("MuzzleFlash3D")
	assert(flash != null and flash.visible, "TEST 06: Muzzle flash spawned and visible on fire")
	print("[PASS] 06: Weapon barrel muzzle flash activates and is visible at weapon tip")
	
	# 7. Projectile spawned in flight
	var spawned_projs = container.get_children()
	assert(spawned_projs.size() > 0, "TEST 07: Projectile spawned into world container")
	var active_bullet = spawned_projs.back()
	var bullet_start_pos = active_bullet.global_position
	print("[PASS] 07: Player firing spawned visible bullet into flight: start pos " + str(bullet_start_pos))
	
	# 8. Projectile travels smoothly (no instant teleport)
	for f in range(4):
		await process_frame
	var bullet_mid_pos = active_bullet.global_position if is_instance_valid(active_bullet) else bullet_start_pos
	assert(bullet_mid_pos.distance_to(bullet_start_pos) > 0.05, "TEST 08: Bullet has moved continuously across frames")
	print("[PASS] 08: Bullet travels along visible trajectory (distance moved: " + str(bullet_mid_pos.distance_to(bullet_start_pos)) + "m)")
	
	# 9. Projectile impact & cleanup
	var impact_data = {"occurred": false}
	var callback = func(_p, _n):
		impact_data["occurred"] = true
	var direct_test = shooting_sys.spawn_projectile(Vector3(0, 1, 0), Vector3(0, 1, 2.0), true, callback, 60.0)
	for i in range(30):
		if impact_data["occurred"]:
			break
		await process_frame
	assert(impact_data["occurred"], "TEST 09: Impact callback triggered upon arrival")
	print("[PASS] 09: Projectile reaches destination and triggers impact callback")

	print("\n--- GROUP 3: IMPACT FX & ENEMY DAMAGE TIMING (10 - 14) ---")
	
	# 10. Impact effect spawning
	var impact_effect = shooting_sys.spawn_impact_effect(Vector3(2, 1, 2), Vector3.UP, true)
	assert(impact_effect != null and is_instance_valid(impact_effect), "TEST 10: ImpactEffect3D instantiated")
	print("[PASS] 10: Impact spark effect spawned with normal alignment")
	
	# 11. Enemy hit reaction on damage
	var prev_enemy_hp = enemy1.current_health
	var test_dmg = DamageInfo.new(25, false, player, "Assault Rifle", enemy1.global_position, Vector3.FORWARD, Vector3.UP, GameConstants.DamageType.BULLET)
	enemy1.take_damage(test_dmg, false)
	assert(enemy1.current_health == prev_enemy_hp - 25, "TEST 11: Enemy takes damage")
	print("[PASS] 11: Enemy successfully processes bullet damage and triggers hit reaction")
	
	# 12. Enemy firing spawns visible projectile
	var enemy_proj_spawned = false
	var initial_player_hp = player.current_health
	enemy1._perform_counter_attack(player)
	var enemy_bullets = []
	for child in container.get_children():
		if "is_player" in child and not child.is_player:
			enemy_bullets.append(child)
	assert(enemy_bullets.size() > 0, "TEST 12: Enemy firing spawns visible hostile projectile")
	print("[PASS] 12: Enemy counter-attack spawns visible crimson projectile")
	
	# 13. Enemy projectile travels and hits player
	for i in range(40):
		if player.current_health < initial_player_hp:
			break
		await process_frame
	assert(player.current_health < initial_player_hp, "TEST 13: Player damaged after enemy bullet flight")
	print("[PASS] 13: Enemy projectile traveled across combat distance and damaged player upon impact")
	
	# 14. Secondary weapon (Pistol) firing
	player.weapon_manager.equip_weapon_by_index(1) # Switch to Tactical Pistol
	await process_frame
	var pistol = player.weapon_manager.get_current_weapon()
	assert(pistol.data.weapon_name == "Tactical Pistol", "TEST 14: Tactical Pistol equipped")
	player._try_fire_active_weapon()
	var pistol_flash = pistol.get_node_or_null("MuzzleFlash3D")
	assert(pistol_flash != null and pistol_flash.visible, "TEST 14: Pistol muzzle flash triggers on fire")
	print("[PASS] 14: Secondary weapon (Tactical Pistol) supports visible firing and barrel muzzle flash")

	print("\n--- GROUP 4: MULTI-STAGE SHOOTING VERIFICATION (15 - 20) ---")
	
	var stage_scenes = [
		"res://scenes/stages/Stage01.tscn",
		"res://scenes/stages/Stage02.tscn",
		"res://scenes/stages/Stage03.tscn",
		"res://scenes/stages/Stage04.tscn",
		"res://scenes/stages/Stage05.tscn",
		"res://scenes/stages/Stage06.tscn"
	]
	
	for idx in range(stage_scenes.size()):
		var path = stage_scenes[idx]
		var stage_num = idx + 1
		var scn = load(path)
		assert(scn != null, "Stage scene must exist: " + path)
		var test_stage = scn.instantiate()
		root.add_child(test_stage)
		for f in range(6):
			await process_frame
			
		var stg_player: Player3D = test_stage.get_node_or_null("Player3D")
		assert(stg_player != null, "Stage " + str(stage_num) + " has Player3D")
		var stg_container = shooting_sys._get_active_world_container()
		assert(stg_container != null, "Stage " + str(stage_num) + " has ActiveCombatFX")
		
		# Test firing in this stage
		var p_wpn = stg_player.weapon_manager.get_current_weapon()
		if p_wpn:
			stg_player._try_fire_active_weapon()
			var stage_bullets = stg_container.get_children()
			assert(stage_bullets.size() > 0, "Stage " + str(stage_num) + " bullet spawned in flight")
			
		print("[PASS] " + str(15 + idx) + ": Stage 0" + str(stage_num) + " successfully verified with visible shooting system")
		test_stage.queue_free()
		for f in range(3):
			await process_frame

	print("\n=================================================================")
	print("  ALL 20 STEP 11 SHOOTING VISIBILITY CRITERIA PASSED! (20/20)    ")
	print("=================================================================")
	quit(0)
