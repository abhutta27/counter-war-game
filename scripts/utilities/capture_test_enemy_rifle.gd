extends SceneTree
## capture_test_enemy_rifle.gd
## Captures screenshot of enemy pointing rifle with new orientation

func _init() -> void:
	await process_frame
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	for i in 15: await process_frame
	
	var player = level.get_node("Player3D")
	var enemy = level.get_node("Enemies/Enemy3D_2")
	
	# Position enemy directly in front of player
	enemy.global_position = Vector3(0.0, 0.0, -4.0)
	enemy.look_at(player.global_position, Vector3.UP)
	enemy.current_state = Enemy3D.State.ATTACK
	
	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.look_at(enemy.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	
	for i in 30: await process_frame
	
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("res://verification_screenshots/debug_test_horizontal_rifle.png")
	print("Saved screenshot to res://verification_screenshots/debug_test_horizontal_rifle.png")
	quit()
