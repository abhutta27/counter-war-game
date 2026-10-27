extends SceneTree

const BRAND_DIR := "res://assets/branding"

func _init() -> void:
	call_deferred("_generate")

func _generate() -> void:
	var mark_svg := FileAccess.get_file_as_string(BRAND_DIR + "/cw_mark.svg")
	var small_mark_svg := FileAccess.get_file_as_string(BRAND_DIR + "/cw_mark_small.svg")
	var logo_svg := FileAccess.get_file_as_string(BRAND_DIR + "/counter_war_logo.svg")
	assert(not mark_svg.is_empty() and not small_mark_svg.is_empty() and not logo_svg.is_empty(), "Brand SVG masters must be readable")
	for size in [16, 32, 48, 64, 128, 256, 512, 1024]:
		var image := Image.new()
		var source := small_mark_svg if size <= 48 else mark_svg
		var err := image.load_svg_from_string(source, float(size) / 1024.0)
		assert(err == OK, "CW mark SVG must rasterize at %d px" % size)
		assert(image.save_png(BRAND_DIR + "/cw_mark_%d.png" % size) == OK)
	var logo := Image.new()
	assert(logo.load_svg_from_string(logo_svg, 1.0) == OK, "Full logo SVG must rasterize")
	assert(logo.save_png(BRAND_DIR + "/counter_war_logo.png") == OK)
	print("[BrandAssets] PASS: SVG masters rasterized at 16/32/48/64/128/256/512/1024 and full logo PNG")
	quit(0)
