extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := (load("res://scenes/stages/Stage03.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	current_scene = stage
	var player: Player3D = stage.get_node("Player3D") as Player3D
	player.max_health = 50000
	player.current_health = 50000
	for enemy in stage.get_node("Enemies").get_children():
		enemy.attack_damage = 0
	var camera := player.get_node("Camera3D") as Camera3D
	camera.current = true

	# Render the genuinely quiet opening before crossing any activation band.
	for _frame in 90:
		await physics_frame
	assert(not stage.is_zone_active(1) and not stage.is_zone_active(2) and not stage.is_zone_active(3))
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_encounter_quiet_opening.png")

	player.global_position = Vector3(0, 0.1, 25)
	for _frame in 90:
		await physics_frame
	assert(stage.is_zone_active(1) and not stage.is_zone_active(2) and not stage.is_zone_active(3))
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_encounter_zone1.png")

	player.global_position = Vector3(0, 0.1, 1)
	for _frame in 90:
		await physics_frame
	assert(stage.is_zone_active(2) and not stage.is_zone_active(3))
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_encounter_zone2.png")

	player.global_position = Vector3(0, 0.1, -20)
	for _frame in 90:
		await physics_frame
	assert(stage.is_zone_active(3))
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/stage03_encounter_zone3.png")
	print("[Stage03Visual] PASS: quiet opening and three progressive encounter bands rendered graphically")
	quit(0)

