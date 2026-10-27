extends SceneTree
## check_barrel_in_world.gd
## Tests weapon rotation candidates and prints barrel world direction and position.

func _init() -> void:
	await process_frame
	var enemy_scene = load("res://scenes/entities/Enemy3D.tscn")
	var enemy = enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = Vector3(0, 0, -10)
	enemy.look_at(Vector3(0, 0, 0), Vector3.UP) # Enemy at (0,0,-10) looking at player at (0,0,0) -> facing +Z !
	await process_frame
	await process_frame
	
	# Enemy is facing player (which is in +Z relative to enemy):
	var enemy_forward = -enemy.global_transform.basis.z # in Godot -Z is forward
	print("Enemy global pos: ", enemy.global_position)
	print("Enemy forward: ", enemy_forward)
	
	var weapon = enemy.enemy_weapon
	var flash = enemy.enemy_muzzle_flash
	
	# Current setup
	print("\n--- Testing Current: rot (-70, 90, 90) ---")
	weapon.rotation_degrees = Vector3(-70.0, 90.0, 90.0)
	for i in 10: await process_frame
	var barrel_dir = (flash.global_position - weapon.global_position).normalized()
	print("Barrel dir: ", barrel_dir)
	print("Barrel pitch deg (Y component): ", rad_to_deg(asin(barrel_dir.y)))
	print("Weapon global pos: ", weapon.global_position)
	print("Flash global pos: ", flash.global_position)

	# Candidate: (164, -15, -190)
	print("\n--- Testing Candidate: rot (164, -15, -190) ---")
	weapon.rotation_degrees = Vector3(164.0, -15.0, -190.0)
	for i in 10: await process_frame
	barrel_dir = (flash.global_position - weapon.global_position).normalized()
	print("Barrel dir: ", barrel_dir)
	print("Barrel pitch deg (Y component): ", rad_to_deg(asin(barrel_dir.y)))
	print("Weapon global pos: ", weapon.global_position)
	print("Flash global pos: ", flash.global_position)
	
	quit()
