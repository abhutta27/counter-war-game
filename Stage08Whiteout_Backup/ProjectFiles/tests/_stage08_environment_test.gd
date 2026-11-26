extends SceneTree
## Automated verification test for Stage 08 — Operation Whiteout Environment.
## Validates scene loading, player placement, HUD presence, atmospheric fog,
## 3 elevation tiers with collision, ramps, solid cover, and summit radar installation.

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"

func _init() -> void:
	print("=========================================================")
	print(" COUNTER-WAR: STAGE 08 WHITEOUT ENVIRONMENT VERIFICATION  ")
	print("=========================================================")
	call_deferred("_run_test")

func _run_test() -> void:
	for _frame in 5:
		await process_frame

	print("[Stage08Test] Loading Stage 08 scene: %s" % STAGE08_SCENE)
	assert(ResourceLoader.exists(STAGE08_SCENE), "Stage 08 scene must exist on disk.")

	var scene_res := load(STAGE08_SCENE) as PackedScene
	assert(scene_res != null, "Stage 08 scene must load as PackedScene.")

	var stage := scene_res.instantiate() as Node3D
	assert(stage != null, "Stage 08 scene must instantiate as Node3D.")
	root.add_child(stage)
	current_scene = stage

	for _frame in 10:
		await process_frame

	# -------------------------------------------------------------
	# 1. ROOT PROPERTIES & ARCHITECTURE
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking root stage configuration...")
	assert(stage.stage_id == 8, "stage_id must be 8.")
	assert(stage.stage_name == "OPERATION WHITEOUT", "stage_name must be 'OPERATION WHITEOUT'.")
	assert(stage.out_of_bounds_y == -12.0, "out_of_bounds_y must be -12.0.")
	assert(stage.recovery_bounds_enabled == true, "recovery_bounds_enabled must be true.")
	assert(stage.physical_boundaries_enabled == true, "physical_boundaries_enabled must be true.")
	print("[Stage08Test] PASS: Root stage properties verified.")

	# -------------------------------------------------------------
	# 2. CORE NODES: PLAYER, HUD, LIGHTING, ENVIRONMENT
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking core nodes: Player, HUD, Environment, Lighting...")
	var player = stage.get_node_or_null("Player3D")
	assert(player != null, "Player3D node must exist in Stage 08.")
	assert(player is CharacterBody3D, "Player3D must be a CharacterBody3D.")
	print("[Stage08Test] Player spawn position: %s" % str(player.global_position))
	assert(player.global_position.y >= 0.0, "Player must spawn at or above ground level.")
	assert(player.global_position.z > 40.0, "Player must spawn in the southern Lower Valley.")

	var hud = stage.get_node_or_null("HUD")
	assert(hud != null, "HUD node must exist in Stage 08.")
	assert(hud is CanvasLayer, "HUD must be a CanvasLayer.")

	var enemies = stage.get_node_or_null("Enemies")
	assert(enemies != null, "Enemies container must exist.")
	assert(enemies.get_child_count() == 12, "Enemies container must contain 12 enemies.")

	var world_env = stage.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert(world_env != null and world_env.environment != null, "WorldEnvironment must exist with Environment resource.")
	var env: Environment = world_env.environment
	assert(env.fog_enabled == true, "Winter atmospheric fog must be enabled.")
	assert(env.fog_density >= 0.005, "Winter fog density must provide limited visibility whiteout atmosphere.")
	print("[Stage08Test] Winter fog settings: enabled=%s, density=%.4f, light_color=%s" % [
		env.fog_enabled, env.fog_density, env.fog_light_color
	])

	var sun = stage.get_node_or_null("SunLight") as DirectionalLight3D
	assert(sun != null, "SunLight (DirectionalLight3D) must exist.")
	assert(sun.shadow_enabled == true, "DirectionalLight3D shadows must be enabled.")
	print("[Stage08Test] PASS: Core nodes verified.")

	# -------------------------------------------------------------
	# 3. THREE ELEVATION TIERS WITH COLLISION
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking 3 elevation tiers...")
	var terrain := stage.get_node_or_null("Environment/Terrain")
	assert(terrain != null, "Environment/Terrain node must exist.")

	# Tier 1: Lower Valley (Y ~ 0)
	var valley_floor := terrain.get_node_or_null("LowerValleyFloor") as StaticBody3D
	assert(valley_floor != null, "LowerValleyFloor StaticBody3D must exist.")
	assert(valley_floor.has_node("Collision"), "LowerValleyFloor must have collision shape.")
	assert(absf(stage.get_tier_elevation("lower_valley") - 0.0) < 0.1, "Lower Valley elevation must be 0.0.")

	# Tier 2: Mid-Ridge (Y ~ 6)
	var mid_ridge_floor := terrain.get_node_or_null("MidRidgeFloor") as StaticBody3D
	assert(mid_ridge_floor != null, "MidRidgeFloor StaticBody3D must exist.")
	assert(mid_ridge_floor.has_node("Collision"), "MidRidgeFloor must have collision shape.")
	assert(absf(stage.get_tier_elevation("mid_ridge") - 6.0) < 0.1, "Mid Ridge elevation must be 6.0.")

	# Tier 3: High Summit (Y ~ 14)
	var summit_floor := terrain.get_node_or_null("SummitFloor") as StaticBody3D
	assert(summit_floor != null, "SummitFloor StaticBody3D must exist.")
	assert(summit_floor.has_node("Collision"), "SummitFloor must have collision shape.")
	assert(absf(stage.get_tier_elevation("high_summit") - 14.0) < 0.1, "High Summit elevation must be 14.0.")

	print("[Stage08Test] PASS: Three distinct elevation tiers verified (0m, 6m, 14m).")

	# -------------------------------------------------------------
	# 4. TRANSITIONAL NAVIGATION RAMPS
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking transitional navigation ramps...")
	var ramps := stage.get_node_or_null("Environment/Ramps")
	assert(ramps != null, "Environment/Ramps node must exist.")

	var ramp1 := ramps.get_node_or_null("ValleyToRidgeRamp") as StaticBody3D
	assert(ramp1 != null, "ValleyToRidgeRamp must exist.")
	assert(ramp1.has_node("Collision"), "ValleyToRidgeRamp must have collision.")
	assert(ramp1.rotation_degrees.x > 5.0, "ValleyToRidgeRamp must be angled as an inclined slope.")

	var ramp2 := ramps.get_node_or_null("RidgeToSummitRamp") as StaticBody3D
	assert(ramp2 != null, "RidgeToSummitRamp must exist.")
	assert(ramp2.has_node("Collision"), "RidgeToSummitRamp must have collision.")
	assert(ramp2.rotation_degrees.x > 5.0, "RidgeToSummitRamp must be angled as an inclined slope.")

	print("[Stage08Test] PASS: Navigation ramps verified.")

	# -------------------------------------------------------------
	# 5. HIGH SUMMIT RADAR INSTALLATION
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking Summit Radar Installation...")
	assert(stage.is_radar_visible() == true, "Radar installation must be visible.")
	var radar := stage.get_node_or_null("Environment/RadarInstallation")
	assert(radar != null, "RadarInstallation node must exist.")

	var radar_plinth := radar.get_node_or_null("RadarPlinth") as StaticBody3D
	assert(radar_plinth != null and radar_plinth.has_node("Collision"), "RadarPlinth must exist with collision.")

	var bunker := radar.get_node_or_null("CommandBunker") as StaticBody3D
	assert(bunker != null and bunker.has_node("Collision"), "CommandBunker must exist with collision.")

	var mast := radar.get_node_or_null("RadarTowerMast") as StaticBody3D
	assert(mast != null and mast.has_node("Collision"), "RadarTowerMast must exist with collision.")

	var dish := radar.get_node_or_null("PrimaryRadarDish") as StaticBody3D
	assert(dish != null and dish.has_node("Collision"), "PrimaryRadarDish must exist with collision.")

	var beacon := radar.get_node_or_null("RadarTopBeacon") as OmniLight3D
	assert(beacon != null, "RadarTopBeacon light must exist.")

	var radar_pos: Vector3 = stage.get_radar_position()
	print("[Stage08Test] Radar station position: %s" % str(radar_pos))
	assert(radar_pos.y >= 14.0, "Radar station must be situated on high summit (Y >= 14).")
	assert(radar_pos.z < -60.0, "Radar station must be situated at northern summit (Z < -60).")

	print("[Stage08Test] PASS: Summit radar installation verified.")

	# -------------------------------------------------------------
	# 6. TACTICAL SOLID COVER & SAFETY BARRIERS
	# -------------------------------------------------------------
	print("\n[Stage08Test] Checking solid cover and perimeter barriers...")
	var cover := stage.get_node_or_null("Environment/TacticalCover")
	assert(cover != null, "TacticalCover group must exist.")
	assert(cover.get_node_or_null("ValleyBarrier_West") is StaticBody3D, "Valley concrete barrier must be solid StaticBody3D.")
	assert(cover.get_node_or_null("RidgeBarrier_West") is StaticBody3D, "Mid-ridge concrete barrier must be solid StaticBody3D.")
	assert(cover.get_node_or_null("SummitBarrier_West") is StaticBody3D, "Summit concrete barrier must be solid StaticBody3D.")

	var safety := stage.get_node_or_null("Environment/SafetyPerimeter")
	assert(safety != null, "SafetyPerimeter group must exist.")
	assert(safety.get_node_or_null("SafetyWest") is StaticBody3D, "SafetyWest invisible wall must exist.")
	assert(safety.get_node_or_null("SafetyEast") is StaticBody3D, "SafetyEast invisible wall must exist.")
	assert(safety.get_node_or_null("SafetySouth") is StaticBody3D, "SafetySouth invisible wall must exist.")
	assert(safety.get_node_or_null("SafetyNorth") is StaticBody3D, "SafetyNorth invisible wall must exist.")

	print("[Stage08Test] PASS: Tactical cover and safety barriers verified.")

	# -------------------------------------------------------------
	# 7. ROUTE WAYPOINTS GROUND COLLISION RAYCAST CHECK
	# -------------------------------------------------------------
	print("\n[Stage08Test] Raycasting route waypoints to ensure continuous walkable collision...")
	var space_state := stage.get_world_3d().direct_space_state
	var waypoints: Array[Vector3] = stage.get_primary_route_waypoints()
	for i in range(waypoints.size()):
		var wp := waypoints[i]
		var from_pos := wp + Vector3(0.0, 5.0, 0.0)
		var to_pos := wp - Vector3(0.0, 5.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		var hit := space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Waypoint %d at %s must intersect walkable ground collision." % [i, str(wp)])
		print("  Waypoint %d: Hit %s at %s" % [i, hit.collider.name, str(hit.position)])

	print("[Stage08Test] PASS: All navigation waypoints confirmed to have solid walkable collision.")

	# -------------------------------------------------------------
	# 8. CLEANUP & EXIT
	# -------------------------------------------------------------
	print("\n=========================================================")
	print(" ALL STAGE 08 WHITEOUT ENVIRONMENT VERIFICATIONS PASSED!   ")
	print("=========================================================")
	stage.queue_free()
	quit(0)
