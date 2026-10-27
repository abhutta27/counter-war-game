extends CharacterBody3D
## PlayerController.gd
## Tactical First-Person Operative Controller with 3D Weapon Mesh Rig, Procedural Recoil, Sway, and Hitscan Shooting.

# class_name PlayerController (migrated to scripts/player/player_controller.gd)

signal shot_fired()
signal shot_hit(target: Node, is_headshot: bool)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal health_changed(current_health: int, max_health: int)
signal operative_died()

# Movement Settings
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 12.0

# Combat Settings
@export var max_health: int = 100
@export var magazine_size: int = 30
@export var base_damage: int = 40
@export var headshot_damage: int = 100
@export var fire_rate: float = 0.12 # Time between shots

# 3D Weapon Model Settings
@export var weapon_scene: PackedScene = preload("res://assets/weapons/Assault Rifle.glb")
@export var weapon_scale: Vector3 = Vector3(0.14, 0.14, 0.14)
@export var default_gun_pos: Vector3 = Vector3(0.24, -0.22, -0.42)
@export var default_gun_rot: Vector3 = Vector3.ZERO

var current_health: int = 100
var current_ammo: int = 30
var is_reloading: bool = false
var can_fire: bool = true
var is_active: bool = true

# Node References
@onready var camera: Camera3D = get_node_or_null("Camera3D")
@onready var raycast: RayCast3D = get_node_or_null("Camera3D/RayCast3D")
@onready var weapon_rig: Node3D = get_node_or_null("Camera3D/WeaponRig")
@onready var gun_model: Node3D = get_node_or_null("Camera3D/WeaponRig/GunModel")
@onready var muzzle_flash: Node3D = get_node_or_null("Camera3D/WeaponRig/GunModel/MuzzleFlash")
@onready var muzzle_light: OmniLight3D = get_node_or_null("Camera3D/WeaponRig/GunModel/MuzzleFlash/OmniLight3D")

# Crosshair HUD
@onready var hitmarker: Control = get_node_or_null("PlayerHUD/CrosshairContainer/Hitmarker")

# Weapon Procedural Animation State
var target_gun_pos: Vector3 = Vector3(0.24, -0.22, -0.42)
var target_gun_rot: Vector3 = Vector3.ZERO
var sway_offset: Vector2 = Vector2.ZERO
var bob_timer: float = 0.0

var active_weapon_instance: Node3D = null

func _ready() -> void:
	current_health = max_health
	current_ammo = magazine_size
	target_gun_pos = default_gun_pos
	target_gun_rot = default_gun_rot
	
	# Setup 3D Weapon Mesh from res://assets/weapons/
	setup_weapon_model()
	
	# Capture mouse cursor for FPS control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if muzzle_flash:
		muzzle_flash.visible = false
	if hitmarker:
		hitmarker.visible = false
		
	emit_signal("health_changed", current_health, max_health)
	emit_signal("ammo_changed", current_ammo, magazine_size)

## Setup or swap 3D weapon model from res://assets/weapons/
func setup_weapon_model(new_weapon_scene: PackedScene = null) -> void:
	if new_weapon_scene:
		weapon_scene = new_weapon_scene
		
	if not gun_model:
		return
		
	# Remove old placeholder box meshes or previous weapon instances if dynamically spawned
	for child in gun_model.get_children():
		if child.name != "MuzzleFlash" and child != active_weapon_instance:
			# If it was an old BoxMesh placeholder, remove it
			if child is MeshInstance3D and child.name in ["Receiver", "Barrel", "Grip", "Magazine", "Sight"]:
				child.queue_free()
	
	if active_weapon_instance and is_instance_valid(active_weapon_instance):
		active_weapon_instance.queue_free()
		active_weapon_instance = null
		
	# Check if gun_model already contains the weapon instance in the scene tree
	for child in gun_model.get_children():
		if child.name != "MuzzleFlash" and not (child.name in ["Receiver", "Barrel", "Grip", "Magazine", "Sight"]):
			active_weapon_instance = child
			break
			
	# If not found in scene tree, instantiate weapon_scene
	if not active_weapon_instance and weapon_scene:
		active_weapon_instance = weapon_scene.instantiate() as Node3D
		if active_weapon_instance:
			active_weapon_instance.name = "WeaponModel"
			active_weapon_instance.scale = weapon_scale
			gun_model.add_child(active_weapon_instance)
			
			# Align muzzle flash to the front tip of the weapon
			if muzzle_flash:
				muzzle_flash.position = Vector3(0, 0.005, -0.32)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_x: float = -event.relative.x * mouse_sensitivity
		var mouse_y: float = -event.relative.y * mouse_sensitivity
		
		# Rotate body horizontally (Yaw)
		rotate_y(mouse_x)
		
		# Rotate camera vertically (Pitch) clamped to +/- 85 deg
		if camera:
			camera.rotate_x(mouse_y)
			camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		
		# Weapon Sway accumulation
		sway_offset.x = clampf(sway_offset.x + event.relative.x * 0.0004, -0.04, 0.04)
		sway_offset.y = clampf(sway_offset.y + event.relative.y * 0.0004, -0.04, 0.04)
		
	# Mouse capture toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not is_active:
		return
		
	_handle_combat_input()
	_update_weapon_transform(delta)

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Jump
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity

	# Get WASD movement direction relative to camera yaw
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var move_direction: Vector3 = (right * input_dir.x + forward * -input_dir.y).normalized()

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * target_speed
		velocity.z = move_direction.z * target_speed
		bob_timer += delta * (14.0 if is_sprinting else 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * delta * 8.0)

	move_and_slide()

# ==============================================================================
# COMBAT & SHOOTING
# ==============================================================================

func _handle_combat_input() -> void:
	# Primary fire (LMB)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire_weapon()
		
	# Reload (R)
	if Input.is_key_pressed(KEY_R):
		reload()

func fire_weapon() -> void:
	if not can_fire or is_reloading or not is_active:
		return
		
	if current_ammo <= 0:
		_play_sound("empty_click")
		reload()
		return
		
	# Consume ammo
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, magazine_size)
	emit_signal("shot_fired")
	
	# Play sound & effects
	_play_sound("gunshot")
		
	_apply_recoil()
	_show_muzzle_flash()
	
	# Raycast hitscan check
	_check_hitscan()
	
	# Fire rate cooldown
	can_fire = false
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_fire = true)

func _check_hitscan() -> void:
	if not raycast:
		return
		
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider:
			# Check if enemy or headshot hitbox
			var target_node = collider
			var is_headshot: bool = false
			
			if collider.is_in_group("headshot_hitbox"):
				is_headshot = true
				if collider.get_parent() and collider.get_parent().has_method("take_damage"):
					target_node = collider.get_parent()
			
			if target_node.has_method("take_damage"):
				var dmg: int = headshot_damage if is_headshot else base_damage
				target_node.take_damage(dmg, is_headshot)
				
				emit_signal("shot_hit", target_node, is_headshot)
				_play_sound("hitmarker", is_headshot)
				_show_hitmarker(is_headshot)

func _apply_recoil() -> void:
	# Procedural Recoil Kickback & Pitch
	target_gun_pos = default_gun_pos + Vector3(randf_range(-0.005, 0.005), 0.015, 0.07)
	target_gun_rot = default_gun_rot + Vector3(deg_to_rad(5.0), randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))
	
	# Camera recoil bump
	if camera:
		camera.rotation.x += deg_to_rad(0.4)

func _update_weapon_transform(delta: float) -> void:
	# Recover gun position/rotation back to default
	target_gun_pos = target_gun_pos.lerp(default_gun_pos, delta * 14.0)
	target_gun_rot = target_gun_rot.lerp(default_gun_rot, delta * 14.0)
	
	# Recover sway
	sway_offset = sway_offset.lerp(Vector2.ZERO, delta * 10.0)
	
	# Calculate walking bob
	var bob_x: float = cos(bob_timer) * 0.006 if is_on_floor() and velocity.length() > 0.5 else 0.0
	var bob_y: float = sin(bob_timer * 2.0) * 0.006 if is_on_floor() and velocity.length() > 0.5 else 0.0
	
	if gun_model:
		gun_model.position = target_gun_pos + Vector3(bob_x - sway_offset.x, bob_y - sway_offset.y, 0.0)
		gun_model.rotation = target_gun_rot + Vector3(-sway_offset.y * 1.5, -sway_offset.x * 1.5, 0.0)

func _show_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	muzzle_flash.visible = true
	if muzzle_light:
		muzzle_light.visible = true
		
	var timer := get_tree().create_timer(0.04)
	timer.timeout.connect(func():
		if muzzle_flash:
			muzzle_flash.visible = false
		if muzzle_light:
			muzzle_light.visible = false
	)

func _show_hitmarker(is_headshot: bool) -> void:
	if not hitmarker:
		return
	hitmarker.visible = true
	hitmarker.modulate = Color.ORANGE_RED if is_headshot else Color.WHITE
	
	var tween := create_tween()
	tween.tween_property(hitmarker, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		if hitmarker:
			hitmarker.visible = false
			hitmarker.modulate.a = 1.0
	)

func reload() -> void:
	if is_reloading or current_ammo == magazine_size:
		return
		
	is_reloading = true
	_play_sound("reload")
		
	# Weapon drop reload animation
	target_gun_pos = default_gun_pos + Vector3(0.05, -0.15, 0.05)
	target_gun_rot = default_gun_rot + Vector3(deg_to_rad(-25.0), deg_to_rad(15.0), deg_to_rad(-10.0))
	
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		current_ammo = magazine_size
		is_reloading = false
		emit_signal("ammo_changed", current_ammo, magazine_size)
	)

func take_damage(amount: int) -> void:
	if not is_active or current_health <= 0:
		return
		
	current_health = maxi(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		is_active = false
		emit_signal("operative_died")

func _play_sound(sound_type: String, extra_param: bool = false) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if not sm:
		return
	match sound_type:
		"gunshot":
			if sm.has_method("play_gunshot"):
				sm.play_gunshot()
		"empty_click":
			if sm.has_method("play_empty_click"):
				sm.play_empty_click()
		"reload":
			if sm.has_method("play_reload"):
				sm.play_reload()
		"hitmarker":
			if sm.has_method("play_hitmarker"):
				sm.play_hitmarker(extra_param)
