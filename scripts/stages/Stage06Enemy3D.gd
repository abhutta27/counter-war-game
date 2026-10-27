class_name Stage06Enemy3D
extends "res://scripts/entities/Enemy3D.gd"
## Stage06-local guard gate and firing protection. Shared Enemy3D remains
## untouched: this subclass stays inert until Stage06SecurityController grants
## combat authority, and world geometry vetoes damage when it blocks the shot.

enum LocalMode { HOLD, SUSPICIOUS, COMBAT }

@export var security_group: String = "checkpoint"
@export var guard_role: String = "base guard"

var local_mode: LocalMode = LocalMode.HOLD
var investigation_point := Vector3.ZERO

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if local_mode == LocalMode.COMBAT:
		super._physics_process(delta)
		return
	# Held guards remain physical and settle safely on the floor, but never run
	# the shared global-acquisition loop.
	target_player = null
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_locomotion_animation(false, false)
	if local_mode == LocalMode.SUSPICIOUS:
		_face_investigation_point()

func hold_position() -> void:
	if is_dead:
		return
	local_mode = LocalMode.HOLD
	target_player = null
	velocity = Vector3.ZERO
	set_meta("stage06_guard_mode", "stealth")

func investigate(position: Vector3) -> void:
	if is_dead or local_mode == LocalMode.COMBAT:
		return
	local_mode = LocalMode.SUSPICIOUS
	investigation_point = position
	set_meta("stage06_guard_mode", "suspicious")
	_face_investigation_point()

func activate_combat(reason: String = "security response") -> void:
	if is_dead or local_mode == LocalMode.COMBAT:
		return
	local_mode = LocalMode.COMBAT
	velocity = Vector3.ZERO
	set_meta("stage06_guard_mode", "combat")
	set_meta("stage06_activation_reason", reason)

func is_stage06_combat_active() -> bool:
	return local_mode == LocalMode.COMBAT and not is_dead

func _face_investigation_point() -> void:
	var flat_target := investigation_point
	flat_target.y = global_position.y
	if global_position.distance_squared_to(flat_target) > 0.01:
		look_at(flat_target, Vector3.UP)

func has_clear_stage06_fire_path() -> bool:
	return has_clear_enemy_fire_path()
