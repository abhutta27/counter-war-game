extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/stages/Stage01.tscn") as PackedScene
	if not packed:
		quit(1)
		return
	var stage := packed.instantiate()
	root.add_child(stage)
	for _frame in 8:
		await process_frame

	var player_camera := stage.get_node_or_null("Player3D/CameraHolder/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = true
	for _frame in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage01_polish_player_view.png")

	if player_camera:
		player_camera.current = false
	var overview := Camera3D.new()
	overview.name = "Stage01OverviewCamera"
	overview.position = Vector3(0, 38, 44)
	overview.fov = 58.0
	stage.add_child(overview)
	overview.look_at_from_position(overview.position, Vector3(0, 0, -7), Vector3.UP)
	overview.current = true
	for _frame in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage01_polish_overview.png")
	quit(0)
