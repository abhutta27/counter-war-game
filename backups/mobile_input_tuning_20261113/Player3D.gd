class_name Player3D
extends CharacterBody3D

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")
const WeaponBase = preload("res://scripts/weapons/weapon_base.gd")
const WeaponManager = preload("res://scripts/weapons/weapon_manager.gd")

signal health_changed(current_hp: int, max_hp: int)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal player_died()
signal operative_died()
signal shot_fired()
signal shot_hit(target: Node, is_headshot: bool)
signal movement_state_changed(new_state: int, old_state: int)
signal jumped()
signal crouch_toggled(is_crouching: bool)

@export var max_health: int = 100
@export var current_health: int = 100
@export var is_active: bool = true
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var jump_velocity: float = 4.8
@export var crouch_speed: float = 2.5
@export var crouch_height: float = 1.2
@export var crouch_camera_y: float = 0.95
@export var crouch_transition_speed: float = 10.0
@export var default_damage: int = 25
@export var weapon_range: float = 100.0
@export var max_slope_angle: float = 50.0
@export var snap_length: float = 0.35
@export var acceleration: float = 50.0
@export var deceleration: float = 40.0

var gravity: float = 9.8
var is_firing_held: bool = false
var _semi_auto_shot_taken: bool = false
var _muzzle_flash_time_remaining: float = 0.0
var is_crouching: bool = false
var current_movement_state: int = GameConstants.MovementState.IDLE
var _standing_height: float = 1.8
var _standing_camera_y: float = 1.55
var _mobile_input: Vector2 = Vector2.ZERO

@onready var camera_holder: Node3D = $CameraHolder if has_node("CameraHolder") else self
@onready var camera_mount: Node3D = camera_holder
@onready var camera: Camera3D = $CameraHolder/Camera3D if has_node("CameraHolder/Camera3D") else (get_node_or_null("Camera3D") as Camera3D)
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var weapon_manager: WeaponManager = get_node_or_null("Camera3D/WeaponRig") as WeaponManager
@onready var rifle_muzzle_flash: Node3D = get_node_or_null("Camera3D/WeaponRig/GunModel/MuzzleFlash") as Node3D

func _ready() -> void:
	add_to_group(GameConstants.GROUP_PLAYER)
	current_health = max_health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = snap_length
	floor_block_on_wall = true
	safe_margin = 0.015
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		_standing_height = (collision_shape.shape as CapsuleShape3D).height
	if camera:
		_standing_camera_y = camera.position.y
	if rifle_muzzle_flash:
		rifle_muzzle_flash.visible = false
	if weapon_manager:
		weapon_manager.ammo_updated.connect(_on_weapon_ammo_updated)
		weapon_manager.weapon_switched.connect(_on_weapon_switched)
		_emit_current_ammo()

func _unhandled_input(event: InputEvent) -> void:
	# Fallback for direct test injection and scenes without a consuming GUI.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			_handle_fire_button(event.pressed)

func _input(event: InputEvent) -> void:
	# Do not intercept input when paused or when mouse is free in UI mode
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or get_tree().paused:
		return

	# Weapon firing receives gameplay input during active captured combat
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_fire_button(event.pressed)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("reload"):
		_reload_active_weapon()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_weapon") and weapon_manager:
		weapon_manager.switch_next_weapon()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _muzzle_flash_time_remaining <= 0.0:
		return
	_muzzle_flash_time_remaining -= delta
	if _muzzle_flash_time_remaining <= 0.0 and rifle_muzzle_flash:
		rifle_muzzle_flash.visible = false

func _physics_process(delta: float) -> void:
	if not is_active or current_health <= 0:
		return

	if is_firing_held:
		_try_fire_active_weapon()

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity
		floor_snap_length = 0.0
		jumped.emit()
	else:
		floor_snap_length = snap_length

	_update_crouch(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if OS.has_feature("mobile"):
		input_dir = (input_dir + _mobile_input).limit_length(1.0)
	var direction := (camera_holder.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_sprinting := Input.is_action_pressed("sprint") and input_dir.y < -0.01 and not is_crouching
	var target_speed := crouch_speed if is_crouching else (run_speed if is_sprinting else walk_speed)

	if direction:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)

	move_and_slide()
	_update_movement_state()

func _update_crouch(delta: float) -> void:
	var crouch_pressed := Input.is_action_pressed("crouch")
	if crouch_pressed != is_crouching:
		is_crouching = crouch_pressed
		crouch_toggled.emit(is_crouching)

	var target_height := crouch_height if is_crouching else _standing_height
	var target_camera_y := crouch_camera_y if is_crouching else _standing_camera_y
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = move_toward(capsule.height, target_height, crouch_transition_speed * delta)
		collision_shape.position.y = capsule.height * 0.5
	if camera:
		camera.position.y = move_toward(camera.position.y, target_camera_y, crouch_transition_speed * delta)

func _update_movement_state() -> void:
	var new_state: int = GameConstants.MovementState.IDLE
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		new_state = GameConstants.MovementState.JUMPING if velocity.y > 0.1 else GameConstants.MovementState.FALLING
	elif is_crouching:
		new_state = GameConstants.MovementState.CROUCHING
	elif horizontal_speed > walk_speed + 0.5:
		new_state = GameConstants.MovementState.SPRINTING
	elif horizontal_speed > 0.1:
		new_state = GameConstants.MovementState.WALKING
	if new_state != current_movement_state:
		var old_state := current_movement_state
		current_movement_state = new_state
		movement_state_changed.emit(current_movement_state, old_state)

func _handle_fire_button(pressed: bool) -> void:
	if not pressed:
		is_firing_held = false
		_semi_auto_shot_taken = false
		return
	if not _can_fire_input():
		return
	var active_weapon := _get_active_weapon()
	if not active_weapon or not active_weapon.data:
		return
	_try_fire_active_weapon()
	if active_weapon.data.is_automatic:
		is_firing_held = true
	else:
		_semi_auto_shot_taken = true

func set_mobile_movement(value: Vector2) -> void:
	_mobile_input = value.limit_length(1.0)

func apply_mobile_look(delta_pixels: Vector2) -> void:
	if not OS.has_feature("mobile") or not camera:
		return
	var sensitivity := 0.002
	rotate_y(-delta_pixels.x * sensitivity)
	var camera_pitch := camera.rotation.x - delta_pixels.y * sensitivity
	camera.rotation.x = clampf(camera_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))

func mobile_fire_pressed(pressed: bool) -> void:
	if OS.has_feature("mobile"):
		_handle_fire_button(pressed)

func mobile_reload() -> void:
	if OS.has_feature("mobile"):
		_reload_active_weapon()

func mobile_switch_weapon() -> void:
	if OS.has_feature("mobile") and weapon_manager:
		weapon_manager.switch_next_weapon()

func _reload_active_weapon() -> void:
	var active_weapon := _get_active_weapon()
	if active_weapon and active_weapon.reload():
		is_firing_held = false
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager and sound_manager.has_method("play_reload"):
			sound_manager.play_reload()

func _can_fire_input() -> bool:
	if not is_active or current_health <= 0:
		return false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state != GameConstants.GameState.PLAYING and gm.current_state != GameConstants.GameState.BOOT:
		return false
	return true

func _get_active_weapon() -> WeaponBase:
	if not weapon_manager:
		return null
	return weapon_manager.get_current_weapon()

func get_weapon_manager() -> WeaponManager:
	return weapon_manager

func _try_fire_active_weapon() -> bool:
	if not _can_fire_input():
		return false
	var active_weapon := _get_active_weapon()
	if not active_weapon:
		return false
	if not active_weapon.fire():
		if active_weapon.current_ammo <= 0:
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager and sound_manager.has_method("play_empty_click"):
				sound_manager.play_empty_click()
		return false

	active_weapon.trigger_muzzle_flash()
	_show_rifle_muzzle_flash(active_weapon)
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager and sound_manager.has_method("play_gunshot"):
		sound_manager.play_gunshot()
	shot_fired.emit()

	var target_point := _perform_hitscan(active_weapon)
	var shooting_system = get_node_or_null("/root/ShootingSystem")
	if shooting_system and shooting_system.has_method("spawn_projectile"):
		shooting_system.spawn_projectile(active_weapon.get_muzzle_global_position(), target_point, true)
	return true

func _show_rifle_muzzle_flash(active_weapon: WeaponBase) -> void:
	if not rifle_muzzle_flash or active_weapon != get_node_or_null("Camera3D/WeaponRig/GunModel"):
		return
	rifle_muzzle_flash.visible = true
	_muzzle_flash_time_remaining = 0.075

func _perform_hitscan(active_weapon: WeaponBase) -> Vector3:
	if not camera:
		return global_position
	var shot_range: float = active_weapon.data.range if active_weapon.data else weapon_range
	var damage: int = active_weapon.data.base_damage if active_weapon.data else default_damage
	var weapon_name: String = active_weapon.data.weapon_name if active_weapon.data else "Player"
	var ray_origin := camera.global_position
	var ray_end := ray_origin + (-camera.global_transform.basis.z * shot_range)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ray_end

	var collider: Node = hit.get("collider", null)
	var target: Node = collider
	var is_headshot := false
	if collider and collider.is_in_group(GameConstants.GROUP_HEADSHOT):
		is_headshot = true
		if collider.get_parent() and collider.get_parent().has_method("take_damage"):
			target = collider.get_parent()
	if target and target.has_method("take_damage"):
		var hit_position: Vector3 = hit.get("position", ray_end)
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		var hit_direction := (hit_position - ray_origin).normalized()
		var damage_info := DamageInfo.new(damage, is_headshot, self, weapon_name, hit_position, hit_direction, hit_normal, GameConstants.DamageType.BULLET)
		target.take_damage(damage_info)
		shot_hit.emit(target, is_headshot)
	return hit.get("position", ray_end)

func _on_weapon_ammo_updated(current_ammo: int, _reserve_ammo: int) -> void:
	var active_weapon := _get_active_weapon()
	if active_weapon and active_weapon.data:
		ammo_changed.emit(current_ammo, active_weapon.data.magazine_size)

func _on_weapon_switched(_new_weapon: WeaponBase, _previous_weapon: WeaponBase) -> void:
	is_firing_held = false
	_semi_auto_shot_taken = false
	_emit_current_ammo()

func _emit_current_ammo() -> void:
	var active_weapon := _get_active_weapon()
	if active_weapon and active_weapon.data:
		ammo_changed.emit(active_weapon.current_ammo, active_weapon.data.magazine_size)

func _on_player_death() -> void:
	is_firing_held = false
	_semi_auto_shot_taken = false

func take_damage(damage_input: Variant) -> void:
	var amount: int = 20
	if damage_input is DamageInfo:
		amount = damage_input.amount
	elif damage_input is int or damage_input is float:
		amount = int(damage_input)

	current_health = maxi(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)

	if current_health <= 0:
		is_active = false
		_on_player_death()
		emit_signal("player_died")
		emit_signal("operative_died")
