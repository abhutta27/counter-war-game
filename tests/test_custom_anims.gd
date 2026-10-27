extends SceneTree

func _process(_delta: float) -> bool:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var lib: AnimationLibrary = ap.get_animation_library("")
	
	# Create HitReaction
	var hit_anim = Animation.new()
	hit_anim.length = 0.3
	var track_r = hit_anim.add_track(Animation.TYPE_VALUE)
	hit_anim.track_set_path(track_r, NodePath("Character:rotation_degrees"))
	hit_anim.track_insert_key(track_r, 0.0, Vector3.ZERO)
	hit_anim.track_insert_key(track_r, 0.08, Vector3(-12.0, 5.0, 0.0))
	hit_anim.track_insert_key(track_r, 0.3, Vector3.ZERO)
	
	var track_p = hit_anim.add_track(Animation.TYPE_VALUE)
	hit_anim.track_set_path(track_p, NodePath("Character:position"))
	hit_anim.track_insert_key(track_p, 0.0, Vector3.ZERO)
	hit_anim.track_insert_key(track_p, 0.08, Vector3(0.0, 0.0, 0.08))
	hit_anim.track_insert_key(track_p, 0.3, Vector3.ZERO)
	
	lib.add_animation("HitReaction", hit_anim)
	
	# Create Death
	var death_anim = Animation.new()
	death_anim.length = 1.0
	var d_rot = death_anim.add_track(Animation.TYPE_VALUE)
	death_anim.track_set_path(d_rot, NodePath("Character:rotation_degrees"))
	death_anim.track_insert_key(d_rot, 0.0, Vector3.ZERO)
	death_anim.track_insert_key(d_rot, 0.2, Vector3(-18.0, 8.0, -5.0))
	death_anim.track_insert_key(d_rot, 0.5, Vector3(-55.0, 15.0, -12.0))
	death_anim.track_insert_key(d_rot, 0.8, Vector3(-85.0, 10.0, -15.0))
	death_anim.track_insert_key(d_rot, 1.0, Vector3(-90.0, 10.0, -15.0))
	
	var d_pos = death_anim.add_track(Animation.TYPE_VALUE)
	death_anim.track_set_path(d_pos, NodePath("Character:position"))
	death_anim.track_insert_key(d_pos, 0.0, Vector3.ZERO)
	death_anim.track_insert_key(d_pos, 0.2, Vector3(0.0, -0.1, 0.1))
	death_anim.track_insert_key(d_pos, 0.5, Vector3(0.0, -0.45, 0.3))
	death_anim.track_insert_key(d_pos, 0.8, Vector3(0.0, -0.75, 0.5))
	death_anim.track_insert_key(d_pos, 1.0, Vector3(0.0, -0.85, 0.6))
	
	lib.add_animation("Death", death_anim)
	
	print("All animations in library: ", ap.get_animation_list())
	ap.play("Death")
	ap.advance(0.5)
	print("Death anim playing at 0.5s, Character rotation: ", inst.get_node("Character").rotation_degrees)
	inst.queue_free()
	quit(0)
	return true
