@tool
extends SceneTree

func _init() -> void:
	print("[IconExtractor] Starting extraction of Stage 08 UI graphics...")
	
	# 1. Extract Skull Emblem from 05_mission_success.png
	var img_success := Image.load_from_file("res://art_reference/stage08/05_mission_success.png")
	if img_success:
		# Image size is around 648x576 or similar. Let's find coordinates.
		var w := img_success.get_width()
		var h := img_success.get_height()
		print("[IconExtractor] 05_mission_success size: %d x %d" % [w, h])
		# 05_mission_success emblem (skull in brackets)
		var emblem_w := 64
		var emblem_h := 46
		var emblem_x := int((w - emblem_w) * 0.5)
		var emblem_y := int(h * 0.138)
		var rect := Rect2i(emblem_x, emblem_y, emblem_w, emblem_h)
		var emblem_img := img_success.get_region(rect)
		emblem_img.save_png("res://assets/ui/stage08_whiteout/success_emblem.png")
		print("[IconExtractor] Saved clean success_emblem.png (%d x %d)" % [emblem_w, emblem_h])

	# 2. Extract Red Emblem from 06_mission_failed.png
	var img_failed := Image.load_from_file("res://art_reference/stage08/06_mission_failed.png")
	if img_failed:
		var w := img_failed.get_width()
		var h := img_failed.get_height()
		print("[IconExtractor] 06_mission_failed size: %d x %d" % [w, h])
		var emblem_w := 54
		var emblem_h := 36
		var emblem_x := int((w - emblem_w) * 0.5)
		var emblem_y := int(h * 0.185)
		var rect := Rect2i(emblem_x, emblem_y, emblem_w, emblem_h)
		var emblem_img := img_failed.get_region(rect)
		emblem_img.save_png("res://assets/ui/stage08_whiteout/failed_emblem.png")
		print("[IconExtractor] Saved clean failed_emblem.png (%d x %d)" % [emblem_w, emblem_h])


	# 3. Extract Minimap circle from 03_gameplay_hud.png
	var img_hud := Image.load_from_file("res://art_reference/stage08/03_gameplay_hud.png")
	if img_hud:
		var w := img_hud.get_width()
		var h := img_hud.get_height()
		print("[IconExtractor] 03_gameplay_hud size: %d x %d" % [w, h])
		# Minimap is bottom left
		var radar_w := int(w * 0.22)
		var radar_h := int(h * 0.25)
		var radar_x := int(w * 0.05)
		var radar_y := int(h * 0.72)
		var rect := Rect2i(radar_x, radar_y, radar_w, radar_h)
		var radar_img := img_hud.get_region(rect)
		radar_img.save_png("res://assets/ui/stage08_whiteout/radar_minimap.png")
		print("[IconExtractor] Saved radar_minimap.png (%d x %d)" % [radar_w, radar_h])

	print("[IconExtractor] Finished successfully.")
	quit(0)
