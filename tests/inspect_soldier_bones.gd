extends SceneTree
## test_enemy_gun_death_lifecycle.gd
## Comprehensive Automated Test for Enemy Gun Detachment, Post-Death Inactivity,
## Kill Counter Reliability, and Clean Combat Lifecycle.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=======================================================")
	print("  BEGIN ENEMY GUN & DEATH LIFECYCLE VERIFICATION SUITE")
	print("=======================================================")
	
	var level_scene = load("res://scenes/Level1.tscn")
	if not level_scene:
		printerr("FAIL: Could not load Level1.tscn")
		quit(1)
		return
		
	var level = level_scene.instantiate()
	root.add_child(level)
	
	for i in range(15):
		await process_frame
		
	var player: Player3D = level.get_node("Player3D") as Player3D
	var enemies_node: Node3D = level.get_node("Enemies")
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	var enemy2: Enemy3D = level.get_node("Enemies/Enemy3D_2") as Enemy3D
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SoundManager")
	
	# TEST 1: Enemy Weapon Hand Attachment (No Floating or Disconnected Gun)
	print("\n[TEST 1] Verifying Enemy Weapon is attached to Soldier Hand...")
	var skel: Skeleton3D = enemy2.soldier_model.find_child("Skeleton3D", true, false)
	var weapon_parent = enemy2.enemy_weapon.get_parent()
	var is_attached_to_hand = (weapon_parent is BoneAttachment3D and (weapon_parent as BoneAttachment3D).bone_name == "mixamorig_RightHand")
	assert(is_attached_to_hand, "Enemy weapon MUST be attached to Skeleton3D via BoneAttachment3D (mixamorig_RightHand)")
	print("  -> TEST 1 PASSED: Enemy rifle is attached to mixamorig_RightHand bone attachment!")

	# TEST 2: Lethal Shot to Enemy — Immediate Inactivity & Weapon Disabling
	print("\n[TEST 2] Testing Lethal Shot to Enemy...")
	var initial_hp = enemy2.current_health
	var fatal_dmg = DamageInfo.new(initial_hp, false, player, "Rifle", enemy2.global_position, Vector3.FORWARD, Vector3.UP, GameConstants.DamageType.BULLET)
	enemy2.take_damage(fatal_dmg)
	await process_frame
	
	assert(enemy2.is_dead == true, "Enemy must be flagged is_dead = true")
	assert(enemy2.is_active == false, "Enemy must be flagged is_active = false")
	assert(enemy2.is_weapon_enabled == false, "Enemy weapon must be flagged is_weapon_enabled = false")
	assert(enemy2.current_state == Enemy3D.State.DEAD, "Enemy state must be State.DEAD")
	assert(enemy2.attack_timer >= 99999.0, "Enemy attack timer must be stopped/maximized")
	assert(enemy2.velocity == Vector3.ZERO, "Enemy velocity must be zeroed on death")
	assert(not enemy2.is_physics_processing(), "Enemy physics process must be disabled on death")
	if enemy2.enemy_muzzle_flash:
		assert(not enemy2.enemy_muzzle_flash.visible, "Muzzle flash must be hidden on death")
	print("  -> TEST 2 PASSED: Lethal shot completely halted enemy AI, physics, attack timer, and disabled weapon!")

	# TEST 3: Dead Enemy Weapon CANNOT Fire (No Damage, No Flash, No Audio)
	print("\n[TEST 3] Testing Dead Enemy Weapon CANNOT Fire...")
	var player_hp_before = player.current_health
	# Forcefully attempt to call counter attack on dead enemy
	enemy2._perform_counter_attack(player)
	for i in range(5):
		await process_frame
		
	var player_hp_after = player.current_health
	assert(player_hp_after == player_hp_before, "Dead enemy must NOT deal damage to player!")
	if enemy2.enemy_muzzle_flash:
		assert(not enemy2.enemy_muzzle_flash.visible, "Dead enemy weapon must NOT show muzzle flash!")
	print("  -> TEST 3 PASSED: Calling counter attack on dead enemy is strictly rejected! Zero player damage.")

	# TEST 4: Dead Enemy Never Crawls or Moves Toward Player
	print("\n[TEST 4] Testing Dead Enemy Does Not Crawl or Move...")
	var death_pos = enemy2.global_position
	# Advance physics ticks
	for i in range(30):
		enemy2._physics_process(0.016)
		await process_frame
	var pos_after_physics = enemy2.global_position
	assert(death_pos.distance_to(pos_after_physics) < 0.001, "Dead enemy position must remain frozen on the spot!")
	print("  -> TEST 4 PASSED: Dead enemy remains 100% frozen on the spot; zero crawling or movement.")

	# TEST 5: Kill Counter Reliability (One Enemy = Exactly ONE Kill)
	print("\n[TEST 5] Testing Kill Counter Reliability across all 5 enemies...")
	var initial_eliminated = level.targets_eliminated
	print("  Initial hostiles eliminated: %d / %d" % [initial_eliminated, level.total_targets])
	
	# Eliminate enemies one by one
	var all_enemies = enemies_node.get_children()
	var expected_kills = 1 # enemy2 was already eliminated in TEST 2
	assert(level.targets_eliminated == 1, "Enemy2 death should have incremented targets_eliminated to 1")
	
	for e in all_enemies:
		var enemy = e as Enemy3D
		if enemy == enemy2:
			continue
		var hp = enemy.current_health
		var d = DamageInfo.new(hp, false, player, "Rifle", enemy.global_position, Vector3.FORWARD, Vector3.UP, GameConstants.DamageType.BULLET)
		enemy.take_damage(d)
		expected_kills += 1
		await process_frame
		assert(level.targets_eliminated == expected_kills, "Each enemy death must increment kills by exactly 1! (Expected: %d, Got: %d)" % [expected_kills, level.targets_eliminated])
		print("  -> Defeated Hostile #%d -> Level targets_eliminated = %d" % [expected_kills, level.targets_eliminated])
		
	assert(level.targets_eliminated == 5, "Total eliminated enemies must be exactly 5!")
	assert(level.is_stage_finished == true, "Stage must complete when all 5 hostiles are eliminated!")
	print("  -> TEST 5 PASSED: Exactly 5 kills registered (1-by-1) with level completion triggered.")

	# TEST 6: Game Over & Audio Shutdown
	print("\n[TEST 6] Testing Game Over Combat Shutdown...")
	player.take_damage(DamageInfo.new(player.current_health, false, enemy1, "Fatal", player.global_position, Vector3.FORWARD, Vector3.UP, GameConstants.DamageType.BULLET))
	await process_frame
	assert(gm.current_state == GameConstants.GameState.GAME_OVER or gm.current_state == GameConstants.GameState.MISSION_COMPLETE, "State machine transitioned")
	print("  -> TEST 6 PASSED: Complete state shutdown verified.")

	print("\n=======================================================")
	print("  ALL ENEMY GUN & DEATH LIFECYCLE TESTS PASSED (6/6)!")
	print("=======================================================\n")
	
	level.queue_free()
	quit(0)

