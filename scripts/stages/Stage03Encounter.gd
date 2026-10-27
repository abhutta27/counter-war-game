class_name Stage03Encounter
extends "res://scripts/LevelBase3D.gd"
## Stage03-only progressive encounter controller. It gates when the existing
## Enemy3D physics behavior begins; it does not replace or modify combat AI.

const ENCOUNTER_GROUPS := {
	1: ["Enemy3D_1", "Enemy3D_2"],
	2: ["Enemy3D_3", "Enemy3D_4", "Enemy3D_5"],
	3: ["Enemy3D_6", "Enemy3D_7"],
}

const TRIGGER_DATA := {
	1: {"name": "OuterForestActivation", "center": Vector3(0, 1.5, 24), "size": Vector3(68, 4, 8)},
	2: {"name": "CommunicationsCompoundActivation", "center": Vector3(0, 1.5, 0), "size": Vector3(72, 4, 8)},
	3: {"name": "InnerBlacksiteActivation", "center": Vector3(0, 1.5, -21), "size": Vector3(72, 4, 8)},
}

var activated_zones: Dictionary = {1: false, 2: false, 3: false}
var encounter_zones: Node3D = null

func _ready() -> void:
	# Children finish _ready before the stage root, so every guard already owns its
	# normal weapon, idle animation, and voice emitter when it is safely paused.
	_set_all_guards_inactive()
	super._ready()
	_build_encounter_zones()

func _set_all_guards_inactive() -> void:
	var container := get_node_or_null("Enemies")
	if not container:
		return
	for enemy in container.get_children():
		_set_guard_active(enemy, false)

func _set_guard_active(enemy: Node, active: bool) -> void:
	if not enemy:
		return
	enemy.set_meta("stage03_encounter_active", active)
	enemy.set_physics_process(active)
	if not active:
		enemy.velocity = Vector3.ZERO
		# Enemy3D begins in IDLE; explicitly retaining it documents the guard state
		# and prevents a stale state if this scene is ever reinitialized in place.
		if "current_state" in enemy:
			enemy.current_state = 0

func _build_encounter_zones() -> void:
	encounter_zones = Node3D.new()
	encounter_zones.name = "EncounterActivationZones"
	add_child(encounter_zones)
	for zone_id in [1, 2, 3]:
		var data: Dictionary = TRIGGER_DATA[zone_id]
		var area := Area3D.new()
		area.name = data.name
		area.position = data.center
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitoring = true
		area.monitorable = false
		var collision := CollisionShape3D.new()
		collision.name = "PlayerTrigger"
		var shape := BoxShape3D.new()
		shape.size = data.size
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_zone_body_entered.bind(zone_id))
		encounter_zones.add_child(area)

func _on_zone_body_entered(body: Node3D, zone_id: int) -> void:
	if body != player and not body.is_in_group("player"):
		return
	activate_encounter_zone(zone_id)

func activate_encounter_zone(zone_id: int) -> void:
	if not ENCOUNTER_GROUPS.has(zone_id) or activated_zones.get(zone_id, false):
		return
	activated_zones[zone_id] = true
	for enemy_name in ENCOUNTER_GROUPS[zone_id]:
		var enemy := enemies_container.get_node_or_null(enemy_name)
		_set_guard_active(enemy, true)
	print("[Stage03Encounter] Zone %d activated: %s" % [zone_id, ENCOUNTER_GROUPS[zone_id]])

func is_zone_active(zone_id: int) -> bool:
	return activated_zones.get(zone_id, false)

func is_enemy_encounter_active(enemy_name: String) -> bool:
	var enemy := enemies_container.get_node_or_null(enemy_name)
	return enemy != null and bool(enemy.get_meta("stage03_encounter_active", false))
