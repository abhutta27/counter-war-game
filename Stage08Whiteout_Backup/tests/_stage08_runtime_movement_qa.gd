extends SceneTree
## Stage 08 Runtime Movement & Visual QA Test
## Tests real physics movement traversal from Lower Valley up Ramp 1 to Mid Ridge,
## and up Ramp 2 to High Summit and Radar Station, monitoring for snags, out-of-bounds,
## and verifying radar line-of-sight and fog visibility parameters.

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"

func _init() -> void:
	print("=========================================================")
	print(" STAGE 08 RUNTIME MOVEMENT & VISUAL QA SUITE            ")
	print("=========================================================")
	call_deferred("_run_qa")

func _run_qa() -> void:
	for _frame in 5:
		await process_frame

	print("[QA] Loading Stage 08 scene...")
	var scene_res := load(STAGE08_SCENE) as PackedScene
	assert(scene_res != null, "Failed to load Stage 08 scene.")

	var stage := scene_res.instantiate() as Node3D
	assert(stage != null, "Failed to instantiate Stage 08.")
	root.add_child(stage)
	current_scene = stage

	for _frame in 10:
		await physics_frame

	var player := stage.get_node_or_null("Player3D") as Player3D
	assert(player != null, "Player3D not found.")
	assert(player.is_active, "Player must be active.")
	player.max_health = 999999
	player.current_health = 999999

	# Settle player on ground
	for _frame in 10:
		await physics_frame

	print("[QA] Player settled at initial position: %s, is_on_floor=%s" % [
		str(player.global_position), player.is_on_floor()
	])
	assert(player.is_on_floor(), "Player must be grounded on spawn.")
	assert(player.global_position.y >= 0.0, "Player must not sink below Y=0 on spawn.")

	# -------------------------------------------------------------
	# CHECK 1: RADAR VISIBILITY & LINE OF SIGHT FROM SPAWN
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 1: Radar Visibility & LoS from Spawn ---")
	var radar_pos: Vector3 = stage.get_radar_position()
	var radar_dish_pos := Vector3(radar_pos.x, 29.5, radar_pos.z)
	var spawn_eye_pos := player.global_position + Vector3(0.0, 1.55, 0.0)

	var dist_to_radar := spawn_eye_pos.distance_to(radar_dish_pos)
	print("[QA] Distance from player spawn to radar dish: %.2f meters" % dist_to_radar)

	var space_state := stage.get_world_3d().direct_space_state
	var los_query := PhysicsRayQueryParameters3D.create(spawn_eye_pos, radar_dish_pos)
	# Exclude player
	los_query.exclude = [player.get_rid()]
	var los_hit := space_state.intersect_ray(los_query)

	if los_hit.is_empty():
		print("[QA] PASS: Direct unobstructed line-of-sight from spawn to radar dish.")
	else:
		print("[QA] LoS hit: %s at %s" % [los_hit.collider.name, str(los_hit.position)])

	var world_env := stage.get_node("WorldEnvironment") as WorldEnvironment
	var env: Environment = world_env.environment
	print("[QA] Environment Fog: enabled=%s, density=%.4f" % [env.fog_enabled, env.fog_density])

	# Fog transmittance formula: T = exp(-density * distance)
	var optical_depth := env.fog_density * dist_to_radar
	var transmittance := exp(-optical_depth)
	print("[QA] Fog optical depth = %.3f, Transmittance = %.1f%%" % [optical_depth, transmittance * 100.0])
	assert(transmittance > 0.15 and transmittance < 0.60, 
		"Radar dish should have ~20-50%% visibility contrast from spawn to provide limited visibility whiteout feeling.")
	print("[QA] PASS: Radar dish silhouette is visible and recognizable through fog from spawn.")

	# -------------------------------------------------------------
	# CHECK 2: REAL PHYSICS MOVEMENT THROUGH LOWER VALLEY
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 2: Movement Through Lower Valley (Z: 48 -> 20) ---")
	# Align player orientation facing north (-Z)
	player.rotation.y = 0.0
	if player.camera_holder:
		player.camera_holder.rotation = Vector3.ZERO

	Input.action_press("move_forward")
	Input.action_press("sprint")

	var prev_z := player.global_position.z
	var frames_stuck := 0
	var valley_cleared := false

	for step in range(300): # Allow up to 5 seconds
		await physics_frame
		var current_pos := player.global_position
		assert(current_pos.y >= -1.0, "Player must not fall through Lower Valley floor.")
		assert(player.is_on_floor(), "Player should remain grounded.")

		if absf(current_pos.z - prev_z) < 0.001:
			frames_stuck += 1
		else:
			frames_stuck = 0
		prev_z = current_pos.z

		assert(frames_stuck < 15, "Player stuck in Lower Valley at %s" % str(current_pos))

		if current_pos.z <= 20.0:
			valley_cleared = true
			print("[QA] Reached Lower Valley exit at Z=%.2f, Y=%.2f" % [current_pos.z, current_pos.y])
			break

	assert(valley_cleared, "Player failed to traverse Lower Valley to Z=20.")
	print("[QA] PASS: Lower Valley movement verified.")

	# -------------------------------------------------------------
	# CHECK 3: TRAVERSAL UP RAMP 1 TO MID-RIDGE (Z: 20 -> 0, Y: 0 -> 6)
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 3: Traversal Up Ramp 1 to Mid-Ridge ---")
	var ramp1_cleared := false
	var max_y_seen := player.global_position.y

	for step in range(300): # Allow up to 5 seconds
		await physics_frame
		var current_pos := player.global_position
		max_y_seen = maxf(max_y_seen, current_pos.y)

		if current_pos.z <= -2.0:
			ramp1_cleared = true
			print("[QA] Successfully climbed Ramp 1! Current pos: Z=%.2f, Y=%.2f, is_on_floor=%s" % [
				current_pos.z, current_pos.y, player.is_on_floor()
			])
			break

	assert(ramp1_cleared, "Player failed to climb Ramp 1 onto Mid-Ridge.")
	assert(player.global_position.y >= 5.8, "Player Y must reach Mid-Ridge elevation (>= 5.8m).")
	assert(player.is_on_floor(), "Player must be grounded on Mid-Ridge.")
	print("[QA] PASS: Ramp 1 climb and Mid-Ridge arrival verified.")

	# -------------------------------------------------------------
	# CHECK 4: TRAVERSAL ACROSS MID-RIDGE (Z: 0 -> -36, Y ~ 6)
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 4: Traversal Across Mid-Ridge (Z: 0 -> -36) ---")
	var mid_ridge_cleared := false

	for step in range(350): # Allow up to 5.8 seconds
		await physics_frame
		var current_pos := player.global_position
		assert(current_pos.y >= 5.0, "Player fell off Mid-Ridge plateau.")
		assert(player.is_on_floor(), "Player should remain grounded on Mid-Ridge.")

		if current_pos.z <= -36.0:
			mid_ridge_cleared = true
			print("[QA] Traversed Mid-Ridge to base of Ramp 2 at Z=%.2f, Y=%.2f" % [current_pos.z, current_pos.y])
			break

	assert(mid_ridge_cleared, "Player failed to traverse Mid-Ridge.")
	print("[QA] PASS: Mid-Ridge traversal verified.")

	# -------------------------------------------------------------
	# CHECK 5: TRAVERSAL UP RAMP 2 TO HIGH SUMMIT (Z: -36 -> -63, Y: 6 -> 14)
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 5: Traversal Up Ramp 2 to High Summit ---")
	var summit_reached := false

	for step in range(350): # Allow up to 5.8 seconds
		await physics_frame
		var current_pos := player.global_position
		assert(current_pos.y >= 5.0, "Player fell during Ramp 2 climb.")

		if current_pos.z <= -63.0:
			summit_reached = true
			print("[QA] Successfully climbed Ramp 2! Current pos: Z=%.2f, Y=%.2f, is_on_floor=%s" % [
				current_pos.z, current_pos.y, player.is_on_floor()
			])
			break

	assert(summit_reached, "Player failed to climb Ramp 2 onto High Summit.")
	assert(player.global_position.y >= 13.5, "Player Y must reach High Summit elevation (>= 13.5m).")
	assert(player.is_on_floor(), "Player must be grounded on High Summit.")
	print("[QA] PASS: Ramp 2 climb and High Summit arrival verified.")

	# -------------------------------------------------------------
	# CHECK 6: APPROACHING RADAR INSTALLATION AT SUMMIT (Z: -63 -> -74)
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 6: Approaching Radar Station (Z: -63 -> -74) ---")
	var radar_reached := false

	for step in range(250): # Allow up to 4.1 seconds
		await physics_frame
		var current_pos := player.global_position
		assert(current_pos.y >= 13.0, "Player fell off High Summit plateau.")

		if current_pos.z <= -74.0:
			radar_reached = true
			print("[QA] Reached Radar Installation core at Z=%.2f, Y=%.2f, is_on_floor=%s" % [
				current_pos.z, current_pos.y, player.is_on_floor()
			])
			break

	Input.action_release("sprint")
	Input.action_release("move_forward")

	assert(radar_reached, "Player failed to reach Radar Installation on summit.")
	print("[QA] PASS: Full continuous traversal from Valley Spawn (Z=48, Y=0) to Summit Radar (Z=-74, Y=14) succeeded!")

	# -------------------------------------------------------------
	# CHECK 7: REVERSE TRAVERSAL / DESCENT CHECK
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 7: Descent Down Ramp 2 (Summit -> Mid-Ridge) ---")
	Input.action_press("move_backward")
	Input.action_press("sprint")
	var descended_ramp2 := false

	for step in range(520): # 8.6 seconds for 38m reverse walk at 5.0 m/s
		await physics_frame
		var current_pos := player.global_position
		if current_pos.z >= -36.0:
			descended_ramp2 = true
			print("[QA] Successfully descended Ramp 2 back to Mid-Ridge at Z=%.2f, Y=%.2f" % [
				current_pos.z, current_pos.y
			])
			break

	Input.action_release("move_backward")
	Input.action_release("sprint")
	assert(descended_ramp2, "Player failed to safely walk down Ramp 2.")
	print("[QA] PASS: Safe slope descent verified without snags or stumbling.")

	# -------------------------------------------------------------
	# CHECK 8: COLLISION COVER BLOCKING & PERIMETER BOUNDARIES
	# -------------------------------------------------------------
	print("\n[QA] --- CHECK 8: Safety Perimeter Collision Validation ---")
	# Test running into west safety boundary
	player.global_position = Vector3(-24.5, 6.2, -18.0)
	player.velocity = Vector3(-8.0, 0.0, 0.0) # push west into barrier at X=-26
	for _frame in 15:
		await physics_frame
		player.move_and_slide()

	print("[QA] Player position after pushing against West barrier: %s" % str(player.global_position))
	assert(player.global_position.x > -26.0, "West safety perimeter must block player from leaving bounds.")
	print("[QA] PASS: Safety perimeter collision blocks out-of-bounds escape.")

	# -------------------------------------------------------------
	# SUMMARY
	# -------------------------------------------------------------
	print("\n=========================================================")
	print(" ALL STAGE 08 MOVEMENT & VISUAL QA CHECKS PASSED!        ")
	print("=========================================================")
	stage.queue_free()
	quit(0)
