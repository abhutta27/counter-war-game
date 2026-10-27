extends SceneTree

const STAGE_SCENE := preload("res://scenes/stages/Stage01.tscn")
const PROJECTILE_BURST := 120
const IMPACT_BURST := 60

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage = STAGE_SCENE.instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.set_process(false)
	stage.set_physics_process(false)
	for enemy in stage.enemies_container.get_children():
		enemy.set_process(false)
		enemy.set_physics_process(false)
	await process_frame

	var shooting_system = root.get_node("ShootingSystem")
	shooting_system.clear_all()
	await process_frame
	var started_usec := Time.get_ticks_usec()
	var projectiles: Array[Node3D] = []
	for index in PROJECTILE_BURST:
		var z := float(index % 12) * 0.15
		var projectile = shooting_system.spawn_projectile(
			Vector3(-20.0, 100.0, z),
			Vector3(20.0, 100.0, z),
			false,
			Callable(),
			55.0,
			true
		)
		projectiles.append(projectile)
	var spawn_usec := Time.get_ticks_usec() - started_usec

	var core_material_rids := {}
	var trail_material_rids := {}
	for projectile in projectiles:
		assert(projectile.path_prevalidated, "Enemy tracer must skip redundant per-frame raycasts")
		core_material_rids[projectile.mesh_instance.material_override.get_rid()] = true
		trail_material_rids[projectile.trail_mesh.material_override.get_rid()] = true
	assert(core_material_rids.size() == 1, "Enemy projectile core material must be shared")
	assert(trail_material_rids.size() == 1, "Enemy projectile trail material must be shared")

	var impacts: Array[Node3D] = []
	for index in IMPACT_BURST:
		impacts.append(shooting_system.spawn_impact_effect(Vector3(float(index), 100.0, 0.0), Vector3.UP, false))
	var impact_material_rids := {}
	for impact in impacts:
		impact_material_rids[impact.spark_mesh_1.material_override.get_rid()] = true
	assert(impact_material_rids.size() == 1, "Enemy impact material must be shared")

	print("[CombatFXPerformance] PASS: %d prevalidated tracers, %d impacts, 3 shared materials, spawn=%.3fms" % [
		PROJECTILE_BURST,
		IMPACT_BURST,
		float(spawn_usec) / 1000.0,
	])
	quit(0)
