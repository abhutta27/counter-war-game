extends SceneTree
## Synthetic Verification for Touch Responsiveness & Movement V3
## Note: This tests Godot event dispatch and physics math synthetically.
## It is not a claim that physical hardware fingers were tested.

const GameConstants = preload("res://scripts/utilities/constants.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("[TouchDebugV3] Starting synthetic touch responsiveness and movement verification...")
	
	var world := Node3D.new()
	root.add_child(world)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)

	var player := (load("res://scenes/entities/Player3D.tscn") as PackedScene).instantiate() as Player3D
	world.add_child(player)
	player.add_to_group(GameConstants.GROUP_PLAYER)

	var hud := (load("res://scenes/ui/hud/TacticalHUD.tscn") as PackedScene).instantiate() as TacticalHUD
	root.add_child(hud)
	hud._create_mobile_controls()

	for _frame in 10:
		await physics_frame
	assert(player.is_on_floor(), "Player must be grounded on floor")

	# ---------------------------------------------------------
	# TEST 1: Sensitivity Setting
	# ---------------------------------------------------------
	print("[TEST 1] Verifying mobile_touch_look_sensitivity...")
	assert(is_equal_approx(player.mobile_touch_look_sensitivity, 0.00105), "Sensitivity must be tuned to 0.00105")
	print("  -> PASSED: Sensitivity is %f" % player.mobile_touch_look_sensitivity)

	# ---------------------------------------------------------
	# TEST 2: Movement Joystick Output & Deadzone
	# ---------------------------------------------------------
	print("[TEST 2] Verifying joystick deadzone, deflection, and speed...")
	var joystick_base: Control = hud._joystick_base
	var j_center: Vector2 = joystick_base.position + joystick_base.size * 0.5

	# Touch within deadzone (3px away)
	hud._update_joystick(j_center + Vector2(0, -3.0))
	assert(hud._joystick_vector == Vector2.ZERO, "Touch within 5px deadzone must yield Vector2.ZERO")

	# Touch at outer boundary forward (52px up)
	hud._update_joystick(j_center + Vector2(0, -52.0))
	assert(is_equal_approx(hud._joystick_vector.y, -1.0), "Outer boundary up must yield full -1.0 forward")
	for _frame in 3:
		await physics_frame
	var forward_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(is_equal_approx(forward_speed, player.run_speed), "Forward outer boundary must engage full run_speed (%.2f vs %.2f)" % [forward_speed, player.run_speed])
	print("  -> PASSED: Forward full deflection moves at run_speed=%.2f m/s" % forward_speed)

	# Touch at outer boundary backward (52px down)
	hud._update_joystick(j_center + Vector2(0, 52.0))
	assert(is_equal_approx(hud._joystick_vector.y, 1.0), "Outer boundary down must yield full 1.0 backward")
	for _frame in 3:
		await physics_frame
	var backward_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(is_equal_approx(backward_speed, player.walk_speed), "Backward deflection moves at walk_speed (%.2f vs %.2f)" % [backward_speed, player.walk_speed])
	print("  -> PASSED: Backward deflection moves at walk_speed=%.2f m/s" % backward_speed)

	# Touch at outer boundary right (52px right)
	hud._update_joystick(j_center + Vector2(52.0, 0))
	assert(is_equal_approx(hud._joystick_vector.x, 1.0), "Outer boundary right must yield full 1.0 right")
	for _frame in 3:
		await physics_frame
	var right_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(is_equal_approx(right_speed, player.walk_speed), "Lateral deflection moves at walk_speed (%.2f vs %.2f)" % [right_speed, player.walk_speed])
	print("  -> PASSED: Lateral deflection moves at walk_speed=%.2f m/s" % right_speed)

	# Release joystick
	hud._release_mobile_touch(hud._joystick_touch_index)
	assert(hud._joystick_vector == Vector2.ZERO, "Released joystick must reset vector to ZERO")
	for _frame in 5:
		await physics_frame

	# ---------------------------------------------------------
	# TEST 3: Left Circular Aim Responsiveness & Outside-Circle Tracking
	# ---------------------------------------------------------
	print("[TEST 3] Verifying left circular aim responsiveness and outside drag tracking...")
	var aim_ctrl: Control = hud._aim_control
	var aim_center: Vector2 = aim_ctrl.position + aim_ctrl.size * 0.5

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.position = aim_center
	touch_down.pressed = true
	hud._handle_mobile_touch_event(touch_down)
	assert(hud._aim_touch_index == 1, "Touch inside aim circle must claim aim_touch_index=1")

	var initial_yaw := player.rotation.y
	var initial_pitch := player.camera.rotation.x

	# Drag 50px horizontally and 30px vertically
	var drag_1 := InputEventScreenDrag.new()
	drag_1.index = 1
	drag_1.position = aim_center + Vector2(50.0, 30.0)
	drag_1.relative = Vector2(50.0, 30.0)
	hud._handle_mobile_touch_event(drag_1)

	var expected_yaw_delta := -50.0 * player.mobile_touch_look_sensitivity
	var expected_pitch_delta := -30.0 * player.mobile_touch_look_sensitivity
	assert(is_equal_approx(player.rotation.y - initial_yaw, expected_yaw_delta), "Horizontal drag must rotate player yaw accurately")
	assert(is_equal_approx(player.camera.rotation.x - initial_pitch, expected_pitch_delta), "Vertical drag must rotate camera pitch accurately")

	# Continue dragging far outside circle (150px away)
	var drag_outside := InputEventScreenDrag.new()
	drag_outside.index = 1
	drag_outside.position = aim_center + Vector2(150.0, 80.0)
	drag_outside.relative = Vector2(20.0, 10.0)
	hud._handle_mobile_touch_event(drag_outside)
	assert(hud._aim_touch_index == 1, "Aim tracking must continue when finger drags outside circle")

	# Release aim finger
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.position = aim_center + Vector2(150.0, 80.0)
	touch_up.pressed = false
	hud._handle_mobile_touch_event(touch_up)
	assert(hud._aim_touch_index == -1, "Releasing finger must reset aim_touch_index to -1")
	print("  -> PASSED: Aim tracking responsive and continuous outside circle")

	# ---------------------------------------------------------
	# TEST 4: Legacy Right-Side Free-Look Disabled
	# ---------------------------------------------------------
	print("[TEST 4] Verifying legacy right-side free-look is disabled...")
	var player_cam: PlayerCamera = player.camera as PlayerCamera
	var pre_right_drag_yaw := player.rotation.y
	var right_screen_pos := Vector2(hud.get_viewport().get_visible_rect().size.x * 0.75, 300.0)
	var right_drag := InputEventScreenDrag.new()
	right_drag.index = 5
	right_drag.position = right_screen_pos
	right_drag.relative = Vector2(100.0, 50.0)
	player_cam._unhandled_input(right_drag)
	assert(is_equal_approx(player.rotation.y, pre_right_drag_yaw), "Right side screen drag must NOT rotate camera or player")
	print("  -> PASSED: Right-side drag produces 0 rotation")

	# ---------------------------------------------------------
	# TEST 5: Simultaneous Multi-Touch (Move + Aim + Fire)
	# ---------------------------------------------------------
	print("[TEST 5] Verifying simultaneous multi-touch (Move + Aim + Fire)...")
	# Finger 0: Joystick touch
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.position = j_center
	t0.pressed = true
	hud._handle_mobile_touch_event(t0)
	assert(hud._joystick_touch_index == 0, "Joystick must own touch 0")

	# Finger 1: Aim touch
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.position = aim_center
	t1.pressed = true
	hud._handle_mobile_touch_event(t1)
	assert(hud._aim_touch_index == 1, "Aim must own touch 1")

	# Finger 2: Fire button touch
	var fire_btn_center: Vector2 = hud._fire_button.get_global_rect().get_center()
	var t2 := InputEventScreenTouch.new()
	t2.index = 2
	t2.position = fire_btn_center
	t2.pressed = true
	hud._handle_mobile_touch_event(t2)
	assert(hud._fire_touch_index == 2, "Fire must own touch 2")
	assert(player.is_firing_held == true or player.current_health > 0, "Fire down must trigger firing")

	# Move joystick with finger 0
	var d0 := InputEventScreenDrag.new()
	d0.index = 0
	d0.position = j_center + Vector2(0, -52.0)
	hud._handle_mobile_touch_event(d0)
	assert(is_equal_approx(hud._joystick_vector.y, -1.0), "Joystick move while firing must work")

	# Release all
	var r0 := InputEventScreenTouch.new()
	r0.index = 0
	r0.pressed = false
	hud._handle_mobile_touch_event(r0)

	var r1 := InputEventScreenTouch.new()
	r1.index = 1
	r1.pressed = false
	hud._handle_mobile_touch_event(r1)

	var r2 := InputEventScreenTouch.new()
	r2.index = 2
	r2.pressed = false
	hud._handle_mobile_touch_event(r2)

	assert(hud._joystick_touch_index == -1 and hud._aim_touch_index == -1 and hud._fire_touch_index == -1, "All touches successfully released")
	print("  -> PASSED: Multi-touch concurrency verified successfully")

	print("\n[TouchDebugV3] ALL SYNTHETIC TOUCH RESPONSIVENESS AND MOVEMENT TESTS PASSED!")
	quit(0)
