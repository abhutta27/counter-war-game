extends SceneTree
## test_step_08_gameplay_stages.gd
## Interactive Visual Gameplay Verification for STEP 08: Multi-Stage Architecture.

const GameConstants = preload("res://scripts/utilities/constants.gd")

var active_stage: Node = null

func _init() -> void:
	call_deferred("_start_verification")

func _start_verification() -> void:
	print("\n=======================================================")
	print("   COUNTER WAR: STEP 08 VISUAL GAMEPLAY VERIFICATION   ")
	print("=======================================================")
	
	# Wait for engine autoloads
	for i in range(5):
		await process_frame
		
	var stg_mgr = root.get_node("StageManager")
	var gm = root.get_node("GameManager")
	
	# -------------------------------------------------------------
	# PHASE 1: Launch Stage 01
	# -------------------------------------------------------------
	print("\n[PHASE 1] Loading Stage 01 via StageManager...")
	stg_mgr.load_stage(1)
	await process_frame
	
	active_stage = root.get_node_or_null("Stage01")
	if not active_stage:
		active_stage = root.get_node_or_null("Level1")
	assert(active_stage != null, "Stage 01 scene must be instantiated and mounted")
	
	for i in range(20):
		await process_frame
		
	print("  -> Stage 01 successfully loaded! ID: %d, Name: %s" % [active_stage.stage_id, active_stage.stage_name])
	var enemies_s1 = active_stage.get_node("Enemies").get_child_count()
	print("  -> Stage 01 enemy count: %d (Expected: 5)" % enemies_s1)
	assert(enemies_s1 == 5, "Stage 01 must have 5 enemies")
	
	# -------------------------------------------------------------
	# PHASE 2: Eliminate Stage 01 Hostiles & Complete Mission
	# -------------------------------------------------------------
	print("\n[PHASE 2] Simulating victory in Stage 01...")
	var enemies_node = active_stage.get_node("Enemies")
	for child in enemies_node.get_children():
		if child.has_method("take_damage"):
			var dmg = preload("res://scripts/combat/damage_info.gd").new(100, false, null, "Rifle", child.global_position, Vector3.FORWARD, Vector3.UP, 0)
			child.take_damage(dmg)
			await process_frame
			
	for i in range(15):
		await process_frame
		
	print("  -> All Stage 01 hostiles neutralized. Total eliminated: %d" % active_stage.targets_eliminated)
	assert(active_stage.is_stage_finished, "Stage 01 must be finished")
	
	# -------------------------------------------------------------
	# PHASE 3: Request Next Stage -> Load Stage 02
	# -------------------------------------------------------------
	print("\n[PHASE 3] Requesting Next Stage (Transition to Stage 02)...")
	stg_mgr.load_next_stage()
	
	for i in range(25):
		await process_frame
		
	var stage02 = root.get_node_or_null("Stage02")
	assert(stage02 != null, "Stage 02 must be active in root scene tree")
	assert(stg_mgr.get_current_stage_id() == 2, "Current stage ID must be 2")
	print("  -> Stage 02 successfully loaded! ID: %d, Name: %s" % [stage02.stage_id, stage02.stage_name])
	
	var enemies_s2 = stage02.get_node("Enemies").get_child_count()
	print("  -> Stage 02 hostile count: %d (Expected: 8)" % enemies_s2)
	assert(enemies_s2 == 8, "Stage 02 must have exactly 8 distinct enemies")
	
	# -------------------------------------------------------------
	# PHASE 4: Simulate Failure on Stage 02 -> Game Over
	# -------------------------------------------------------------
	print("\n[PHASE 4] Simulating Player Failure in Stage 02...")
	var player_s2: Player3D = stage02.get_node("Player3D") as Player3D
	player_s2.take_damage(100)
	
	for i in range(20):
		await process_frame
		
	assert(gm.current_state == GameConstants.GameState.GAME_OVER, "Game state must be GAME_OVER")
	print("  -> Player defeated in Stage 02. Game Over confirmed.")
	
	# -------------------------------------------------------------
	# PHASE 5: Trigger Stage 02 Restart
	# -------------------------------------------------------------
	print("\n[PHASE 5] Triggering RESTART from Game Over...")
	stg_mgr.restart_current_stage()
	
	for i in range(25):
		await process_frame
		
	var restarted_stage02 = root.get_node_or_null("Stage02")
	assert(restarted_stage02 != null, "Restarted stage MUST remain Stage 02")
	assert(stg_mgr.get_current_stage_id() == 2, "CRITICAL: Stage ID must stay 2 on restart!")
	assert(gm.current_state == GameConstants.GameState.PLAYING, "Game state must be PLAYING upon restart")
	
	var fresh_enemies = restarted_stage02.get_node("Enemies").get_child_count()
	var fresh_player = restarted_stage02.get_node("Player3D")
	assert(fresh_enemies == 8, "Restarted Stage 02 must have all 8 fresh enemies")
	assert(fresh_player.current_health == 100, "Restarted Player must have full health (100)")
	
	print("  -> Stage 02 cleanly restarted! Hostiles restored: %d, Player HP: %d" % [fresh_enemies, fresh_player.current_health])
	
	print("\n=======================================================")
	print("  ALL VISUAL GAMEPLAY STAGE VERIFICATIONS PASSED (5/5) ")
	print("=======================================================")
	quit(0)
