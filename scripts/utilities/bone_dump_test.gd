extends SceneTree
## bone_dump_test.gd — headless CLI runner.
## Run via: godot --headless --script scripts/utilities/bone_dump_test.gd
## Loads Soldier.glb, prints every bone name + rest rotation in degrees,
## then lists all AnimationPlayer clips.

func _init() -> void:
	# Must wait one frame for everything to be ready
	await process_frame

	var soldier_scene = load("res://assets/characters/Soldier.glb")
	if not soldier_scene:
		print("[BoneDump] ERROR: Could not load Soldier.glb")
		quit()
		return

	var soldier: Node3D = soldier_scene.instantiate() as Node3D
	if not soldier:
		print("[BoneDump] ERROR: Could not instantiate Soldier.glb")
		quit()
		return

	root.add_child(soldier)
	await process_frame

	# Find Skeleton3D
	var skel: Skeleton3D = _find_skeleton(soldier)
	if not skel:
		print("[BoneDump] ERROR: No Skeleton3D found in Soldier.glb")
		quit()
		return

	print("")
	print("=============================================================")
	print("  SOLDIER.GLB BONE DUMP")
	print("=============================================================")
	print("  Total bones: %d" % skel.get_bone_count())
	print("")
	for i in skel.get_bone_count():
		var bname := skel.get_bone_name(i)
		var parent_idx := skel.get_bone_parent(i)
		var parent_name := skel.get_bone_name(parent_idx) if parent_idx >= 0 else "ROOT"
		var rest: Transform3D = skel.get_bone_rest(i)
		var euler: Vector3 = rest.basis.get_euler(EULER_ORDER_XYZ) * (180.0 / PI)
		print("  [%02d] parent=%-30s  name=%-40s  rest_euler_XYZ_deg=(%6.1f, %6.1f, %6.1f)" % [
			i, parent_name, bname, euler.x, euler.y, euler.z
		])

	print("")
	print("=============================================================")
	print("  ANIMATION CLIPS")
	print("=============================================================")
	# AnimationPlayer can be found directly or via the root
	var ap: AnimationPlayer = _find_anim_player(soldier)
	if ap:
		print("  AnimationPlayer found: %s" % ap.get_path())
		for lib_name in ap.get_animation_library_list():
			var lib: AnimationLibrary = ap.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				var anim: Animation = lib.get_animation(anim_name)
				print("  clip '%s/%s'  length=%.2fs  tracks=%d" % [
					lib_name, anim_name, anim.length, anim.get_track_count()
				])
	else:
		print("  No AnimationPlayer found.")

	print("")
	print("=============================================================")
	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null
