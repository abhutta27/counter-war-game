extends "res://scripts/LevelBase3D.gd"
## Stage 07 — OPERATION IRON HARBOR
## Expansive coastal military cargo port environment, atmospheric night lighting,
## tactical navigation corridors, and an introductory cinematic sequence.

var _materials: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}
var _cyl_shape_cache: Dictionary = {}

# Cinematic State
@export var cinematic_enabled: bool = true
var is_cinematic_playing: bool = false
var cinematic_elapsed: float = 0.0
const CINEMATIC_DURATION: float = 4.5

var _cinematic_camera: Camera3D = null
var _cinematic_overlay: CanvasLayer = null

# Cinematic Keyframes (Camera position & look-at target)
var _cam_p0 := Vector3(36.0, 28.0, -66.0)
var _cam_t0 := Vector3(-10.0, 6.0, 4.0)

var _cam_p1 := Vector3(18.0, 16.0, -18.0)
var _cam_t1 := Vector3(-18.0, 4.0, 15.0)

var _cam_p2 := Vector3(0.0, 3.2, 53.0)
var _cam_t2 := Vector3(0.0, 1.8, 25.0)

# Guard Combat and Awareness
const POLL_RATE := 0.12
const VISION_RANGE := 22.0
const VISION_HALF_FOV := 68.0
const CLOSE_RANGE := 7.0
const GUNSHOT_HEARING_RANGE := 30.0

const GUARD_DATA := {
	"Enemy3D_1": {"role": "outer gate patrol", "zone": "entrance"},
	"Enemy3D_2": {"role": "checkpoint sandbag guard", "zone": "entrance"},
	"Enemy3D_3": {"role": "central highway scout", "zone": "entrance"},
	"Enemy3D_4": {"role": "yard alpha entrance sentry", "zone": "yard"},
	"Enemy3D_5": {"role": "yard alpha freight alley defender", "zone": "yard"},
	"Enemy3D_6": {"role": "warehouse loading dock guard", "zone": "yard"},
	"Enemy3D_7": {"role": "yard bravo forklift security", "zone": "yard"},
	"Enemy3D_8": {"role": "watchtower perimeter guard", "zone": "yard"},
	"Enemy3D_9": {"role": "command compound apron guard", "zone": "command"},
	"Enemy3D_10": {"role": "command west blast barrier guard", "zone": "command"},
	"Enemy3D_11": {"role": "bunker blast door sentinel", "zone": "command"},
	"Enemy3D_12": {"role": "quayside transit patrol", "zone": "command"},
}

const GUARD_LOOK_TARGETS := {
	"Enemy3D_1": Vector3(-6.0, 0.0, 60.0),
	"Enemy3D_2": Vector3(8.0, 0.0, 60.0),
	"Enemy3D_3": Vector3(-1.0, 0.0, 60.0),
	"Enemy3D_4": Vector3(0.0, 0.0, 28.0),
	"Enemy3D_5": Vector3(-22.0, 0.0, 30.0),
	"Enemy3D_6": Vector3(-26.0, 0.0, 20.0),
	"Enemy3D_7": Vector3(10.0, 0.0, 24.0),
	"Enemy3D_8": Vector3(20.0, 0.0, 18.0),
	"Enemy3D_9": Vector3(34.0, 0.0, 0.0),
	"Enemy3D_10": Vector3(22.0, 0.0, 0.0),
	"Enemy3D_11": Vector3(34.0, 0.0, -10.0),
	"Enemy3D_12": Vector3(10.0, 0.0, -10.0),
}

var guard_active: Dictionary = {}
var _poll_time: float = 0.0

# Objective & Mission State
var is_alarm_disabled: bool = false
var is_data_retrieved: bool = false
var _extraction_completed: bool = false

const INTERACTION_RADIUS := 3.5
const alarm_console_position := Vector3(38.0, 0.0, 25.0)
const data_terminal_position := Vector3(30.0, 0.0, -21.5)
const lz_charlie_position := Vector3(-36.0, 0.15, -48.0)

var _alarm_status_mesh: Node3D = null
var _alarm_label_3d: Label3D = null
var _alarm_audio_player: AudioStreamPlayer3D = null
var _cached_alarm_stream: AudioStream = null

const ALARM_SIREN_CUSTOM_PATHS: Array[String] = [
	"res://assets/audio/siren/alarm_siren.wav",
	"res://assets/audio/siren/alarm_siren.ogg",
	"res://assets/audio/siren/alarm_siren.mp3",
	"res://assets/audio/alarm/alarm_siren.wav",
	"res://assets/audio/alarm/alarm_siren.ogg",
	"res://assets/audio/alarm/alarm_siren.mp3",
]

var _terminal_status_mesh: Node3D = null
var _terminal_label_3d: Label3D = null
var _lz_label_3d: Label3D = null
var _interaction_prompt_label: Label = null


func _ready() -> void:
	_create_materials()
	_build_harbor()
	_freeze_guards()
	super._ready()
	if player and not player.shot_fired.is_connected(_on_player_gunshot_alert):
		player.shot_fired.connect(_on_player_gunshot_alert)

	_setup_interaction_hud()
	_update_objective_hud()

	_cinematic_camera = get_node_or_null("CinematicCamera") as Camera3D
	if cinematic_enabled and _cinematic_camera:
		start_cinematic()
	else:
		if player and is_instance_valid(player):
			player.is_active = true
			if "camera" in player and player.camera:
				player.camera.make_current()
		_start_alarm_audio()

	var count := enemies_container.get_child_count() if enemies_container else 0
	print("[Stage07IronHarbor] Operation Iron Harbor ready with %d tactical guards." % count)


func _process(delta: float) -> void:
	super._process(delta)
	if is_cinematic_playing:
		_update_cinematic(delta)
	else:
		_update_interaction_prompts()


func _physics_process(delta: float) -> void:
	if is_cinematic_playing or is_stage_finished or not player or not is_instance_valid(player):
		return
	_poll_time -= delta
	if _poll_time <= 0.0:
		_poll_time = POLL_RATE
		_poll_guard_contacts()


func _unhandled_input(event: InputEvent) -> void:
	if is_cinematic_playing:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			skip_cinematic()
			get_viewport().set_input_as_handled()
		return

	var is_interact_key := false
	if event is InputEventKey and event.pressed and not event.echo:
		is_interact_key = (event.physical_keycode == KEY_E)
	if event.is_action_pressed("interact") or is_interact_key:
		if _try_player_interaction():
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
# INTRO CINEMATIC SYSTEM
# ------------------------------------------------------------------------------

func start_cinematic() -> void:
	if not _cinematic_camera:
		return
	is_cinematic_playing = true
	cinematic_elapsed = 0.0

	if hud:
		hud.visible = false

	if player and is_instance_valid(player):
		player.is_active = false
		player.visible = false
		var p_hud := player.get_node_or_null("PlayerHUD") as CanvasLayer
		if p_hud:
			p_hud.visible = false

	_cinematic_camera.make_current()
	_cinematic_camera.global_position = _cam_p0
	_cinematic_camera.look_at(_cam_t0, Vector3.UP)

	_create_cinematic_overlay()


func _update_cinematic(delta: float) -> void:
	cinematic_elapsed += delta
	var progress := clampf(cinematic_elapsed / CINEMATIC_DURATION, 0.0, 1.0)
	# Smooth S-curve easing
	var t := progress * progress * (3.0 - 2.0 * progress)

	var cur_pos: Vector3
	var cur_target: Vector3
	if t < 0.5:
		var seg_t := t * 2.0
		cur_pos = _cam_p0.lerp(_cam_p1, seg_t)
		cur_target = _cam_t0.lerp(_cam_t1, seg_t)
	else:
		var seg_t := (t - 0.5) * 2.0
		cur_pos = _cam_p1.lerp(_cam_p2, seg_t)
		cur_target = _cam_t1.lerp(_cam_t2, seg_t)

	if _cinematic_camera:
		_cinematic_camera.global_position = cur_pos
		_cinematic_camera.look_at(cur_target, Vector3.UP)

	if cinematic_elapsed >= CINEMATIC_DURATION:
		end_cinematic()


func skip_cinematic() -> void:
	if not is_cinematic_playing:
		return
	print("[Stage07IronHarbor] Cinematic skipped by user.")
	end_cinematic()


func end_cinematic() -> void:
	is_cinematic_playing = false
	if _cinematic_overlay and is_instance_valid(_cinematic_overlay):
		_cinematic_overlay.queue_free()
		_cinematic_overlay = null

	if hud:
		hud.visible = true

	if player and is_instance_valid(player):
		player.visible = true
		player.is_active = true
		var p_hud := player.get_node_or_null("PlayerHUD") as CanvasLayer
		if p_hud:
			p_hud.visible = true
		if "camera" in player and player.camera:
			player.camera.make_current()

	print("[Stage07IronHarbor] Cinematic concluded. Combat operative deployed.")
	_start_alarm_audio()


func is_cinematic_active() -> bool:
	return is_cinematic_playing


func get_cinematic_progress() -> float:
	return clampf(cinematic_elapsed / CINEMATIC_DURATION, 0.0, 1.0)


func _create_cinematic_overlay() -> void:
	if _cinematic_overlay:
		return
	var overlay := CanvasLayer.new()
	overlay.name = "CinematicOverlay"
	overlay.layer = 50
	add_child(overlay)
	_cinematic_overlay = overlay

	# Root control
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)

	# Letterbox Top
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.02, 0.03, 0.05, 0.96)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = 54.0
	root.add_child(top_bar)

	# Letterbox Bottom
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.02, 0.03, 0.05, 0.96)
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -68.0
	bottom_bar.offset_bottom = 0.0
	root.add_child(bottom_bar)

	# Mission Card VBox
	var card := VBoxContainer.new()
	card.anchor_left = 0.05
	card.anchor_right = 0.95
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_top = -62.0
	card.offset_bottom = -8.0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(card)

	var title_lbl := Label.new()
	title_lbl.text = "OPERATION IRON HARBOR // COASTAL SECTOR 07"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.22))
	title_lbl.add_theme_font_size_override("font_size", 16)
	card.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "DIRECTIVE: INFILTRATE CARGO TERMINAL // NEUTRALIZE DEFENDERS // PROCEED TO LZ CHARLIE   [ SPACE / ENTER / ESC ] TO SKIP"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.94, 0.85))
	sub_lbl.add_theme_font_size_override("font_size", 12)
	card.add_child(sub_lbl)


# ------------------------------------------------------------------------------
# GUARD COMBAT AND AWARENESS METHODS
# ------------------------------------------------------------------------------

func _freeze_guards() -> void:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		var guard := enemy as CharacterBody3D
		if not guard:
			continue
		guard_active[guard.name] = false
		guard.set_physics_process(false)
		guard.velocity = Vector3.ZERO
		if guard.has_signal("health_changed") and not guard.health_changed.is_connected(_on_guard_health_changed):
			guard.health_changed.connect(_on_guard_health_changed.bind(guard))
		if GUARD_LOOK_TARGETS.has(guard.name):
			_face_position(guard, GUARD_LOOK_TARGETS[guard.name])


func _poll_guard_contacts() -> void:
	if not player or not is_instance_valid(player):
		return
	var p_pos: Vector3 = player.global_position
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		var guard := enemy as CharacterBody3D
		if not guard or guard.is_dead or guard_active.get(guard.name, false):
			continue
		var g_data: Dictionary = GUARD_DATA.get(guard.name, {})
		var zone: String = g_data.get("zone", "")
		var dist: float = guard.global_position.distance_to(p_pos)

		var should_activate := false
		match zone:
			"entrance":
				if p_pos.z >= 34.0 and dist <= 26.0:
					should_activate = true
			"yard":
				if p_pos.z <= 40.0 and p_pos.z >= -15.0 and dist <= 24.0:
					should_activate = true
			"command":
				if p_pos.z <= 4.0 and dist <= 28.0:
					should_activate = true

		if not should_activate and dist <= VISION_RANGE and _has_line_of_sight(guard):
			var to_player: Vector3 = p_pos - guard.global_position
			to_player.y = 0.0
			var forward: Vector3 = -guard.global_basis.z
			forward.y = 0.0
			var dot: float = forward.normalized().dot(to_player.normalized())
			if dist <= CLOSE_RANGE or dot >= cos(deg_to_rad(VISION_HALF_FOV)):
				should_activate = true

		if should_activate:
			activate_guard(guard, "contact confirmed (%s zone)" % zone)


func activate_guard(guard: Node, reason := "contact") -> void:
	if not guard or guard.is_dead or guard_active.get(guard.name, false):
		return
	guard_active[guard.name] = true
	guard.velocity = Vector3.ZERO
	if "target_player" in guard and player:
		guard.target_player = player
	guard.set_physics_process(true)
	print("[Stage07IronHarbor] Guard %s activated: %s" % [guard.name, reason])


func _on_guard_health_changed(current_hp: int, max_hp: int, guard: Node) -> void:
	if current_hp < max_hp and not guard.is_dead:
		activate_guard(guard, "incoming fire")
		_alert_nearby_guards(guard.global_position, 18.0)


func _on_player_gunshot_alert() -> void:
	if is_cinematic_playing or not player or not is_instance_valid(player):
		return
	var gunshot_pos: Vector3 = player.global_position
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		if enemy.is_dead or guard_active.get(enemy.name, false):
			continue
		var dist: float = enemy.global_position.distance_to(gunshot_pos)
		if dist <= GUNSHOT_HEARING_RANGE:
			activate_guard(enemy, "nearby gunshot")


func _alert_nearby_guards(contact_pos: Vector3, radius: float) -> void:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return
	for enemy in enemies.get_children():
		if enemy.is_dead or guard_active.get(enemy.name, false):
			continue
		if enemy.global_position.distance_to(contact_pos) <= radius:
			activate_guard(enemy, "nearby guard engaged")


func _has_line_of_sight(guard: CollisionObject3D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		guard.global_position + Vector3.UP * 1.35,
		player.global_position + Vector3.UP * 1.25,
		1,
		[guard.get_rid()]
	)
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == player


func _face_position(node: Node3D, target: Vector3) -> void:
	var t := target
	t.y = node.global_position.y
	if node.global_position.distance_squared_to(t) > 0.1:
		node.look_at(t, Vector3.UP)


# ------------------------------------------------------------------------------
# OBJECTIVE INTERACTION & MISSION COMPLETION METHODS
# ------------------------------------------------------------------------------

func _try_player_interaction() -> bool:
	if not player or not is_instance_valid(player) or not player.is_active or is_stage_finished:
		return false
	var p_pos: Vector3 = player.global_position

	var dist_alarm: float = p_pos.distance_to(alarm_console_position)
	if dist_alarm <= INTERACTION_RADIUS:
		return interact_with_alarm()

	var dist_terminal: float = p_pos.distance_to(data_terminal_position)
	if dist_terminal <= INTERACTION_RADIUS:
		return interact_with_terminal()

	return false


func interact_with_alarm() -> bool:
	if is_alarm_disabled:
		return false
	is_alarm_disabled = true
	_stop_alarm_audio()
	_update_alarm_console_visuals()
	_update_objective_hud()
	_show_hud_toast("OBJECTIVE 1 SECURED: HARBOR ALARM OFFLINE", Color(0.2, 1.0, 0.45))
	print("[Stage07IronHarbor] Objective 1 Complete: Harbor Security Alarm Disabled.")
	return true


func interact_with_terminal() -> bool:
	if is_data_retrieved:
		return false
	if not is_alarm_disabled:
		_show_hud_toast("ACCESS DENIED // HARBOR ALARM MUST BE DISABLED FIRST", Color(1.0, 0.35, 0.2))
		print("[Stage07IronHarbor] Terminal locked: Harbor security alarm must be disabled first.")
		return false
	is_data_retrieved = true
	_update_data_terminal_visuals()
	_update_objective_hud()
	_show_hud_toast("OBJECTIVE 2 SECURED: SECTOR 07 INTEL RETRIEVED", Color(0.2, 1.0, 0.45))
	print("[Stage07IronHarbor] Objective 2 Complete: Command Intel Dossier Secured.")
	return true


func trigger_extraction() -> bool:
	if is_stage_finished or _extraction_completed:
		return false
	if not is_alarm_disabled:
		_show_hud_toast("EXTRACTION DENIED // OBJECTIVE 1 INCOMPLETE: DISABLE ALARM", Color(1.0, 0.35, 0.2))
		print("[Stage07IronHarbor] Extraction denied: Alarm is still active.")
		return false
	if not is_data_retrieved:
		_show_hud_toast("EXTRACTION DENIED // OBJECTIVE 2 INCOMPLETE: SECURE INTEL DATA", Color(1.0, 0.35, 0.2))
		print("[Stage07IronHarbor] Extraction denied: Intel data not retrieved.")
		return false
	var living_guards := _count_living_guards()
	if living_guards > 0:
		var message := "EXTRACTION DENIED // NEUTRALIZE ALL HOSTILES (%d REMAINING)" % living_guards
		_show_hud_toast(message, Color(1.0, 0.35, 0.2))
		_update_objective_hud()
		print("[Stage07IronHarbor] Extraction denied: %d hostiles remain alive." % living_guards)
		return false

	_extraction_completed = true
	_update_objective_hud()
	_show_hud_toast("MISSION ACCOMPLISHED // EVAC CONFIRMED AT LZ CHARLIE", Color(0.25, 1.0, 0.6))
	print("[Stage07IronHarbor] All objectives completed. Extracting operative at LZ Charlie.")
	call_deferred("_complete_stage", true)
	return true


func _on_extraction_area_body_entered(body: Node3D) -> void:
	if is_stage_finished or _extraction_completed:
		return
	if body == player or body.is_in_group("player"):
		trigger_extraction()


func _complete_stage_if_all_targets_eliminated() -> void:
	# In Stage 07, eliminating hostiles yields tactical combat score, but mission completion
	# strictly requires objective fulfillment (Alarm disabled + Intel retrieved) and evac at LZ Charlie.
	pass


func _count_living_guards() -> int:
	var enemies := get_node_or_null("Enemies") as Node3D
	if not enemies:
		return 0
	var living := 0
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy) or not ("is_dead" in enemy) or not enemy.is_dead:
			living += 1
	return living


func _complete_stage(is_victory: bool) -> void:
	if is_victory and (not is_alarm_disabled or not is_data_retrieved or not _extraction_completed or _count_living_guards() > 0):
		print("[Stage07IronHarbor] Victory rejected: required objectives, all guard eliminations, and LZ extraction are mandatory.")
		return
	_stop_alarm_audio()
	super._complete_stage(is_victory)
	if is_victory:
		var pm := get_node_or_null("/root/ProfileManager")
		if pm and pm.has_method("record_stage_completed"):
			pm.record_stage_completed(stage_id)
		if summary_dialog:
			summary_dialog.mission_status_label.text = "OPERATION SECURED"
			summary_dialog.mission_status_label.modulate = Color(0.25, 1.0, 0.62)
			summary_dialog.stage_name_label.text = "COASTAL EMBARGO BROKEN // LZ CHARLIE EVAC COMPLETE"
			summary_dialog.next_btn.visible = false
			summary_dialog.retry_btn.text = "REPLAY STAGE 07"
			summary_dialog.menu_btn.text = "RETURN TO HQ"


func _on_main_menu_requested() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().set_meta("hq_return_stage_id", stage_id)
	get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")


func _setup_interaction_hud() -> void:
	var hud_node := get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return
	_interaction_prompt_label = Label.new()
	_interaction_prompt_label.name = "InteractionPrompt"
	_interaction_prompt_label.anchor_left = 0.5
	_interaction_prompt_label.anchor_right = 0.5
	_interaction_prompt_label.anchor_top = 0.68
	_interaction_prompt_label.anchor_bottom = 0.68
	_interaction_prompt_label.offset_left = -300.0
	_interaction_prompt_label.offset_right = 300.0
	_interaction_prompt_label.offset_top = -24.0
	_interaction_prompt_label.offset_bottom = 24.0
	_interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_prompt_label.add_theme_font_size_override("font_size", 16)
	_interaction_prompt_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	_interaction_prompt_label.visible = false
	hud_node.add_child(_interaction_prompt_label)


func _update_objective_hud() -> void:
	var hud_node := get_node_or_null("HUD") as CanvasLayer
	if not hud_node:
		return
	var compact_lbl: Label = hud_node.get_node_or_null("TopBar/CenterBox/CompactObjectiveLabel")
	var status_text := ""
	if not is_alarm_disabled:
		status_text = "OBJ: [1/3] DISABLE SECURITY ALARM | [ ] INTEL | [ ] EXTRACT"
	elif not is_data_retrieved:
		status_text = "OBJ: [X] ALARM DISABLED | [2/3] RETRIEVE INTEL | [ ] EXTRACT"
	elif not _extraction_completed:
		status_text = "OBJ: [X] ALARM | [X] INTEL | NEUTRALIZE %d HOSTILES | PROCEED TO LZ CHARLIE" % _count_living_guards()
	else:
		status_text = "DIRECTIVE: MISSION COMPLETE // LZ CHARLIE EXTRACTION CONFIRMED"

	if compact_lbl:
		compact_lbl.text = status_text


func _update_interaction_prompts() -> void:
	if not _interaction_prompt_label or is_cinematic_playing or is_stage_finished:
		if _interaction_prompt_label:
			_interaction_prompt_label.visible = false
		return
	if not player or not is_instance_valid(player):
		_interaction_prompt_label.visible = false
		return

	var p_pos: Vector3 = player.global_position
	var dist_alarm: float = p_pos.distance_to(alarm_console_position)
	var dist_terminal: float = p_pos.distance_to(data_terminal_position)
	var dist_lz: float = p_pos.distance_to(lz_charlie_position)

	if dist_alarm <= INTERACTION_RADIUS and not is_alarm_disabled:
		_interaction_prompt_label.text = "[E] DISABLE HARBOR SECURITY ALARM"
		_interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_interaction_prompt_label.visible = true
	elif dist_terminal <= INTERACTION_RADIUS:
		if not is_alarm_disabled:
			_interaction_prompt_label.text = "[LOCKED] SECURITY LOCKDOWN — DISABLE HARBOR ALARM FIRST"
			_interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
			_interaction_prompt_label.visible = true
		elif not is_data_retrieved:
			_interaction_prompt_label.text = "[E] DOWNLOAD SECTOR 07 INTEL DOSSIER"
			_interaction_prompt_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
			_interaction_prompt_label.visible = true
		else:
			_interaction_prompt_label.text = "INTEL DOSSIER SECURED // PROCEED TO LZ CHARLIE"
			_interaction_prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			_interaction_prompt_label.visible = true
	elif dist_lz <= 12.0 and (not is_alarm_disabled or not is_data_retrieved):
		_interaction_prompt_label.text = "EXTRACTION UNAVAILABLE: MISSION OBJECTIVES INCOMPLETE"
		_interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2))
		_interaction_prompt_label.visible = true
	else:
		_interaction_prompt_label.visible = false


func _show_hud_toast(message: String, color: Color = Color.WHITE) -> void:
	if not _interaction_prompt_label:
		return
	_interaction_prompt_label.text = message
	_interaction_prompt_label.add_theme_color_override("font_color", color)
	_interaction_prompt_label.visible = true


func _update_alarm_console_visuals() -> void:
	if _alarm_status_mesh and _materials.has("beacon_green"):
		var mesh_inst := _alarm_status_mesh.get_node_or_null("Mesh") as MeshInstance3D
		if mesh_inst:
			mesh_inst.material_override = _materials["beacon_green"]
	if _alarm_label_3d:
		_alarm_label_3d.modulate = Color(0.25, 1.0, 0.5)
		_alarm_label_3d.text = "ALARM OFFLINE // RADAR DOWN"
	if _terminal_label_3d and not is_data_retrieved:
		_terminal_label_3d.modulate = Color(0.2, 0.85, 1.0)
		_terminal_label_3d.text = "[E] EXTRACT INTEL DATA"


func _update_data_terminal_visuals() -> void:
	if _terminal_status_mesh and _materials.has("beacon_green"):
		var mesh_inst := _terminal_status_mesh.get_node_or_null("Mesh") as MeshInstance3D
		if mesh_inst:
			mesh_inst.material_override = _materials["beacon_green"]
	if _terminal_label_3d:
		_terminal_label_3d.modulate = Color(0.25, 1.0, 0.5)
		_terminal_label_3d.text = "INTEL SECURED // READY"
	if _lz_label_3d:
		_lz_label_3d.modulate = Color(0.25, 1.0, 0.5)
		_lz_label_3d.text = "LZ CHARLIE // EXTRACTION READY"


# ------------------------------------------------------------------------------
# ENVIRONMENT DESIGN & GEOMETRY
# ------------------------------------------------------------------------------

func _create_materials() -> void:
	_add_mat("ground", Color(0.18, 0.21, 0.23), 0.92)
	_add_mat("asphalt", Color(0.10, 0.12, 0.14), 0.90)
	_add_mat("concrete", Color(0.35, 0.38, 0.40), 0.86)
	_add_mat("concrete_dark", Color(0.22, 0.25, 0.26), 0.88)
	_add_mat("water", Color(0.015, 0.12, 0.19), 0.16, 0.45)
	_add_mat("warehouse_wall", Color(0.26, 0.31, 0.33), 0.82, 0.20)
	_add_mat("warehouse_roof", Color(0.14, 0.17, 0.20), 0.70, 0.42)
	_add_mat("steel", Color(0.24, 0.27, 0.30), 0.55, 0.68)
	_add_mat("steel_dark", Color(0.11, 0.14, 0.16), 0.60, 0.72)
	_add_mat("glass", Color(0.10, 0.28, 0.36), 0.18, 0.52)
	_add_mat("yellow", Color(0.92, 0.68, 0.12), 0.62, 0.12)
	_add_mat("hazard_black", Color(0.07, 0.08, 0.09), 0.85)
	_add_mat("white", Color(0.85, 0.88, 0.89), 0.65)
	_add_mat("red_container", Color(0.52, 0.15, 0.11), 0.78, 0.35)
	_add_mat("blue_container", Color(0.09, 0.26, 0.44), 0.78, 0.40)
	_add_mat("green_container", Color(0.16, 0.30, 0.21), 0.82, 0.32)
	_add_mat("orange_container", Color(0.72, 0.35, 0.10), 0.78, 0.30)
	_add_mat("gray_container", Color(0.30, 0.33, 0.36), 0.75, 0.38)
	_add_mat("wood", Color(0.36, 0.24, 0.13), 0.92)
	_add_mat("sandbag", Color(0.42, 0.38, 0.29), 0.95)
	_add_mat("fuel_tank", Color(0.72, 0.75, 0.78), 0.45, 0.42)
	_add_mat("ship_hull", Color(0.10, 0.13, 0.16), 0.75, 0.55)
	_add_mat("ship_red", Color(0.45, 0.11, 0.09), 0.80)
	_add_mat("helipad", Color(0.09, 0.11, 0.13), 0.85, 0.25)
	_add_mat("beacon_red", Color(1.0, 0.15, 0.15), 0.2, 0.0, Color(1.0, 0.15, 0.15), 2.2)
	_add_mat("beacon_green", Color(0.15, 1.0, 0.4), 0.2, 0.0, Color(0.15, 1.0, 0.4), 2.0)
	_add_mat("beacon_amber", Color(1.0, 0.72, 0.1), 0.2, 0.0, Color(1.0, 0.72, 0.1), 2.2)


func _build_harbor() -> void:
	var env_node := $Environment as Node3D
	_build_ground_and_roads(env_node)
	_build_waterfront_and_ship(env_node)
	_build_quay_crane(env_node)
	_build_perimeter_and_spawn(env_node)
	_build_container_yard_alpha(env_node)
	_build_cargo_warehouse(env_node)
	_build_container_yard_bravo(env_node)
	_build_security_watchtower(env_node)
	_build_enemy_command_center(env_node)
	_build_helipad_extraction(env_node)
	_build_high_mast_floodlights(env_node)


func _build_ground_and_roads(parent: Node3D) -> void:
	var ground := _group(parent, "PortGround")
	# Expansive base port apron (130m wide x 136m deep)
	_box(ground, "MainApron", Vector3(0, -0.5, 0), Vector3(130, 1.0, 136), "ground")

	# Central Logistics Highway (running South-North)
	_box(ground, "CentralHighway", Vector3(0, 0.015, 6), Vector3(16, 0.03, 116), "asphalt", false)
	# West Logistics Road (towards Warehouse & Helipad)
	_box(ground, "WestLogisticsRoad", Vector3(-27, 0.018, 8), Vector3(9, 0.035, 104), "asphalt", false)
	# East Patrol Road (towards Watchtower & Command)
	_box(ground, "EastPatrolRoad", Vector3(27, 0.018, 6), Vector3(9, 0.035, 104), "asphalt", false)
	# Quayside Heavy Apron (along the waterfront)
	_box(ground, "QuayApron", Vector3(0, 0.025, -57), Vector3(128, 0.05, 20), "concrete", false)

	# Painted Road Markings on Central Highway
	for z in range(62, -45, -7):
		_box(ground, "CenterDash", Vector3(-0.25, 0.05, float(z)), Vector3(0.16, 0.02, 3.2), "yellow_marking", false)
		_box(ground, "CenterDash", Vector3(0.25, 0.05, float(z)), Vector3(0.16, 0.02, 3.2), "yellow_marking", false)
	for side in [-1.0, 1.0]:
		_box(ground, "HighwayBoundary", Vector3(side * 7.8, 0.05, 6), Vector3(0.2, 0.02, 116), "white_marking", false)

	# Quayside Crane Rails
	for rail_z in [-51.0, -63.0]:
		_box(ground, "CraneRail", Vector3(0, 0.06, rail_z), Vector3(126, 0.04, 0.35), "steel", false)


func _build_waterfront_and_ship(parent: Node3D) -> void:
	var waterfront := _group(parent, "Waterfront")

	# Ocean Water Plane extending to the northern horizon
	_box(waterfront, "HarborOcean", Vector3(0, -0.4, -94), Vector3(160, 0.2, 54), "water", false)

	# Massive Concrete Seawall
	_box(waterfront, "Seawall", Vector3(0, 0.9, -67.5), Vector3(130, 1.8, 1.6), "concrete_dark")
	# Seawall Hazard Stripe along top edge
	for i in range(26):
		var stripe_x := -62.4 + float(i) * 4.99
		var mat := "yellow" if (i % 2 == 0) else "hazard_black"
		_box(waterfront, "HazardStripe", Vector3(stripe_x, 1.82, -67.5), Vector3(4.99, 0.04, 1.55), mat, false)

	# Mooring Bollards along the quay
	for b in range(9):
		var bollard_x := -52.0 + float(b) * 13.0
		_cylinder(waterfront, "MooringBollard", Vector3(bollard_x, 0.45, -66.2), 0.32, 0.9, "steel_dark")
		_cylinder(waterfront, "BollardCap", Vector3(bollard_x, 0.95, -66.2), 0.45, 0.15, "steel_dark")

	# Ocean Navigation Buoys in deep water
	for buoy_data in [[Vector3(-45, 0.3, -90), "beacon_red"], [Vector3(45, 0.3, -90), "beacon_green"]]:
		var pos: Vector3 = buoy_data[0]
		var col: String = buoy_data[1]
		_cylinder(waterfront, "BuoyBody", pos, 1.1, 1.4, "yellow", Vector3.ZERO, false)
		_box(waterfront, "BuoyMast", pos + Vector3(0, 1.4, 0), Vector3(0.3, 1.6, 0.3), "steel_dark", false)
		_box(waterfront, "BuoyLight", pos + Vector3(0, 2.3, 0), Vector3(0.4, 0.4, 0.4), col, false)

	# Moored Naval Transport Ship "IRON TITAN"
	var ship := _group(waterfront, "CargoShip")
	var ship_pos := Vector3(14, 0, -82)
	# Ship Hull (72m length x 16m beam x 8.6m height)
	_box(ship, "ShipKeelRed", ship_pos + Vector3(0, 1.0, 0), Vector3(72, 2.0, 16), "ship_red")
	_box(ship, "ShipMainHull", ship_pos + Vector3(0, 4.8, 0), Vector3(72, 5.6, 16), "ship_hull")
	# Ship Deck
	_box(ship, "ShipMainDeck", ship_pos + Vector3(0, 7.7, 0), Vector3(71.6, 0.3, 15.6), "steel_dark")
	# Ship Bridge / Superstructure at stern (east end)
	_box(ship, "ShipSuperstructure", ship_pos + Vector3(24, 11.2, 0), Vector3(18, 6.8, 14), "concrete")
	_box(ship, "ShipBridgeRoof", ship_pos + Vector3(24, 14.8, 0), Vector3(19, 0.4, 15), "steel_dark")
	_box(ship, "ShipBridgeWindows", ship_pos + Vector3(14.8, 12.8, 0), Vector3(0.2, 1.6, 12), "glass", false)
	# Radar Mast
	_box(ship, "ShipRadarMast", ship_pos + Vector3(24, 17.5, 0), Vector3(0.6, 5.0, 0.6), "steel", false)
	_box(ship, "ShipRadarCross", ship_pos + Vector3(24, 19.2, 0), Vector3(3.2, 0.3, 0.3), "steel", false)
	_box(ship, "ShipMastLight", ship_pos + Vector3(24, 20.2, 0), Vector3(0.4, 0.4, 0.4), "beacon_red", false)

	# Containers stacked on ship cargo deck
	var ship_colors := ["red_container", "blue_container", "orange_container", "green_container"]
	for bay in range(4):
		var bay_x := ship_pos.x - 26.0 + float(bay) * 9.5
		for row in [-3.2, 3.2]:
			_box(ship, "DeckContainer", Vector3(bay_x, 9.2, ship_pos.z + row), Vector3(8.5, 2.7, 5.8), ship_colors[(bay + int(row)) % 4])
			_box(ship, "DeckContainerUpper", Vector3(bay_x, 11.9, ship_pos.z + row), Vector3(8.5, 2.7, 5.8), ship_colors[(bay + 2) % 4])


func _build_quay_crane(parent: Node3D) -> void:
	var crane := _group(parent, "ShipToShoreCrane")
	var crane_pos := Vector3(16, 0, -57)

	# 4 Heavy Steel Legs (Gantry Portal)
	for x_off in [-10.0, 10.0]:
		for z_off in [-6.0, 6.0]:
			var leg_pos := crane_pos + Vector3(x_off, 12.5, z_off)
			_box(crane, "CraneLeg", leg_pos, Vector3(1.2, 25.0, 1.2), "yellow")
			_box(crane, "CraneBogeyWheel", crane_pos + Vector3(x_off, 0.6, z_off), Vector3(2.4, 1.2, 2.8), "steel_dark")
		# Cross Braces
		_box(crane, "LegCrossBeam", crane_pos + Vector3(x_off, 14.0, 0), Vector3(1.0, 1.0, 12.0), "yellow", false)
		_box(crane, "LegCrossBeam", crane_pos + Vector3(x_off, 22.0, 0), Vector3(1.0, 1.0, 12.0), "yellow", false)

	# Horizontal Bridge Gantry
	_box(crane, "CraneBridgeGantry", crane_pos + Vector3(0, 25.6, 0), Vector3(24.0, 1.6, 14.0), "yellow")
	# Boom reaching out over the sea (towards Z = -82)
	_box(crane, "CraneBoom", crane_pos + Vector3(0, 26.8, -12.0), Vector3(3.2, 1.4, 28.0), "yellow")
	# Back-reach counterweight arm
	_box(crane, "CraneBackreach", crane_pos + Vector3(0, 26.8, 11.0), Vector3(3.2, 1.4, 10.0), "steel_dark")
	_box(crane, "Counterweight", crane_pos + Vector3(0, 26.0, 15.0), Vector3(6.0, 2.4, 3.5), "concrete_dark")

	# Operator Cabin
	_box(crane, "CraneCabin", crane_pos + Vector3(4.0, 23.2, -4.0), Vector3(3.4, 2.6, 3.4), "steel")
	_box(crane, "CabinWindow", crane_pos + Vector3(4.0, 23.2, -5.75), Vector3(2.8, 1.6, 0.12), "glass", false)

	# Spreader / Hoist Trolley suspended over quay
	_box(crane, "TrolleySpreader", crane_pos + Vector3(0, 15.0, -8.0), Vector3(6.5, 0.8, 2.8), "yellow")
	for corner in [Vector3(-2.8, 20.0, -9.0), Vector3(2.8, 20.0, -9.0), Vector3(-2.8, 20.0, -7.0), Vector3(2.8, 20.0, -7.0)]:
		_box(crane, "HoistCable", corner, Vector3(0.08, 10.0, 0.08), "steel_dark", false)

	# Rooftop Warning Beacons on Crane Top
	_box(crane, "CraneBeaconL", crane_pos + Vector3(-9.0, 28.2, 0), Vector3(0.5, 0.8, 0.5), "beacon_red", false)
	_box(crane, "CraneBeaconR", crane_pos + Vector3(9.0, 28.2, 0), Vector3(0.5, 0.8, 0.5), "beacon_red", false)


func _build_perimeter_and_spawn(parent: Node3D) -> void:
	var perimeter := _group(parent, "PerimeterAndSpawn")

	# Outer Perimeter Concrete Walls
	_box(perimeter, "WestPerimeterWall", Vector3(-64.5, 3.0, 0), Vector3(1.2, 6.0, 136), "concrete_dark")
	_box(perimeter, "EastPerimeterWall", Vector3(64.5, 3.0, 0), Vector3(1.2, 6.0, 136), "concrete_dark")
	# South Perimeter Wall (flanking the gate)
	_box(perimeter, "SouthWallLeft", Vector3(-39.0, 2.5, 67.5), Vector3(50.0, 5.0, 1.0), "concrete_dark")
	_box(perimeter, "SouthWallRight", Vector3(39.0, 2.5, 67.5), Vector3(50.0, 5.0, 1.0), "concrete_dark")

	# South Checkpoint Gatehouse (Z = 63, X = -11)
	_box(perimeter, "GatehouseFloor", Vector3(-11, 0.15, 63), Vector3(6.5, 0.3, 7.0), "concrete")
	_box(perimeter, "GatehouseBuilding", Vector3(-11, 2.1, 63), Vector3(6.0, 3.8, 6.5), "warehouse_wall")
	_box(perimeter, "GatehouseRoof", Vector3(-11, 4.15, 63), Vector3(6.8, 0.35, 7.2), "warehouse_roof")
	_box(perimeter, "GatehouseWindow", Vector3(-7.9, 2.2, 63), Vector3(0.12, 1.4, 4.0), "glass", false)

	# Boom Barrier & Security Island
	_box(perimeter, "SecurityIsland", Vector3(0, 0.25, 64.5), Vector3(2.4, 0.5, 6.0), "concrete")
	_box(perimeter, "BarrierPost", Vector3(0, 1.2, 64.5), Vector3(0.6, 1.6, 0.6), "yellow")
	_box(perimeter, "BoomArmLeft", Vector3(-4.5, 1.1, 64.5), Vector3(8.0, 0.18, 0.18), "white_marking", false)
	_box(perimeter, "BoomArmRight", Vector3(4.5, 1.1, 64.5), Vector3(8.0, 0.18, 0.18), "white_marking", false)

	# Tactical Jersey Barriers for initial player cover
	_box(perimeter, "JerseyBarrierL", Vector3(-3.2, 0.6, 54), Vector3(4.5, 1.2, 0.7), "concrete")
	_box(perimeter, "JerseyBarrierR", Vector3(3.2, 0.6, 54), Vector3(4.5, 1.2, 0.7), "concrete")
	_box(perimeter, "CoverSandbags", Vector3(6.8, 0.45, 52), Vector3(3.2, 0.9, 1.4), "sandbag")

	# Large Port Entrance Sign — Mounted above security gate facing +Z
	_physical_sign(
		perimeter,
		"HarborEntranceSign",
		Vector3(0, 5.2, 64.6),
		Vector3(14.0, 1.4, 0.14),
		"OPERATION IRON HARBOR",
		"MILITARY CARGO TERMINAL 07 // RESTRICTED ZONE",
		"steel_dark",
		"yellow",
		"+Z",
		38,
		22,
		Color(0.98, 0.94, 0.85)
	)


func _build_container_yard_alpha(parent: Node3D) -> void:
	var yard := _group(parent, "ContainerYardAlpha")
	var colors := ["red_container", "blue_container", "green_container", "orange_container", "gray_container"]

	# Container Yard Alpha Entrance Sign — Mounted flush on front container wall facing +Z
	_physical_sign(
		yard,
		"YardAlphaSign",
		Vector3(-16.0, 2.6, 48.46),
		Vector3(5.2, 1.15, 0.08),
		"CONTAINER YARD ALPHA",
		"FREIGHT MARSHALLING SECTOR",
		"steel_dark",
		"yellow",
		"+Z",
		32,
		18,
		Color(0.96, 0.92, 0.85)
	)

	# 4 Stacking Rows creating 3 distinct tactical alleys (Alley A, B, C)
	for row_idx in range(4):
		var row_x := -16.0 - float(row_idx) * 9.5 # X = -16, -25.5, -35, -44.5
		for stack_idx in range(7):
			var stack_z := 44.0 - float(stack_idx) * 9.8
			# Leave wide cross-alleys for combat movement and flanking
			if stack_idx in [2, 5]:
				continue
			var col_name: String = colors[(row_idx * 3 + stack_idx) % colors.size()]
			var center := Vector3(row_x, 1.35, stack_z)
			_box(yard, "CargoContainer", center, Vector3(6.4, 2.7, 8.8), col_name)

			# Detailed Container Ribs & Corner Castings
			for rib in range(5):
				var rib_z := stack_z - 3.6 + float(rib) * 1.8
				_box(yard, "RibL", Vector3(row_x - 3.22, 1.35, rib_z), Vector3(0.06, 2.6, 0.08), "steel_dark", false)
				_box(yard, "RibR", Vector3(row_x + 3.22, 1.35, rib_z), Vector3(0.06, 2.6, 0.08), "steel_dark", false)

			# 2-tier and 3-tier verticality on select stacks
			if (row_idx + stack_idx) % 2 == 1:
				var upper_col: String = colors[(row_idx * 2 + stack_idx + 1) % colors.size()]
				_box(yard, "CargoContainerL2", Vector3(row_x, 4.05, stack_z), Vector3(6.4, 2.7, 8.8), upper_col)
			if (row_idx == 3 and stack_idx == 3) or (row_idx == 1 and stack_idx == 4):
				var top_col: String = colors[(row_idx + stack_idx + 3) % colors.size()]
				_box(yard, "CargoContainerL3", Vector3(row_x, 6.75, stack_z), Vector3(6.4, 2.7, 8.8), top_col)

	# Tactical Pallets and Crates inside alleys
	_box(yard, "AlleyPalletsA", Vector3(-20.5, 0.5, 24.0), Vector3(2.4, 1.0, 3.2), "wood")
	_box(yard, "AlleyPalletsB", Vector3(-30.0, 0.5, -4.0), Vector3(3.0, 1.0, 2.2), "wood")
	_box(yard, "AlleyPalletsC", Vector3(-40.0, 0.5, 34.0), Vector3(2.8, 1.0, 2.8), "wood")


func _build_cargo_warehouse(parent: Node3D) -> void:
	var wh := _group(parent, "CargoWarehouse")
	var center_x := -42.0
	var center_z := 4.0

	# Heavy Elevated Concrete Loading Dock
	_box(wh, "DockPlatform", Vector3(center_x + 12.0, 0.6, center_z), Vector3(4.0, 1.2, 34.0), "concrete")
	_box(wh, "DockRampSouth", Vector3(center_x + 12.0, 0.3, center_z + 18.5), Vector3(4.0, 0.6, 3.0), "concrete")
	_box(wh, "DockRampNorth", Vector3(center_x + 12.0, 0.3, center_z - 18.5), Vector3(4.0, 0.6, 3.0), "concrete")

	# Main Warehouse Structure (22m wide x 34m long x 10m high)
	_box(wh, "WarehouseFloor", Vector3(center_x, 0.1, center_z), Vector3(22.0, 0.2, 34.0), "concrete_dark")
	_box(wh, "WarehouseBackWall", Vector3(center_x - 11.0, 5.0, center_z), Vector3(0.8, 10.0, 34.0), "warehouse_wall")
	_box(wh, "WarehouseNorthWall", Vector3(center_x, 5.0, center_z - 17.0), Vector3(22.0, 10.0, 0.8), "warehouse_wall")
	_box(wh, "WarehouseSouthWall", Vector3(center_x, 5.0, center_z + 17.0), Vector3(22.0, 10.0, 0.8), "warehouse_wall")

	# Front Wall with 3 Loading Bays
	_box(wh, "FrontWallA", Vector3(center_x + 10.5, 5.0, center_z - 13.5), Vector3(0.8, 10.0, 7.0), "warehouse_wall")
	_box(wh, "FrontWallB", Vector3(center_x + 10.5, 5.0, center_z), Vector3(0.8, 10.0, 6.0), "warehouse_wall")
	_box(wh, "FrontWallC", Vector3(center_x + 10.5, 5.0, center_z + 13.5), Vector3(0.8, 10.0, 7.0), "warehouse_wall")
	_box(wh, "FrontLintel", Vector3(center_x + 10.5, 8.8, center_z), Vector3(0.8, 2.4, 34.0), "warehouse_wall")

	# Sloped Industrial Corrugated Roof
	_box(wh, "WarehouseRoof", Vector3(center_x, 10.4, center_z), Vector3(23.5, 0.6, 35.5), "warehouse_roof")

	# Loading Bay Doors: Bay 1 & 2 closed with hazard frame, Bay 3 partially open
	_box(wh, "BayDoor1", Vector3(center_x + 10.2, 4.4, center_z - 7.0), Vector3(0.15, 6.5, 5.8), "steel_dark")
	_box(wh, "BayDoor2", Vector3(center_x + 10.2, 4.4, center_z + 7.0), Vector3(0.15, 6.5, 5.8), "steel_dark")
	# Bay 3 open walkable corridor: Door raised high
	_box(wh, "BayDoor3Raised", Vector3(center_x + 10.2, 6.8, center_z - 7.0), Vector3(0.15, 2.2, 5.8), "steel_dark", false)

	# Interior Warehouse Shelving Racks visible from bay
	_box(wh, "InteriorRack1", Vector3(center_x - 4.0, 3.5, center_z - 7.0), Vector3(3.5, 7.0, 12.0), "steel")
	_box(wh, "InteriorRack2", Vector3(center_x - 4.0, 3.5, center_z + 7.0), Vector3(3.5, 7.0, 12.0), "steel")

	# Warehouse Signage — Mounted on FrontLintel facing East (+X) toward logistics roadway
	_physical_sign(
		wh,
		"WarehouseSign",
		Vector3(center_x + 10.95, 8.6, center_z),
		Vector3(0.14, 1.6, 14.0),
		"CARGO WAREHOUSE 07",
		"NAVAL FREIGHT LOGISTICS // BAYS 01-03",
		"steel_dark",
		"yellow",
		"+X",
		38,
		21,
		Color(0.98, 0.95, 0.88)
	)


func _build_container_yard_bravo(parent: Node3D) -> void:
	var yard := _group(parent, "ContainerYardBravo")
	var colors := ["blue_container", "green_container", "gray_container", "red_container", "orange_container"]

	# Organized East Freight Blocks
	for row_idx in range(3):
		var row_x := 18.0 + float(row_idx) * 11.0 # X = 18, 29, 40
		for stack_idx in range(6):
			var stack_z := 42.0 - float(stack_idx) * 11.0
			# Keep clear lane for the security tower and command road
			if stack_idx == 2:
				continue
			var col_name: String = colors[(row_idx * 2 + stack_idx) % colors.size()]
			var center := Vector3(row_x, 1.35, stack_z)
			_box(yard, "CargoContainer", center, Vector3(6.4, 2.7, 9.4), col_name)

			if stack_idx in [1, 4]:
				var col2: String = colors[(row_idx + stack_idx + 1) % colors.size()]
				_box(yard, "StackedContainer", Vector3(row_x, 4.05, stack_z), Vector3(6.4, 2.7, 9.4), col2)

	# Forklift Vehicle parked between stacks
	var fl_pos := Vector3(23.5, 0, 18.0)
	_box(yard, "ForkliftChassis", fl_pos + Vector3(0, 0.7, 0), Vector3(2.6, 1.4, 3.8), "yellow")
	_box(yard, "ForkliftMast", fl_pos + Vector3(0, 1.9, -1.8), Vector3(2.2, 3.2, 0.35), "steel_dark")
	_box(yard, "ForkliftProngs", fl_pos + Vector3(0, 0.15, -2.6), Vector3(1.8, 0.15, 1.6), "steel")
	_box(yard, "ForkliftCage", fl_pos + Vector3(0, 1.8, 0.3), Vector3(2.2, 1.8, 2.2), "steel_dark", false)

	# Heavy Generator Substation
	var gen_pos := Vector3(48.0, 0, 12.0)
	_box(yard, "GenPad", gen_pos + Vector3(0, 0.2, 0), Vector3(8.0, 0.4, 8.0), "concrete")
	_box(yard, "GenBody", gen_pos + Vector3(0, 1.8, 0), Vector3(5.5, 3.0, 5.5), "steel_dark")
	_box(yard, "GenExhaust", gen_pos + Vector3(1.6, 3.8, 1.6), Vector3(0.5, 1.8, 0.5), "steel", false)
	_box(yard, "GenWarningStripe", gen_pos + Vector3(0, 2.2, -2.8), Vector3(4.5, 0.4, 0.1), "yellow", false)


func _build_security_watchtower(parent: Node3D) -> void:
	var tower := _group(parent, "SecurityWatchtower")
	var center := Vector3(44.0, 0, 26.0)

	# Heavy Concrete Base Plinth
	_box(tower, "TowerPlinth", center + Vector3(0, 0.4, 0), Vector3(11.0, 0.8, 11.0), "concrete_dark")

	# 4 Structural Steel Lattice Pylons
	for x_off in [-4.2, 4.2]:
		for z_off in [-4.2, 4.2]:
			_box(tower, "PylonLeg", center + Vector3(x_off, 6.0, z_off), Vector3(0.65, 12.0, 0.65), "steel_dark")
	# Cross Stiffeners
	_box(tower, "CrossBeamMid", center + Vector3(0, 6.0, 0), Vector3(9.0, 0.35, 9.0), "steel", false)

	# Elevated Observation Deck & Armored Cabin (at Y = 12m to 17m)
	_box(tower, "CatwalkDeck", center + Vector3(0, 12.2, 0), Vector3(11.4, 0.5, 11.4), "steel")
	_box(tower, "GuardCabin", center + Vector3(0, 14.7, 0), Vector3(7.8, 4.6, 7.8), "warehouse_wall")
	_box(tower, "CabinRoof", center + Vector3(0, 17.2, 0), Vector3(8.6, 0.4, 8.6), "warehouse_roof")

	# 360-degree Vision Slits
	_box(tower, "WindowSouth", center + Vector3(0, 14.8, 3.96), Vector3(6.4, 1.6, 0.12), "glass", false)
	_box(tower, "WindowWest", center + Vector3(-3.96, 14.8, 0), Vector3(0.12, 1.6, 6.4), "glass", false)
	_box(tower, "WindowNorth", center + Vector3(0, 14.8, -3.96), Vector3(6.4, 1.6, 0.12), "glass", false)
	_box(tower, "WindowEast", center + Vector3(3.96, 14.8, 0), Vector3(0.12, 1.6, 6.4), "glass", false)

	# Aircraft Obstruction Beacon
	_box(tower, "TowerBeacon", center + Vector3(0, 17.8, 0), Vector3(0.6, 0.8, 0.6), "beacon_red", false)

	# High-Power Searchlight (SpotLight3D angled toward container alleys)
	var searchlight := SpotLight3D.new()
	searchlight.name = "TowerSearchlight"
	searchlight.position = center + Vector3(-3.6, 12.8, -3.6)
	searchlight.rotation_degrees = Vector3(-32, 138, 0)
	searchlight.light_color = Color(0.95, 0.96, 1.0)
	searchlight.light_energy = 5.5
	searchlight.spot_range = 65.0
	searchlight.spot_angle = 36.0
	searchlight.spot_attenuation = 0.85
	searchlight.shadow_enabled = true
	tower.add_child(searchlight)

	# Security Watchtower Identification Plaque — Mounted on west tower pylon frame facing roadway (-X)
	_physical_sign(
		tower,
		"WatchtowerSign",
		center + Vector3(-4.25, 3.2, -2.5),
		Vector3(0.12, 1.25, 4.2),
		"SECURITY WATCHTOWER",
		"PERIMETER RADAR // SECTOR EAST",
		"steel_dark",
		"yellow",
		"-X",
		30,
		18,
		Color(0.98, 0.94, 0.86)
	)

	_build_alarm_console(tower)


func _build_enemy_command_center(parent: Node3D) -> void:
	var cmd := _group(parent, "EnemyCommandCenter")
	var center := Vector3(34.0, 0, -32.0)

	# Concrete Foundation
	_box(cmd, "CommandFloor", center + Vector3(0, 0.2, 0), Vector3(24.0, 0.4, 22.0), "concrete_dark")

	# Reinforced Bunker Building (22m wide x 20m long x 8m high)
	_box(cmd, "CommandBackWall", center + Vector3(0, 4.4, -10.0), Vector3(22.0, 8.4, 0.8), "warehouse_wall")
	_box(cmd, "CommandLeftWall", center + Vector3(-10.6, 4.4, 0), Vector3(0.8, 8.4, 20.0), "warehouse_wall")
	_box(cmd, "CommandRightWall", center + Vector3(10.6, 4.4, 0), Vector3(0.8, 8.4, 20.0), "warehouse_wall")
	_box(cmd, "CommandFrontLeft", center + Vector3(-7.0, 4.4, 10.0), Vector3(6.8, 8.4, 0.8), "warehouse_wall")
	_box(cmd, "CommandFrontRight", center + Vector3(7.0, 4.4, 10.0), Vector3(6.8, 8.4, 0.8), "warehouse_wall")
	_box(cmd, "CommandDoorHeader", center + Vector3(0, 7.2, 10.0), Vector3(7.2, 2.8, 0.8), "warehouse_wall")
	_box(cmd, "CommandRoof", center + Vector3(0, 8.8, 0), Vector3(23.2, 0.6, 21.2), "warehouse_roof")

	# Armored Blast Door & Control Glass
	_box(cmd, "BlastDoor", center + Vector3(0, 3.0, 9.8), Vector3(6.4, 5.8, 0.25), "steel_dark")
	_box(cmd, "CommandWindow", center + Vector3(-7.0, 4.2, 10.45), Vector3(4.2, 1.4, 0.12), "glass", false)

	# Rooftop Communication Mast & Satellite Dish Antenna
	_box(cmd, "RadioMast", center + Vector3(6.0, 14.0, -5.0), Vector3(0.6, 11.0, 0.6), "steel", false)
	_box(cmd, "RadioCrossArm", center + Vector3(6.0, 18.0, -5.0), Vector3(3.2, 0.3, 0.3), "steel", false)
	_box(cmd, "RadioBeacon", center + Vector3(6.0, 19.8, -5.0), Vector3(0.5, 0.6, 0.5), "beacon_red", false)

	# Satellite Dish
	_cylinder(cmd, "DishRing", center + Vector3(-5.0, 11.0, -4.0), 2.2, 0.5, "steel", Vector3(42, 25, 0), false)
	_cylinder(cmd, "DishFeed", center + Vector3(-5.8, 12.2, -3.2), 0.2, 2.0, "yellow", Vector3(42, 25, 0), false)

	# Perimeter Sandbags & Blast Barriers
	_box(cmd, "BlastBarrierWest", center + Vector3(-13.5, 0.8, 12.0), Vector3(6.0, 1.6, 0.9), "concrete")
	_box(cmd, "BlastBarrierEast", center + Vector3(13.5, 0.8, 12.0), Vector3(6.0, 1.6, 0.9), "concrete")
	_box(cmd, "SandbagPosition", center + Vector3(0, 0.5, 14.5), Vector3(7.0, 1.0, 1.4), "sandbag")

	# Compound Identification Sign — Mounted on CommandDoorHeader facing +Z
	_physical_sign(
		cmd,
		"CommandSign",
		center + Vector3(0, 7.3, 10.46),
		Vector3(8.2, 1.4, 0.12),
		"COMMAND CENTER",
		"SECTOR 07 // EMBARGO CONTROL BUNKER",
		"steel_dark",
		"yellow",
		"+Z",
		36,
		20,
		Color(0.98, 0.95, 0.88)
	)

	# Tactical Command Data Terminal
	_build_data_terminal(cmd)


func _build_helipad_extraction(parent: Node3D) -> void:
	var lz := _group(parent, "ExtractionHelipad")
	var center := Vector3(-36.0, 0.15, -48.0)

	# Heavy Raised Concrete Pier
	_box(lz, "PierBase", center, Vector3(24.0, 0.3, 24.0), "helipad")

	# Yellow Helipad Landing Markings
	# Outer Border Box
	for side in [-1.0, 1.0]:
		_box(lz, "PadBorderZ", center + Vector3(side * 10.0, 0.18, 0), Vector3(0.35, 0.04, 20.0), "yellow_marking", false)
		_box(lz, "PadBorderX", center + Vector3(0, 0.18, side * 10.0), Vector3(20.0, 0.04, 0.35), "yellow_marking", false)

	# Bold "H" Touchdown Center Marker
	_box(lz, "H_StemLeft", center + Vector3(-2.2, 0.19, 0), Vector3(0.55, 0.04, 6.0), "yellow_marking", false)
	_box(lz, "H_StemRight", center + Vector3(2.2, 0.19, 0), Vector3(0.55, 0.04, 6.0), "yellow_marking", false)
	_box(lz, "H_CrossBar", center + Vector3(0, 0.19, 0), Vector3(4.0, 0.04, 0.55), "yellow_marking", false)

	# Green Airfield Perimeter Marker Beacons
	for angle_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
		var rad := deg_to_rad(float(angle_deg))
		var m_pos := center + Vector3(cos(rad) * 9.6, 0.22, sin(rad) * 9.6)
		_box(lz, "PadLight", m_pos, Vector3(0.35, 0.25, 0.35), "beacon_green", false)

	# Tactical Fuel Staging Storage (West edge of LZ)
	var fuel_pos := center + Vector3(-16.0, 0, 0)
	_cylinder(lz, "FuelTank1", fuel_pos + Vector3(0, 2.2, -4.5), 2.2, 5.5, "fuel_tank", Vector3(90, 0, 0))
	_cylinder(lz, "FuelTank2", fuel_pos + Vector3(0, 2.2, 4.5), 2.2, 5.5, "fuel_tank", Vector3(90, 0, 0))
	_box(lz, "FuelPipes", fuel_pos + Vector3(2.0, 0.8, 0), Vector3(0.4, 0.4, 9.0), "steel", false)
	_box(lz, "CrashCrates", center + Vector3(10.5, 0.6, 8.0), Vector3(2.5, 1.2, 3.5), "steel_dark")

	# Extraction Staging Ground Sign — Twin steel stanchions facing +Z (approaching player)
	_physical_sign(
		lz,
		"ExtractionSign",
		center + Vector3(0, 2.0, 12.2),
		Vector3(6.2, 1.35, 0.14),
		"LZ CHARLIE",
		"TACTICAL EVACUATION HELIPAD",
		"steel_dark",
		"beacon_green",
		"+Z",
		38,
		21,
		Color(0.96, 0.98, 0.96),
		true
	)

	# Real Extraction Trigger & Evac Status Marker
	_build_extraction_trigger(lz)


func _build_alarm_console(parent: Node3D) -> void:
	var console := _group(parent, "AlarmConsole")
	var pos := alarm_console_position

	_box(console, "ConsolePedestal", pos + Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.8), "steel_dark")
	_box(console, "ConsoleSlant", pos + Vector3(0, 1.05, 0), Vector3(1.1, 0.25, 0.7), "steel")
	_box(console, "KeyboardPad", pos + Vector3(0, 1.15, 0.1), Vector3(0.8, 0.08, 0.35), "yellow", false)

	_alarm_status_mesh = _box(console, "AlarmStatusLight", pos + Vector3(0, 1.45, 0), Vector3(0.4, 0.4, 0.4), "beacon_red", false)

	# Alarm Console Equipment Tag — Mounted flush on front of pedestal facing +Z
	_physical_sign(
		console,
		"AlarmConsoleTag",
		pos + Vector3(0, 0.55, 0.42),
		Vector3(0.95, 0.32, 0.04),
		"ALARM CONTROL",
		"RADAR & BASE PERIMETER",
		"steel_dark",
		"beacon_red",
		"+Z",
		22,
		13,
		Color(1.0, 0.88, 0.82)
	)

	_alarm_label_3d = Label3D.new()
	_alarm_label_3d.name = "AlarmLabel3D"
	_alarm_label_3d.position = pos + Vector3(0, 2.0, 0)
	_alarm_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alarm_label_3d.font_size = 28
	_alarm_label_3d.outline_size = 6
	_alarm_label_3d.modulate = Color(1.0, 0.85, 0.2)
	_alarm_label_3d.text = "[E] DISABLE SECURITY ALARM"
	console.add_child(_alarm_label_3d)

	var area := Area3D.new()
	area.name = "AlarmInteractionArea"
	area.position = pos + Vector3(0, 1.0, 0)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACTION_RADIUS
	col.shape = shape
	area.add_child(col)
	console.add_child(area)

	_build_alarm_audio(console, pos)


func _build_alarm_audio(parent: Node3D, pos: Vector3) -> void:
	_alarm_audio_player = AudioStreamPlayer3D.new()
	_alarm_audio_player.name = "AlarmSirenAudio3D"
	_alarm_audio_player.position = pos + Vector3(0, 3.0, 0)
	_alarm_audio_player.unit_size = 20.0
	_alarm_audio_player.max_distance = 300.0
	_alarm_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	_alarm_audio_player.bus = "Master"
	_alarm_audio_player.stream = _get_alarm_siren_stream()
	_alarm_audio_player.autoplay = false
	parent.add_child(_alarm_audio_player)


func _get_alarm_siren_stream() -> AudioStream:
	if _cached_alarm_stream:
		return _cached_alarm_stream

	for path in ALARM_SIREN_CUSTOM_PATHS:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
					stream.loop_end = stream.data.size()
				elif stream is AudioStreamOggVorbis:
					stream.loop = true
				elif stream is AudioStreamMP3:
					stream.loop = true
				print("[Stage07IronHarbor] Loaded custom siren audio: %s" % path)
				_cached_alarm_stream = stream
				return _cached_alarm_stream

	print("[Stage07IronHarbor] Using procedural synthesized emergency siren.")
	_cached_alarm_stream = _synthesize_alarm_siren()
	return _cached_alarm_stream


func _synthesize_alarm_siren() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.0
	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Smooth continuous frequency oscillation between 540 Hz and 900 Hz in a 2-second cycle
		var cycle: float = sin(t / duration * TAU)
		var freq: float = 720.0 + 180.0 * cycle
		phase += (freq / float(sample_rate)) * TAU
		var sample_val: float = sin(phase) * 0.42
		# Add third harmonic for authentic industrial klaxon timbre
		sample_val += sin(phase * 3.0) * 0.12
		sample_val = clampf(sample_val, -1.0, 1.0)
		var byte_val: int = int((sample_val * 0.5 + 0.5) * 255.0)
		data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	stream.data = data
	return stream


func _start_alarm_audio() -> void:
	if is_alarm_disabled or is_cinematic_playing:
		return
	if _alarm_audio_player and not _alarm_audio_player.playing:
		_alarm_audio_player.play()
		print("[Stage07IronHarbor] Harbor security siren activated (looping).")


func _stop_alarm_audio() -> void:
	if _alarm_audio_player and _alarm_audio_player.playing:
		_alarm_audio_player.stop()
		print("[Stage07IronHarbor] Harbor security siren stopped.")


func is_alarm_audio_playing() -> bool:
	return _alarm_audio_player != null and _alarm_audio_player.playing


func get_alarm_audio_player() -> AudioStreamPlayer3D:
	return _alarm_audio_player


func _build_data_terminal(parent: Node3D) -> void:
	var terminal := _group(parent, "DataTerminal")
	var pos := data_terminal_position

	_box(terminal, "TerminalRack", pos + Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 1.0), "steel_dark")
	_box(terminal, "TerminalScreen", pos + Vector3(0, 1.3, 0.51), Vector3(0.9, 0.65, 0.08), "glass")
	_box(terminal, "AccessDeck", pos + Vector3(0, 0.85, 0.6), Vector3(1.0, 0.15, 0.4), "steel")

	_terminal_status_mesh = _box(terminal, "TerminalStatusLight", pos + Vector3(0, 2.35, 0), Vector3(0.4, 0.3, 0.4), "beacon_red", false)

	# Intel Terminal Equipment Tag — Mounted flush on upper fascia facing +Z
	_physical_sign(
		terminal,
		"IntelTerminalTag",
		pos + Vector3(0, 1.95, 0.52),
		Vector3(1.15, 0.32, 0.04),
		"INTEL TERMINAL",
		"TACTICAL DATA ARCHIVE",
		"steel_dark",
		"yellow",
		"+Z",
		24,
		14,
		Color(0.85, 0.95, 1.0)
	)

	_terminal_label_3d = Label3D.new()
	_terminal_label_3d.name = "TerminalLabel3D"
	_terminal_label_3d.position = pos + Vector3(0, 2.8, 0)
	_terminal_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_terminal_label_3d.font_size = 28
	_terminal_label_3d.outline_size = 6
	_terminal_label_3d.modulate = Color(1.0, 0.4, 0.2)
	_terminal_label_3d.text = "[LOCKED] DISABLE ALARM FIRST"
	terminal.add_child(_terminal_label_3d)

	var area := Area3D.new()
	area.name = "DataInteractionArea"
	area.position = pos + Vector3(0, 1.0, 0)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACTION_RADIUS
	col.shape = shape
	area.add_child(col)
	terminal.add_child(area)


func _build_extraction_trigger(parent: Node3D) -> void:
	var center := lz_charlie_position

	var extract_area := Area3D.new()
	extract_area.name = "ExtractionArea"
	extract_area.position = center + Vector3(0, 2.0, 0)
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(20.0, 4.0, 20.0)
	col_shape.shape = box_shape
	extract_area.add_child(col_shape)
	extract_area.body_entered.connect(_on_extraction_area_body_entered)
	parent.add_child(extract_area)

	_lz_label_3d = Label3D.new()
	_lz_label_3d.name = "LZCharlieStatusLabel"
	_lz_label_3d.position = center + Vector3(0, 4.2, 0)
	_lz_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lz_label_3d.font_size = 32
	_lz_label_3d.outline_size = 8
	_lz_label_3d.modulate = Color(1.0, 0.72, 0.2)
	_lz_label_3d.text = "LZ CHARLIE // EVAC STANDBY"
	parent.add_child(_lz_label_3d)


func _build_high_mast_floodlights(parent: Node3D) -> void:
	var lights := _group(parent, "HighMastLighting")

	# 3 High-Mast Industrial Yard Lighting Towers strategically lighting the map
	var tower_positions := [
		Vector3(-14.0, 0, 36.0),  # Lights Central Highway South & Yard Alpha Entrance
		Vector3(14.0, 0, -10.0),  # Lights Command Compound Approach & Yard Bravo
		Vector3(-18.0, 0, -42.0)  # Lights Warehouse North Loading Dock & Helipad Approach
	]

	for idx in range(tower_positions.size()):
		var base_pos: Vector3 = tower_positions[idx]
		var mast_height := 16.0

		# 4-Legged Steel Mast
		_box(lights, "MastBase", base_pos + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2), "concrete")
		_box(lights, "MastPylon", base_pos + Vector3(0, mast_height * 0.5, 0), Vector3(0.55, mast_height, 0.55), "steel_dark")
		# Cross Head Platform
		_box(lights, "MastCrosshead", base_pos + Vector3(0, mast_height, 0), Vector3(4.8, 0.4, 1.2), "steel")

		# Floodlight Lanterns
		for x_off in [-1.8, 1.8]:
			_box(lights, "LanternHousing", base_pos + Vector3(x_off, mast_height - 0.4, 0), Vector3(0.9, 0.5, 0.9), "yellow", false)

		# Omnidirectional/Spot Industrial Floodlight
		var flood := OmniLight3D.new()
		flood.name = "MastFloodlight_%d" % (idx + 1)
		flood.position = base_pos + Vector3(0, mast_height - 0.5, 0)
		flood.light_color = Color(0.98, 0.94, 0.86)
		flood.light_energy = 4.2
		flood.omni_range = 38.0
		flood.omni_attenuation = 0.92
		flood.shadow_enabled = false
		lights.add_child(flood)


# ------------------------------------------------------------------------------
# HELPER CONSTRUCTORS & CACHING
# ------------------------------------------------------------------------------

func _add_mat(mat_name: String, albedo: Color, rough: float, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_energy: float = 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_energy
	_materials[mat_name] = m


func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat_name: String, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)

	var mesh_key := "%0.2f:%0.2f:%0.2f:%s" % [size.x, size.y, size.z, mat_name]
	if not _box_mesh_cache.has(mesh_key):
		var b_mesh := BoxMesh.new()
		b_mesh.size = size
		b_mesh.material = _materials.get(mat_name)
		_box_mesh_cache[mesh_key] = b_mesh

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh_cache[mesh_key]
	root.add_child(mi)

	if collision:
		var shape_key := "%0.2f:%0.2f:%0.2f" % [size.x, size.y, size.z]
		if not _box_shape_cache.has(shape_key):
			var b_shape := BoxShape3D.new()
			b_shape.size = size
			_box_shape_cache[shape_key] = b_shape
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = _box_shape_cache[shape_key]
		root.add_child(cs)

	return root


func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat_name: String, rot_deg: Vector3 = Vector3.ZERO, collision: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees = rot_deg
	parent.add_child(root)

	var mesh_key := "%0.2f:%0.2f:%s" % [radius, height, mat_name]
	if not _cyl_mesh_cache.has(mesh_key):
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = radius
		c_mesh.bottom_radius = radius
		c_mesh.height = height
		c_mesh.radial_segments = 16
		c_mesh.material = _materials.get(mat_name)
		_cyl_mesh_cache[mesh_key] = c_mesh

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _cyl_mesh_cache[mesh_key]
	root.add_child(mi)

	if collision:
		var shape_key := "%0.2f:%0.2f" % [radius, height]
		if not _cyl_shape_cache.has(shape_key):
			var c_shape := CylinderShape3D.new()
			c_shape.radius = radius
			c_shape.height = height
			_cyl_shape_cache[shape_key] = c_shape
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		cs.shape = _cyl_shape_cache[shape_key]
		root.add_child(cs)

	return root


func _physical_sign(
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	size: Vector3,
	primary_text: String,
	sub_text: String = "",
	board_mat: String = "steel_dark",
	border_mat: String = "yellow",
	facing: String = "+Z",
	font_size: int = 34,
	sub_font_size: int = 20,
	text_color: Color = Color(0.96, 0.94, 0.88),
	ground_posts: bool = false
) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)

	# Physical Backing Board
	_box(root, "BackingBoard", Vector3.ZERO, size, board_mat, false)

	# Structural Accent Borders / Hazard Trim
	if not border_mat.is_empty():
		var strip_thick := 0.04
		if facing in ["+Z", "-Z"]:
			_box(root, "BorderTop", Vector3(0, size.y * 0.5 - strip_thick * 0.5, 0), Vector3(size.x, strip_thick, size.z * 1.04), border_mat, false)
			_box(root, "BorderBottom", Vector3(0, -size.y * 0.5 + strip_thick * 0.5, 0), Vector3(size.x, strip_thick, size.z * 1.04), border_mat, false)
		elif facing in ["+X", "-X"]:
			_box(root, "BorderTop", Vector3(0, size.y * 0.5 - strip_thick * 0.5, 0), Vector3(size.x * 1.04, strip_thick, size.z), border_mat, false)
			_box(root, "BorderBottom", Vector3(0, -size.y * 0.5 + strip_thick * 0.5, 0), Vector3(size.x * 1.04, strip_thick, size.z), border_mat, false)

	# Support Stanchions for Ground-Anchored Signs
	if ground_posts:
		var post_height := pos.y
		var post_offset_x := size.x * 0.38
		var p_left := Vector3(-post_offset_x, -pos.y * 0.5, 0)
		var p_right := Vector3(post_offset_x, -pos.y * 0.5, 0)
		_box(root, "StanchionLeft", p_left, Vector3(0.14, post_height, 0.14), "steel_dark", true)
		_box(root, "StanchionRight", p_right, Vector3(0.14, post_height, 0.14), "steel_dark", true)

	# Text orientation & surface flush offset
	var label_rot := Vector3.ZERO
	var label_offset := Vector3.ZERO
	var y_offset := 0.0
	var sub_y_offset := 0.0

	if not sub_text.is_empty():
		y_offset = size.y * 0.18
		sub_y_offset = -size.y * 0.22

	match facing:
		"+Z":
			label_rot = Vector3.ZERO
			label_offset = Vector3(0, 0, size.z * 0.5 + 0.02)
		"-Z":
			label_rot = Vector3(0, 180, 0)
			label_offset = Vector3(0, 0, -size.z * 0.5 - 0.02)
		"+X":
			label_rot = Vector3(0, 90, 0)
			label_offset = Vector3(size.x * 0.5 + 0.02, 0, 0)
		"-X":
			label_rot = Vector3(0, -90, 0)
			label_offset = Vector3(-size.x * 0.5 - 0.02, 0, 0)

	var main_lbl := Label3D.new()
	main_lbl.name = "PrimaryText"
	main_lbl.position = label_offset + Vector3(0, y_offset, 0)
	main_lbl.rotation_degrees = label_rot
	main_lbl.text = primary_text
	main_lbl.font_size = font_size
	main_lbl.pixel_size = 0.005
	main_lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	main_lbl.double_sided = false
	main_lbl.outline_size = 8
	main_lbl.outline_modulate = Color(0.04, 0.05, 0.06, 0.95)
	main_lbl.modulate = text_color
	root.add_child(main_lbl)

	if not sub_text.is_empty():
		var sub_lbl := Label3D.new()
		sub_lbl.name = "SubText"
		sub_lbl.position = label_offset + Vector3(0, sub_y_offset, 0)
		sub_lbl.rotation_degrees = label_rot
		sub_lbl.text = sub_text
		sub_lbl.font_size = sub_font_size
		sub_lbl.pixel_size = 0.005
		sub_lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sub_lbl.double_sided = false
		sub_lbl.outline_size = 6
		sub_lbl.outline_modulate = Color(0.04, 0.05, 0.06, 0.95)
		sub_lbl.modulate = Color(0.42, 0.82, 0.96)
		root.add_child(sub_lbl)

	return root


func _sign(parent: Node3D, node_name: String, pos: Vector3, text: String, _horizontal: bool) -> void:
	_physical_sign(parent, node_name, pos, Vector3(8.0, 1.2, 0.1), text, "", "steel_dark", "yellow", "+Z", 34)
