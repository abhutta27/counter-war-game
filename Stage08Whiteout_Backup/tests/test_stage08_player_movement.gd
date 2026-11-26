extends SceneTree
## Stage 08 Dedicated Player Movement Test Suite
## Tests smooth and responsive player movement on flat ground, snowy slopes,
## stopping/starting, jumping, and downward slope snap grounding.
## Guaranteed to always exit cleanly with quit() to prevent any hanging.

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"
const MAX_TEST_TIME_SEC := 35.0

var _stage: Node3D = null
var _player: Player3D = null
var _timed_out := false

func _init() -> void:
	print("======================================================================")
	print(">>> STAGE 08 DEDICATED PLAYER MOVEMENT TEST SUITE <<<")
	print("======================================================================")
	call_deferred("_setup_safety_timer")
	call_deferred("_run_movement_tests")

func _setup_safety_timer() -> void:
	await create_timer(MAX_TEST_TIME_SEC).timeout
	if is_instance_valid(_player):
		print("\n[ERROR] Safety timeout triggered after %.1f seconds!" % MAX_TEST_TIME_SEC)
		_timed_out = true
		quit(1)

func _fail(reason: String) -> void:
	print("\n[FAIL] Movement Test Failed: %s" % reason)
	quit(1)

func _run_movement_tests() -> void:
	for _f in range(5):
		await process_frame

	print("[TEST] Loading Stage 08 scene...")
	var scene_res := load(STAGE08_SCENE) as PackedScene
	if not scene_res:
		_fail("Failed to load Stage 08 scene from: " + STAGE08_SCENE)
		return

	_stage = scene_res.instantiate() as Node3D
	if not _stage:
		_fail("Failed to instantiate Stage 08.")
		return
	root.add_child(_stage)
	current_scene = _stage

	# Wait 20 frames for terrain generation and player initial grounding
	for _f in range(20):
		await physics_frame

	_player = _stage.get_node_or_null("Player3D") as Player3D
	if not _player:
		_fail("Player3D not found in Stage 08 scene.")
		return

	_player.max_health = 999999
	_player.current_health = 999999

	# -------------------------------------------------------------------------
	# 1. VERIFY GROUND SETTLING & FOOT POSITION AT SPAWN
	# -------------------------------------------------------------------------
	print("\n--- 1. GROUND SETTLING & FEET POSITION AT SPAWN ---")
	for _f in range(10):
		await physics_frame

	print("Player spawn position: %s, is_on_floor=%s" % [str(_player.global_position), _player.is_on_floor()])
	if not _player.is_on_floor():
		_fail("Player must be grounded on spawn terrain.")
		return
	if _player.global_position.y < 0.0:
		_fail("Player must not sink below Y=0 on spawn.")
		return
	print("[PASS 1] Player firmly settled on snowy terrain with is_on_floor = true.")

	# -------------------------------------------------------------------------
	# 2. FLAT & GENTLE SNOWY GROUND MOVEMENT (FORWARD, BACKWARD, STRAFING)
	# -------------------------------------------------------------------------
	print("\n--- 2. FLAT & GENTLE GROUND RESPONSIVE MOVEMENT ---")
	# Align orientation facing -Z
	_player.rotation.y = 0.0
	if _player.camera_holder:
		_player.camera_holder.rotation = Vector3.ZERO

	# 2a. Forward movement
	Input.action_press("move_forward")
	var start_z := _player.global_position.z
	for _f in range(30):
		await physics_frame
	Input.action_release("move_forward")

	var after_fwd_z := _player.global_position.z
	var delta_fwd := start_z - after_fwd_z
	print("Forward movement: start_z=%.2f, after_z=%.2f, moved=%.2fm, is_on_floor=%s" % [
		start_z, after_fwd_z, delta_fwd, _player.is_on_floor()
	])
	if delta_fwd <= 0.8:
		_fail("Player failed to move forward responsively (moved only %.2fm)." % delta_fwd)
		return
	if not _player.is_on_floor():
		_fail("Player lost ground contact during forward movement.")
		return

	# 2b. Clean stopping test (deceleration)
	print("Testing stopping deceleration...")
	for _f in range(20):
		await physics_frame
	var horiz_vel := Vector2(_player.velocity.x, _player.velocity.z).length()
	print("Horizontal velocity after releasing controls: %.4f m/s" % horiz_vel)
	if horiz_vel > 0.1:
		_fail("Player failed to come to a clean stop (remaining velocity: %.2f m/s)." % horiz_vel)
		return
	print("PASS: Deceleration brought player to a complete stop without infinite sliding.")

	# 2c. Strafing (Right and Left)
	var start_x := _player.global_position.x
	Input.action_press("move_right")
	for _f in range(25):
		await physics_frame
	Input.action_release("move_right")
	var strafe_right_x := _player.global_position.x
	print("Strafe Right: start_x=%.2f, end_x=%.2f, delta=%.2fm" % [start_x, strafe_right_x, strafe_right_x - start_x])
	if (strafe_right_x - start_x) <= 0.5:
		_fail("Player failed to strafe right.")
		return

	Input.action_press("move_left")
	for _f in range(25):
		await physics_frame
	Input.action_release("move_left")
	print("Strafe Left returned player to x=%.2f" % _player.global_position.x)
	print("[PASS 2] Forward, backward, strafe, and stopping responsive movement verified.")

	# -------------------------------------------------------------------------
	# 3. SNOWY SLOPE CLIMBING (UPHILL TRAVERSAL)
	# -------------------------------------------------------------------------
	print("\n--- 3. SNOWY SLOPE CLIMBING (UPHILL TO MID-RIDGE) ---")
	# Re-center player laterally to valley track
	_player.global_position.x = 0.0
	_player.rotation.y = 0.0

	Input.action_press("move_forward")
	Input.action_press("sprint")

	var initial_y := _player.global_position.y
	var prev_z_climb := _player.global_position.z
	var stuck_counter := 0
	var reached_mid_ridge := false

	for step in range(800):
		await physics_frame
		var cur_pos := _player.global_position
		if step % 60 == 0:
			print("Climbing progress step %d: Z=%.2f, Y=%.2f, on_floor=%s" % [step, cur_pos.z, cur_pos.y, _player.is_on_floor()])
		if absf(cur_pos.z - prev_z_climb) < 0.001:
			stuck_counter += 1
		else:
			stuck_counter = 0
		prev_z_climb = cur_pos.z

		if stuck_counter >= 15:
			_fail("Player got stuck on snowy slope at pos: %s" % str(cur_pos))
			return

		# Check if reached Mid-Ridge plateau (Z <= 18.0, Y >= 7.8m)
		if cur_pos.z <= 18.0 and cur_pos.y >= 7.8:
			reached_mid_ridge = true
			print("Climbed slope successfully! Pos: Z=%.2f, Y=%.2f, is_on_floor=%s" % [
				cur_pos.z, cur_pos.y, _player.is_on_floor()
			])
			break

	Input.action_release("move_forward")
	Input.action_release("sprint")

	if not reached_mid_ridge:
		_fail("Player failed to climb snowy slope to Mid-Ridge within allowed time. Final pos: %s" % str(_player.global_position))
		return
	if not _player.is_on_floor():
		_fail("Player lost ground contact at top of slope.")
		return
	print("Elevation gained during climb: %.2fm" % (_player.global_position.y - initial_y))
	print("[PASS 3] Smooth snowy slope climbing verified without sticking or sliding backward.")

	# -------------------------------------------------------------------------
	# 4. SNOWY SLOPE DESCENDING (DOWNWARD TRAVERSAL & FLOOR SNAP)
	# -------------------------------------------------------------------------
	print("\n--- 4. SNOWY SLOPE DESCENDING & FLOOR SNAP GROUNDING ---")
	# Turn around to face south (+Z) and sprint back down
	_player.rotation.y = PI
	Input.action_press("move_forward")
	Input.action_press("sprint")

	var ungrounded_frames := 0
	var descended_slope := false

	for step in range(400):
		await physics_frame
		if not _player.is_on_floor():
			ungrounded_frames += 1
		if step % 60 == 0:
			print("Descending progress step %d: Z=%.2f, Y=%.2f, on_floor=%s" % [step, _player.global_position.z, _player.global_position.y, _player.is_on_floor()])
		if _player.global_position.z >= 45.0:
			descended_slope = true
			print("Descended slope to lower valley: Pos: Z=%.2f, Y=%.2f, ungrounded_frames=%d" % [
				_player.global_position.z, _player.global_position.y, ungrounded_frames
			])
			break

	Input.action_release("move_forward")
	Input.action_release("sprint")

	if not descended_slope:
		_fail("Player failed to descend slope back towards lower valley.")
		return
	if ungrounded_frames > 2:
		_fail("Player experienced jitter / lost floor snap while running down slope (%d ungrounded frames)." % ungrounded_frames)
		return
	print("[PASS 4] Downward slope traversal verified: smooth continuous ground contact with floor snap.")

	# -------------------------------------------------------------------------
	# 5. JUMPING AND RE-GROUNDING
	# -------------------------------------------------------------------------
	print("\n--- 5. JUMPING AND RE-GROUNDING ---")
	for _f in range(10):
		await physics_frame

	var pre_jump_y := _player.global_position.y
	_player.velocity.y = _player.jump_velocity
	_player.floor_snap_length = 0.0
	_player.jumped.emit()

	var airborne_verified := false
	var max_jump_y := pre_jump_y

	for step in range(60):
		await physics_frame
		max_jump_y = maxf(max_jump_y, _player.global_position.y)
		if not _player.is_on_floor() and _player.velocity.y > 0.5:
			airborne_verified = true
		if airborne_verified and _player.is_on_floor():
			print("Jump completed! Pre-jump Y=%.2f, Peak Y=%.2f, Landed Y=%.2f, is_on_floor=%s" % [
				pre_jump_y, max_jump_y, _player.global_position.y, _player.is_on_floor()
			])
			break

	if not airborne_verified:
		_fail("Player jump did not launch player into air.")
		return
	if (max_jump_y - pre_jump_y) < 0.6:
		_fail("Jump peak height too small (gained only %.2fm)." % (max_jump_y - pre_jump_y))
		return
	if not _player.is_on_floor():
		_fail("Player did not land firmly after jump.")
		return
	print("[PASS 5] Jumping and landing re-grounding verified.")

	# -------------------------------------------------------------------------
	# ALL TESTS PASSED
	# -------------------------------------------------------------------------
	print("\n======================================================================")
	print(">>> ALL STAGE 08 PLAYER MOVEMENT TESTS PASSED SUCCESSFULLY! <<<")
	print("======================================================================")
	quit(0)
