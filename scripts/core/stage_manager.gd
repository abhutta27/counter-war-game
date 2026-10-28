extends Node
## Central campaign catalog and guarded stage-loading coordinator.

const GameConstants = preload("res://scripts/utilities/constants.gd")

signal stage_loaded(stage_id: int, stage_info: Dictionary)
signal stage_completed(stage_id: int)
signal stage_restarted(stage_id: int)

const OPERATION_REGISTRY: Dictionary = {
	1: {"operation_id": 1, "title": "OPERATION I"},
	2: {"operation_id": 2, "title": "OPERATION II"},
	3: {"operation_id": 3, "title": "OPERATION III"}
}

# This is the single authoritative catalog for every real mission.
const STAGE_REGISTRY: Dictionary = {
	1: {
		"stage_id": 1, "id": 1,
		"mission_title": "OPERATION DESERT OUTPOST", "name": "OPERATION DESERT OUTPOST",
		"desc": "Arid Perimeter Outpost Neutralization", "operation_id": 1,
		"scene_path": "res://scenes/stages/Stage01.tscn", "fallback_path": "res://scenes/Level1.tscn"
	},
	2: {
		"stage_id": 2, "id": 2,
		"mission_title": "OPERATION ABANDONED CITY", "name": "OPERATION ABANDONED CITY",
		"desc": "Ruined Urban Sector Clearance", "operation_id": 1,
		"scene_path": "res://scenes/stages/Stage02.tscn", "fallback_path": "res://scenes/stages/Stage02.tscn"
	},
	3: {
		"stage_id": 3, "id": 3,
		"mission_title": "OPERATION FOREST CAMP", "name": "OPERATION FOREST CAMP",
		"desc": "Dense Woodlands Military Base Infiltration", "operation_id": 1,
		"scene_path": "res://scenes/stages/Stage03.tscn", "fallback_path": "res://scenes/stages/Stage03.tscn"
	},
	4: {
		"stage_id": 4, "id": 4,
		"mission_title": "OPERATION INDUSTRIAL ZONE", "name": "OPERATION INDUSTRIAL ZONE",
		"desc": "Factory Complex & Cargo Depot Assault", "operation_id": 1,
		"scene_path": "res://scenes/stages/Stage04.tscn", "fallback_path": "res://scenes/stages/Stage04.tscn"
	},
	5: {
		"stage_id": 5, "id": 5,
		"mission_title": "OPERATION MOUNTAIN BASE", "name": "OPERATION MOUNTAIN BASE",
		"desc": "Alpine Canyon Checkpoint & Peak Fortification", "operation_id": 1,
		"scene_path": "res://scenes/stages/Stage05.tscn", "fallback_path": "res://scenes/stages/Stage05.tscn"
	},
	6: {
		"stage_id": 6, "id": 6,
		"mission_title": "OPERATION NIGHT MILITARY BASE", "name": "OPERATION NIGHT MILITARY BASE",
		"desc": "Black-Ops Night Facility Infiltration", "operation_id": 2,
		"scene_path": "res://scenes/stages/Stage06.tscn", "fallback_path": "res://scenes/stages/Stage06.tscn"
	},
	7: {
		"stage_id": 7, "id": 7,
		"mission_title": "OPERATION IRON HARBOR", "name": "OPERATION IRON HARBOR",
		"desc": "Coastal Cargo Port Infiltration", "operation_id": 3,
		"scene_path": "res://scenes/stages/Stage07.tscn", "fallback_path": "res://scenes/stages/Stage07.tscn"
	}
}

const TOTAL_STAGES: int = 7

var current_stage_id: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var profile_manager = get_node_or_null("/root/ProfileManager")
	if profile_manager and profile_manager.has_signal("profile_changed"):
		profile_manager.profile_changed.connect(_on_profile_changed)
		_on_profile_changed(profile_manager.get_profile())
	print("[StageManager] Initialized with %d registered stages." % STAGE_REGISTRY.size())

func _on_profile_changed(profile: Dictionary) -> void:
	if profile.is_empty():
		current_stage_id = 1
		return
	var highest_unlocked := clampi(int(profile.get("highest_unlocked_stage", 1)), 1, TOTAL_STAGES)
	current_stage_id = clampi(int(profile.get("last_played_stage", 1)), 1, highest_unlocked)
	get_tree().set_meta("selected_stage_id", current_stage_id)
	if get_tree().has_meta("hq_return_stage_id"):
		get_tree().remove_meta("hq_return_stage_id")

func get_current_stage_id() -> int:
	return current_stage_id

func set_current_stage_id(stage_id: int) -> void:
	if not STAGE_REGISTRY.has(stage_id):
		push_warning("[StageManager] Ignoring unknown current Stage ID: %d" % stage_id)
		return
	current_stage_id = stage_id
	get_tree().set_meta("selected_stage_id", stage_id)
	var profile_manager = get_node_or_null("/root/ProfileManager")
	if profile_manager and profile_manager.has_method("set_last_played_stage"):
		profile_manager.set_last_played_stage(stage_id)

func get_registered_stage_ids() -> Array[int]:
	var ids: Array[int] = []
	for stage_id in STAGE_REGISTRY.keys():
		ids.append(int(stage_id))
	ids.sort()
	return ids

func get_operation_ids() -> Array[int]:
	var ids: Array[int] = []
	for operation_id in OPERATION_REGISTRY.keys():
		ids.append(int(operation_id))
	ids.sort()
	return ids

func get_operation_info(operation_id: int) -> Dictionary:
	if not OPERATION_REGISTRY.has(operation_id):
		return {}
	return OPERATION_REGISTRY[operation_id].duplicate(true)

func get_stages_for_operation(operation_id: int) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	for stage_id in get_registered_stage_ids():
		var info := get_stage_info(stage_id)
		if int(info.get("operation_id", -1)) == operation_id:
			stages.append(info)
	return stages

func get_stage_info(stage_id: int) -> Dictionary:
	if not STAGE_REGISTRY.has(stage_id):
		return {}
	return STAGE_REGISTRY[stage_id].duplicate(true)

func is_stage_unlocked(stage_id: int) -> bool:
	if not STAGE_REGISTRY.has(stage_id):
		return false
	var profile_manager = get_node_or_null("/root/ProfileManager")
	return profile_manager != null \
		and profile_manager.has_method("has_valid_profile") \
		and profile_manager.has_valid_profile() \
		and stage_id <= profile_manager.get_highest_unlocked_stage()

func get_next_registered_stage_id(stage_id: int) -> int:
	for registered_id in get_registered_stage_ids():
		if registered_id > stage_id:
			return registered_id
	return -1

func load_stage(stage_id: int) -> bool:
	return _load_stage_internal(stage_id, false)

## Debug-only bypass used by isolated automated stage tests. Production callers
## must use load_stage(), which always enforces profile progression.
func load_stage_for_testing(stage_id: int) -> bool:
	if not OS.is_debug_build():
		push_error("[StageManager] Test-only stage loading is unavailable in release builds.")
		return false
	return _load_stage_internal(stage_id, true)

func _load_stage_internal(stage_id: int, bypass_progression: bool) -> bool:
	if not STAGE_REGISTRY.has(stage_id):
		push_warning("[StageManager] Rejected unknown Stage ID: %d" % stage_id)
		return false
	if not bypass_progression and not is_stage_unlocked(stage_id):
		push_warning("[StageManager] Rejected locked Stage ID: %d" % stage_id)
		return false

	var info := get_stage_info(stage_id)
	var path_to_load: String = str(info.get("scene_path", ""))
	if not ResourceLoader.exists(path_to_load):
		var fallback: String = str(info.get("fallback_path", ""))
		if not ResourceLoader.exists(fallback):
			push_error("[StageManager] No loadable scene for Stage %d." % stage_id)
			return false
		path_to_load = fallback

	# Mutate campaign state only after all validation succeeds.
	set_current_stage_id(stage_id)
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager and sound_manager.has_method("stop_all"):
		sound_manager.stop_all()
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("change_state"):
		if game_manager.current_state != GameConstants.GameState.PLAYING:
			game_manager.change_state(GameConstants.GameState.PLAYING)

	print("[StageManager] Loading Stage %d -> %s" % [stage_id, path_to_load])
	var err := get_tree().change_scene_to_file(path_to_load)
	if err != OK:
		push_error("[StageManager] Failed to load scene: %s (Error: %d)" % [path_to_load, err])
		return false
	stage_loaded.emit(stage_id, info)
	return true

func load_next_stage() -> bool:
	var next_id := get_next_registered_stage_id(current_stage_id)
	if next_id < 0:
		print("[StageManager] Campaign complete; no stage follows Stage %d." % current_stage_id)
		return false
	return load_stage(next_id)

func load_next_stage_for_testing() -> bool:
	if not OS.is_debug_build():
		return false
	var next_id := get_next_registered_stage_id(current_stage_id)
	return next_id >= 0 and load_stage_for_testing(next_id)

func restart_current_stage() -> bool:
	if not STAGE_REGISTRY.has(current_stage_id):
		return false
	print("[StageManager] Restarting Current Stage: %d" % current_stage_id)
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager and sound_manager.has_method("stop_all"):
		sound_manager.stop_all()
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("change_state"):
		game_manager.change_state(GameConstants.GameState.PLAYING)
	stage_restarted.emit(current_stage_id)
	if get_tree().current_scene:
		get_tree().reload_current_scene()
		return true
	return load_stage(current_stage_id)
