extends SceneTree

const STAGE_SCENE:=preload("res://scenes/stages/Stage05.tscn")

func _init()->void:
	call_deferred("_run")

func _new_stage(freeze_for_traversal:=false):
	if current_scene:
		current_scene.queue_free()
		await process_frame
	var stage=STAGE_SCENE.instantiate()
	root.add_child(stage);current_scene=stage
	if freeze_for_traversal:
		stage.set_physics_process(false)
		for enemy in stage.enemies_container.get_children():enemy.set_physics_process(false)
	for _frame in 24:await physics_frame
	stage.player.max_health=50000;stage.player.current_health=50000
	for enemy in stage.enemies_container.get_children():enemy.attack_damage=0
	return stage

func _run()->void:
	var stage=await _new_stage()
	var enemies:Array[Node]=stage.enemies_container.get_children()
	assert(enemies.size()==14 and stage.total_targets==14,"Stage05 must track exactly 14 enemies")
	assert(stage.hud.hostiles_counter_label.text=="HOSTILES: 14 / 14","HUD must start at 14 / 14")
	assert(stage.player.global_position.distance_to(Vector3(0,0,52))<.25,"Player must spawn at valley entry")
	# Exposed checkpoint guards get a fair mutual-visibility opportunity, while
	# later mountain groups remain isolated behind terrain and elevation.
	for _frame in 40:await physics_frame
	assert(stage.is_guard_active("Enemy3D_1") or stage.is_guard_active("Enemy3D_2"),"A clearly exposed checkpoint guard must promptly detect the Player")
	for guarded_name in ["Enemy3D_7","Enemy3D_8","Enemy3D_9","Enemy3D_12","Enemy3D_13","Enemy3D_14"]:
		assert(not stage.is_guard_active(guarded_name),"Spawn contact must not wake future group %s"%guarded_name)
	stage=await _new_stage(true)
	enemies=stage.enemies_container.get_children()

	# Every authored spawn is clear at body height and has terrain immediately below.
	var sphere:=SphereShape3D.new();sphere.radius=.32
	for enemy in enemies:
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,enemy.global_position+Vector3.UP*.95);query.collision_mask=1
		var overlaps:Array[Dictionary]=stage.get_world_3d().direct_space_state.intersect_shape(query,8)
		assert(overlaps.is_empty(),"%s must be outside static collision"%enemy.name)
		var ray:=PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP*1.5,enemy.global_position+Vector3.DOWN*.5,1)
		assert(not stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"%s must stand on supported terrain"%enemy.name)

	# Actual Player traversal: broad primary ramps, then the covered service ramp.
	for target in [Vector3(0,0,31),Vector3(0,4,9),Vector3(0,4,-2),Vector3(8,4,-13),Vector3(8,8,-35),Vector3(0,8,-49),Vector3(0,13,-69),Vector3(0,13,-82)]:
		await _walk_to(stage,target)
	assert(stage.player.global_position.y>12.5,"Primary route must produce a real 13m elevation gain")
	stage.player.global_position=Vector3(0,4,-10)
	for _frame in 10:await physics_frame
	for target in [Vector3(-12,4,-13),Vector3(-12,8,-35),Vector3(-7,8,-44)]:
		await _walk_to(stage,target)
	assert(stage.player.global_position.y>7.5,"Service tunnel route must climb and rejoin upper terrace")

	# Observer cannot see through the authored ridge, then confirms a clear route.
	stage=await _new_stage()
	var observer=stage.enemies_container.get_node("Enemy3D_6")
	var blocked_position:=Vector3(4,4,7)
	observer.look_at(blocked_position,Vector3.UP);stage.player.global_position=blocked_position
	for _frame in 45:await physics_frame
	assert(not stage.has_observer_relayed("Enemy3D_6"),"Lower observer must not see through RidgeOccluderLower")
	stage.player.global_position=Vector3(24,4,-7)
	observer.look_at(stage.player.global_position,Vector3.UP)
	for _frame in 35:await physics_frame
	assert(stage.has_observer_relayed("Enemy3D_6"),"Clear observer contact must trigger lower relay")
	for linked in ["Enemy3D_3","Enemy3D_4","Enemy3D_5"]:assert(stage.is_guard_active(linked),"Lower relay must activate %s"%linked)
	for unlinked in ["Enemy3D_8","Enemy3D_9","Enemy3D_12","Enemy3D_13","Enemy3D_14"]:assert(not stage.is_guard_active(unlinked),"Lower relay must not activate %s"%unlinked)

	# Counterplay: dead observer cannot relay its linked upper-road defenders.
	stage=await _new_stage()
	var upper_observer=stage.enemies_container.get_node("Enemy3D_7")
	upper_observer.take_damage(upper_observer.current_health)
	for _frame in 8:await physics_frame
	assert(upper_observer.is_dead and not stage.has_observer_relayed("Enemy3D_7"),"Eliminated observer cannot relay")
	assert(not stage.is_guard_active("Enemy3D_8") and not stage.is_guard_active("Enemy3D_9"),"Bypassed observer leaves linked group unaware")

	# A real lower-terrace shot affects only that elevation band.
	stage.player.global_position=Vector3(0,4,0)
	var weapon=stage.player.get_weapon_manager().get_current_weapon();var ammo_before:int=weapon.current_ammo
	stage.player._handle_fire_button(true);await physics_frame;stage.player._handle_fire_button(false)
	assert(weapon.current_ammo<ammo_before,"Gunfire test must use the real Player weapon")
	var lower_reaction:=false
	for name in ["Enemy3D_3","Enemy3D_4","Enemy3D_5","Enemy3D_6"]:
		lower_reaction=lower_reaction or stage.is_guard_alert(name) or stage.is_guard_active(name)
	assert(lower_reaction,"Lower terrace defenders must react to local gunfire")
	for name in ["Enemy3D_12","Enemy3D_13","Enemy3D_14"]:assert(not stage.is_guard_alert(name) and not stage.is_guard_active(name),"Summit must not hear lower gunfire")

	# Engage each terrain section and prove defenders stay on supported combat floors.
	var sections={"valley":{"names":["Enemy3D_1","Enemy3D_2"],"player":Vector3(0,0,35),"min_y":-.4},"lower":{"names":["Enemy3D_3","Enemy3D_4","Enemy3D_5","Enemy3D_6"],"player":Vector3(0,4,-3),"min_y":3.5},"upper":{"names":["Enemy3D_8","Enemy3D_9","Enemy3D_10","Enemy3D_11"],"player":Vector3(0,8,-42),"min_y":7.5},"summit":{"names":["Enemy3D_12","Enemy3D_13","Enemy3D_14"],"player":Vector3(0,13,-79),"min_y":12.5}}
	for section in sections.values():
		stage.player.global_position=section["player"]
		for name in section["names"]:stage.activate_guard(stage.enemies_container.get_node(name),"terrain validation",false)
		for _frame in 80:await physics_frame
		for name in section["names"]:
			var enemy=stage.enemies_container.get_node(name)
			assert(enemy.global_position.y>=section["min_y"],"%s must not fall from its combat terrace"%name)

	# Completion is counted only after defender 14, then NEXT MISSION reaches Stage06.
	enemies=stage.enemies_container.get_children()
	for i in range(enemies.size()):
		var enemy=enemies[i]
		if not enemy.is_dead:enemy.take_damage(enemy.current_health)
		await process_frame
		if i<13:assert(not stage.is_stage_finished,"Mission cannot finish before hostile 14")
	assert(stage.targets_eliminated==14 and stage.hud.hostiles_counter_label.text=="HOSTILES: 00 / 14","HUD must reach 00 / 14")
	assert(stage.is_stage_finished and stage.summary_dialog.visible,"Mission Complete must appear after all 14")
	var manager=root.get_node("StageManager");assert(manager.load_next_stage(),"NEXT MISSION must request Stage06")
	for _frame in 30:await process_frame
	assert(current_scene!=null and current_scene.name=="Stage06","Stage05 must advance to Stage06")
	print("[Stage05RelayRegression] PASS: opening, ascent, relay, counterplay, local gunfire, tunnel, 14/14, Stage06")
	quit(0)

func _walk_to(stage,target:Vector3)->void:
	var player=stage.player
	Input.action_press("move_forward")
	var reached:=false
	for _frame in 600:
		var flat_target:=Vector3(target.x,player.global_position.y,target.z)
		if player.global_position.distance_squared_to(flat_target)>.01:player.look_at(flat_target,Vector3.UP)
		await physics_frame
		var delta:Vector3=target-player.global_position;delta.y=0
		if delta.length()<1.0:reached=true;break
	Input.action_release("move_forward")
	assert(reached,"Player must traverse route segment to %s without jumping (stopped at %s)"%[target,player.global_position])

