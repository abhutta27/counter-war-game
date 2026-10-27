class_name WeaponBase
extends Node3D
## WeaponBase.gd
## Base component representing a physical equipped or holstered weapon instance.
## Controls magazine ammunition, reserve pool, reload lifecycle, and firing architecture.

const WeaponData = preload("res://scripts/weapons/weapon_data.gd")

signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal fired()
signal reload_started()
signal reload_finished()
signal equipped()
signal unequipped()

@export var data: WeaponData = null

var current_ammo: int = 0
var reserve_ammo: int = 0
var is_reloading: bool = false
var is_equipped: bool = false
var can_fire: bool = true

var _cooldown_timer: float = 0.0
var _reload_timer: float = 0.0

var weapon_mesh_instance: Node3D = null

func _init(p_data: WeaponData = null) -> void:
	if p_data:
		setup(p_data)

func _ready() -> void:
	if data and current_ammo == 0 and reserve_ammo == 0:
		setup(data)

## Initializes weapon with specific data resource and fills magazine
func setup(p_data: WeaponData) -> void:
	data = p_data
	current_ammo = data.magazine_size
	reserve_ammo = data.starting_reserve_ammo
	
	position = data.default_position
	rotation = data.default_rotation
	
	_spawn_visual_model()
	ammo_changed.emit(current_ammo, reserve_ammo)

func _spawn_visual_model() -> void:
	if not data or not data.weapon_model:
		return
		
	if weapon_mesh_instance and is_instance_valid(weapon_mesh_instance):
		weapon_mesh_instance.queue_free()
		weapon_mesh_instance = null
		
	weapon_mesh_instance = data.weapon_model.instantiate() as Node3D
	if weapon_mesh_instance:
		weapon_mesh_instance.name = "Model"
		weapon_mesh_instance.scale = data.model_scale
		add_child(weapon_mesh_instance)

func equip() -> void:
	is_equipped = true
	visible = true
	equipped.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)

func unequip() -> void:
	is_equipped = false
	visible = false
	if is_reloading:
		is_reloading = false
		_reload_timer = 0.0
	unequipped.emit()

func can_shoot() -> bool:
	return is_equipped and can_fire and not is_reloading and current_ammo > 0 and _cooldown_timer <= 0.0

## Consumes ammo, starts cooldown timer, and emits fired signal (mechanics reserved for Step 07)
func fire() -> bool:
	if not can_shoot():
		return false
		
	current_ammo -= 1
	_cooldown_timer = data.fire_rate if data else 0.1
	can_fire = false
	
	fired.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)
	return true

## Initiates reload process if ammo is missing and reserve is available
func reload() -> bool:
	if not is_equipped or is_reloading or not data:
		return false
	if current_ammo >= data.magazine_size or reserve_ammo <= 0:
		return false
		
	is_reloading = true
	_reload_timer = data.reload_time
	reload_started.emit()
	return true

func _complete_reload() -> void:
	if not data:
		return
	var needed: int = data.magazine_size - current_ammo
	var transfer: int = mini(needed, reserve_ammo)
	current_ammo += transfer
	reserve_ammo -= transfer
	is_reloading = false
	_reload_timer = 0.0
	can_fire = true
	
	reload_finished.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)

func add_reserve_ammo(amount: int) -> void:
	if not data:
		return
	reserve_ammo = mini(reserve_ammo + amount, data.max_reserve_ammo)
	ammo_changed.emit(current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	if not is_equipped:
		return
		
	# Cooldown recovery
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			can_fire = true
			
	# Reload recovery
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_complete_reload()

## Returns global barrel tip position for projectile spawning
func get_muzzle_global_position() -> Vector3:
	var offset = data.muzzle_offset if data else Vector3(0.0, 0.02, -0.38)
	return to_global(offset)

## Triggers visual barrel muzzle flash
func trigger_muzzle_flash() -> void:
	var sys = get_node_or_null("/root/ShootingSystem")
	if sys and sys.has_method("trigger_muzzle_flash"):
		var offset = data.muzzle_offset if data else Vector3(0.0, 0.02, -0.38)
		sys.trigger_muzzle_flash(self, offset, true)