extends SceneTree
## Automated routing/physics verification. This is synthetic input, not a claim
## that a physical keyboard was tested.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 30.0)
	floor_shape.shape = box
	floor.add_child(floor_shape)
	floor.position.y = -0.5
	world.add_child(floor)

	var player := (load("res://scenes/entities/Player3D.tscn") as PackedScene).instantiate() as Player3D
	world.add_child(player)
	for _frame in 8:
		await physics_frame
	assert(player.is_on_floor(), "Player must settle on the floor before input checks")

	Input.action_press("move_forward")
	for _frame in 3:
		await physics_frame
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(is_equal_approx(walk_speed, player.walk_speed), "Forward walk must use approved walk speed")

	Input.action_press("sprint")
	for _frame in 3:
		await physics_frame
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(is_equal_approx(sprint_speed, player.run_speed), "W + Shift must use configured sprint speed")
	assert(sprint_speed > walk_speed, "Sprint must be measurably faster than walk")
	Input.action_release("sprint")
	Input.action_release("move_forward")

	Input.action_press("jump")
	await physics_frame
	await physics_frame
	assert(player.velocity.y > 0.0, "Grounded Space action must start a jump")
	Input.action_release("jump")
	while not player.is_on_floor():
		await physics_frame

	await _verify_crouch_key(player, KEY_CTRL, "Ctrl")
	await _verify_crouch_key(player, KEY_C, "C")

	print("[PlayerMovementControls] PASS synthetic: walk=%.2f sprint=%.2f jump_v=%.2f Ctrl/C hold crouch" % [walk_speed, sprint_speed, player.jump_velocity])
	quit()

func _verify_crouch_key(player: Player3D, keycode: Key, label: String) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await physics_frame
	await physics_frame
	assert(player.is_crouching, "%s press must enter crouch" % label)
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame
	await physics_frame
	assert(not player.is_crouching, "%s release must leave crouch (hold behavior)" % label)
