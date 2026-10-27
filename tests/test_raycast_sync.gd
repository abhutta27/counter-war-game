extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var level_scene = load("res://scenes/Level1.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	for i in range(5):
		await process_frame
	var enemy1: Enemy3D = level.get_node("Enemies/Enemy3D_1") as Enemy3D
	var player = level.get_node("Player3D")
	
	var wpn = enemy1.enemy_weapon
	assert(wpn != null and is_instance_valid(wpn), "Enemy weapon must exist")
	
	# Verify Enemy Weapon is strictly parented to Soldier Hand on Enemy
	var weapon_parent = wpn.get_parent()
	assert(weapon_parent is BoneAttachment3D and (weapon_parent as BoneAttachment3D).bone_name == "mixamorig_RightHand", "Weapon must be parented to mixamorig_RightHand")
	
	# Verify distance from enemy is ~1m (in hands) and NOT at player camera
	var dist_to_enemy = wpn.global_position.distance_to(enemy1.global_position)
	var dist_to_player = wpn.global_position.distance_to(player.global_position)
	assert(dist_to_enemy < 1.8, "Enemy weapon MUST stay in enemy soldier hand (dist: %f)" % dist_to_enemy)
	assert(dist_to_player > 5.0, "Enemy weapon MUST NOT be attached to player/camera (dist: %f)" % dist_to_player)
	print("[PASS] Enemy rifle is firmly held in soldier hand (dist to enemy: %.2fm, dist to player: %.2fm)" % [dist_to_enemy, dist_to_player])
	
	enemy1._perform_counter_attack(player)
	for i in range(5):
		await process_frame
		
	# Re-verify during combat / firing
	dist_to_enemy = wpn.global_position.distance_to(enemy1.global_position)
	dist_to_player = wpn.global_position.distance_to(player.global_position)
	assert(dist_to_enemy < 1.8, "Enemy weapon MUST remain in enemy hand during firing (dist: %f)" % dist_to_enemy)
	assert(dist_to_player > 5.0, "Enemy weapon MUST NOT teleport to player during firing (dist: %f)" % dist_to_player)
	print("[PASS] Enemy rifle strictly maintained in soldier hands during combat firing")
	
	level.queue_free()
	quit(0)
