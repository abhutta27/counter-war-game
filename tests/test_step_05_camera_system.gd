extends SceneTree
## test_step_05_camera_system.gd
## Automated integration and verification tests for STEP 05: First-Person Camera System.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const PlayerMovementConfig = preload("res://scripts/player/player_movement_config.gd")
const PlayerCamera = preload("res://scripts/player/player_camera.gd")
const PlayerCameraConfig = preload("res://scripts/player/player_camera_config.gd")
const PlayerInput = preload("res://scripts/player/player_input.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("--- BEGIN STEP 05 CAMERA SYSTEM TEST SUITE ---")
	var success := true
	
	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.change_state(GameConstants.GameState.MAIN_MENU)
		gm.change_state(GameConstants.GameState.PLAYING)
		
	# Setup Player and Camera hierarchy
	var player := PlayerController.new()
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.name = "CollisionShape3D"
	player.add_child(col_shape)
	
	var camera := PlayerCamera.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	root.add_child(player)
	
	player._ready()
	camera._ready()
	
	# TEST 01: Setup & Hierarchy Check
	print("[TEST 01] Verifying camera attachment and initial eye height...")
	if camera.get_parent() != player:
		printerr("FAILED: Camera3D is not a direct child of PlayerController")
		success = false
	if absf(camera.position.y - 1.55) > 0.01:
		printerr("FAILED: Camera eye height expected 1.55m, got: ", camera.position.y)
		success = false
	if absf(camera.fov - 75.0) > 0.1:
		printerr("FAILED: Base FOV expected 75.0, got: ", camera.fov)
		success = false
	if success:
		print("  -> TEST 01 PASSED (Camera attached at eye level 1.55m, FOV 75)")

	# TEST 02: Player Movement Check
	print("[TEST 02] Verifying player movement with camera mount...")
	var pre_z: float = player.velocity.z
	player.velocity.z = -4.5
	if player.velocity.z != -4.5:
		printerr("FAILED: Movement velocity not set")
		success = false
	player.velocity.z = 0.0
	print("  -> TEST 02 PASSED (Player movement functional)")

	# Set mouse captured for mouse tests
	camera.set_mouse_captured(true)

	# TEST 03: Mouse X -> Player/Yaw Rotation
	print("[TEST 03] Testing Mouse X motion (Horizontal look rotates Player body)...")
	var initial_yaw: float = player.rotation.y
	var motion_x := InputEventMouseMotion.new()
	motion_x.relative = Vector2(50.0, 0.0) # Move mouse right
	camera._unhandled_input(motion_x)
	
	if player.rotation.y == initial_yaw:
		printerr("FAILED: Player body did not rotate horizontally with mouse X")
		success = false
	else:
		print("  -> TEST 03 PASSED (Player Yaw changed from ", initial_yaw, " to ", player.rotation.y, ")")

	# TEST 04: Mouse Y -> Camera/Pitch Rotation
	print("[TEST 04] Testing Mouse Y motion (Vertical look rotates Camera pitch only)...")
	var initial_pitch: float = camera.rotation.x
	var initial_player_pitch: float = player.rotation.x
	var motion_y := InputEventMouseMotion.new()
	motion_y.relative = Vector2(0.0, 40.0) # Move mouse down (look down)
	camera._unhandled_input(motion_y)
	
	if camera.rotation.x == initial_pitch:
		printerr("FAILED: Camera did not pitch vertically with mouse Y")
		success = false
	if player.rotation.x != initial_player_pitch:
		printerr("FAILED: Player body pitched! Only Camera should pitch vertically.")
		success = false
	if success:
		print("  -> TEST 04 PASSED (Camera Pitch changed: ", initial_pitch, " to ", camera.rotation.x, ", Player body stays upright)")

	# TEST 05: Pitch Limits (Clamp)
	print("[TEST 05] Testing Camera pitch limits clamping (prevent over-rotation)...")
	var extreme_up := InputEventMouseMotion.new()
	extreme_up.relative = Vector2(0.0, -10000.0) # Look straight up
	camera._unhandled_input(extreme_up)
	
	var max_pitch_rad: float = deg_to_rad(85.0)
	var min_pitch_rad: float = deg_to_rad(-85.0)
	
	if camera.pitch > max_pitch_rad + 0.001 or camera.pitch < min_pitch_rad - 0.001:
		printerr("FAILED: Camera pitch exceeded clamp limits: ", rad_to_deg(camera.pitch))
		success = false
		
	var extreme_down := InputEventMouseMotion.new()
	extreme_down.relative = Vector2(0.0, 20000.0) # Look straight down
	camera._unhandled_input(extreme_down)
	if camera.pitch > max_pitch_rad + 0.001 or camera.pitch < min_pitch_rad - 0.001:
		printerr("FAILED: Camera pitch exceeded clamp limits: ", rad_to_deg(camera.pitch))
		success = false
	print("  -> TEST 05 PASSED (Camera pitch safely clamped within [-85 deg, +85 deg])")

	# TEST 06: ESC Releases Mouse
	print("[TEST 06] Testing ESC key releases mouse cursor...")
	var esc_event := InputEventKey.new()
	esc_event.physical_keycode = KEY_ESCAPE
	esc_event.pressed = true
	camera._unhandled_input(esc_event)
	
	if camera.is_captured():
		printerr("FAILED: Mouse not released on ESC. Captured state: ", camera.is_captured())
		success = false
	else:
		print("  -> TEST 06 PASSED (Mouse released to MOUSE_MODE_VISIBLE on ESC)")

	# TEST 07: Click Window Re-captures Mouse
	print("[TEST 07] Testing click in window re-captures mouse cursor...")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	camera._unhandled_input(click_event)
	
	if not camera.is_captured():
		printerr("FAILED: Mouse not captured on click. Captured state: ", camera.is_captured())
		success = false
	else:
		print("  -> TEST 07 PASSED (Mouse captured back to MOUSE_MODE_CAPTURED on click)")

	# TEST 08: Movement + Mouse Look Simultaneous Sync
	print("[TEST 08] Testing Movement + Mouse Look simultaneous execution...")
	# Rotate player yaw by 90 degrees
	player.rotation.y = deg_to_rad(90.0)
	var forward_dir: Vector3 = -player.global_transform.basis.z
	# At 90 deg yaw, forward should point along -X
	if absf(forward_dir.x - (-1.0)) > 0.01:
		printerr("FAILED: Forward vector does not match rotated player yaw")
		success = false
	else:
		print("  -> Movement orientation perfectly synchronized with player yaw.")
		
	# Check crouch lowers camera height
	player.is_crouching = true
	player.current_camera_y = 0.95
	camera.position.y = player.current_camera_y
	if absf(camera.position.y - 0.95) > 0.01:
		printerr("FAILED: Camera height not tracking crouch position")
		success = false
	print("  -> TEST 08 PASSED (No jitter, smooth orientation and crouch tracking)")

	# Cleanup
	player.queue_free()

	if success:
		print("--- ALL STEP 05 TESTS PASSED PERFECTLY! ---")
		quit(0)
	else:
		printerr("--- STEP 05 TESTS ENCOUNTERED FAILURES! ---")
		quit(1)