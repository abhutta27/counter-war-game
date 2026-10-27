extends SceneTree

func _init() -> void:
	var scene = load("res://assets/characters/Soldier.glb")
	var inst = scene.instantiate()
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	for anim_name in ap.get_animation_list():
		var anim: Animation = ap.get_animation(anim_name)
		print("Anim: ", anim_name, " length: ", anim.length, " loop: ", anim.loop_mode, " track_count: ", anim.get_track_count())
	inst.queue_free()
	quit(0)
