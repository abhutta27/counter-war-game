extends SceneTree
## test_step_09_gameplay_walkthrough.gd
## Interactive Visual Gameplay Verification across all 6 distinct stage environments.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_gameplay_walkthrough")

func _run_gameplay_walkthrough() -> void:
	print("=========================================================")
	print("   COUNTER WAR - STEP 09 GAMEPLAY WALKTHROUGH (1 TO 6)   ")
	print("=========================================================")
	
	for i in range(5):
		await process_frame
		
	var stg_mgr = root.get_node("StageManager")
	var gm = root.get_node("GameManager")
	
	var expected_stages = [
		{"id": 1, "name": "OPERATION DESERT OUTPOST", "enemies": 5, "root_name": "Stage01"},
		{"id": 2, "name": "OPERATION ABANDONED CITY", "enemies": 6, "root_name": "Stage02"},
		{"id": 3, "name": "OPERATION FOREST CAMP", "enemies": 7, "root_name": "Stage03"},
		{"id": 4, "name": "OPERATION INDUSTRIAL ZONE", "enemies": 12, "root_name": "Stage04"},
		{"id": 5, "name": "OPERATION MOUNTAIN BASE", "enemies": 14, "root_name": "Stage05"},
		{"id": 6, "name": "OPERATION NIGHT MILITARY BASE", "enemies": 10, "root_name": "Stage06"}
	]
	
	for s_idx in range(expected_stages.size()):
		var data = expected_stages[s_idx]
		var stage_id = data["id"]
		print("\n---------------------------------------------------------")
		print("[PHASE %d] Launching Stage %d: %s" % [stage_id, stage_id, data["name"]])
		print("---------------------------------------------------------")
		
		stg_mgr.load_stage(stage_id)
		for f in range(25):
			await process_frame
			
		var active_scene = root.get_node_or_null(data["root_name"])
		assert(active_scene != null, "Scene %s must be active in root" % data["root_name"])
		assert(active_scene.stage_id == stage_id, "Stage ID must match %d" % stage_id)
		assert(active_scene.stage_name == data["name"], "Stage Name must match %s" % data["name"])
		
		var enemies_container = active_scene.get_node_or_null("Enemies")
		assert(enemies_container != null, "Enemies container must exist in Stage %d" % stage_id)
		var enemy_count = enemies_container.get_child_count()
		assert(enemy_count == data["enemies"], "Stage %d must have %d enemies (Found: %d)" % [stage_id, data["enemies"], enemy_count])
		print("  -> Verified Stage %d Scene loaded cleanly: %s with %d distinct enemies" % [stage_id, data["name"], enemy_count])
		
		var player = active_scene.get_node_or_null("Player3D")
		assert(player != null, "Shared Player3D must be present in Stage %d" % stage_id)
		assert(player.current_health == 100, "Player must be at full health (100 HP)")
		
		# In Stage 3, test active combat damage & kill registration
		if stage_id == 3:
			print("  -> Simulating tactical combat engagement in Stage 03 Forest Camp...")
			var enemy1 = enemies_container.get_child(0)
			var lethal_dmg = DamageInfo.new(100, false, player, "Rifle", enemy1.global_position, Vector3.FORWARD, Vector3.UP, 0)
			enemy1.take_damage(lethal_dmg)
			for f in range(10):
				await process_frame
			assert(active_scene.targets_eliminated == 1, "Kill counter must accurately increment in Stage 03")
			print("  -> Combat test in Stage 03 passed: Hostile eliminated, kill registered cleanly.")
			
		# In Stage 5, test player failure and restart isolation
		if stage_id == 5:
			print("  -> Simulating Player Defeat in Stage 05 Mountain Base...")
			player.take_damage(100)
			for f in range(20):
				await process_frame
			assert(gm.current_state == GameConstants.GameState.GAME_OVER, "Game State must be GAME_OVER")
			print("  -> Game Over confirmed on Stage 05. Testing Restart Isolation...")
			stg_mgr.restart_current_stage()
			for f in range(25):
				await process_frame
			var restarted = root.get_node_or_null("Stage05")
			assert(restarted != null, "Restarting must preserve Stage 05 scene!")
			assert(stg_mgr.get_current_stage_id() == 5, "Current stage ID MUST remain 5 on restart!")
			assert(restarted.get_node("Enemies").get_child_count() == 14, "All 14 enemies must be restored on Stage 05 restart")
			print("  -> Restart test passed: Stage 05 cleanly reloaded with all 14 fresh enemies.")
			
	print("\n=========================================================")
	print(" ALL 6 STAGES GAMEPLAY & COMBAT WALKTHROUGH PASSED (6/6) ")
	print("=========================================================")
	quit(0)
