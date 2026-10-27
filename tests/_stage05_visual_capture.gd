extends SceneTree

func _init()->void:call_deferred("_capture")

func _capture()->void:
	var stage=(load("res://scenes/stages/Stage05.tscn") as PackedScene).instantiate();root.add_child(stage);current_scene=stage
	for _frame in 20:await process_frame
	var player_camera:=stage.get_node("Player3D/Camera3D") as Camera3D;player_camera.current=true
	await _save("stage05_correction_valley_spawn.png")
	player_camera.current=false
	var camera:=Camera3D.new();camera.fov=75;stage.add_child(camera);camera.current=true
	await _from(camera,Vector3(0,2.0,52),Vector3(100,-20,110),"stage05_correction_valley_depth.png")
	await _from(camera,Vector3(0,2.0,28),Vector3(0,6,-14),"stage05_correction_lower_ascent.png")
	await _from(camera,Vector3(8,9.5,-33),Vector3(0,14,-76),"stage05_correction_upper_road.png")
	await _from(camera,Vector3(0,14.7,-64),Vector3(2,18,-84),"stage05_correction_summit_approach.png")
	await _from(camera,Vector3(82,58,70),Vector3(0,5,-25),"stage05_correction_panorama.png")
	quit(0)

func _from(camera:Camera3D,pos:Vector3,target:Vector3,file_name:String)->void:
	camera.look_at_from_position(pos,target,Vector3.UP)
	for _frame in 5:await process_frame
	await _save(file_name)

func _save(file_name:String)->void:
	for _frame in 3:await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://verification_screenshots/"+file_name)
