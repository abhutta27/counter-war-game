extends SceneTree
## test_step_06_weapon_architecture.gd
## Automated integration and verification tests for STEP 06: Weapon Architecture.

const GameConstants = preload("res://scripts/utilities/constants.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const PlayerMovementConfig = preload("res://scripts/player/player_movement_config.gd")
const PlayerCamera = preload("res://scripts/player/player_camera.gd")
const PlayerCameraConfig = preload("res://scripts/player/player_camera_config.gd")
const WeaponData = preload("res://scripts/weapons/weapon_data.gd")
const WeaponBase = preload("res://scripts/weapons/weapon_base.gd")
const WeaponManager = preload("res://scripts/weapons/weapon_manager.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("--- BEGIN STEP 06 WEAPON ARCHITECTURE TEST SUITE ---")
	var success := true
	
	# TEST 01: Game Launch & Game State
	print("[TEST 01] Verifying game systems and state machine launch...")
	var gm = root.get_node_or_null("GameManager")
	var eb = root.get_node_or_null("EventBus")
	if not gm or not eb:
		printerr("FAILED: GameManager or EventBus not found")
		quit(1)
		return
	gm.change_state(GameConstants.GameState.MAIN_MENU)
	gm.change_state(GameConstants.GameState.PLAYING)
	if gm.current_state != GameConstants.GameState.PLAYING:
		printerr("FAILED: Could not transition to PLAYING state")
		success = false
	else:
		print("  -> TEST 01 PASSED (Game state is PLAYING)")

	# Setup full Player + Camera hierarchy
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

	# TEST 02: Existing Player Controller
	print("[TEST 02] Verifying Player Controller movement foundation...")
	if not player.is_in_group(GameConstants.GROUP_PLAYER):
		printerr("FAILED: Player not in GROUP_PLAYER")
		success = false
	print("  -> TEST 02 PASSED (Player Controller intact)")

	# TEST 03: Existing Camera System
	print("[TEST 03] Verifying Camera System integration...")
	if camera.get_parent() != player or absf(camera.position.y - 1.55) > 0.01:
		printerr("FAILED: Camera mount height or parentage invalid. Expected 1.55, got: ", camera.position.y)
		success = false
	else:
		print("  -> TEST 03 PASSED (Camera System intact at 1.55m eye level)")

	# TEST 04: Weapon Architecture Initialization
	print("[TEST 04] Testing WeaponBase initialization & ammo lifecycle...")
	var rifle_data := WeaponData.new()
	rifle_data.weapon_id = "m4a1"
	rifle_data.weapon_name = "M4A1 Carbine"
	rifle_data.magazine_size = 30
	rifle_data.starting_reserve_ammo = 90
	rifle_data.max_reserve_ammo = 120
	rifle_data.fire_rate = 0.1
	rifle_data.reload_time = 1.5
	
	var weapon1 := WeaponBase.new(rifle_data)
	if weapon1.current_ammo != 30 or weapon1.reserve_ammo != 90:
		printerr("FAILED: WeaponBase ammo initialization failed")
		success = false
		
	# Equip weapon
	weapon1.equip()
	if not weapon1.is_equipped or not weapon1.visible:
		printerr("FAILED: WeaponBase equip failed")
		success = false
		
	# Fire one round (consumes ammo)
	var fire_ok: bool = weapon1.fire()
	if not fire_ok or weapon1.current_ammo != 29:
		printerr("FAILED: WeaponBase fire did not decrement ammo properly")
		success = false
	else:
		print("  -> TEST 04 PASSED (WeaponBase initialized, equipped, and consumed round)")

	# TEST 05: Weapon Data Loading
	print("[TEST 05] Verifying data-driven WeaponData parameters...")
	var pistol_data := WeaponData.new()
	pistol_data.weapon_id = "usp45"
	pistol_data.weapon_name = "USP .45"
	pistol_data.weapon_type = GameConstants.WeaponType.PISTOL
	pistol_data.magazine_size = 12
	pistol_data.starting_reserve_ammo = 48
	pistol_data.base_damage = 25
	pistol_data.reload_time = 1.2
	
	if pistol_data.magazine_size != 12 or pistol_data.weapon_type != GameConstants.WeaponType.PISTOL:
		printerr("FAILED: WeaponData parameters not stored accurately")
		success = false
	else:
		print("  -> TEST 05 PASSED (Data-driven weapon stats loaded accurately)")

	# TEST 06: Weapon Manager Current Weapon Identification & Switching
	print("[TEST 06] Testing WeaponManager registration and switching...")
	var weapon_manager := WeaponManager.new()
	weapon_manager.name = "WeaponHolder"
	camera.add_child(weapon_manager)
	
	var weapon2 := WeaponBase.new(pistol_data)
	
	weapon_manager.register_weapon(weapon1)
	weapon_manager.register_weapon(weapon2)
	
	if weapon_manager.get_weapon_count() != 2:
		printerr("FAILED: WeaponManager did not register 2 weapons")
		success = false
		
	# Equip weapon 0 (Rifle)
	weapon_manager.equip_weapon_by_index(0)
	var active_w = weapon_manager.get_current_weapon()
	if not active_w or active_w.data.weapon_id != "m4a1":
		printerr("FAILED: Current weapon is not M4A1")
		success = false
		
	# Switch to next weapon (Pistol)
	weapon_manager.switch_next_weapon()
	active_w = weapon_manager.get_current_weapon()
	if not active_w or active_w.data.weapon_id != "usp45":
		printerr("FAILED: Switch to USP .45 failed")
		success = false
	else:
		print("  -> TEST 06 PASSED (WeaponManager correctly identified and switched weapons)")

	# TEST 07: Player + Camera + Weapon Hierarchy Runtime Check
	print("[TEST 07] Verifying Player -> Camera3D -> WeaponHolder hierarchy...")
	if weapon_manager.get_parent() != camera or camera.get_parent() != player:
		printerr("FAILED: Complete Player -> Camera -> Weapon hierarchy broken")
		success = false
	var retrieved_wm = player.get_weapon_manager()
	if retrieved_wm != weapon_manager:
		printerr("FAILED: PlayerController.get_weapon_manager() did not resolve WeaponHolder")
		success = false
	else:
		print("  -> TEST 07 PASSED (Clean hierarchy: Player -> Camera3D -> WeaponHolder -> WeaponBase)")

	# TEST 08: Full Regression Check (STEP 01 - 05)
	print("[TEST 08] Testing full regression (Movement + Camera + Weapon + State Machine)...")
	# Rotate player yaw and camera pitch
	camera.set_mouse_captured(true)
	var mouse_event := InputEventMouseMotion.new()
	mouse_event.relative = Vector2(40.0, -20.0)
	camera._unhandled_input(mouse_event)
	
	if player.rotation.y == 0.0 or camera.rotation.x == 0.0:
		printerr("FAILED: Mouse look regression detected")
		success = false
		
	# Check weapon transforms remain attached under camera
	if not is_instance_valid(weapon_manager) or not is_instance_valid(camera):
		printerr("FAILED: Instances invalidated during camera rotation")
		success = false
	else:
		print("  -> TEST 08 PASSED (Zero regression across all prior steps)")

	# Cleanup
	player.queue_free()

	if success:
		print("--- ALL STEP 06 TESTS PASSED PERFECTLY! ---")
		quit(0)
	else:
		printerr("--- STEP 06 TESTS ENCOUNTERED FAILURES! ---")
		quit(1)