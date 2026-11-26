extends SceneTree
## Automated Verification Test for Stage 08:
## 1. Live Enemy Remaining Counter verification (Start, Decrement by 1, Decrement to 0, Zero duplicates)
## 2. Mountain environment validation & Gameplay Screenshot capture

const STAGE08_SCENE := "res://scenes/stages/Stage08.tscn"
const EVIDENCE_PNG := "res://verification_screenshots/stage08_whiteout_environment_and_enemy_counter.png"

func _init() -> void:
	print("================================================================")
	print(">>> STAGE 08 ENEMY COUNTER & UPGRADED MOUNTAIN ENVIRONMENT <<<")
	print("================================================================")
	call_deferred("_run_verification")

func _run_verification() -> void:
	for _f in range(5):
		await process_frame

	print("[TEST] Instantiating Stage08...")
	var packed := load(STAGE08_SCENE) as PackedScene
	assert(packed != null, "Failed to load Stage 08 scene.")
	var stage := packed.instantiate() as Stage08Whiteout
	assert(stage != null, "Failed to instantiate Stage08Whiteout.")
	root.add_child(stage)
	current_scene = stage

	# Allow 30 frames for _ready, procedural generation, and HUD setup
	for _f in range(30):
		await process_frame
		await physics_frame

	# -------------------------------------------------------------------------
	# 1. VERIFY ENEMY COUNTER AT MISSION START
	# -------------------------------------------------------------------------
	print("\n--- 1. VERIFYING ENEMY COUNTER AT MISSION START ---")
	var initial_live: int = stage.get_live_enemy_count()
	print("Initial live enemies counted: %d" % initial_live)
	assert(initial_live == 12, "Expected 12 live enemies at start, got: %d" % initial_live)

	var hud_node := stage.get_node_or_null("HUD") as CanvasLayer
	assert(hud_node != null, "HUD CanvasLayer missing in Stage08")
	var stage08_hud: Stage08HUD = hud_node.get_node_or_null("Stage08HUD") as Stage08HUD
	assert(stage08_hud != null, "Stage08HUD missing in HUD CanvasLayer")

	var counter_card: PanelContainer = stage08_hud.get_node_or_null("TopBar/EnemyCounterCard") as PanelContainer
	assert(counter_card != null and counter_card.visible, "TopBar/EnemyCounterCard must be present and visible")

	var counter_lbl: Label = stage08_hud.get_node_or_null("TopBar/EnemyCounterCard/Margin/HBox/CounterLabel") as Label
	assert(counter_lbl != null, "CounterLabel missing in EnemyCounterCard")
	print("Live HUD Counter Text at Start: '%s'" % counter_lbl.text)
	assert(counter_lbl.text == "ENEMIES REMAINING: 12", "Counter should display 'ENEMIES REMAINING: 12', got: '%s'" % counter_lbl.text)
	print("[PASS 1] Enemy counter correctly initialized with live enemy count (12).")

	# -------------------------------------------------------------------------
	# 2. ELIMINATE ONE ENEMY & VERIFY COUNTER DECREMENTS BY EXACTLY ONE
	# -------------------------------------------------------------------------
	print("\n--- 2. ELIMINATING 1 ENEMY & VERIFYING DECREMENT ---")
	var enemies_container := stage.get_node_or_null("Enemies") as Node3D
	assert(enemies_container != null, "Enemies container missing")
	var first_enemy = enemies_container.get_child(0)
	assert(first_enemy != null, "First enemy missing")

	# Simulate lethal hit
	print("Eliminating enemy: %s" % first_enemy.name)
	first_enemy.call("take_damage", 200)

	# Allow 10 frames for death signal and HUD update
	for _f in range(10):
		await process_frame
		await physics_frame

	var after_1_live: int = stage.get_live_enemy_count()
	print("Live enemies after 1 elimination: %d" % after_1_live)
	assert(after_1_live == 11, "Expected 11 live enemies, got: %d" % after_1_live)
	print("Live HUD Counter Text after 1 kill: '%s'" % counter_lbl.text)
	assert(counter_lbl.text == "ENEMIES REMAINING: 11", "Counter should display 'ENEMIES REMAINING: 11', got: '%s'" % counter_lbl.text)
	print("[PASS 2] Enemy counter decreased by exactly one immediately upon enemy death.")

	# -------------------------------------------------------------------------
	# 3. ELIMINATE ALL REMAINING ENEMIES & VERIFY ZERO REACHED CORRECTLY
	# -------------------------------------------------------------------------
	print("\n--- 3. ELIMINATING ALL REMAINING ENEMIES & VERIFYING ZERO ---")
	for i in range(1, enemies_container.get_child_count()):
		var enemy = enemies_container.get_child(i)
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			enemy.call("take_damage", 200)

	for _f in range(15):
		await process_frame
		await physics_frame

	var final_live: int = stage.get_live_enemy_count()
	print("Live enemies after eliminating all: %d" % final_live)
	assert(final_live == 0, "Expected 0 live enemies, got: %d" % final_live)
	print("Live HUD Counter Text at 0: '%s'" % counter_lbl.text)
	assert(counter_lbl.text == "ENEMIES REMAINING: 00", "Counter should display 'ENEMIES REMAINING: 00', got: '%s'" % counter_lbl.text)
	print("[PASS 3] Enemy counter successfully reached zero without duplicates.")

	# -------------------------------------------------------------------------
	# 4. VERIFY UPGRADED MOUNTAIN ENVIRONMENT & NATURAL PROPS
	# -------------------------------------------------------------------------
	print("\n--- 4. VERIFYING UPGRADED MOUNTAIN ENVIRONMENT & NATURAL PROPS ---")
	var env_node := stage.get_node_or_null("Environment") as Node3D
	assert(env_node != null, "Environment node missing")

	# Check 3D mountain ranges
	var r1 := env_node.get_node_or_null("DistantMountainRange_01") as MeshInstance3D
	var r2 := env_node.get_node_or_null("DistantMountainRange_02") as MeshInstance3D
	var r3 := env_node.get_node_or_null("DistantMountainRange_03") as MeshInstance3D
	assert(r1 != null and r1.mesh != null, "DistantMountainRange_01 missing or has null mesh")
	assert(r2 != null and r2.mesh != null, "DistantMountainRange_02 missing or has null mesh")
	assert(r3 != null and r3.mesh != null, "DistantMountainRange_03 missing or has null mesh")
	print("PASS: DistantMountainRange_01 (Backdrop), 02 (Mid-range Crest), and 03 (Horizon Massif) verified.")

	# Check NaturalProps (mountainside cliffs, boulders, conifers)
	var natural_props := env_node.get_node_or_null("NaturalProps") as Node3D
	assert(natural_props != null, "NaturalProps container missing under Environment")
	var prop_count := natural_props.get_child_count()
	print("Natural props instantiated: %d" % prop_count)
	assert(prop_count >= 20, "Expected at least 20 natural props (cliffs, boulders, conifers), found: %d" % prop_count)
	print("[PASS 4] Upgraded 3D mountain ranges and natural props verified.")

	# -------------------------------------------------------------------------
	# 5. CAPTURE REAL GAMEPLAY SCREENSHOT
	# -------------------------------------------------------------------------
	print("\n--- 5. CAPTURING GAMEPLAY EVIDENCE SCREENSHOT ---")
	# Reset stage to fresh state for clean screenshot
	stage.queue_free()
	for _f in range(5):
		await process_frame

	var fresh_stage := packed.instantiate() as Stage08Whiteout
	root.add_child(fresh_stage)
	current_scene = fresh_stage

	for _f in range(40):
		await process_frame
		await physics_frame

	var vp := root.get_viewport()
	if vp:
		var tex := vp.get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.save_png(EVIDENCE_PNG)
				print("[SCREENSHOT CAPTURED] %s" % EVIDENCE_PNG)

	print("\n================================================================")
	print(">>> ALL STAGE 08 ENEMY COUNTER & MOUNTAIN TESTS PASSED <<<")
	print("================================================================")
	quit(0)
