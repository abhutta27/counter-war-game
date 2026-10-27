class_name CombatFeedback
extends Control
## CombatFeedback.gd
## Manages real-time FPS combat feedback:
## - Tactical reticle with dynamic firing spread & recovery
## - Hitmarker with body/headshot visual distinction
## - Directional damage indicator pointing toward attackers
## - Subtle screen edge damage vignette
## - Kill confirmation toast ("HOSTILE ELIMINATED")

# Crosshair Nodes
@onready var crosshair_container: Control = $Crosshair
@onready var reticle_dot: ColorRect = $Crosshair/CenterDot
@onready var line_left: ColorRect = $Crosshair/LineL
@onready var line_right: ColorRect = $Crosshair/LineR
@onready var line_top: ColorRect = $Crosshair/LineT
@onready var line_bottom: ColorRect = $Crosshair/LineB

# Hitmarker Nodes
@onready var hitmarker_container: Control = $Crosshair/Hitmarker

# Kill Confirmation
@onready var kill_toast: PanelContainer = $KillToast
@onready var kill_toast_label: Label = $KillToast/KillToastLabel

# Damage Indicators
@onready var damage_vignette: ColorRect = $DamageVignette
@onready var damage_indicator_rotator: Control = $DamageIndicatorRotator
@onready var damage_indicator_pointer: Node = $DamageIndicatorRotator/IndicatorPointer

# Base Reticle Dimensions
const BASE_GAP: float = 6.0
const RECOIL_SPREAD: float = 7.0
const SPREAD_RECOVERY_TIME: float = 0.16

var _crosshair_tween: Tween = null
var _hitmarker_tween: Tween = null
var _damage_vignette_tween: Tween = null
var _damage_indicator_tween: Tween = null
var _kill_toast_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_mouse_filters(self)
	
	if hitmarker_container:
		hitmarker_container.visible = false
	if damage_vignette:
		damage_vignette.visible = false
		damage_vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	if damage_indicator_rotator:
		damage_indicator_rotator.visible = false
		damage_indicator_rotator.modulate.a = 0.0
	if kill_toast:
		kill_toast.visible = false
		kill_toast.modulate.a = 0.0
		
	_reset_crosshair_gap(BASE_GAP)

func _setup_mouse_filters(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_setup_mouse_filters(child)

## Sets the gap of the 4 crosshair lines from the center dot
func _reset_crosshair_gap(gap: float) -> void:
	if not line_left or not line_right or not line_top or not line_bottom:
		return
	# Line width = 10, thickness = 2
	line_left.position = Vector2(-gap - 10.0, -1.0)
	line_right.position = Vector2(gap, -1.0)
	line_top.position = Vector2(-1.0, -gap - 10.0)
	line_bottom.position = Vector2(-1.0, gap)

## Called when player fires a weapon - expands crosshair reticle and snaps back
func on_weapon_fired() -> void:
	if not crosshair_container:
		return
	if _crosshair_tween and _crosshair_tween.is_valid():
		_crosshair_tween.kill()
		
	_crosshair_tween = create_tween()
	_crosshair_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Snap outward
	_crosshair_tween.tween_method(_reset_crosshair_gap, BASE_GAP + RECOIL_SPREAD, BASE_GAP, SPREAD_RECOVERY_TIME)

## Called when shot hits an enemy - pulses hitmarker (white for body, crimson for headshot)
func on_shot_hit(is_headshot: bool) -> void:
	if not hitmarker_container:
		return
		
	hitmarker_container.visible = true
	var hit_color = Color(1.0, 0.2, 0.2, 1.0) if is_headshot else Color(1.0, 0.95, 0.8, 0.95)
	
	for tick in hitmarker_container.get_children():
		if tick is ColorRect:
			tick.color = hit_color
			
	if _hitmarker_tween and _hitmarker_tween.is_valid():
		_hitmarker_tween.kill()
		
	hitmarker_container.scale = Vector2(1.25, 1.25)
	_hitmarker_tween = create_tween()
	_hitmarker_tween.set_parallel(true)
	_hitmarker_tween.tween_property(hitmarker_container, "scale", Vector2.ONE, 0.1)
	_hitmarker_tween.tween_interval(0.12)
	_hitmarker_tween.chain().tween_callback(func():
		if hitmarker_container:
			hitmarker_container.visible = false
	)

## Called when player takes damage - displays subtle edge vignette and directional pointer
func on_player_damaged(damage_amount: int, attacker_pos: Vector3, player_pos: Vector3, camera_transform: Transform3D) -> void:
	# 1. Edge damage flash
	if damage_vignette:
		damage_vignette.visible = true
		var intensity = clampf(float(damage_amount) / 40.0, 0.2, 0.45)
		damage_vignette.color = Color(0.75, 0.05, 0.05, intensity)
		
		if _damage_vignette_tween and _damage_vignette_tween.is_valid():
			_damage_vignette_tween.kill()
		_damage_vignette_tween = create_tween()
		_damage_vignette_tween.tween_property(damage_vignette, "color:a", 0.0, 0.35)
		_damage_vignette_tween.tween_callback(func():
			if damage_vignette:
				damage_vignette.visible = false
		)
		
	# 2. Directional damage indicator pointing towards attacker
	if attacker_pos != Vector3.ZERO and damage_indicator_rotator:
		var dir_to_attacker = (attacker_pos - player_pos)
		dir_to_attacker.y = 0.0
		
		if dir_to_attacker.length_squared() > 0.01:
			dir_to_attacker = dir_to_attacker.normalized()
			var cam_forward = -camera_transform.basis.z
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()
			
			var cam_right = camera_transform.basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()
			
			# Project onto camera horizontal plane
			var x_dot = dir_to_attacker.dot(cam_right)
			var z_dot = dir_to_attacker.dot(cam_forward)
			# Angle: 0 is straight ahead (-Z), PI/2 is right (+X), -PI/2 is left (-X)
			var angle = atan2(x_dot, z_dot)
			
			damage_indicator_rotator.visible = true
			damage_indicator_rotator.rotation = angle
			damage_indicator_rotator.modulate.a = 1.0
			
			if _damage_indicator_tween and _damage_indicator_tween.is_valid():
				_damage_indicator_tween.kill()
			_damage_indicator_tween = create_tween()
			_damage_indicator_tween.tween_interval(0.2)
			_damage_indicator_tween.tween_property(damage_indicator_rotator, "modulate:a", 0.0, 0.5)
			_damage_indicator_tween.tween_callback(func():
				if damage_indicator_rotator:
					damage_indicator_rotator.visible = false
			)

## Called when an enemy is neutralized - displays brief tactical kill confirmation toast
func on_enemy_eliminated(enemy_name: String = "HOSTILE", points: int = 500) -> void:
	if not kill_toast or not kill_toast_label:
		return
		
	kill_toast_label.text = "[ + ] %s ELIMINATED (+%d PTS)" % [enemy_name.to_upper(), points]
	kill_toast.visible = true
	kill_toast.modulate.a = 0.0
	kill_toast.offset_top = 65.0
	kill_toast.offset_bottom = 93.0
	
	if _kill_toast_tween and _kill_toast_tween.is_valid():
		_kill_toast_tween.kill()
		
	_kill_toast_tween = create_tween()
	_kill_toast_tween.set_parallel(true)
	_kill_toast_tween.tween_property(kill_toast, "modulate:a", 1.0, 0.12)
	_kill_toast_tween.tween_property(kill_toast, "offset_top", 50.0, 0.12)
	_kill_toast_tween.tween_property(kill_toast, "offset_bottom", 78.0, 0.12)
	
	_kill_toast_tween.chain().tween_interval(1.0)
	
	_kill_toast_tween.chain().set_parallel(true)
	_kill_toast_tween.tween_property(kill_toast, "modulate:a", 0.0, 0.25)
	_kill_toast_tween.tween_property(kill_toast, "offset_top", 42.0, 0.25)
	_kill_toast_tween.tween_property(kill_toast, "offset_bottom", 70.0, 0.25)
	
	_kill_toast_tween.chain().tween_callback(func():
		if kill_toast:
			kill_toast.visible = false
	)
