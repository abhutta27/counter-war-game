extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var stage = (load("res://scenes/stages/Stage04.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	current_scene = stage
	for _frame in 20:
		await process_frame
	var player_camera := stage.get_node("Player3D/Camera3D") as Camera3D
	player_camera.current = true
	await _save("stage04_steelworks_entry.png")
	player_camera.current = false
	var camera := Camera3D.new()
	camera.fov = 70
	stage.add_child(camera)
	camera.current = true
	await _capture_from(camera, Vector3(30, 17, 39), Vector3(0, 1.5, 13), "stage04_steelworks_freight_yard.png")
	await _capture_from(camera, Vector3(-20, 2.8, -7), Vector3(2, 1.4, -25), "stage04_steelworks_machinery_hall.png")
	await _capture_from(camera, Vector3(49, 67, 54), Vector3(0, 0, -10), "stage04_steelworks_overview.png")
	quit(0)

func _capture_from(camera: Camera3D, position: Vector3, target: Vector3, file_name: String) -> void:
	camera.look_at_from_position(position, target, Vector3.UP)
	for _frame in 5:
		await process_frame
	await _save(file_name)

func _save(file_name: String) -> void:
	for _frame in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/" + file_name)
