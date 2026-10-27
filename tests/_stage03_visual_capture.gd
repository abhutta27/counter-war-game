extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/stages/Stage03.tscn") as PackedScene
	if not packed:
		quit(1)
		return
	var stage := packed.instantiate()
	root.add_child(stage)
	for enemy in stage.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	for _frame in 12:
		await process_frame

	var player_camera := stage.get_node_or_null("Player3D/Camera3D") as Camera3D
	if player_camera:
		player_camera.current = true
	for _frame in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_blacksite_player_view.png")

	if player_camera:
		player_camera.current = false
	var overview := Camera3D.new()
	overview.name = "Stage03OverviewCamera"
	overview.position = Vector3(50, 62, 66)
	overview.fov = 62.0
	stage.add_child(overview)
	overview.look_at_from_position(overview.position, Vector3(0, 1, -7), Vector3.UP)
	overview.current = true
	for _frame in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_blacksite_overview.png")
	quit(0)
