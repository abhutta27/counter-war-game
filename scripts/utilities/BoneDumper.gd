@tool
extends Node
## BoneDumper.gd — one-shot runtime diagnostic.
## Add as AutoLoad or child of any node in the scene tree.
## On _ready it finds the first Skeleton3D in the scene and prints
## every bone name + rest-pose rotation in degrees.

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_dump_all_skeletons()

func _dump_all_skeletons() -> void:
	var skels: Array = []
	_find_skeletons(get_tree().root, skels)
	if skels.is_empty():
		print("[BoneDumper] No Skeleton3D found in scene.")
		return
	for skel in skels:
		print("[BoneDumper] === Skeleton3D: %s ===" % skel.get_path())
		var bc := skel.get_bone_count()
		print("[BoneDumper] Total bones: %d" % bc)
		for i in bc:
			var name := skel.get_bone_name(i)
			var rest: Transform3D = skel.get_bone_rest(i)
			var euler_deg: Vector3 = rest.basis.get_euler() * (180.0 / PI)
			var pose_rot: Quaternion = skel.get_bone_pose_rotation(i)
			var pose_euler: Vector3 = Basis(pose_rot).get_euler() * (180.0 / PI)
			print("[BoneDumper]  [%02d] %-40s  rest_euler_deg=(%5.1f, %5.1f, %5.1f)  pose_euler_deg=(%5.1f, %5.1f, %5.1f)" % [
				i, name,
				euler_deg.x, euler_deg.y, euler_deg.z,
				pose_euler.x, pose_euler.y, pose_euler.z
			])
		# Also dump AnimationPlayer clips
		var ap: AnimationPlayer = skel.get_parent().find_child("AnimationPlayer", true, false) as AnimationPlayer
		if not ap:
			ap = skel.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			print("[BoneDumper] --- AnimationPlayer clips on %s ---" % ap.get_path())
			for lib_name in ap.get_animation_library_list():
				var lib: AnimationLibrary = ap.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					print("[BoneDumper]   clip: '%s/%s'" % [lib_name, anim_name])
		else:
			print("[BoneDumper] No AnimationPlayer found near skeleton.")

func _find_skeletons(node: Node, result: Array) -> void:
	if node is Skeleton3D:
		result.append(node)
	for child in node.get_children():
		_find_skeletons(child, result)
