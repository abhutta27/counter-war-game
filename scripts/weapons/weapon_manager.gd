class_name WeaponManager
extends Node3D
## WeaponManager.gd
## Manages weapon slots, inventory, active weapon equipping, and weapon switching architecture.

const WeaponBase = preload("res://scripts/weapons/weapon_base.gd")

signal weapon_switched(new_weapon: WeaponBase, previous_weapon: WeaponBase)
signal weapon_registered(weapon: WeaponBase)
signal ammo_updated(current_ammo: int, reserve_ammo: int)

var weapons: Array[WeaponBase] = []
var current_weapon_index: int = -1

func _ready() -> void:
	# Automatically register any pre-placed child WeaponBase nodes
	for child in get_children():
		if child is WeaponBase and not (child in weapons):
			register_weapon(child)
			
	if weapons.size() > 0 and current_weapon_index == -1:
		equip_weapon_by_index(0)

## Adds a weapon to the inventory and parents it to this mount if needed
func register_weapon(weapon: WeaponBase) -> bool:
	if not weapon or weapon in weapons:
		return false
		
	if weapon.get_parent() != self:
		add_child(weapon)
		
	weapons.append(weapon)
	weapon.unequip() # Holster initially
	
	# Connect ammo relay signal
	weapon.ammo_changed.connect(_on_weapon_ammo_changed.bind(weapon))
	weapon.fired.connect(_on_weapon_fired.bind(weapon))
	
	weapon_registered.emit(weapon)
	return true

## Equips weapon by index
func equip_weapon_by_index(index: int) -> bool:
	if index < 0 or index >= weapons.size() or index == current_weapon_index:
		return false
		
	var prev_weapon: WeaponBase = get_current_weapon()
	if prev_weapon:
		prev_weapon.unequip()
		
	current_weapon_index = index
	var new_weapon: WeaponBase = weapons[current_weapon_index]
	new_weapon.equip()
	
	weapon_switched.emit(new_weapon, prev_weapon)
	
	# Relay to EventBus
	var eb = get_node_or_null("/root/EventBus")
	if eb and new_weapon.data:
		eb.weapon_switched.emit(new_weapon.data.weapon_name)
		eb.ammo_updated.emit(new_weapon.current_ammo, new_weapon.data.magazine_size)
		
	return true

## Equips weapon by string ID
func equip_weapon_by_id(weapon_id: String) -> bool:
	for i in range(weapons.size()):
		var w = weapons[i]
		if w.data and w.data.weapon_id == weapon_id:
			return equip_weapon_by_index(i)
	return false

func switch_next_weapon() -> bool:
	if weapons.size() <= 1:
		return false
	var next_idx: int = (current_weapon_index + 1) % weapons.size()
	return equip_weapon_by_index(next_idx)

func switch_previous_weapon() -> bool:
	if weapons.size() <= 1:
		return false
	var prev_idx: int = (current_weapon_index - 1 + weapons.size()) % weapons.size()
	return equip_weapon_by_index(prev_idx)

func get_current_weapon() -> WeaponBase:
	if current_weapon_index >= 0 and current_weapon_index < weapons.size():
		return weapons[current_weapon_index]
	return null

func get_weapon_count() -> int:
	return weapons.size()

func _on_weapon_ammo_changed(current: int, reserve: int, weapon: WeaponBase) -> void:
	if weapon == get_current_weapon():
		ammo_updated.emit(current, reserve)
		var eb = get_node_or_null("/root/EventBus")
		if eb and weapon.data:
			eb.ammo_updated.emit(current, weapon.data.magazine_size)

func _on_weapon_fired(weapon: WeaponBase) -> void:
	if weapon == get_current_weapon():
		var eb = get_node_or_null("/root/EventBus")
		if eb and weapon.data:
			eb.weapon_fired.emit(weapon.data.weapon_name)