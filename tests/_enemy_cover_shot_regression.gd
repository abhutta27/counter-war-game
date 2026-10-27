extends SceneTree

const STAGE_SCENES := [
	preload("res://scenes/stages/Stage01.tscn"),
	preload("res://scenes/stages/Stage02.tscn"),
	preload("res://scenes/stages/Stage03.tscn"),
	preload("res://scenes/stages/Stage04.tscn"),
	preload("res://scenes/stages/Stage05.tscn"),
	preload("res://scenes/stages/Stage06.tscn"),
]

const SHOT_DAMAGE := 7
const ARENA_Y := 100.0

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for stage_index in STAGE_SCENES.size():
		await _verify_stage(stage_index + 1, STAGE_SCENES[stage_index])
	if _failures == 0:
		print("[EnemyCoverShot] PASS: exposed, two solid covers, peek/re-cover, angles, and Stage01-06 masks")
		quit(0)
	else:
		printerr("[EnemyCoverShot] FAIL: %d combat-cover checks failed" % _failures)
		quit(1)

func _verify_stage(stage_id: int, stage_scene: PackedScene) -> void:
	var stage = stage_scene.instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_process(false)
	stage.set_physics_process(false)
	await process_frame
	await physics_frame

	var player = stage.player
	var shooter = stage.enemies_container.get_child(0)
	for enemy in stage.enemies_container.get_children():
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.attack_damage = 0
	shooter.attack_damage = SHOT_DAMAGE
	shooter.target_player = player
	shooter.current_state = 2 # Enemy3D.State.ATTACK
	player.max_health = 5000
	player.current_health = 5000

	var solid_bodies := _solid_world_bodies(stage)
	_check(solid_bodies.size() >= 2, "Stage%02d must expose at least two solid layer-1 environment colliders" % stage_id)

	# Controlled firing lane uses the same layer/mask contract as authored cover.
	var test_cover := StaticBody3D.new()
	test_cover.name = "RegressionSolidCover"
	test_cover.collision_layer = 1
	test_cover.collision_mask = 1
	var cover_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.6)
	cover_shape.shape = box
	test_cover.add_child(cover_shape)
	stage.add_child(test_cover)

	# Open lane: existing damage amount remains unchanged.
	await _place_lane(shooter, player, test_cover, Vector3(0, ARENA_Y + 20, 0), Vector3(-5, ARENA_Y, 0), Vector3(5, ARENA_Y, 0))
	_expect_damage(shooter, player, true, "Stage%02d open lane" % stage_id)

	# First cover, then peek, then return behind cover.
	await _place_lane(shooter, player, test_cover, Vector3(0, ARENA_Y + 1.5, 0), Vector3(0, ARENA_Y, -5), Vector3(0, ARENA_Y, 5))
	for shot_index in 5:
		_expect_damage(shooter, player, false, "Stage%02d sustained wall fire shot %d" % [stage_id, shot_index + 1])
	await _place_lane(shooter, player, test_cover, Vector3(0, ARENA_Y + 1.5, 10), Vector3(-5, ARENA_Y, 0), Vector3(5, ARENA_Y, 0))
	_expect_damage(shooter, player, true, "Stage%02d peek from cover" % stage_id)
	await _place_lane(shooter, player, test_cover, Vector3(0, ARENA_Y + 1.5, 0), Vector3(0, ARENA_Y, -5), Vector3(0, ARENA_Y, 5))
	_expect_damage(shooter, player, false, "Stage%02d returned to cover" % stage_id)

	# A second angle exercises the same collision contract diagonally.
	await _place_lane(shooter, player, test_cover, Vector3(0, ARENA_Y + 1.5, 0), Vector3(-4, ARENA_Y, -4), Vector3(4, ARENA_Y, 4))
	_expect_damage(shooter, player, false, "Stage%02d diagonal solid cover" % stage_id)

	stage.queue_free()
	await process_frame

func _solid_world_bodies(stage: Node) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for node in _all_descendants(stage):
		if node is StaticBody3D and node.collision_layer & 1 != 0:
			for child in node.get_children():
				if child is CollisionShape3D and not child.disabled and child.shape:
					result.append(node)
					break
	return result

func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result

func _place_lane(shooter, player, cover: StaticBody3D, cover_position: Vector3, shooter_position: Vector3, player_position: Vector3) -> void:
	cover.global_position = cover_position
	shooter.global_position = shooter_position
	shooter.velocity = Vector3.ZERO
	player.global_position = player_position
	player.velocity = Vector3.ZERO
	var flat_target := player_position
	flat_target.y = shooter_position.y
	shooter.look_at(flat_target, Vector3.UP)
	await physics_frame
	await process_frame

func _expect_damage(shooter, player, should_damage: bool, label: String) -> void:
	var health_before: int = player.current_health
	shooter._enemy_shoot()
	var expected := health_before - SHOT_DAMAGE if should_damage else health_before
	_check(player.current_health == expected, "%s: expected health %d, got %d" % [label, expected, player.current_health])

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[EnemyCoverShot] %s" % message)
