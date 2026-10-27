extends SceneTree

const GameConstants = preload("res://scripts/utilities/constants.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_tests()
	return true

func _run_tests() -> void:
	print("--- BEGIN STEPS 01-06 PLAYABLE INTEGRATION TEST ---")
	
	# Load Level1 scene
	var level_scene = load("res://scenes/Level1.tscn")
	if not level_scene:
		push_error("FAILED to load Level1.tscn")
		quit(1)
		return
		
	var level = level_scene.instantiate()
	root.add_child(level)
	
	# 1. Verify Game Manager state
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager singleton must exist")
	print("[TEST 01] Game State Verification...")
	assert(gm.current_state == GameConstants.GameState.PLAYING, "Game state must be PLAYING")
	print("  -> TEST 01 PASSED (State is PLAYING)")
	
	# 2. Verify Player3D
	print("[TEST 02] Player3D Controller Verification...")
	var player = level.get_node_or_null("Player3D")
	assert(player != null, "Player3D node must exist in Level1")
	assert(player is Player3D, "Player node must be an instance of Player3D")
	print("  -> TEST 02 PASSED (Player3D verified)")
	
	# 3. Verify Camera3D & PlayerCamera
	print("[TEST 03] Camera3D & PlayerCamera Verification...")
	var cam = player.get_node_or_null("Camera3D")
	assert(cam != null, "Camera3D must exist on player")
	assert(cam is Camera3D, "Camera3D is a Camera3D node")
	print("  -> TEST 03 PASSED (Camera3D attached)")
	
	# 4. Verify WeaponManager & Weapons
	print("[TEST 04] WeaponManager Integration Verification...")
	var wm = player.get_weapon_manager()
	assert(wm != null, "WeaponManager must exist on player")
	assert(wm.get_weapon_count() == 2, "WeaponManager must have 2 registered weapons")
	
	var active_w = wm.get_current_weapon()
	assert(active_w != null, "Active weapon must not be null")
	assert(active_w.data.weapon_id == "assault_rifle", "Initial equipped weapon must be assault_rifle")
	print("  -> TEST 04 PASSED (Assault Rifle equipped by default)")
	
	# 5. Verify Weapon Switching (Step 06)
	print("[TEST 05] Weapon Switching Verification (Assault Rifle <-> Pistol)...")
	var switched = wm.switch_next_weapon()
	assert(switched, "Switching to next weapon must succeed")
	var sec_w = wm.get_current_weapon()
	assert(sec_w.data.weapon_id == "pistol", "Switched weapon must be pistol")
	
	# Switch back
	switched = wm.switch_next_weapon()
	assert(switched, "Switching back to primary must succeed")
	assert(wm.get_current_weapon().data.weapon_id == "assault_rifle", "Primary must be active again")
	print("  -> TEST 05 PASSED (Weapon switching verified)")
	
	# 6. Verify Ammo & Firing Lifecycle (Step 06 - NO Step 07 Raycast)
	print("[TEST 06] Weapon Firing & Ammo Consumption (Step 06 Architecture)...")
	var initial_ammo = active_w.current_ammo
	var fired = active_w.fire()
	assert(fired, "Active weapon must be able to fire")
	assert(active_w.current_ammo == initial_ammo - 1, "Firing must consume 1 round")
	print("  -> TEST 06 PASSED (Ammo consumed cleanly, no Step 07 damage raycast)")
	
	# 7. Verify Movement State Integration (Step 04)
	print("[TEST 07] Movement State Machine Verification...")
	assert(player.get_movement_state() == GameConstants.MovementState.IDLE, "Player initial state should be IDLE")
	print("  -> TEST 07 PASSED (Player movement states functional)")
	
	# Clean up
	level.queue_free()
	print("--- ALL STEPS 01-06 PLAYABLE INTEGRATION TESTS PASSED PERFECTLY! ---")
	quit(0)
