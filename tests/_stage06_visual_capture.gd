extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage06.tscn")
const OUTPUT_DIR := "res://verification_screenshots/stage06_rebuild"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_physics_process(false)
	for enemy in stage.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	var player = stage.get_node("Player3D")
	player.set_physics_process(false)
	var camera := player.get_node("Camera3D") as Camera3D
	camera.current = true
	for _frame in 24:
		await process_frame
	var shots := [
		["01_spawn_outer_approach.png", Vector3(0, 0, 36), Vector3(0, 1.5, 23)],
		["02_main_security_gate.png", Vector3(0, 0, 31), Vector3(0, 2.0, 22)],
		["03_illuminated_security_road.png", Vector3(-6.5, 0, 17), Vector3(-6.5, 1.4, -4)],
		["04_dark_maintenance_route.png", Vector3(14, 0, 15), Vector3(15, 1.4, -8)],
		["05_searchlight_towers.png", Vector3(-5, 0, 10), Vector3(-18, 0.8, 18)],
		["06_utility_internal_base.png", Vector3(8, 0, 9), Vector3(16, 1.5, -3)],
		["07_helipad.png", Vector3(0, 0, -7), Vector3(0, 1.0, -18)],
		["08_command_hangar.png", Vector3(0, 0, -20), Vector3(0, 2.5, -34)],
		["09_final_combat_area.png", Vector3(-9, 0, -17), Vector3(1, 1.4, -29)],
		["10_night_panorama.png", Vector3(-30, 0, 34), Vector3(0, 1.5, -10)]
	]
	for shot in shots:
		player.global_position = shot[1]
		player.look_at(shot[2], Vector3.UP)
		camera.rotation = Vector3.ZERO
		for _frame in 5:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s" % [OUTPUT_DIR, shot[0]]
		var error := image.save_png(path)
		assert(error == OK, "Could not save %s" % path)
		print("[Stage06Visual] Saved %s" % path)
	print("[Stage06Visual] PASS: 10 player-camera-height views captured")
	quit(0)
