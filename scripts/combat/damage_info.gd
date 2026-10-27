class_name DamageInfo
extends RefCounted
## DamageInfo.gd
## Structured data package containing complete contextual information for any damage event.

const GameConstants = preload("res://scripts/utilities/constants.gd")

var amount: int = 0
var damage_type: GameConstants.DamageType = GameConstants.DamageType.BULLET
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.UP
var hit_direction: Vector3 = Vector3.FORWARD
var attacker: Node = null
var weapon_name: String = ""
var is_critical: bool = false
var impulse: float = 0.0

func _init(
	p_amount: int = 0,
	p_is_critical: bool = false,
	p_attacker: Node = null,
	p_weapon_name: String = "",
	p_hit_pos: Vector3 = Vector3.ZERO,
	p_hit_dir: Vector3 = Vector3.FORWARD,
	p_hit_norm: Vector3 = Vector3.UP,
	p_damage_type: GameConstants.DamageType = GameConstants.DamageType.BULLET
) -> void:
	amount = p_amount
	is_critical = p_is_critical
	attacker = p_attacker
	weapon_name = p_weapon_name
	hit_position = p_hit_pos
	hit_direction = p_hit_dir
	hit_normal = p_hit_norm
	damage_type = p_damage_type