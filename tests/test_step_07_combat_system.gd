extends SceneTree
## test_step_07_combat_system.gd
## Automated integration & combat test suite for STEP 07: Real Playable Human Enemy & Combat System.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_combat_tests()
	return true

func _run_combat_tests() -> void:
	print("--- BEGIN STEP 07 HUMAN ENEMY & COMBAT SYSTEM TEST SUITE ---")
	
	# Load Level 1
	var level_res = load("res://scenes/Level1.tscn")
	if not level_res:
		printerr("FAILED to load Level1.tscn")
		quit(1)
		return
		
	var level = level_res.instantiate()
	root.add_child(level)
	
	# TEST 01: Verify Game State
	print("[TEST 01] Verifying game state transition to PLAYING...")
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager singleton must exist")
	assert(gm.current_state == GameConstants.GameState.PLAYING, "Game state must be PLAYING")
	print("  -> TEST 01 PASSED (State is PLAYING)")
	
	# TEST 02: Verify Player3D
	print("[TEST 02] Verifying Player3D setup...")
	var player: Player3D = level.get_node_or_null("Player3D") as Player3D
	assert(player != null, "Player3D must exist in Level1")
	assert(player.is_active, "Player must be active initially")
	assert(player.current_health == 100, "Player must start with 100 HP")
	print("  -> TEST 02 PASSED (Player3D ready at 100 HP)")
	
	# TEST 03: Verify Real Humanoid 3D Soldier Model on Enemy
	print("[TEST 03] Verifying real humanoid 3D soldier enemy (no primitives)...")
	var enemy: Enemy3D = level.get_node_or_null("Enemies/Enemy3D_1") as Enemy3D
	assert(enemy != null, "Enemy3D_1 must exist in Level1")
	assert(enemy is Enemy3D, "Enemy node must be an instance of Enemy3D")
	
	var soldier_model = enemy.get_node_or_null("SoldierModel")
	assert(soldier_model != null, "SoldierModel (Soldier.glb) must be attached to enemy")
	
	var skeleton = soldier_model.find_child("Skeleton3D", true, false)
	assert(skeleton != null, "Soldier must have a rigged Skeleton3D")
	
	var body_mesh = soldier_model.find_child("vanguard_Mesh", true, false)
	assert(body_mesh != null, "Soldier must have textured humanoid mesh (vanguard_Mesh)")
	
	var visor_mesh = soldier_model.find_child("vanguard_visor", true, false)
	assert(visor_mesh != null, "Soldier must have tactical helmet visor mesh")
	print("  -> TEST 03 PASSED (Proper rigged humanoid 3D soldier verified)")
	
	# TEST 04: Verify Enemy Animation Lifecycle
	print("[TEST 04] Verifying enemy animation lifecycle (Idle, Walk, Run, HitReaction, Death)...")
	var ap: AnimationPlayer = soldier_model.get_node_or_null("AnimationPlayer")
	assert(ap != null, "AnimationPlayer must exist on soldier model")
	
	var anims = ap.get_animation_list()
	assert("Idle" in anims, "Soldier must have Idle animation")
	assert("Walk" in anims, "Soldier must have Walk animation")
	assert("Run" in anims, "Soldier must have Run animation")
	assert("HitReaction" in anims, "Soldier must have HitReaction animation")
	assert("Death" in anims, "Soldier must have Death animation")
	print("  -> TEST 04 PASSED (All 5 required animation states verified: ", anims, ")")
	
	# TEST 05: Verify Player Detection & Pursuit
	print("[TEST 05] Verifying enemy player detection and chase AI...")
	enemy.global_position = Vector3(0, 0, 18) # 14m away from player at (0, 0, 4)
	enemy._physics_process(0.1)
	assert(enemy.current_state == Enemy3D.State.CHASE, "Enemy must switch to CHASE when player detected")
	enemy._physics_process(0.1)
	assert(enemy.velocity.length_squared() > 0.0, "Enemy must move towards player during pursuit")
	print("  -> TEST 05 PASSED (Player detection & pursuit movement functional)")
	
	# TEST 06: Test Player Weapon Hitscan & Damage on Enemy
	print("[TEST 06] Testing weapon firing & raycast damage against enemy...")
	var enemy2: Enemy3D = level.get_node_or_null("Enemies/Enemy3D_2") as Enemy3D
	assert(enemy2 != null, "Enemy3D_2 must exist in Level1")
	var initial_enemy_hp = enemy2.current_health
	var initial_player_ammo = player.weapon_manager.get_current_weapon().current_ammo
	
	# Aim directly at Enemy 2 (already aligned in level at 0, 0, -16)
	player.camera_mount.look_at(enemy2.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	player._try_fire_active_weapon()
	
	# Verify ammo consumed
	assert(player.weapon_manager.get_current_weapon().current_ammo == initial_player_ammo - 1, "Firing must consume 1 round")
	
	# Verify enemy took damage
	assert(enemy2.current_health < initial_enemy_hp, "Enemy health must decrease after being hit")
	print("  -> TEST 06 PASSED (Hitscan hit registered, ammo consumed, enemy HP: ", initial_enemy_hp, " -> ", enemy2.current_health, ")")
	
	# TEST 07: Verify Enemy Hit Reaction
	print("[TEST 07] Verifying enemy hit reaction...")
	var ap2: AnimationPlayer = enemy2.get_node("SoldierModel/AnimationPlayer")
	assert(enemy2.current_state == Enemy3D.State.HIT or ap2.current_animation == "HitReaction", "Enemy must enter hit reaction state/animation")
	print("  -> TEST 07 PASSED (Hit reaction triggered on enemy)")
	
	# TEST 08: Test Enemy Counter-Attack & Player Health Reduction
	print("[TEST 08] Testing enemy counter-attack and player damage...")
	var initial_player_hp = player.current_health
	enemy._perform_counter_attack(player)
	
	assert(player.current_health < initial_player_hp, "Player health must decrease after enemy attack")
	print("  -> TEST 08 PASSED (Enemy counter-attacked! Player HP: ", initial_player_hp, " -> ", player.current_health, ")")
	
	# TEST 09: Test Enemy Lethal Damage & Death State
	print("[TEST 09] Testing enemy lethal damage & death animation...")
	var lethal_dmg = DamageInfo.new(200, true, player, "Assault Rifle", enemy.global_position, Vector3.FORWARD, Vector3.UP, GameConstants.DamageType.BULLET)
	enemy.take_damage(lethal_dmg, true)
	
	assert(enemy.is_dead, "Enemy must be marked dead")
	assert(enemy.current_health == 0, "Enemy health must be 0")
	assert(enemy.current_state == Enemy3D.State.DEAD, "Enemy state must be DEAD")
	assert(enemy.collision_shape.disabled, "Enemy collision shape must be disabled on death")
	assert(ap.current_animation == "Death", "Enemy must play Death animation on defeat")
	print("  -> TEST 09 PASSED (Death animation playing, collision disabled, enemy defeated)")
	
	# TEST 10: Test Player Death Foundation
	print("[TEST 10] Testing player death handling at 0 HP...")
	var player_died_flag = [false]
	player.operative_died.connect(func(): player_died_flag[0] = true)
	
	player.take_damage(player.current_health)
	assert(player.current_health == 0, "Player health must be 0")
	assert(not player.is_active, "Player must be inactive after death")
	assert(player_died_flag[0], "operative_died signal must be emitted")
	assert(gm.current_state == GameConstants.GameState.GAME_OVER, "GameManager state must transition to GAME_OVER")
	print("  -> TEST 10 PASSED (Player death foundation verified)")
	
	level.queue_free()
	print("--- ALL STEP 07 COMBAT SYSTEM TESTS PASSED PERFECTLY! ---")
	quit(0)
