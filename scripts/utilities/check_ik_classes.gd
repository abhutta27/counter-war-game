extends SceneTree
## check_ik_classes.gd
func _init() -> void:
	print("Has SkeletonIK3D: ", ClassDB.class_exists("SkeletonIK3D"))
	print("Has SkeletonModifier3D: ", ClassDB.class_exists("SkeletonModifier3D"))
	print("Has SkeletonModificationStack3D: ", ClassDB.class_exists("SkeletonModificationStack3D"))
	quit()
