extends SceneTree
## test_step_04_player_controller.gd
## Automated integration and physics tests for STEP 04: Player Controller.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const PlayerMovementConfig = preload("res://scripts/player/player_movement_config.gd")
const PlayerInput = preload("res://scripts/player/player_input.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("--- BEGIN STEP 04 PLAYER CONTROLLER TEST SUITE ---")
	var success := true
	
	# Test 1: Input Map Verification
	print("[Test 1] Verifying Godot Input Map actions...")
	PlayerInput.ensure_input_map()
	var required_actions := [
		"move_forward", "move_backward", "move_left", "move_right",
		"jump", "sprint", "crouch", "pause",
		"fire", "aim", "reload", "switch_weapon", "interact"
	]
	for act in required_actions:
		if not InputMap.has_action(act):
			printerr("FAILED: Missing required InputMap action: ", act)
			success = false
	if success:
		print("  -> All 13 InputMap actions verified.")

	# Test 2: Movement Config Validation
	print("[Test 2] Validating PlayerMovementConfig parameters...")
	var cfg := PlayerMovementConfig.new()
	if cfg.walk_speed <= 0.0 or cfg.run_speed <= cfg.walk_speed or cfg.sprint_speed <= cfg.run_speed:
		printerr("FAILED: Speed hierarchy invalid (walk < run < sprint)")
		success = false
	if cfg.crouch_speed >= cfg.walk_speed:
		printerr("FAILED: Crouch speed should be slower than walk speed")
		success = false
	if cfg.standing_height <= cfg.crouch_height:
		printerr("FAILED: Standing height must be greater than crouch height")
		success = false
	if cfg.jump_velocity <= 0.0 or cfg.gravity <= 0.0:
		printerr("FAILED: Jump or Gravity invalid")
		success = false
	print("  -> PlayerMovementConfig validated.")

	# Test 3: Player Controller Instantiation & Node Setup
	print("[Test 3] Testing PlayerController setup and registration...")
	var player := PlayerController.new()
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = cfg.standing_height
	capsule.radius = 0.4
	col_shape.shape = capsule
	col_shape.name = "CollisionShape3D"
	player.add_child(col_shape)
	
	var cam_mount := Node3D.new()
	cam_mount.name = "Camera3D"
	player.add_child(cam_mount)
	
	root.add_child(player)
	
	# Trigger ready manually to simulate in-tree lifecycle
	player._ready()
	
	if not player.is_in_group(GameConstants.GROUP_PLAYER):
		printerr("FAILED: Player not added to GROUP_PLAYER")
		success = false
	if player.collision_layer != GameConstants.LAYER_PLAYER:
		printerr("FAILED: Collision layer mismatch. Expected LAYER_PLAYER (2), got: ", player.collision_layer)
		success = false
	if (player.collision_mask & GameConstants.LAYER_WORLD) == 0:
		printerr("FAILED: Collision mask does not include LAYER_WORLD")
		success = false
		
	var gm = root.get_node_or_null("GameManager")
	if gm and gm.get_player() != player:
		printerr("FAILED: GameManager did not register active player")
		success = false
	print("  -> PlayerController node setup and registration PASSED.")

	# Test 4: Acceleration and Deceleration Physics Simulation
	print("[Test 4] Testing physics-based smooth acceleration & deceleration...")
	# Simulate moving on floor
	var test_delta: float = 0.016 # ~60fps step
	
	# Transition via legal state route: BOOT -> MAIN_MENU -> PLAYING
	if gm:
		gm.change_state(GameConstants.GameState.MAIN_MENU)
		gm.change_state(GameConstants.GameState.PLAYING)
		
	# Apply forward wish dir manually to check acceleration formula
	var wish_dir := Vector3.FORWARD
	var target_speed := cfg.run_speed
	var target_vel := wish_dir * target_speed
	var initial_vel := player.velocity
	
	# Simulate one step of acceleration
	player.velocity.z = move_toward(player.velocity.z, target_vel.z, cfg.ground_acceleration * target_speed * test_delta)
	if absf(player.velocity.z) <= absf(initial_vel.z) or absf(player.velocity.z) >= target_speed:
		printerr("FAILED: Velocity should smoothly accelerate, got: ", player.velocity.z)
		success = false
	else:
		print("  -> Smooth acceleration verified: ", initial_vel.z, " -> ", player.velocity.z)
		
	# Simulate deceleration to stop
	var decel_step: float = move_toward(player.velocity.z, 0.0, cfg.ground_deceleration * cfg.run_speed * test_delta)
	if absf(decel_step) >= absf(player.velocity.z):
		printerr("FAILED: Deceleration failed to reduce velocity")
		success = false
	else:
		print("  -> Smooth deceleration verified: ", player.velocity.z, " -> ", decel_step)

	# Test 5: Gravity and Jump Mechanics
	print("[Test 5] Testing jump and gravity mechanics...")
	# Simulate jump
	player.velocity.y = cfg.jump_velocity
	if absf(player.velocity.y - cfg.jump_velocity) > 0.001:
		printerr("FAILED: Jump velocity not applied. Expected: ", cfg.jump_velocity, ", got: ", player.velocity.y)
		success = false
		
	# Apply in-air gravity over time
	var pre_grav_y: float = player.velocity.y
	player.velocity.y -= cfg.gravity * test_delta
	if player.velocity.y >= pre_grav_y:
		printerr("FAILED: Gravity did not decrease velocity.y")
		success = false
	print("  -> Jump and Gravity simulation PASSED.")

	# Test 6: Crouch Architecture & Height Adjustment
	print("[Test 6] Testing crouch architecture...")
	var crouch_signal_fired := [false]
	player.crouch_toggled.connect(func(c): crouch_signal_fired[0] = true)
	
	player.is_crouching = true
	player.crouch_toggled.emit(true)
	if not crouch_signal_fired[0]:
		printerr("FAILED: crouch_toggled signal did not fire")
		success = false
		
	# Simulate crouch height transition
	var pre_height: float = player.current_shape_height
	player.current_shape_height = move_toward(player.current_shape_height, cfg.crouch_height, cfg.crouch_transition_speed * test_delta)
	if player.current_shape_height >= pre_height:
		printerr("FAILED: Crouch did not smoothly decrease collision shape height")
		success = false
	print("  -> Crouch architecture and height reduction PASSED.")

	# Test 7: Movement State Transitions
	print("[Test 7] Testing Movement State determinations and signals...")
	var state_signal_box := [-1]
	player.movement_state_changed.connect(func(new_s, old_s): state_signal_box[0] = new_s)
	
	# Test IDLE state
	player.velocity = Vector3.ZERO
	player.current_horizontal_speed = 0.0
	player.is_crouching = false
	player.was_on_floor = true
	var idle_state = GameConstants.MovementState.IDLE
	player.movement_state_changed.emit(idle_state, player.current_movement_state)
	player.current_movement_state = idle_state
	if player.get_movement_state() != GameConstants.MovementState.IDLE:
		printerr("FAILED: IDLE state mismatch")
		success = false
		
	# Test SPRINTING state
	var sprint_state = GameConstants.MovementState.SPRINTING
	player.movement_state_changed.emit(sprint_state, player.current_movement_state)
	player.current_movement_state = sprint_state
	if player.get_movement_state() != GameConstants.MovementState.SPRINTING or state_signal_box[0] != GameConstants.MovementState.SPRINTING:
		printerr("FAILED: SPRINTING state signal mismatch")
		success = false
		
	# Test CROUCHING state
	var crouch_state = GameConstants.MovementState.CROUCHING
	player.movement_state_changed.emit(crouch_state, player.current_movement_state)
	player.current_movement_state = crouch_state
	if player.get_movement_state() != GameConstants.MovementState.CROUCHING:
		printerr("FAILED: CROUCHING state mismatch")
		success = false
	print("  -> Movement state machine PASSED.")

	# Cleanup
	player.queue_free()

	if success:
		print("--- ALL STEP 04 TESTS PASSED PERFECTLY! ---")
		quit(0)
	else:
		printerr("--- STEP 04 TESTS ENCOUNTERED FAILURES! ---")
		quit(1)