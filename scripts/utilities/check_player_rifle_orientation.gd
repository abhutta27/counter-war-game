extends SceneTree
## check_player_rifle_orientation.gd
## Checks how Assault Rifle is oriented in Player3D

func _init() -> void:
	await process_frame
	var scene = load("res://scenes/entities/Player3D.tscn")
	var player = scene.instantiate()
	root.add_child(player)
	await process_frame

	var gun_model = player.find_child("GunModel", true, false)
	var rifle = player.find_child("Assault Rifle", true, false)
	var muzzle = player.find_child("MuzzleFlash", true, false)

	print("Player GunModel pos: ", gun_model.position, " rot: ", gun_model.rotation_degrees)
	print("Player Assault Rifle pos: ", rifle.position, " rot: ", rifle.rotation_degrees, " scale: ", rifle.scale)
	print("Player MuzzleFlash pos: ", muzzle.position)
	print("Player Rifle forward basis (-Z): ", -rifle.global_transform.basis.z)
	print("Player GunModel forward basis (-Z): ", -gun_model.global_transform.basis.z)
	quit()
