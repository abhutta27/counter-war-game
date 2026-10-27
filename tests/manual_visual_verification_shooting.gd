extends SceneTree
## manual_visual_verification_shooting.gd
## Captures high-resolution gameplay visual verification screenshots of:
## 1. Player bullet in flight + tracer trail + muzzle flash (Stage 01 Desert)
## 2. Enemy counter-attack bullet flying toward player (Stage 01)
## 3. Tactical Pistol firing & tracer flight (Stage 01)
## 4. Impact spark burst on surface (Stage 01)
## 5. Stage 02 (Abandoned City) visible bullet flight
## 6. Stage 06 (Night Military Base) night emissive tracer flight

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")

func _init() -> void:
	call_deferred("_run_visual_capture")

func _run_visual_capture() -> void:
	print("\n=================================================================")
	print("  BEGIN VISIBLE SHOOTING GAMEPLAY SCREENSHOT VERIFICATION        ")
	print("=================================================================")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("verification_screenshots"):
		dir.make_dir("verification_screenshots")
		
	# --- SCENE 1: STAGE 01 DESERT OUTPOST (Player & Enemy Shooting) ---
	var stage01_scn = load("res://scenes/stages/Stage01.tscn")
	var stage01 = stage01_scn.instantiate()
	root.add_child(stage01)
	
	for i in range(15):
		await process_frame
		
	var player: Player3D = stage01.get_node("Player3D") as Player3D
	var enemy1: Enemy3D = stage01.get_node("Enemies/Enemy3D_1") as Enemy3D
	var shooting_sys = root.get_node("ShootingSystem")
	
	# Wait for intro directive banner to settle
	for i in range(120):
		await process_frame

	# 1. Capture Player Assault Rifle firing + Muzzle Flash + Bullet in Flight
	print("[SCREENSHOT 1] Capturing Player Assault Rifle firing & tracer flight...")
	player._try_fire_active_weapon()
	for f in range(3): # Let bullet fly ~3-4 meters into air
		await process_frame
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://verification_screenshots/shooting_01_player_bullet_flight.png")
	print("  -> Saved res://verification_screenshots/shooting_01_player_bullet_flight.png")

	# 2. Capture Enemy Bullet Flying toward Player
	print("[SCREENSHOT 2] Capturing Enemy counter-attack bullet flight...")
	enemy1._perform_counter_attack(player)
	for f in range(4): # Let enemy bullet fly halfway to player
		await process_frame
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://verification_screenshots/shooting_02_enemy_bullet_incoming.png")
	print("  -> Saved res://verification_screenshots/shooting_02_enemy_bullet_incoming.png")

	# 3. Capture Tactical Pistol Firing
	print("[SCREENSHOT 3] Capturing Tactical Pistol firing...")
	player.weapon_manager.equip_weapon_by_index(1)
	for f in range(5):
		await process_frame
	player._try_fire_active_weapon()
	for f in range(2):
		await process_frame
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://verification_screenshots/shooting_03_pistol_flight.png")
	print("  -> Saved res://verification_screenshots/shooting_03_pistol_flight.png")

	# 4. Capture Impact Sparks Effect
	print("[SCREENSHOT 4] Capturing Impact Sparks Effect...")
	var aim_target = player.global_position + (-player.camera_mount.global_transform.basis.z * 5.0)
	var impact = shooting_sys.spawn_impact_effect(aim_target, Vector3.UP, true)
	for f in range(3):
		await process_frame
	var img4 = root.get_viewport().get_texture().get_image()
	img4.save_png("res://verification_screenshots/shooting_04_impact_sparks.png")
	print("  -> Saved res://verification_screenshots/shooting_04_impact_sparks.png")
	
	stage01.queue_free()
	for f in range(5):
		await process_frame

	# --- SCENE 2: STAGE 02 ABANDONED CITY ---
	print("[SCREENSHOT 5] Capturing Stage 02 Abandoned City shooting...")
	var stage02_scn = load("res://scenes/stages/Stage02.tscn")
	var stage02 = stage02_scn.instantiate()
	root.add_child(stage02)
	for f in range(15):
		await process_frame
	var player2: Player3D = stage02.get_node("Player3D") as Player3D
	player2._try_fire_active_weapon()
	for f in range(3):
		await process_frame
	var img5 = root.get_viewport().get_texture().get_image()
	img5.save_png("res://verification_screenshots/shooting_05_stage_02_shooting.png")
	print("  -> Saved res://verification_screenshots/shooting_05_stage_02_shooting.png")
	
	stage02.queue_free()
	for f in range(5):
		await process_frame

	# --- SCENE 3: STAGE 06 NIGHT MILITARY BASE (Emissive Night Tracer) ---
	print("[SCREENSHOT 6] Capturing Stage 06 Night Military Base glowing tracer...")
	var stage06_scn = load("res://scenes/stages/Stage06.tscn")
	var stage06 = stage06_scn.instantiate()
	root.add_child(stage06)
	for f in range(15):
		await process_frame
	var player6: Player3D = stage06.get_node("Player3D") as Player3D
	player6._try_fire_active_weapon()
	for f in range(3):
		await process_frame
	var img6 = root.get_viewport().get_texture().get_image()
	img6.save_png("res://verification_screenshots/shooting_06_stage_06_night_tracer.png")
	print("  -> Saved res://verification_screenshots/shooting_06_stage_06_night_tracer.png")
	
	stage06.queue_free()
	for f in range(5):
		await process_frame

	print("\n=================================================================")
	print("  ALL 6 SHOOTING VISUAL SCREENSHOTS CAPTURED SUCCESSFULLY!       ")
	print("=================================================================")
	quit(0)
