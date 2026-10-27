class_name Enemy3D
extends CharacterBody3D

const GameConstants = preload("res://scripts/utilities/constants.gd")
const DamageInfo = preload("res://scripts/combat/damage_info.gd")
const EnemyRifleScene = preload("res://assets/weapons/Assault Rifle.glb")

enum State { IDLE, CHASE, ATTACK, DEAD }

const COMBAT_DISTANCE: float = 10.0
const COMBAT_EXIT_DISTANCE: float = 12.0
const MINIMUM_COMBAT_DISTANCE: float = 5.0
const RIFLE_SKELETON_SCALE_COMPENSATION: float = 22.0
const RIFLE_HAND_ROTATION_DEGREES := Vector3(164.0, -15.0, -190.0)
const SEPARATION_RADIUS: float = 2.25
const SEPARATION_WEIGHT: float = 1.1
const RETREAT_SPEED_FACTOR: float = 0.65
const COMBAT_SPACING_SPEED_FACTOR: float = 0.35
const ENEMY_FIRE_COLLISION_MASK: int = 1
const PLAYER_TORSO_HEIGHT: float = 1.2
# Measured against the imported rifle mesh. These points place the pistol grip
# on the right hand and the front hand on the underside of the handguard.
const RIFLE_RIGHT_GRIP_POINT := Vector3(0.0, -0.45, -0.55)
const RIFLE_LEFT_FOREGRIP_POINT := Vector3(0.0, -0.35, 0.65)

signal health_changed(current_hp: int, max_hp: int)
signal enemy_died()

@export var max_health: int = 100
@export var current_health: int = 100
@export var attack_damage: int = 15
@export var attack_range: float = 15.0
@export var move_speed: float = 3.5

var target_player: Node3D = null
var gravity: float = 9.8
var is_dead: bool = false
var fire_timer: float = 0.0
var current_state: State = State.IDLE
var enemy_weapon: Node3D = null
var enemy_muzzle_flash: Node3D = null
var _right_hand_attachment: BoneAttachment3D = null
var _weapon_aim_pivot: Node3D = null
var _right_arm_ik: SkeletonIK3D = null
var _left_arm_ik: SkeletonIK3D = null
var _right_hand_target: Marker3D = null
var _left_hand_target: Marker3D = null
var _combat_pose_active: bool = false
var _death_tween: Tween = null
var _has_detected_player: bool = false
var _alert_voice_player: AudioStreamPlayer3D = null
@export var fire_rate: float = 1.0

@onready var anim_player: AnimationPlayer = get_node_or_null("SoldierModel/AnimationPlayer") as AnimationPlayer
@onready var skeleton_node: Skeleton3D = get_node_or_null("SoldierModel/Character/Skeleton3D") as Skeleton3D
@onready var soldier_model: Node3D = get_node_or_null("SoldierModel") as Node3D
@onready var body_collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var headshot_area: Area3D = get_node_or_null("HeadshotArea") as Area3D
@onready var health_bar_3d: Sprite3D = get_node_or_null("HealthBar3D") as Sprite3D

func _ready() -> void:
	add_to_group(GameConstants.GROUP_ENEMIES)
	current_health = max_health
	# Enemies steer around one another in script instead of forming a rigid
	# capsule queue. World and Player collision (layer 1) remain enabled.
	set_collision_mask_value(2, false)
	_configure_locomotion_animations()
	_setup_enemy_rifle()
	_setup_alert_voice_player()
	_play_locomotion_animation("Idle")

func _setup_alert_voice_player() -> void:
	_alert_voice_player = AudioStreamPlayer3D.new()
	_alert_voice_player.name = "EnemyAlertVoice3D"
	_alert_voice_player.bus = "Master"
	# Source clips peak around -10.7 dBFS or lower, so +9 dB retains roughly
	# 1.7 dB of peak headroom before spatial attenuation while staying clear
	# beside the non-spatial gunshot mix.
	_alert_voice_player.volume_db = 9.0
	# Level enemies initially call out from roughly 17–30 m. A 22 m reference
	# size keeps that range intelligible while inverse-distance falloff still
	# preserves direction and prevents distant voices sounding unnaturally close.
	_alert_voice_player.unit_size = 22.0
	_alert_voice_player.max_distance = 45.0
	_alert_voice_player.max_polyphony = 1
	add_child(_alert_voice_player)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var is_chasing := false

	if not is_on_floor():
		velocity.y -= gravity * delta

	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group(GameConstants.GROUP_PLAYER)
		if players.size() > 0:
			target_player = players[0] as Node3D

	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		
		# Look towards player naturally
		var target_pos = target_player.global_position
		target_pos.y = global_position.y
		if global_position.distance_squared_to(target_pos) > 0.1:
			look_at(target_pos, Vector3.UP)

		# Enter rifle range at 10 m and use a 12 m exit threshold so the state
		# does not flicker when the Player moves around the firing line.
		var should_chase: bool = distance > COMBAT_DISTANCE
		if current_state == State.ATTACK:
			should_chase = distance > COMBAT_EXIT_DISTANCE

		if should_chase:
			var dir := _get_chase_direction()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			is_chasing = true
			_change_state(State.CHASE)
		else:
			_change_state(State.ATTACK)
			if distance < MINIMUM_COMBAT_DISTANCE:
				# A close Player causes a controlled back-step while the Enemy keeps
				# its rifle/aim pose instead of continuing into body contact.
				var retreat_direction := _get_retreat_direction()
				velocity.x = retreat_direction.x * move_speed * RETREAT_SPEED_FACTOR
				velocity.z = retreat_direction.z * move_speed * RETREAT_SPEED_FACTOR
			else:
				# No forward chase velocity in ATTACK. Only a small lateral correction
				# is allowed when another living Enemy occupies the same firing slot.
				var spacing_direction := _get_combat_spacing_direction()
				velocity.x = spacing_direction.x * move_speed * COMBAT_SPACING_SPEED_FACTOR
				velocity.z = spacing_direction.z * move_speed * COMBAT_SPACING_SPEED_FACTOR

		# Shooting Logic
		fire_timer += delta
		if fire_timer >= fire_rate and current_state == State.ATTACK and distance <= attack_range:
			fire_timer = 0.0
			_enemy_shoot()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_change_state(State.IDLE)

	var position_before_move := global_position
	move_and_slide()
	var actual_motion := global_position - position_before_move
	actual_motion.y = 0.0
	var moved_this_frame := actual_motion.length() > maxf(0.001, move_speed * delta * 0.05)
	_update_locomotion_animation(is_chasing and moved_this_frame, current_state == State.ATTACK)

func _get_chase_direction() -> Vector3:
	if not target_player or not is_instance_valid(target_player):
		return Vector3.ZERO
	var to_player := target_player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.0001:
		return Vector3.ZERO
	to_player = to_player.normalized()

	var separation := _get_separation_vector()
	var steering := to_player + separation * SEPARATION_WEIGHT
	return steering.normalized() if steering.length_squared() > 0.0001 else to_player

func _get_retreat_direction() -> Vector3:
	if not target_player or not is_instance_valid(target_player):
		return Vector3.ZERO
	var away_from_player := global_position - target_player.global_position
	away_from_player.y = 0.0
	if away_from_player.length_squared() <= 0.0001:
		away_from_player = -global_transform.basis.z
	away_from_player = away_from_player.normalized()
	var steering := away_from_player + _get_separation_vector() * SEPARATION_WEIGHT
	return steering.normalized() if steering.length_squared() > 0.0001 else away_from_player

func _get_combat_spacing_direction() -> Vector3:
	var separation := _get_separation_vector()
	if separation.length_squared() <= 0.0001 or not target_player or not is_instance_valid(target_player):
		return Vector3.ZERO
	# Preserve the firing radius: spacing in ATTACK is lateral, never another
	# forward push into the Player or a retreat beyond the preferred ring.
	var to_player := target_player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.0001:
		var radial := to_player.normalized()
		separation -= radial * separation.dot(radial)
	return separation.normalized() if separation.length_squared() > 0.0001 else Vector3.ZERO

func _get_separation_vector() -> Vector3:
	var separation := Vector3.ZERO
	var forward := Vector3.ZERO
	if target_player and is_instance_valid(target_player):
		forward = target_player.global_position - global_position
		forward.y = 0.0
		forward = forward.normalized()
	for node in get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES):
		var other := node as Enemy3D
		if not other or other == self or other.is_dead:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance >= SEPARATION_RADIUS:
			continue
		if distance <= 0.001:
			# Stable opposite lateral directions prevent exact-position stacking.
			away = Vector3(-forward.z, 0.0, forward.x)
			if get_instance_id() > other.get_instance_id():
				away = -away
			distance = 0.001
		else:
			away /= distance
			# When enemies are queued on the same approach line, sidestep instead
			# of merely pushing the rear enemy backward into an endless queue.
			if forward.length_squared() > 0.5 and absf(away.dot(forward)) > 0.8:
				away = Vector3(-forward.z, 0.0, forward.x)
				if get_instance_id() > other.get_instance_id():
					away = -away
		separation += away * (1.0 - distance / SEPARATION_RADIUS)
	return separation

func _setup_enemy_rifle() -> void:
	if not skeleton_node:
		push_warning("Enemy3D: Soldier skeleton not found; rifle setup skipped.")
		return

	_right_hand_attachment = BoneAttachment3D.new()
	_right_hand_attachment.name = "RightHandWeaponAttachment"
	_right_hand_attachment.bone_name = "mixamorig_RightHand"
	skeleton_node.add_child(_right_hand_attachment)
	_weapon_aim_pivot = Node3D.new()
	_weapon_aim_pivot.name = "RifleGripPivot"
	_right_hand_attachment.add_child(_weapon_aim_pivot)

	enemy_weapon = EnemyRifleScene.instantiate() as Node3D
	if not enemy_weapon:
		push_warning("Enemy3D: Assault Rifle asset could not be instantiated.")
		return
	enemy_weapon.name = "EnemyRifle"
	_weapon_aim_pivot.add_child(enemy_weapon)
	# Soldier's imported skeleton is scaled to 0.01. Local 22.0 produces a
	# clear 0.22 world scale (about 0.89 m total rifle length).
	enemy_weapon.rotation_degrees = Vector3.ZERO
	enemy_weapon.scale = Vector3.ONE * RIFLE_SKELETON_SCALE_COMPENSATION
	# Move the mesh so its measured pistol-grip point, not its scene origin,
	# sits exactly on RifleGripPivot / mixamorig_RightHand.
	enemy_weapon.position = -RIFLE_RIGHT_GRIP_POINT * RIFLE_SKELETON_SCALE_COMPENSATION
	_apply_chase_weapon_transform()

	var muzzle_marker := Marker3D.new()
	muzzle_marker.name = "MuzzleMarker"
	# Asset inspection confirms the physical barrel runs along local +Z.
	muzzle_marker.position = Vector3(0.0, 0.0, 2.15)
	enemy_weapon.add_child(muzzle_marker)

	_right_hand_target = Marker3D.new()
	_right_hand_target.name = "RightHandCombatTarget"
	_right_hand_target.position = Vector3(0.20, 1.34, -0.25)
	add_child(_right_hand_target)

	_left_hand_target = Marker3D.new()
	_left_hand_target.name = "LeftHandForegripTarget"
	_left_hand_target.position = Vector3(0.20, 1.36, -0.47)
	add_child(_left_hand_target)

	_right_arm_ik = _create_arm_ik(
		"RightArmWeaponIK",
		"mixamorig_RightArm",
		"mixamorig_RightHand",
		_right_hand_target,
		false
	)
	_left_arm_ik = _create_arm_ik(
		"LeftArmForegripIK",
		"mixamorig_LeftArm",
		"mixamorig_LeftHand",
		_left_hand_target,
		false
	)

func _create_arm_ik(
	node_name: String,
	root_bone_name: String,
	tip_bone_name: String,
	target_node: Node3D,
	override_tip_rotation: bool
) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = node_name
	ik.root_bone = root_bone_name
	ik.tip_bone = tip_bone_name
	ik.override_tip_basis = override_tip_rotation
	ik.max_iterations = 20
	ik.min_distance = 0.005
	skeleton_node.add_child(ik)
	ik.target_node = ik.get_path_to(target_node)
	ik.interpolation = 0.0
	ik.stop()
	return ik

func _process(_delta: float) -> void:
	if not _combat_pose_active or is_dead:
		return
	if enemy_weapon and _weapon_aim_pivot and target_player and is_instance_valid(target_player):
		var target_point := target_player.global_position + Vector3.UP * 1.2
		if _weapon_aim_pivot.global_position.distance_squared_to(target_point) > 0.01:
			# use_model_front=true aligns the rifle's verified local +Z barrel axis.
			_weapon_aim_pivot.look_at(target_point, Vector3.UP, true)
		# Drive the existing left-arm IK from the rifle's actual handguard point.
		# This keeps both hands on visible weapon geometry as the enemy turns.
		if _left_hand_target:
			_left_hand_target.global_position = enemy_weapon.to_global(RIFLE_LEFT_FOREGRIP_POINT)

func _apply_chase_weapon_transform() -> void:
	if not enemy_weapon or not _weapon_aim_pivot:
		return
	_weapon_aim_pivot.position = Vector3.ZERO
	var hand_basis := Basis.from_euler(Vector3(
		deg_to_rad(RIFLE_HAND_ROTATION_DEGREES.x),
		deg_to_rad(RIFLE_HAND_ROTATION_DEGREES.y),
		deg_to_rad(RIFLE_HAND_ROTATION_DEGREES.z)
	))
	# The historical hand transform aligned -Z; flip it so the real +Z barrel
	# points forward while the Run animation remains fully unmodified.
	_weapon_aim_pivot.basis = hand_basis * Basis(Vector3.UP, PI)
	enemy_weapon.position = -RIFLE_RIGHT_GRIP_POINT * RIFLE_SKELETON_SCALE_COMPENSATION
	enemy_weapon.rotation_degrees = Vector3.ZERO
	enemy_weapon.scale = Vector3.ONE * RIFLE_SKELETON_SCALE_COMPENSATION

func _change_state(new_state: State) -> void:
	if is_dead:
		new_state = State.DEAD
	if current_state == new_state:
		return
	var detected_now := not _has_detected_player and current_state == State.IDLE and new_state in [State.CHASE, State.ATTACK]
	current_state = new_state
	_set_combat_pose(current_state == State.ATTACK)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("enemy_state_changed"):
		event_bus.enemy_state_changed.emit(self, current_state)
	if detected_now:
		_has_detected_player = true
		var sound_manager := get_node_or_null("/root/SoundManager")
		if sound_manager and sound_manager.has_method("try_play_enemy_alert"):
			sound_manager.try_play_enemy_alert(_alert_voice_player)

func _set_combat_pose(enabled: bool) -> void:
	if _combat_pose_active == enabled:
		return
	_combat_pose_active = enabled
	if enabled:
		if _right_arm_ik:
			_right_arm_ik.interpolation = 1.0
			_right_arm_ik.start()
		if _left_arm_ik:
			_left_arm_ik.interpolation = 1.0
			_left_arm_ik.start()
	else:
		if _right_arm_ik:
			_right_arm_ik.interpolation = 0.0
			_right_arm_ik.stop()
		if _left_arm_ik:
			_left_arm_ik.interpolation = 0.0
			_left_arm_ik.stop()
		_apply_chase_weapon_transform()

func _configure_locomotion_animations() -> void:
	if not anim_player:
		return
	for animation_name in [&"Idle", &"Run", &"Walk"]:
		if anim_player.has_animation(animation_name):
			var animation := anim_player.get_animation(animation_name)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR

func _update_locomotion_animation(is_chasing: bool, is_attacking: bool = false) -> void:
	if is_dead or not anim_player:
		return
	var current_name := String(anim_player.current_animation)
	if anim_player.is_playing() and "hit" in current_name.to_lower():
		return
	_play_locomotion_animation("Run" if is_chasing and not is_attacking else "Idle")

func _play_locomotion_animation(animation_name: StringName) -> void:
	if not anim_player or not anim_player.has_animation(animation_name):
		return
	if anim_player.current_animation != animation_name or not anim_player.is_playing():
		anim_player.play(animation_name, 0.15)

func _enemy_shoot() -> void:
	if is_dead or current_state != State.ATTACK:
		return
	if target_player and is_instance_valid(target_player) and target_player.has_method("take_damage"):
		var muzzle := enemy_weapon.get_node_or_null("MuzzleMarker") as Node3D if enemy_weapon else null
		var origin := muzzle.global_position if muzzle else global_position + Vector3.UP * 1.2
		var target_point := target_player.global_position + Vector3.UP * 1.2
		var fire_path_hit := _get_enemy_fire_path_hit(origin, target_point)
		var first_collider = fire_path_hit.get("collider")
		var impact_point: Vector3 = fire_path_hit.get("position", target_point)
		var shooting_system := get_node_or_null("/root/ShootingSystem")
		if shooting_system:
			enemy_muzzle_flash = shooting_system.trigger_muzzle_flash(muzzle, Vector3.ZERO, false) if muzzle else null
			# The shot ray is resolved once here. The visible tracer follows that exact
			# clear or blocked path and does not repeat raycasts on every render frame.
			shooting_system.spawn_projectile(origin, impact_point, false, Callable(), -1.0, true)
		var sound_manager := get_node_or_null("/root/SoundManager")
		if sound_manager and sound_manager.has_method("play_gunshot"):
			sound_manager.play_gunshot()

		# Cover, not awareness, decides damage. A Player hit is valid only when the
		# Player body is the first layer-1 collider along the real muzzle path.
		if first_collider != target_player:
			return
		var shot_direction := (target_point - origin).normalized()
		var dmg = DamageInfo.new(
			attack_damage,
			false,
			self,
			"Assault Rifle",
			origin,
			shot_direction,
			Vector3.UP,
			GameConstants.DamageType.BULLET
		)
		target_player.take_damage(dmg)

func has_clear_enemy_fire_path() -> bool:
	if is_dead or not target_player or not is_instance_valid(target_player):
		return false
	var muzzle := enemy_weapon.get_node_or_null("MuzzleMarker") as Node3D if enemy_weapon else null
	var origin := muzzle.global_position if muzzle else global_position + Vector3.UP * 1.2
	var target_point := target_player.global_position + Vector3.UP * PLAYER_TORSO_HEIGHT
	var hit := _get_enemy_fire_path_hit(origin, target_point)
	return not hit.is_empty() and hit.get("collider") == target_player

func _get_enemy_fire_path_hit(origin: Vector3, target_point: Vector3) -> Dictionary:
	if is_dead or not target_player or not is_instance_valid(target_player):
		return {}
	if origin.distance_squared_to(target_point) <= 0.01:
		return {"collider": target_player, "position": target_point, "normal": Vector3.UP}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		target_point,
		ENEMY_FIRE_COLLISION_MASK,
		[get_rid()]
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)

func take_damage(damage_input: Variant) -> void:
	if is_dead:
		return

	var amount: int = 0
	if damage_input is DamageInfo:
		amount = damage_input.amount
	elif typeof(damage_input) == TYPE_INT or typeof(damage_input) == TYPE_FLOAT:
		amount = int(damage_input)

	current_health = maxi(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)

	if current_health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	_set_combat_pose(false)
	velocity = Vector3.ZERO
	fire_timer = 0.0
	target_player = null
	set_physics_process(false)
	if anim_player:
		# Soldier.glb has no imported Death clip. Freeze locomotion before the
		# controlled model-root fall so Run can never override the corpse pose.
		anim_player.stop()
	if enemy_muzzle_flash and is_instance_valid(enemy_muzzle_flash):
		enemy_muzzle_flash.visible = false
	if health_bar_3d:
		health_bar_3d.visible = false
	_retire_combat_collision()
	_start_procedural_death_fall()
	enemy_died.emit()

func _retire_combat_collision() -> void:
	# A dead body remains visual only: it cannot block living enemies and cannot
	# intercept Player hitscan/projectiles aimed at an enemy behind it.
	collision_layer = 0
	collision_mask = 0
	if body_collision:
		body_collision.set_deferred("disabled", true)
	if headshot_area:
		headshot_area.collision_layer = 0
		headshot_area.collision_mask = 0
		headshot_area.set_deferred("monitoring", false)
		headshot_area.set_deferred("monitorable", false)
		var head_collision := headshot_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if head_collision:
			head_collision.set_deferred("disabled", true)

func _start_procedural_death_fall() -> void:
	if not soldier_model:
		return
	var fall_direction := -1.0 if get_instance_id() % 2 == 0 else 1.0
	var start_rotation := soldier_model.rotation_degrees
	var start_position := soldier_model.position
	_death_tween = create_tween()
	_death_tween.set_trans(Tween.TRANS_QUAD)
	_death_tween.set_ease(Tween.EASE_IN)
	_death_tween.set_parallel(true)
	_death_tween.tween_property(
		soldier_model,
		"rotation_degrees",
		start_rotation + Vector3(0.0, 0.0, 86.0 * fall_direction),
		0.62
	)
	_death_tween.tween_property(
		soldier_model,
		"position",
		start_position + Vector3(0.08 * fall_direction, 0.10, 0.0),
		0.62
	)
