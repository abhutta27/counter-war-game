class_name WeaponData
extends Resource
## WeaponData.gd
## Data-driven resource defining individual weapon specifications, ammunition, and visual configs.

const GameConstants = preload("res://scripts/utilities/constants.gd")

@export_group("Identification")
@export var weapon_id: String = "assault_rifle"
@export var weapon_name: String = "Assault Rifle"
@export var weapon_type: GameConstants.WeaponType = GameConstants.WeaponType.ASSAULT_RIFLE

@export_group("Ammunition & Magazine")
@export var magazine_size: int = 30
@export var max_reserve_ammo: int = 120
@export var starting_reserve_ammo: int = 90

@export_group("Ballistics & Mechanics")
@export var is_automatic: bool = false
@export var base_damage: int = 35
@export var fire_rate: float = 0.11 # Time in seconds between consecutive rounds
@export var range: float = 100.0
@export var reload_time: float = 1.6
@export var movement_speed_modifier: float = 1.0
@export var can_ads: bool = true

@export_group("Model & Transform")
@export var weapon_model: PackedScene = null
@export var default_position: Vector3 = Vector3(0.24, -0.22, -0.42)
@export var default_rotation: Vector3 = Vector3.ZERO
@export var model_scale: Vector3 = Vector3(0.14, 0.14, 0.14)
@export var muzzle_offset: Vector3 = Vector3(0.0, 0.02, -0.38)