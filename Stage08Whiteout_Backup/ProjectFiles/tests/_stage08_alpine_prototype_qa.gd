extends Node
## Automated Verification & Screenshot Capture Suite for Stage 08 Alpine Prototype.
## Tests standalone scene compilation, shader rendering, procedural mesh generation,
## and captures high-resolution screenshots from multiple viewpoints.

const PROTO_SCENE := "res://scenes/prototypes/Stage08_AlpinePrototype.tscn"
const OUT_DIR := "res://verification_screenshots/alpine_prototype"

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("=========================================================")
	print(" STAGE 08 ALPINE TERRAIN PROTOTYPE VERIFICATION & CAPTURE ")
	print("=========================================================")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var packed := load(PROTO_SCENE) as PackedScene
	assert(packed != null, "Failed to load Alpine Prototype scene.")

	var stage := packed.instantiate() as Node3D
	assert(stage != null, "Failed to instantiate Alpine Prototype scene.")
	get_tree().root.add_child(stage)
	var spawn_cam := stage.get_node("Cameras/SpawnViewCamera") as Camera3D
	var pano_cam := stage.get_node("Cameras/PanoramaOverviewCamera") as Camera3D
	var valley_cam := stage.get_node("Cameras/ValleyDepthCamera") as Camera3D
	spawn_cam.position = Vector3(0.0, 22.0, 72.0)
	spawn_cam.look_at(Vector3(0.0, 10.0, -145.0))
	pano_cam.position = Vector3(150.0, 105.0, 110.0)
	pano_cam.look_at(Vector3(-55.0, -8.0, -155.0))
	valley_cam.position = Vector3(18.0, 82.0, 115.0)
	valley_cam.look_at(Vector3(-76.0, -23.0, -48.0))

	# Settle procedural mesh generation, PBR shader compilation and rendering frames
	print("[QA] Waiting for mesh and shader compilation to settle...")
	for _frame in 30:
		await get_tree().process_frame
	var frame_samples: Array[float] = []
	for _frame in 120:
		var frame_start := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_samples.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
	frame_samples.sort()
	var avg_ms := 0.0
	for sample in frame_samples:
		avg_ms += sample
	avg_ms /= float(frame_samples.size())
	print("[PERF] 120 rendered frames: avg %.2f ms (%.1f FPS), p95 %.2f ms, max %.2f ms" % [avg_ms, 1000.0 / avg_ms, frame_samples[113], frame_samples[-1]])

	# Verify Terrain Generation
	var terrain_node := stage.get_node_or_null("AlpineTerrainGenerator/SculptedMountainTerrain") as MeshInstance3D
	assert(terrain_node != null, "SculptedMountainTerrain must exist.")
	assert(terrain_node.mesh != null, "SculptedMountainTerrain mesh must be generated.")
	print("[QA] Terrain mesh confirmed with %d surfaces." % terrain_node.mesh.get_surface_count())

	var lake_node := stage.get_node_or_null("AlpineTerrainGenerator/FrozenAlpineLake/LakeIceSurface")
	assert(lake_node != null, "Frozen lake surface must exist.")

	var radar_node := stage.get_node_or_null("AlpineTerrainGenerator/SummitRadarInstallation")
	assert(radar_node != null, "Summit radar installation must exist.")

	var forest_node := stage.get_node_or_null("AlpineTerrainGenerator/AlpineConiferForest")
	assert(forest_node != null, "Alpine conifer forest must exist.")

	print("[QA] All core procedural components verified.")

	# --- CAPTURE 1: Front Spawn View ---
	spawn_cam.current = true
	for _frame in 10:
		await get_tree().process_frame

	var img1 := get_viewport().get_texture().get_image()
	if img1 == null:
		push_error("Viewport screenshot unavailable: Godot is running with a dummy/headless renderer.")
		get_tree().quit(2)
		return
	var p1 := "%s/01_alpine_spawn_view.png" % OUT_DIR
	var err1 := img1.save_png(p1)
	assert(err1 == OK, "Failed to save 01_alpine_spawn_view.png")
	print("[QA] Captured: 01_alpine_spawn_view.png")

	# --- CAPTURE 2: Elevated Mountain Panorama & Pass Overview ---
	spawn_cam.current = false
	pano_cam.current = true
	for _frame in 10:
		await get_tree().process_frame

	var img2 := get_viewport().get_texture().get_image()
	var p2 := "%s/02_alpine_panorama_overview.png" % OUT_DIR
	var err2 := img2.save_png(p2)
	assert(err2 == OK, "Failed to save 02_alpine_panorama_overview.png")
	print("[QA] Captured: 02_alpine_panorama_overview.png")

	# --- CAPTURE 3: Deep Sunken Valley & Frozen Lake View ---
	pano_cam.current = false
	valley_cam.current = true
	for _frame in 10:
		await get_tree().process_frame

	var img3 := get_viewport().get_texture().get_image()
	var p3 := "%s/03_alpine_deep_valley_lake.png" % OUT_DIR
	var err3 := img3.save_png(p3)
	assert(err3 == OK, "Failed to save 03_alpine_deep_valley_lake.png")
	print("[QA] Captured: 03_alpine_deep_valley_lake.png")

	print("\n=========================================================")
	print(" ALL ALPINE PROTOTYPE VERIFICATIONS & CAPTURES PASSED!   ")
	print("=========================================================")

	stage.queue_free()
	get_tree().quit(0)
