extends SceneTree
## test_step_07_firing_bug_fix.gd
## Targeted automated verification test for STEP 07 Firing Bug Fix.

const GameConstants = preload("res://scripts/utilities/constants.gd")

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_firing_tests()
	return true

func _run_firing_tests() -> void:
	print("=== BEGIN STEP 07 FIRING BUG FIX VERIFICATION ===")
	
	var level_res = load("res://scenes/Level1.tscn")
	assert(level_res != null, "Failed to load Level1.tscn")
	var level = level_res.instantiate()
	root.add_child(level)
	
	var player: Player3D = level.get_node_or_null("Player3D") as Player3D
	assert(player != null, "Player3D must exist in Level1")
	var wm = player.get_weapon_manager()
	assert(wm != null, "WeaponManager must exist")
	
	# -------------------------------------------------------------
	# TEST 1: Right Mouse Button NEVER fires
	# -------------------------------------------------------------
	print("\n[TEST 1] Testing Right Mouse Button does NOT fire...")
	var initial_ar_ammo = wm.get_current_weapon().current_ammo
	
	# Simulate Right Click Press
	var r_press = InputEventMouseButton.new()
	r_press.button_index = MOUSE_BUTTON_RIGHT
	r_press.pressed = true
	player._unhandled_input(r_press)
	
	assert(player.is_firing_held == false, "Right click must never set is_firing_held")
	assert(wm.get_current_weapon().current_ammo == initial_ar_ammo, "Right click must not consume ammo")
	
	# Simulate Right Click Release
	var r_release = InputEventMouseButton.new()
	r_release.button_index = MOUSE_BUTTON_RIGHT
	r_release.pressed = false
	player._unhandled_input(r_release)
	assert(wm.get_current_weapon().current_ammo == initial_ar_ammo, "Right click release must not fire")
	print("  -> TEST 1 PASSED: Right Mouse Button strictly blocked from firing!")
	
	# -------------------------------------------------------------
	# TEST 2: Semi-Automatic (Pistol) fires ONLY ONCE per click
	# -------------------------------------------------------------
	print("\n[TEST 2] Testing Semi-Automatic (Tactical Pistol) single-shot behavior...")
	# Switch to Pistol (index 1)
	wm.equip_weapon_by_index(1)
	var pistol = wm.get_current_weapon()
	assert(pistol.data.weapon_type == GameConstants.WeaponType.PISTOL, "Must be equipped with Pistol")
	assert(pistol.data.is_automatic == false, "Pistol must be marked is_automatic = false")
	assert(pistol.current_ammo == 15, "Pistol should have 15 rounds")
	
	# Click Left Mouse Button
	var l_press = InputEventMouseButton.new()
	l_press.button_index = MOUSE_BUTTON_LEFT
	l_press.pressed = true
	player._unhandled_input(l_press)
	
	# Must have fired exactly 1 shot
	assert(pistol.current_ammo == 14, "Pistol must fire exactly 1 shot on click (HP: 15 -> 14)")
	assert(player.is_firing_held == false, "Semi-automatic weapon must never keep is_firing_held = true")
	
	# Simulate holding down the mouse button over 10 consecutive physics ticks (0.5 seconds)
	for i in range(10):
		pistol._process(0.1)
		player._physics_process(0.05)
		
	# Ammo MUST still be 14! (NEVER endless firing loop)
	assert(pistol.current_ammo == 14, "Pistol must NOT continue firing while button is held! Remaining ammo: " + str(pistol.current_ammo))
	print("  -> TEST 2 PASSED: Pistol fired exactly 1 shot; holding button did NOT cause continuous fire!")
	
	# Second click should fire second shot
	var l_release = InputEventMouseButton.new()
	l_release.button_index = MOUSE_BUTTON_LEFT
	l_release.pressed = false
	player._unhandled_input(l_release)
	
	player._unhandled_input(l_press) # click again
	assert(pistol.current_ammo == 13, "Second click fires second shot (14 -> 13)")
	player._unhandled_input(l_release)
	print("  -> TEST 2.1 PASSED: Fresh click fires second shot correctly.")
	
	# -------------------------------------------------------------
	# TEST 3: Automatic (Assault Rifle) fires while held, stops on release
	# -------------------------------------------------------------
	print("\n[TEST 3] Testing Automatic (Assault Rifle) press-and-hold & release-stop...")
	# Switch back to Assault Rifle (index 0)
	wm.equip_weapon_by_index(0)
	var ar = wm.get_current_weapon()
	assert(ar.data.weapon_type == GameConstants.WeaponType.ASSAULT_RIFLE, "Must be equipped with Assault Rifle")
	assert(ar.data.is_automatic == true, "Assault Rifle must be marked is_automatic = true")
	var ar_start_ammo = ar.current_ammo
	
	# Press Left Mouse
	player._unhandled_input(l_press)
	assert(player.is_firing_held == true, "Automatic weapon press sets is_firing_held = true")
	assert(ar.current_ammo == ar_start_ammo - 1, "First round fired immediately on press")
	
	# Simulate automatic fire over multiple cooldown cycles while button held
	ar._process(0.15)
	assert(ar.can_shoot() == true, "Weapon must be ready to shoot again")
	player._try_fire_active_weapon()
	assert(ar.current_ammo == ar_start_ammo - 2, "Second round fired automatically")
	
	# Now simulate Left Mouse Button Release
	player._unhandled_input(l_release)
	assert(player.is_firing_held == false, "Mouse release must set is_firing_held = false immediately")
	
	# Process multiple frames after release
	for i in range(5):
		ar._process(0.15)
		player._physics_process(0.05)
		
	# Ammo MUST remain at ar_start_ammo - 2!
	assert(ar.current_ammo == ar_start_ammo - 2, "Assault Rifle MUST stop firing immediately upon release! Ammo remained: " + str(ar.current_ammo))
	print("  -> TEST 3 PASSED: Automatic weapon fires when held, stops immediately upon release!")
	
	# -------------------------------------------------------------
	# TEST 3.1: Automatic (Assault Rifle) Single Tap = Exactly 1 Shot
	# -------------------------------------------------------------
	print("\n[TEST 3.1] Testing Automatic (Assault Rifle) quick single tap behavior...")
	var tap_start_ammo = ar.current_ammo
	# Fast tap: press then release immediately
	player._unhandled_input(l_press)
	player._unhandled_input(l_release)
	assert(ar.current_ammo == tap_start_ammo - 1, "Quick tap must fire exactly 1 round")
	assert(player.is_firing_held == false, "Release immediately clears is_firing_held")
	
	# Simulate 20 subsequent physics frames
	for i in range(20):
		ar._process(0.05)
		player._physics_process(0.05)
		
	assert(ar.current_ammo == tap_start_ammo - 1, "Quick tap MUST NOT cause continuous firing! Ammo remained: " + str(ar.current_ammo))
	print("  -> TEST 3.1 PASSED: Fast tap produces exactly 1 round and stops completely!")
	
	# -------------------------------------------------------------
	# TEST 4: Weapon Switch resets firing state
	# -------------------------------------------------------------
	print("\n[TEST 4] Testing Weapon Switch resets firing state...")
	player.is_firing_held = true
	wm.switch_next_weapon()
	assert(player.is_firing_held == false, "Switching weapons must reset is_firing_held to false")
	print("  -> TEST 4 PASSED: Weapon switch resets firing state!")
	
	# -------------------------------------------------------------
	# TEST 5: Player Death resets firing state
	# -------------------------------------------------------------
	print("\n[TEST 5] Testing Player Death resets firing state...")
	player.is_firing_held = true
	player._on_player_death()
	assert(player.is_firing_held == false, "Player death must reset is_firing_held to false")
	print("  -> TEST 5 PASSED: Player death resets firing state!")
	
	level.queue_free()
	print("\n=== ALL STEP 07 FIRING BUG FIX TESTS PASSED WITH 100% SUCCESS! ===")
	quit(0)
