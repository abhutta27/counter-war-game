extends Node
## Versioned, offline persistence for isolated local operative profiles.

signal profile_loaded(profile: Dictionary)
signal profile_saved(profile: Dictionary)
signal profile_changed(profile: Dictionary)
signal profile_invalid()

const SAVE_VERSION: int = 2
const LEGACY_SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://counter_war_profile.json"
const MAX_NAME_LENGTH: int = 24
const TOTAL_STAGES: int = 8

var current_profile: Dictionary = {}
var save_path: String = SAVE_PATH
var _profiles: Dictionary = {}
var _active_profile_id: String = ""
var _loaded_save_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()

func has_valid_profile() -> bool:
	return _is_valid_profile(current_profile)

func get_profile() -> Dictionary:
	return current_profile.duplicate(true)

func get_active_profile_id() -> String:
	return _active_profile_id

func get_profile_names() -> Array[String]:
	var names: Array[String] = []
	for profile_id in _profiles:
		var profile: Variant = _profiles[profile_id]
		if _is_valid_profile(profile):
			names.append(str(profile.get("player_name", "")))
	names.sort_custom(func(a: String, b: String): return a.naturalnocasecmp_to(b) < 0)
	return names

func get_profile_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for profile_id in _profiles:
		var profile: Variant = _profiles[profile_id]
		if _is_valid_profile(profile):
			entries.append({
				"profile_id": str(profile_id),
				"player_name": str(profile.get("player_name", ""))
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary):
		return str(a.get("player_name", "")).naturalnocasecmp_to(str(b.get("player_name", ""))) < 0
	)
	return entries

func has_profile_named(raw_name: String) -> bool:
	var clean_name := sanitize_player_name(raw_name)
	return not clean_name.is_empty() and not _find_profile_id_by_name(clean_name).is_empty()

func switch_profile(profile_id: String) -> bool:
	if profile_id.is_empty() or not _profiles.has(profile_id):
		return false
	var candidate: Variant = _profiles[profile_id]
	if not _is_valid_profile(candidate):
		return false
	var previous_profiles := _profiles.duplicate(true)
	var previous_active_id := _active_profile_id
	var previous_profile := current_profile.duplicate(true)
	_active_profile_id = profile_id
	current_profile = _normalize_profile(candidate, profile_id)
	if not save_profile():
		_profiles = previous_profiles
		_active_profile_id = previous_active_id
		current_profile = previous_profile
		return false
	profile_changed.emit(get_profile())
	return true

func create_new_profile(raw_name: String) -> bool:
	var clean_name := sanitize_player_name(raw_name)
	if clean_name.is_empty() or has_profile_named(clean_name):
		return false
	var previous_profiles := _profiles.duplicate(true)
	var previous_active_id := _active_profile_id
	var previous_profile := current_profile.duplicate(true)
	var profile_id := _generate_profile_id()
	_profiles[profile_id] = _new_profile(profile_id, clean_name)
	_active_profile_id = profile_id
	current_profile = _normalize_profile(_profiles[profile_id], profile_id)
	if not save_profile():
		_profiles = previous_profiles
		_active_profile_id = previous_active_id
		current_profile = previous_profile
		return false
	profile_changed.emit(get_profile())
	return true

func get_player_name() -> String:
	return str(current_profile.get("player_name", "")) if has_valid_profile() else ""

func get_highest_unlocked_stage() -> int:
	return clampi(int(current_profile.get("highest_unlocked_stage", 1)), 1, TOTAL_STAGES)

func get_best_score(stage_id: int) -> int:
	var scores: Dictionary = current_profile.get("best_scores", {})
	return maxi(0, int(scores.get(str(clampi(stage_id, 1, TOTAL_STAGES)), 0)))

func get_highest_score() -> int:
	return maxi(0, int(current_profile.get("highest_score", 0)))

func get_career_score() -> int:
	return maxi(0, int(current_profile.get("career_score", 0)))

func load_profile() -> bool:
	_loaded_save_path = save_path
	_clear_runtime_profiles()
	if not FileAccess.file_exists(save_path):
		profile_invalid.emit()
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		profile_invalid.emit()
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[ProfileManager] Local profile JSON is corrupt; identity entry is required.")
		profile_invalid.emit()
		return false
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		profile_invalid.emit()
		return false

	var migrated := false
	if int(parsed.get("save_version", 0)) == LEGACY_SAVE_VERSION and _is_valid_profile(parsed):
		_migrate_legacy_profile(parsed)
		migrated = true
	elif int(parsed.get("save_version", 0)) == SAVE_VERSION:
		_load_profile_registry(parsed)
	else:
		push_warning("[ProfileManager] Local profile is missing or corrupt; identity entry is required.")
		profile_invalid.emit()
		return false

	if not has_valid_profile():
		_clear_runtime_profiles()
		profile_invalid.emit()
		return false

	if migrated and not save_profile():
		return false
	profile_loaded.emit(get_profile())
	profile_changed.emit(get_profile())
	return true

## Compatibility entry point: identity submission now means switch to an existing
## operative or create a new isolated operative; it never renames another record.
func create_or_update_profile(raw_name: String) -> bool:
	return create_or_switch_profile(raw_name)

func create_or_switch_profile(raw_name: String) -> bool:
	var clean_name := sanitize_player_name(raw_name)
	if clean_name.is_empty():
		return false

	var matching_id := _find_profile_id_by_name(clean_name)
	if matching_id.is_empty():
		matching_id = _generate_profile_id()
		_profiles[matching_id] = _new_profile(matching_id, clean_name)
	_active_profile_id = matching_id
	current_profile = _normalize_profile(_profiles[matching_id], matching_id)
	if not save_profile():
		return false
	profile_changed.emit(get_profile())
	return true

func rename_current_profile(raw_name: String) -> bool:
	if not has_valid_profile() or _active_profile_id.is_empty():
		return false
	var clean_name := sanitize_player_name(raw_name)
	if clean_name.is_empty():
		return false
	var matching_id := _find_profile_id_by_name(clean_name)
	if not matching_id.is_empty() and matching_id != _active_profile_id:
		return false
	current_profile["player_name"] = clean_name
	if not save_profile():
		return false
	profile_changed.emit(get_profile())
	return true

func save_profile() -> bool:
	if not _is_valid_profile(current_profile):
		return false
	# Tests and tooling redirect save_path to isolated files. Never carry registry
	# entries from a previously loaded file into the new destination.
	if _loaded_save_path != save_path:
		_profiles = {}
		_active_profile_id = str(current_profile.get("profile_id", ""))
		_loaded_save_path = save_path
	if _active_profile_id.is_empty():
		_active_profile_id = str(current_profile.get("profile_id", ""))
	if _active_profile_id.is_empty():
		_active_profile_id = _generate_profile_id()
	current_profile = _normalize_profile(current_profile, _active_profile_id)
	_profiles[_active_profile_id] = current_profile.duplicate(true)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[ProfileManager] Unable to open local profile for writing: %s" % save_path)
		return false
	file.store_string(JSON.stringify({
		"save_version": SAVE_VERSION,
		"active_profile_id": _active_profile_id,
		"profiles": _profiles
	}, "\t"))
	file.flush()
	profile_saved.emit(get_profile())
	return true

func set_last_played_stage(stage_id: int) -> void:
	if not has_valid_profile():
		return
	var safe_stage := clampi(stage_id, 1, get_highest_unlocked_stage())
	if int(current_profile.get("last_played_stage", 1)) == safe_stage:
		return
	current_profile["last_played_stage"] = safe_stage
	save_profile()

func record_stage_completed(stage_id: int) -> void:
	if not has_valid_profile():
		return
	var safe_stage := clampi(stage_id, 1, TOTAL_STAGES)
	var completed: Array = current_profile.get("completed_stages", [])
	if not completed.has(safe_stage):
		completed.append(safe_stage)
		completed.sort()
	current_profile["completed_stages"] = completed
	current_profile["highest_unlocked_stage"] = maxi(
		get_highest_unlocked_stage(),
		mini(safe_stage + 1, TOTAL_STAGES)
	)
	current_profile["last_played_stage"] = safe_stage
	save_profile()

func record_stage_score(stage_id: int, mission_score: int) -> Dictionary:
	var safe_stage := clampi(stage_id, 1, TOTAL_STAGES)
	var safe_score := maxi(0, mission_score)
	var previous_best := get_best_score(safe_stage)
	var is_new_best := safe_score > previous_best
	if has_valid_profile() and is_new_best:
		var scores: Dictionary = current_profile.get("best_scores", {}).duplicate(true)
		scores[str(safe_stage)] = safe_score
		current_profile["best_scores"] = scores
		_recalculate_score_totals()
		save_profile()
	return {
		"stage_id": safe_stage,
		"mission_score": safe_score,
		"previous_best": previous_best,
		"best_score": safe_score if is_new_best else previous_best,
		"is_new_best": is_new_best,
		"highest_score": get_highest_score(),
		"career_score": get_career_score()
	}

func sanitize_player_name(raw_name: String) -> String:
	var clean_name := raw_name.strip_edges()
	if clean_name.length() > MAX_NAME_LENGTH:
		clean_name = clean_name.left(MAX_NAME_LENGTH)
	return clean_name

func _is_valid_profile(profile: Variant) -> bool:
	return profile is Dictionary \
		and not sanitize_player_name(str(profile.get("player_name", ""))).is_empty()

func _new_profile(profile_id: String, player_name: String) -> Dictionary:
	return {
		"profile_id": profile_id,
		"player_name": sanitize_player_name(player_name),
		"highest_unlocked_stage": 1,
		"completed_stages": [],
		"best_scores": {},
		"highest_score": 0,
		"career_score": 0,
		"last_played_stage": 1
	}

func _normalize_profile(source: Dictionary, fallback_id: String = "") -> Dictionary:
	var completed: Array = []
	var source_completed: Variant = source.get("completed_stages", [])
	if source_completed is Array:
		for value in source_completed:
			var stage_id := int(value)
			if stage_id >= 1 and stage_id <= TOTAL_STAGES and not completed.has(stage_id):
				completed.append(stage_id)
		completed.sort()

	var scores: Dictionary = {}
	if source.get("best_scores", {}) is Dictionary:
		for key in source.get("best_scores", {}):
			var stage_id := int(str(key))
			var score := maxi(0, int(source.get("best_scores", {})[key]))
			if stage_id >= 1 and stage_id <= TOTAL_STAGES and score > 0:
				scores[str(stage_id)] = score
	var career_score := 0
	var highest_score := 0
	for score in scores.values():
		career_score += int(score)
		highest_score = maxi(highest_score, int(score))
	var highest_unlocked := clampi(int(source.get("highest_unlocked_stage", 1)), 1, TOTAL_STAGES)
	for completed_stage in completed:
		highest_unlocked = maxi(highest_unlocked, mini(int(completed_stage) + 1, TOTAL_STAGES))
	var profile_id := str(source.get("profile_id", fallback_id))
	return {
		"profile_id": profile_id,
		"player_name": sanitize_player_name(str(source.get("player_name", ""))),
		"highest_unlocked_stage": highest_unlocked,
		"completed_stages": completed,
		"best_scores": scores,
		"highest_score": highest_score,
		"career_score": career_score,
		"last_played_stage": clampi(int(source.get("last_played_stage", 1)), 1, highest_unlocked)
	}

func _load_profile_registry(container: Dictionary) -> void:
	var source_profiles: Variant = container.get("profiles", {})
	if not source_profiles is Dictionary:
		return
	for source_id in source_profiles:
		var profile_id := str(source_id)
		var profile: Variant = source_profiles[source_id]
		if _is_valid_profile(profile):
			_profiles[profile_id] = _normalize_profile(profile, profile_id)
	_active_profile_id = str(container.get("active_profile_id", ""))
	if not _profiles.has(_active_profile_id) and not _profiles.is_empty():
		_active_profile_id = str(_profiles.keys()[0])
	if _profiles.has(_active_profile_id):
		current_profile = _profiles[_active_profile_id].duplicate(true)

func _migrate_legacy_profile(legacy: Dictionary) -> void:
	var profile_id := _generate_profile_id()
	_active_profile_id = profile_id
	current_profile = _normalize_profile(legacy, profile_id)
	_profiles[profile_id] = current_profile.duplicate(true)

func _find_profile_id_by_name(player_name: String) -> String:
	var folded := player_name.to_lower()
	for profile_id in _profiles:
		var profile: Dictionary = _profiles[profile_id]
		if str(profile.get("player_name", "")).to_lower() == folded:
			return str(profile_id)
	return ""

func _generate_profile_id() -> String:
	var candidate := "operative_%d_%d" % [Time.get_ticks_usec(), randi()]
	while _profiles.has(candidate):
		candidate = "operative_%d_%d" % [Time.get_ticks_usec(), randi()]
	return candidate

func _clear_runtime_profiles() -> void:
	current_profile = {}
	_profiles = {}
	_active_profile_id = ""

func _recalculate_score_totals() -> void:
	var career_score := 0
	var highest_score := 0
	var scores: Dictionary = current_profile.get("best_scores", {})
	for score in scores.values():
		var safe_score := maxi(0, int(score))
		career_score += safe_score
		highest_score = maxi(highest_score, safe_score)
	current_profile["career_score"] = career_score
	current_profile["highest_score"] = highest_score
