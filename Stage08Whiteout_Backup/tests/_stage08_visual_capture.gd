extends SceneTree
## Stage 08 Visual Prototype Capture Script
## Spawns the real Stage08 scene, settles frames, and captures player spawn view.

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"
const SPAWN_IMG := "res://verification_screenshots/stage08_prototype_spawn_view.png"
const OVERVIEW_IMG := "res://verification_screenshots/stage08_prototype_overview.png"

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var scene_res := load(STAGE08_SCENE) as PackedScene
	if not scene_res:
		quit(1)
		return

	var stage := scene_res.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	# Wait for materials, sky, shaders and physics to settle
	for _frame in 25:
		await process_frame

	# 1. Player First-Person Camera View from Spawn
	var player := stage.get_node_or_null("Player3D") as CharacterBody3D
	var camera: Camera3D = null
	if player:
		camera = player.get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.current = true

	# Let rendering server finalize frame post draw
	for _frame in 10:
		await process_frame

	var img_spawn := root.get_viewport().get_texture().get_image()
	var err1 := img_spawn.save_png(SPAWN_IMG)
	print("[Capture] Spawn view saved: ", err1 == OK)

	# 2. Elevated Panorama Overview View showing deep valley and mountain ranges
	if camera:
		camera.current = false

	var pano_cam := Camera3D.new()
	pano_cam.name = "PanoCamera"
	stage.add_child(pano_cam)
	# Position on elevated bluff looking across valley towards radar station and distant peaks
	pano_cam.position = Vector3(12.0, 8.5, 48.0)
	pano_cam.look_at(Vector3(0.0, 14.0, -45.0), Vector3.UP)
	pano_cam.fov = 74.0
	pano_cam.current = true

	for _frame in 10:
		await process_frame

	var img_pano := root.get_viewport().get_texture().get_image()
	var err2 := img_pano.save_png(OVERVIEW_IMG)
	print("[Capture] Overview panorama saved: ", err2 == OK)

	stage.queue_free()
	quit(0)
