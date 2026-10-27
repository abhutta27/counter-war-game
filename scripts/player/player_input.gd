class_name PlayerInput
extends RefCounted
## PlayerInput.gd
## Decoupled input reader utilizing Godot Input Map actions with programmatic fallback guarantee.

static var _initialized: bool = false

static func ensure_input_map() -> void:
	if _initialized:
		return
	_initialized = true
	_register_action_if_missing("move_forward", [KEY_W, KEY_UP])
	_register_action_if_missing("move_backward", [KEY_S, KEY_DOWN])
	_register_action_if_missing("move_left", [KEY_A, KEY_LEFT])
	_register_action_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_register_action_if_missing("jump", [KEY_SPACE])
	_register_action_if_missing("sprint", [KEY_SHIFT])
	_register_action_if_missing("crouch", [KEY_CTRL, KEY_C])
	_register_action_if_missing("pause", [KEY_ESCAPE])
	_register_action_if_missing("reload", [KEY_R])
	_register_action_if_missing("switch_weapon", [KEY_Q])
	_register_action_if_missing("interact", [KEY_E])
	_register_mouse_action_if_missing("fire", MOUSE_BUTTON_LEFT)
	_register_mouse_action_if_missing("aim", MOUSE_BUTTON_RIGHT)

static func _register_action_if_missing(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for kc in keycodes:
			var event := InputEventKey.new()
			event.physical_keycode = kc as Key
			InputMap.action_add_event(action_name, event)

static func _register_mouse_action_if_missing(action_name: String, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action_name, event)

## Returns 2D movement vector normalized, where X is strafe (left/right) and Y is forward/backward
static func get_movement_vector() -> Vector2:
	ensure_input_map()
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

static func is_sprint_pressed() -> bool:
	ensure_input_map()
	return Input.is_action_pressed("sprint")

static func is_jump_just_pressed() -> bool:
	ensure_input_map()
	return Input.is_action_just_pressed("jump")

static func is_crouch_pressed() -> bool:
	ensure_input_map()
	return Input.is_action_pressed("crouch")

static func is_crouch_just_pressed() -> bool:
	ensure_input_map()
	return Input.is_action_just_pressed("crouch")