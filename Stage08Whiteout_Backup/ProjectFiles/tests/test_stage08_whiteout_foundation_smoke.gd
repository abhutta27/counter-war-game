extends SceneTree
## Automated Smoke Test for Stage08WhiteoutFoundation
## Tests headless initialization, player physics/floor contact, weapon manager,
## firing & switching, tactical HUD, and player death/result flow.

const Stage08WhiteoutFoundation = preload("res://scripts/stages/Stage08WhiteoutFoundation.gd")
const FOUNDATION_SCENE_PATH := "res://scenes/stages/Stage08WhiteoutFoundation.tscn"

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==========================================================")
	print(" STAGE 08 WHITEOUT FOUNDATION — SMOKE & INTEGRATION SUITE ")
	print("==========================================================")

	var packed := ResourceLoader.load(FOUNDATION_SCENE_PATH) as PackedScene
	if not packed:
		_fail("Failed to load scene: %s" % FOUNDATION_SCENE_PATH)
		return
	print("[PASS] ResourceLoader loaded Stage08WhiteoutFoundation.tscn successfully.")

	var stage := packed.instantiate() as Stage08WhiteoutFoundation
	if not stage:
		_fail("Failed to instantiate Stage08WhiteoutFoundation.")
		return
	print("[PASS] Instantiated Stage08WhiteoutFoundation successfully.")

	root.add_child(stage)

	# 1. Check Scene Hierarchy & Node Types
	var player: Player3D = stage.get_node_or_null("Player3D") as Player3D
	var enemies: Node3D = stage.get_node_or_null("Enemies") as Node3D
	var hud: CanvasLayer = stage.get_node_or_null("HUD") as CanvasLayer
	var terrain: StaticBody3D = stage.get_node_or_null("Terrain") as StaticBody3D

	if not player:
		_fail("Player3D node not found or wrong type.")
		return
	print("[PASS] Player3D node found and typed correctly.")

	if not enemies:
		_fail("Enemies node not found.")
		return
	print("[PASS] Enemies node found.")

	if not hud:
		_fail("HUD node not found.")
		return
	print("[PASS] HUD node found (TacticalHUD).")

	if not terrain:
		_fail("Terrain node not found.")
		return
	print("[PASS] Terrain node found with collision.")

	var weapon_manager = player.get_node_or_null("Camera3D/WeaponRig") as WeaponManager
	if not weapon_manager:
		_fail("WeaponManager node not found in Player3D.")
		return
	print("[PASS] WeaponManager found in Player3D hierarchy.")

	var summary_dialog = hud.get_node_or_null("StageSummaryDialog")
	if not summary_dialog:
		_fail("StageSummaryDialog not found in HUD.")
		return
	print("[PASS] StageSummaryDialog found in HUD.")

	# 2. Process physics frames to let Player settle onto Terrain
	print("[TEST] Running physics frames to let Player settle onto Terrain...")
	for frame in 30:
		await process_frame

	print("[INFO] Player global_position after settle: %s" % str(player.global_position))
	print("[INFO] Player is_on_floor: %s" % str(player.is_on_floor()))

	if player.global_position.y < -2.0:
		_fail("Player fell below terrain! Y = %f" % player.global_position.y)
		return
	if not player.is_on_floor():
		_fail("Player is not on floor after 30 physics frames.")
		return
	print("[PASS] Player standing firmly on floor. Position: %s" % str(player.global_position))

	# 3. Test Movement via Input Action
	print("[TEST] Testing movement via Input action 'move_right'...")
	var initial_pos: Vector3 = player.global_position
	Input.action_press("move_right")
	for frame in 15:
		await process_frame
	Input.action_release("move_right")
	for frame in 5:
		await process_frame

	print("[INFO] Player position after move_right: %s" % str(player.global_position))
	if absf(player.global_position.x - initial_pos.x) < 0.05:
		_fail("Player did not move along X axis with move_right action.")
		return
	print("[PASS] Player movement verified. Delta X: %f" % (player.global_position.x - initial_pos.x))

	# 4. Test WeaponManager Initialization & Firing
	var cur_weapon = weapon_manager.get_current_weapon()
	if not cur_weapon or not cur_weapon.data:
		_fail("Current weapon not initialized.")
		return
	print("[PASS] Active weapon: %s (Type: %s, Ammo: %d/%d)" % [
		cur_weapon.data.weapon_name,
		cur_weapon.data.weapon_id,
		cur_weapon.current_ammo,
		cur_weapon.data.magazine_size
	])

	var initial_shots_fired: int = stage.shots_fired
	var initial_ammo: int = cur_weapon.current_ammo

	# Fire active weapon
	print("[TEST] Testing primary weapon fire...")
	player._handle_fire_button(true)
	player._handle_fire_button(false)

	for frame in 3:
		await process_frame

	if stage.shots_fired != initial_shots_fired + 1:
		_fail("LevelBase3D did not record shot_fired event. Expected %d, got %d" % [initial_shots_fired + 1, stage.shots_fired])
		return
	if cur_weapon.current_ammo != initial_ammo - 1:
		_fail("Weapon ammo did not decrement. Expected %d, got %d" % [initial_ammo - 1, cur_weapon.current_ammo])
		return
	print("[PASS] Primary weapon firing verified. Shots fired: %d, Ammo: %d" % [stage.shots_fired, cur_weapon.current_ammo])

	# 5. Test Weapon Switching
	print("[TEST] Testing weapon switching...")
	var switch_success := weapon_manager.switch_next_weapon()
	if not switch_success:
		_fail("Failed to switch weapon.")
		return
	var switched_weapon = weapon_manager.get_current_weapon()
	if not switched_weapon or switched_weapon == cur_weapon:
		_fail("Weapon switch did not change active weapon.")
		return
	print("[PASS] Switched to weapon: %s (%s)" % [switched_weapon.data.weapon_name, switched_weapon.data.weapon_id])

	# Switch back to rifle for consistency
	weapon_manager.switch_next_weapon()

	# 6. Test Player Death & Single Result Flow
	print("[TEST] Testing player death and result flow...")
	if stage.is_stage_finished:
		_fail("Stage was marked finished prematurely.")
		return

	var death_signals_count := [0]
	player.operative_died.connect(func(): death_signals_count[0] += 1)

	# Apply lethal damage
	player.take_damage(player.max_health + 50)

	for frame in 5:
		await process_frame

	if player.current_health > 0:
		_fail("Player survived lethal damage. Health: %d" % player.current_health)
		return
	if player.is_active:
		_fail("Player is_active is still true after death.")
		return
	if not stage.is_stage_finished:
		_fail("Stage is not marked finished after player death.")
		return
	if not summary_dialog.visible:
		_fail("StageSummaryDialog is not visible after player death.")
		return
	if death_signals_count[0] != 1:
		_fail("operative_died fired %d times (expected 1)." % death_signals_count[0])
		return
	print("[PASS] Player death flow verified: Health = 0, is_active = false, is_stage_finished = true, StageSummaryDialog.visible = true, signal count = 1.")

	print("==========================================================")
	print(" ALL STAGE 08 WHITEOUT FOUNDATION CHECKS PASSED (100%)    ")
	print("==========================================================")
	stage.queue_free()
	quit(0)

func _fail(reason: String) -> void:
	printerr("[FAIL] " + reason)
	print("[FAIL] " + reason)
	quit(1)
