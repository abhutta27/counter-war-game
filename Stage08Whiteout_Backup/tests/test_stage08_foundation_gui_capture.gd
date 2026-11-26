extends SceneTree
## Stage08WhiteoutFoundation GUI Capture Script

const SCENE_PATH := "res://scenes/stages/Stage08WhiteoutFoundation.tscn"
const OUT_PATH := "res://verification_screenshots/stage08_foundation_spawn_gui.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if not packed:
		printerr("Failed to load scene")
		quit(1)
		return

	var stage := packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	for _f in 30:
		await process_frame

	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img:
		var err := img.save_png(OUT_PATH)
		print("[GUI_CAPTURE] Saved spawn screenshot to ", OUT_PATH, " (status: ", err, ")")
	else:
		print("[GUI_CAPTURE] Texture image was null")

	quit(0)
