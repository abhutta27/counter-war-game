extends Control
## Compact Operations HQ: profile summary, mission browser, dossier details,
## and one guarded deploy/replay action.

const MissionRowScene = preload("res://scenes/ui/OperationStageCard.tscn")
const MissionRowScript = preload("res://scripts/ui/OperationStageCard.gd")
const GameConstants = preload("res://scripts/utilities/constants.gd")

@onready var codename_label: Label = $SafeMargin/HQPanel/Content/Header/HeaderRow/ProfileSummary/Codename
@onready var campaign_label: Label = $SafeMargin/HQPanel/Content/Header/HeaderRow/ProfileSummary/Campaign
@onready var highest_score_label: Label = $SafeMargin/HQPanel/Content/Header/HeaderRow/HighestScore/Value
@onready var career_score_label: Label = $SafeMargin/HQPanel/Content/Header/HeaderRow/CareerScore/Value
@onready var switch_button: Button = $SafeMargin/HQPanel/Content/Header/HeaderRow/HeaderActions/SwitchButton
@onready var refresh_button: Button = $SafeMargin/HQPanel/Content/Header/HeaderRow/HeaderActions/RefreshButton
@onready var missions_container: VBoxContainer = $SafeMargin/HQPanel/Content/MainSplit/MissionPanel/MissionMargin/MissionColumn/MissionScroll/MissionRows
@onready var stage_code_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/StageLine/StageCode
@onready var detail_status_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/StageLine/Status
@onready var detail_title_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/MissionTitle
@onready var briefing_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/Briefing
@onready var detail_best_score_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/ScoreRow/BestValue
@onready var unlock_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/DetailsScroll/Details/UnlockRequirement
@onready var action_button: Button = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/ActionButton
@onready var feedback_label: Label = $SafeMargin/HQPanel/Content/MainSplit/DetailsPanel/DetailsMargin/DetailsColumn/Feedback
@onready var controls_button: Button = $SafeMargin/HQPanel/Content/Footer/ControlsButton
@onready var controls_overlay: Control = $ControlsOverlay
@onready var controls_label: Label = $ControlsOverlay/Center/Panel/Margin/Content/ControlsLabel
@onready var controls_close_button: Button = $ControlsOverlay/Center/Panel/Margin/Content/CloseButton
@onready var exit_button: Button = $SafeMargin/HQPanel/Content/Footer/ExitButton

var _mission_rows: Array[Node] = []
var _selected_stage_id: int = -1
var _profile_snapshot: Dictionary = {}

func _ready() -> void:
	_prepare_hq_input()
	switch_button.pressed.connect(_on_switch_operative_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	action_button.pressed.connect(_on_action_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	controls_close_button.pressed.connect(_on_controls_close_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	if not ProfileManager.profile_saved.is_connected(_on_profile_saved):
		ProfileManager.profile_saved.connect(_on_profile_saved)
	controls_overlay.visible = false
	refresh_from_profile()

func _input(event: InputEvent) -> void:
	if not controls_overlay.visible:
		return
	var is_escape: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if event.is_action_pressed("pause") or is_escape:
		_on_controls_close_pressed()
		get_viewport().set_input_as_handled()

func refresh_from_profile(preferred_stage_id: int = -1) -> void:
	if not ProfileManager.has_valid_profile():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/IdentityScreen.tscn")
		return
	_profile_snapshot = ProfileManager.get_profile()
	_update_header()
	_build_mission_rows()
	var initial_stage := preferred_stage_id
	if initial_stage < 1:
		initial_stage = _determine_initial_stage()
	if not _is_valid_initial_selection(initial_stage):
		initial_stage = _get_safe_available_stage()
	_select_stage(initial_stage)

func _update_header() -> void:
	var highest_unlocked := ProfileManager.get_highest_unlocked_stage()
	var completed: Array = _profile_snapshot.get("completed_stages", [])
	codename_label.text = "CODENAME  %s" % ProfileManager.get_player_name().to_upper()
	campaign_label.text = "CAMPAIGN COMPLETE" if _is_campaign_complete(completed) else "STAGE %02d AVAILABLE" % highest_unlocked
	highest_score_label.text = _format_score(ProfileManager.get_highest_score())
	career_score_label.text = _format_score(ProfileManager.get_career_score())

func _build_mission_rows() -> void:
	for child in missions_container.get_children():
		child.queue_free()
	_mission_rows.clear()
	var highest_unlocked := ProfileManager.get_highest_unlocked_stage()
	var completed: Array = _profile_snapshot.get("completed_stages", [])
	for operation_id in StageManager.get_operation_ids():
		var stages: Array[Dictionary] = StageManager.get_stages_for_operation(operation_id)
		if stages.is_empty():
			continue
		var operation := StageManager.get_operation_info(operation_id)
		var operation_label := Label.new()
		operation_label.text = str(operation.get("title", "OPERATION %d" % operation_id))
		operation_label.add_theme_color_override("font_color", Color(0.36, 0.77, 0.96))
		operation_label.add_theme_font_size_override("font_size", 12)
		operation_label.custom_minimum_size.y = 20.0
		operation_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		missions_container.add_child(operation_label)
		for stage_info in stages:
			var stage_id := int(stage_info.get("stage_id", -1))
			var row := MissionRowScene.instantiate()
			missions_container.add_child(row)
			row.configure(stage_info, _get_stage_status(stage_id, highest_unlocked, completed), ProfileManager.get_best_score(stage_id))
			row.mission_selected.connect(_select_stage)
			_mission_rows.append(row)

func _select_stage(stage_id: int) -> void:
	var info: Dictionary = StageManager.get_stage_info(stage_id)
	if info.is_empty():
		stage_id = _get_safe_available_stage()
		info = StageManager.get_stage_info(stage_id)
	if info.is_empty():
		return
	_selected_stage_id = stage_id
	for row in _mission_rows:
		row.set_selected(row.stage_id == stage_id)

	var status := _get_stage_status(stage_id, ProfileManager.get_highest_unlocked_stage(), _profile_snapshot.get("completed_stages", []))
	stage_code_label.text = "STAGE %02d" % stage_id
	detail_title_label.text = str(info.get("mission_title", info.get("name", "CLASSIFIED OPERATION")))
	briefing_label.text = str(info.get("desc", "Mission briefing unavailable."))
	detail_status_label.text = status
	detail_best_score_label.text = "%s PTS" % _format_score(ProfileManager.get_best_score(stage_id))
	feedback_label.text = "MISSION DOSSIER READY"
	match status:
		MissionRowScript.STATUS_COMPLETED:
			detail_status_label.modulate = Color(0.42, 0.91, 0.62)
			action_button.text = "REPLAY MISSION"
			action_button.disabled = false
			unlock_label.text = "MISSION SECURED • REPLAY AVAILABLE"
			unlock_label.modulate = Color(0.42, 0.78, 0.58)
		MissionRowScript.STATUS_AVAILABLE:
			detail_status_label.modulate = Color(0.42, 0.82, 1.0)
			action_button.text = "DEPLOY"
			action_button.disabled = false
			unlock_label.text = "CLEARED FOR DEPLOYMENT"
			unlock_label.modulate = Color(0.42, 0.75, 0.92)
		_:
			detail_status_label.modulate = Color(0.62, 0.65, 0.7)
			action_button.text = "MISSION LOCKED"
			action_button.disabled = true
			unlock_label.text = _get_unlock_requirement(stage_id)
			unlock_label.modulate = Color(0.84, 0.63, 0.32)

func _determine_initial_stage() -> int:
	if get_tree().has_meta("hq_return_stage_id"):
		var returned_stage := int(get_tree().get_meta("hq_return_stage_id"))
		get_tree().remove_meta("hq_return_stage_id")
		return returned_stage
	var completed: Array = _profile_snapshot.get("completed_stages", [])
	if _is_campaign_complete(completed):
		var last_played := int(_profile_snapshot.get("last_played_stage", 6))
		return last_played if not StageManager.get_stage_info(last_played).is_empty() else 6
	for stage_id in StageManager.get_registered_stage_ids():
		if stage_id <= ProfileManager.get_highest_unlocked_stage() and not completed.has(stage_id):
			return stage_id
	return _get_safe_available_stage()

func _is_valid_initial_selection(stage_id: int) -> bool:
	return not StageManager.get_stage_info(stage_id).is_empty() and stage_id <= ProfileManager.get_highest_unlocked_stage()

func _get_safe_available_stage() -> int:
	var fallback := 1
	var highest_unlocked := ProfileManager.get_highest_unlocked_stage()
	for stage_id in StageManager.get_registered_stage_ids():
		if stage_id <= highest_unlocked:
			fallback = stage_id
	return fallback

func _get_stage_status(stage_id: int, highest_unlocked: int, completed: Array) -> String:
	if stage_id > highest_unlocked:
		return MissionRowScript.STATUS_LOCKED
	if completed.has(stage_id):
		return MissionRowScript.STATUS_COMPLETED
	return MissionRowScript.STATUS_AVAILABLE

func _get_unlock_requirement(stage_id: int) -> String:
	var previous_id := -1
	for registered_id in StageManager.get_registered_stage_ids():
		if registered_id >= stage_id:
			break
		previous_id = registered_id
	return "COMPLETE STAGE %02d TO UNLOCK" % previous_id if previous_id > 0 else "PROGRESSION REQUIRED"

func _is_campaign_complete(completed: Array) -> bool:
	for stage_id in StageManager.get_registered_stage_ids():
		if not completed.has(stage_id):
			return false
	return true

func _on_action_pressed() -> void:
	if _selected_stage_id < 1 or action_button.disabled:
		return
	feedback_label.text = "DEPLOYING TO STAGE %02d…" % _selected_stage_id
	if not StageManager.load_stage(_selected_stage_id):
		feedback_label.text = "DEPLOYMENT BLOCKED BY CAMPAIGN PROGRESSION"

func _on_refresh_pressed() -> void:
	var keep_selected := _selected_stage_id
	feedback_label.text = "REFRESHING LOCAL DOSSIER…"
	if ProfileManager.load_profile():
		refresh_from_profile(keep_selected)
	else:
		get_tree().change_scene_to_file("res://scenes/IdentityScreen.tscn")

func _on_profile_saved(_profile: Dictionary) -> void:
	# Saves triggered during play are normally observed when this scene is rebuilt;
	# this also keeps an already-open HQ truthful without changing profile data.
	if is_inside_tree():
		refresh_from_profile(_selected_stage_id)

func _on_switch_operative_pressed() -> void:
	get_tree().set_meta("switching_operative", true)
	get_tree().change_scene_to_file("res://scenes/IdentityScreen.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_controls_pressed() -> void:
	controls_overlay.open()

func _on_controls_close_pressed() -> void:
	controls_overlay.close()
	controls_button.grab_focus()

func _prepare_hq_input() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("change_state") and game_manager.current_state != GameConstants.GameState.MAIN_MENU:
		game_manager.change_state(GameConstants.GameState.MAIN_MENU)

func get_selected_stage_id() -> int:
	return _selected_stage_id

func get_mission_rows() -> Array[Node]:
	return _mission_rows.duplicate()

func _format_score(value: int) -> String:
	var raw := str(maxi(0, value))
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
