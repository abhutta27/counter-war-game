extends Control
## Registry-backed operative selection with a focused first-run creation flow.

@onready var mode_title: Label = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/ModeTitle
@onready var instruction: Label = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/Instruction
@onready var selection_section: VBoxContainer = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/SelectionSection
@onready var profile_selector: OptionButton = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/SelectionSection/ProfileSelector
@onready var continue_button: Button = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/SelectionSection/ContinueButton
@onready var new_operative_button: Button = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/NewOperativeButton
@onready var creation_section: VBoxContainer = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/CreationSection
@onready var name_input: LineEdit = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/CreationSection/NameInput
@onready var create_button: Button = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/CreationSection/CreateButton
@onready var creation_back_button: Button = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/CreationSection/CreationBackButton
@onready var back_button: Button = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/BackButton
@onready var feedback_label: Label = $SafeMargin/Page/Center/CenterPanel/Margin/VBox/FeedbackLabel
@onready var controls_button: Button = $SafeMargin/Page/Footer/ControlsButton
@onready var exit_button: Button = $SafeMargin/Page/Footer/ExitButton
@onready var controls_overlay: Control = $ControlsOverlay
@onready var controls_label: Label = $ControlsOverlay/Center/Panel/Margin/Content/ControlsLabel
@onready var controls_close_button: Button = $ControlsOverlay/Center/Panel/Margin/Content/CloseButton

var _profile_entries: Array[Dictionary] = []
var _can_return_to_hq := false
var _is_submitting := false
var _is_transitioning := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var switching := get_tree().has_meta("switching_operative") and bool(get_tree().get_meta("switching_operative"))
	if not switching and ProfileManager.has_valid_profile():
		_open_hq()
		return
	if switching:
		get_tree().remove_meta("switching_operative")

	_can_return_to_hq = switching and ProfileManager.has_valid_profile()
	continue_button.pressed.connect(_continue_selected_profile)
	new_operative_button.pressed.connect(_show_creation_flow)
	create_button.pressed.connect(_create_operative)
	creation_back_button.pressed.connect(_show_selection_flow)
	back_button.pressed.connect(_open_hq)
	controls_button.pressed.connect(_open_help)
	exit_button.pressed.connect(_on_exit_pressed)
	name_input.text_submitted.connect(func(_text: String): _create_operative())
	_refresh_profile_selector()

	if _profile_entries.is_empty():
		_show_creation_flow(false)
	else:
		_show_selection_flow()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if controls_overlay.is_open():
		controls_overlay.close()
		controls_button.grab_focus()
		get_viewport().set_input_as_handled()
		return
	var popup := profile_selector.get_popup()
	if popup.visible:
		popup.hide()
		profile_selector.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if creation_section.visible and not _profile_entries.is_empty():
		_show_selection_flow()
		get_viewport().set_input_as_handled()
	elif _can_return_to_hq:
		_open_hq()
		get_viewport().set_input_as_handled()

func _refresh_profile_selector() -> void:
	_profile_entries = ProfileManager.get_profile_entries()
	profile_selector.clear()
	var active_id := ProfileManager.get_active_profile_id()
	var active_index := 0
	for index in _profile_entries.size():
		var entry := _profile_entries[index]
		profile_selector.add_item(str(entry.get("player_name", "")))
		profile_selector.set_item_metadata(index, str(entry.get("profile_id", "")))
		if str(entry.get("profile_id", "")) == active_id:
			active_index = index
	if not _profile_entries.is_empty():
		profile_selector.select(active_index)

func _continue_selected_profile() -> void:
	var selected := profile_selector.selected
	if selected < 0 or selected >= profile_selector.item_count:
		_show_error("Select an operative to continue.")
		return
	var profile_id := str(profile_selector.get_item_metadata(selected))
	if not ProfileManager.switch_profile(profile_id):
		_show_error("Operative could not be loaded. Try again.")
		return
	_open_hq()

func _show_creation_flow(allow_back: bool = true) -> void:
	mode_title.text = "CREATE OPERATIVE"
	instruction.text = "Choose your codename to begin."
	selection_section.visible = false
	new_operative_button.visible = false
	creation_section.visible = true
	creation_back_button.visible = allow_back and not _profile_entries.is_empty()
	back_button.visible = false
	feedback_label.text = ""
	name_input.clear()
	name_input.grab_focus()

func _show_selection_flow() -> void:
	mode_title.text = "SWITCH OPERATIVE"
	instruction.text = "Select an operative to continue."
	creation_section.visible = false
	selection_section.visible = true
	new_operative_button.visible = true
	back_button.visible = _can_return_to_hq
	feedback_label.text = ""
	profile_selector.grab_focus()

func _create_operative() -> void:
	if _is_submitting:
		return
	var clean_name := ProfileManager.sanitize_player_name(name_input.text)
	if clean_name.is_empty():
		_show_error("Enter a valid codename.")
		name_input.grab_focus()
		return
	if ProfileManager.has_profile_named(clean_name):
		_show_error("That codename already exists.")
		name_input.grab_focus()
		return
	_is_submitting = true
	create_button.disabled = true
	name_input.editable = false
	if not ProfileManager.create_new_profile(clean_name):
		_is_submitting = false
		create_button.disabled = false
		name_input.editable = true
		_show_error("Could not save. Try again.")
		name_input.grab_focus()
		return
	_open_hq()

func _open_help() -> void:
	controls_overlay.open()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_error(message: String) -> void:
	feedback_label.text = message

func _open_hq() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	set_process_input(false)
	# Let the submit key complete before the HQ becomes interactive. Without this
	# guard, an Enter release can activate DEPLOY in the newly loaded HQ.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/StageSelection.tscn")
