extends Node
## Isolated rendering, capture, and 22-second three-view performance run.

const PROTOTYPE_SCENE := "res://scenes/prototypes/Stage08_AlpineHybridPrototype.tscn"
const OUTPUT_DIR := "res://verification_screenshots/stage08_alpine_hybrid"
const CAPTURE_NAMES := ["01_valley_approach.png", "02_ridge_panorama.png", "03_valley_floor.png"]
const CAMERA_NAMES := ["ValleyApproach", "RidgePanorama", "ValleyFloor"]
const SAMPLE_WINDOW_SECONDS := 7.5
const RENDER_SIZE := Vector2i(1600, 900)
var _render_viewport: SubViewport

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_render_viewport = SubViewport.new()
	_render_viewport.size = RENDER_SIZE
	_render_viewport.own_world_3d = true
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_render_viewport)
	var packed := load(PROTOTYPE_SCENE) as PackedScene
	assert(packed != null, "Hybrid prototype scene did not load.")
	var stage := packed.instantiate() as Node3D
	assert(stage != null, "Hybrid prototype did not instantiate as Node3D.")
	_render_viewport.add_child(stage)
	print("[RUN] Godot %s | %s | %s" % [Engine.get_version_info().string, OS.get_name(), RenderingServer.get_video_adapter_name()])
	print("[RUN] Offscreen 3D render resolution: %s | target 60 FPS (16.67 ms)" % RENDER_SIZE)

	for _frame in 150:
		await get_tree().process_frame
	assert(stage.has_node("CaptureCameras"), "Prototype failed to finish building its cameras.")
	var cameras := stage.get_node("CaptureCameras")
	var metric_sets: Array[Dictionary] = []
	for view_index in range(CAMERA_NAMES.size()):
		var camera := cameras.get_node(CAMERA_NAMES[view_index]) as Camera3D
		camera.make_current()
		for _frame in 14:
			await get_tree().process_frame
		var image := _render_viewport.get_texture().get_image()
		assert(image != null, "Viewport returned no image; windowed rendering is required.")
		assert(image.get_size() == RENDER_SIZE, "Captured viewport size %s did not match requested %s." % [image.get_size(), RENDER_SIZE])
		var image_path: String = OUTPUT_DIR + "/" + str(CAPTURE_NAMES[view_index])
		assert(image.save_png(image_path) == OK, "Could not save screenshot: " + image_path)
		print("[CAPTURE] %s (%dx%d)" % [image_path, image.get_width(), image.get_height()])
		metric_sets.append(await _sample_view(CAMERA_NAMES[view_index], SAMPLE_WINDOW_SECONDS))

	var report := _format_report(metric_sets)
	print(report)
	var log_file := FileAccess.open(OUTPUT_DIR + "/stage08_alpine_hybrid_run.log", FileAccess.WRITE)
	assert(log_file != null, "Could not write performance log.")
	log_file.store_string(report + "\n")
	log_file.close()
	print("[RUN] Wrote %s/stage08_alpine_hybrid_run.log" % OUTPUT_DIR)
	stage.queue_free()
	get_tree().quit(0)

func _sample_view(view_name: String, seconds: float) -> Dictionary:
	var frame_wall := []
	var game_cpu := []
	var render_cpu := []
	var render_gpu := []
	var static_mem_peak := 0.0
	var video_mem_peak := 0.0
	var texture_mem_peak := 0.0
	var viewport_rid := _render_viewport.get_viewport_rid()
	var started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started) / 1000000.0 < seconds:
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_wall.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
		game_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		static_mem_peak = maxf(static_mem_peak, Performance.get_monitor(Performance.MEMORY_STATIC))
		video_mem_peak = maxf(video_mem_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		texture_mem_peak = maxf(texture_mem_peak, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	return {
		"name": view_name,
		"seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
		"frames": frame_wall.size(),
		"wall": _statistics(frame_wall),
		"game_cpu": _statistics(game_cpu),
		"render_cpu": _statistics(render_cpu),
		"render_gpu": _statistics(render_gpu),
		"wall_samples": frame_wall,
		"game_cpu_samples": game_cpu,
		"render_cpu_samples": render_cpu,
		"render_gpu_samples": render_gpu,
		"static_mem_peak": static_mem_peak,
		"video_mem_peak": video_mem_peak,
		"texture_mem_peak": texture_mem_peak
	}

func _statistics(samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"avg": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += float(sample)
	var p95_index := clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)
	return {"avg": total / float(sorted.size()), "p95": float(sorted[p95_index]), "max": float(sorted[-1])}

func _format_report(metric_sets: Array[Dictionary]) -> String:
	var total_seconds := 0.0
	var total_frames := 0
	var all_wall := []
	var all_game_cpu := []
	var all_render_cpu := []
	var all_render_gpu := []
	var static_mem_peak := 0.0
	var video_mem_peak := 0.0
	var texture_mem_peak := 0.0
	var lines := PackedStringArray()
	lines.append("Stage 08 Alpine Hybrid Prototype — performance report")
	lines.append("Godot %s | %s | GPU: %s | offscreen render: %s" % [Engine.get_version_info().string, OS.get_name(), RenderingServer.get_video_adapter_name(), RENDER_SIZE])
	lines.append("FPS target: 60 (16.67 ms); target status is not assumed.")
	for item in metric_sets:
		total_seconds += item.seconds
		total_frames += item.frames
		static_mem_peak = maxf(static_mem_peak, item.static_mem_peak)
		video_mem_peak = maxf(video_mem_peak, item.video_mem_peak)
		texture_mem_peak = maxf(texture_mem_peak, item.texture_mem_peak)
		lines.append("%s: %.2f s, %d frames | total frame ms avg/p95/max %s | game-loop CPU ms avg/p95/max %s | render CPU ms avg/p95/max %s | GPU ms avg/p95/max %s" % [item.name, item.seconds, item.frames, _stats_string(item.wall), _stats_string(item.game_cpu), _stats_string(item.render_cpu), _stats_string(item.render_gpu)])
		all_wall.append_array(item.wall_samples)
		all_game_cpu.append_array(item.game_cpu_samples)
		all_render_cpu.append_array(item.render_cpu_samples)
		all_render_gpu.append_array(item.render_gpu_samples)
	lines.append("Measured duration: %.2f s, %d rendered frames." % [total_seconds, total_frames])
	lines.append("All-view frame ms avg/p95/max: %s | game-loop CPU: %s ms | render CPU: %s ms | GPU: %s ms" % [_stats_string(_statistics(all_wall)), _stats_string(_statistics(all_game_cpu)), _stats_string(_statistics(all_render_cpu)), _stats_string(_statistics(all_render_gpu))])
	lines.append("Memory peak: Godot static %.1f MiB | video %.1f MiB | textures %.1f MiB" % [static_mem_peak / 1048576.0, video_mem_peak / 1048576.0, texture_mem_peak / 1048576.0])
	lines.append("Note: 0 ms GPU/video values mean the driver did not expose a sample; static memory is Godot-tracked memory, not OS working set.")
	lines.append("Performance target is met only if measured p95 total-frame time is <=16.67 ms in the release-like build on the target machine.")
	return "\n".join(lines)

func _stats_string(stats: Dictionary) -> String:
	return "%.2f / %.2f / %.2f" % [stats.avg, stats.p95, stats.max]
