extends Control
## Shared controls/help overlay used by Operations HQ and operative creation.

@onready var controls_label: Label = $Center/Panel/Margin/Content/ControlsLabel
@onready var close_button: Button = $Center/Panel/Margin/Content/CloseButton

func _ready() -> void:
	controls_label.text = _build_controls_help()
	close_button.pressed.connect(close)
	visible = false

func open() -> void:
	visible = true
	close_button.grab_focus()

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _build_controls_help() -> String:
	var move := "/".join([
		_first_input_label("move_forward"), _first_input_label("move_left"),
		_first_input_label("move_backward"), _first_input_label("move_right")
	])
	return "MOVE                         %s\nJUMP (GROUNDED)              %s\nSPRINT (HOLD WITH FORWARD)   %s + %s\nCROUCH (HOLD)                %s\nFIRE                         %s\nRELOAD                       %s\nSWITCH WEAPON                %s\nPAUSE                        %s" % [
		move, _input_labels("jump"), _first_input_label("move_forward"), _input_labels("sprint"),
		_input_labels("crouch"), _input_labels("fire"), _input_labels("reload"),
		_input_labels("switch_weapon"), _input_labels("pause")
	]

func _first_input_label(action: StringName) -> String:
	var labels := _input_label_list(action)
	return labels[0] if not labels.is_empty() else "—"

func _input_labels(action: StringName) -> String:
	var labels := _input_label_list(action)
	return "/".join(labels) if not labels.is_empty() else "—"

func _input_label_list(action: StringName) -> Array[String]:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		var label := event.as_text().replace(" (Physical)", "").replace(" - Physical", "")
		if not labels.has(label):
			labels.append(label)
	return labels
