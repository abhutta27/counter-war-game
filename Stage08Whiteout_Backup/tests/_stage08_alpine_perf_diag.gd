extends Node
## One-variant performance diagnostic for the isolated hybrid prototype.

const PROTOTYPE_SCENE := "res://scenes/prototypes/Stage08_AlpineHybridPrototype.tscn"
const OUTPUT_DIR := "res://verification_screenshots/stage08_alpine_hybrid"
const RENDER_SIZE := Vector2i(1600, 900)
const RUN_SECONDS := 22.0
var _viewport: SubViewport
var _texture_replacements := 0

func _init() -> void:
	print("[DIAG] diagnostic scene script initialized")
	call_deferred("_run")

func _run() -> void:
	var variant := "baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			variant = arg.trim_prefix("--variant=")
	print("[DIAG] requested variant: %s | user args: %s" % [variant, OS.get_cmdline_user_args()])
	if not ["baseline", "shadows", "vegetation", "textures"].has(variant):
		push_error("Unknown diagnostic variant: " + variant)
		get_tree().quit(2)
		return
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = RENDER_SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	var stage := (load(PROTOTYPE_SCENE) as PackedScene).instantiate() as Node3D
	_viewport.add_child(stage)
	for _frame in 150:
		await get_tree().process_frame
	print("[DIAG] scene loaded; applying variant %s" % variant)
	_apply_variant(stage, variant)
	print("[DIAG] variant setup completed: %s" % variant)
	for _frame in 30:
		await get_tree().process_frame
	var camera := stage.get_node("CaptureCameras/ValleyApproach") as Camera3D
	camera.make_current()
	var rid := _viewport.get_viewport_rid()
	print("[DIAG] variant=%s | Godot=%s | OS=%s | GPU=%s | renderer=%s | resolution=%s | duration=%.1fs" % [variant, Engine.get_version_info().string, OS.get_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method"), RENDER_SIZE, RUN_SECONDS])
	var frame_ms: Array[float] = []
	var game_cpu: Array[float] = []
	var render_cpu: Array[float] = []
	var render_gpu: Array[float] = []
	var static_mem := 0.0
	var video_mem := 0.0
	var tex_mem := 0.0
	var start := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - start) / 1000000.0 < RUN_SECONDS:
		var tick := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_ms.append(float(Time.get_ticks_usec() - tick) / 1000.0)
		game_cpu.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		static_mem = maxf(static_mem, float(Performance.get_monitor(Performance.MEMORY_STATIC)))
		video_mem = maxf(video_mem, float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		tex_mem = maxf(tex_mem, float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var report := "Stage 08 Alpine Hybrid Prototype — %s\n" % variant
	report += "Godot %s | %s | GPU %s | renderer %s | viewport %dx%d\n" % [Engine.get_version_info().string, OS.get_name(), RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method"), RENDER_SIZE.x, RENDER_SIZE.y]
	report += "Elapsed %.2fs | frames %d | frame ms avg/p95/max %s | average FPS %.2f\n" % [elapsed, frame_ms.size(), _stats(frame_ms), 1000.0 / _average(frame_ms)]
	report += "Godot process CPU ms avg/p95/max %s | render CPU ms avg/p95/max %s | render GPU ms avg/p95/max %s\n" % [_stats(game_cpu), _available_stats(render_cpu), _available_stats(render_gpu)]
	report += "Peak memory: Godot static %s | video %s | textures %s\n" % [_memory(static_mem), _memory(video_mem), _memory(tex_mem)]
	if variant == "textures":
		report += "Reduced texture resources applied: %d (max side 512 px)\n" % _texture_replacements
	report += "60 FPS target: %s (p95 must be <= 16.67 ms).\n" % ("met" if _percentile(frame_ms, 0.95) <= 16.67 else "not met")
	print(report)
	var f := FileAccess.open(OUTPUT_DIR + "/performance_" + variant + ".log", FileAccess.WRITE)
	f.store_string(report)
	f.close()
	get_tree().quit(0)

func _apply_variant(stage: Node3D, variant: String) -> void:
	if variant == "shadows":
		var sun := stage.get_node("AlpineSun") as DirectionalLight3D
		sun.shadow_enabled = false
	elif variant == "vegetation":
		for child in stage.get_children():
			if child.name.begins_with("fir_sapling_") or child.name.begins_with("pine_sapling_small_"):
				child.visible = false
	elif variant == "textures":
		for node in stage.find_children("*", "GeometryInstance3D", true, false):
			var geometry := node as GeometryInstance3D
			if geometry is MeshInstance3D and geometry.mesh != null:
				var mi := geometry as MeshInstance3D
				for surface in mi.mesh.get_surface_count():
					var material := mi.get_active_material(surface)
					if material is StandardMaterial3D:
						var reduced := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
						for prop in ["albedo_texture", "normal_texture", "orm_texture", "metallic_texture", "roughness_texture"]:
							var tex: Variant = reduced.get(prop)
							if tex is Texture2D:
								reduced.set(prop, _shrink(tex))
						mi.set_surface_override_material(surface, reduced)
					elif material is ShaderMaterial:
						var reduced_shader := (material as ShaderMaterial).duplicate() as ShaderMaterial
						for uniform in reduced_shader.shader.get_shader_uniform_list():
							var uniform_name: String = uniform.name
							var tex: Variant = reduced_shader.get_shader_parameter(uniform_name)
							if tex is Texture2D:
								reduced_shader.set_shader_parameter(uniform_name, _shrink(tex))
						mi.set_surface_override_material(surface, reduced_shader)

func _shrink(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var longest := maxi(image.get_width(), image.get_height())
	if longest <= 512:
		return texture
	_texture_replacements += 1
	var scale := 512.0 / float(longest)
	image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _stats(values: Array[float]) -> String:
	values.sort()
	var p95 := values[clampi(int(ceil(values.size() * 0.95)) - 1, 0, values.size() - 1)]
	return "%.2f/%.2f/%.2f" % [_average(values), p95, values[-1]]

func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())

func _available_stats(values: Array[float]) -> String:
	for value in values:
		if value > 0.0:
			return _stats(values)
	return "unavailable (timer returned zero)"

func _memory(bytes: float) -> String:
	if bytes <= 0.0:
		return "unavailable"
	return "%.1f MiB" % (bytes / 1048576.0)

func _percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(sorted.size() * fraction)) - 1, 0, sorted.size() - 1)
	return sorted[index]
