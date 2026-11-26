class_name Stage08HUD
extends Control
## Stage 08 — Operation Whiteout Dedicated Gameplay HUD
## Faithfully implements art_reference/stage08/03_gameplay_hud.png
## Features:
## - Top-left Objective card (Diamond icon + CURRENT OBJECTIVE + dynamic directive)
## - Top-center floating compass tape with dynamic camera heading
## - Top-right RECON DRONE status badge
## - Right MISSION PROGRESS checklist (Reach the ridge, Eliminate snipers, Secure facility, Extract)
## - Bottom-left circular radar minimap + Health bar & HP readout
## - Bottom-right weapon ammo card (M4A1 30|180) + Grenade (2) & Medkit (3) gear badges

# Nodes
@onready var objective_card: PanelContainer = $TopBar/ObjectiveCard
@onready var objective_title_label: Label = $TopBar/ObjectiveCard/Margin/HBox/VBox/ObjectiveTitle
@onready var objective_desc_label: Label = $TopBar/ObjectiveCard/Margin/HBox/VBox/ObjectiveDesc
@onready var enemy_counter_card: PanelContainer = get_node_or_null("TopBar/EnemyCounterCard")
@onready var enemy_counter_label: Label = get_node_or_null("TopBar/EnemyCounterCard/Margin/HBox/CounterLabel")
@onready var hostile_icon_label: Label = get_node_or_null("TopBar/EnemyCounterCard/Margin/HBox/HostileIcon")
@onready var compass_tape_label: Label = $TopBar/CompassContainer/TapeLabel
@onready var compass_heading_label: Label = $TopBar/CompassContainer/HeadingLabel

@onready var progress_panel: PanelContainer = $RightPanel/MissionProgressPanel
@onready var checklist_container: VBoxContainer = $RightPanel/MissionProgressPanel/Margin/VBox/ChecklistItems

@onready var radar_rect: TextureRect = $BottomLeft/RadarContainer/RadarTexture
@onready var health_number_label: Label = $BottomLeft/HealthCard/HealthContainer/HealthNumber
@onready var health_bar: ProgressBar = $BottomLeft/HealthCard/HealthContainer/HealthBar

@onready var weapon_ammo_label: Label = $BottomRight/WeaponCard/Margin/VBox/AmmoRow/CurrentAmmo
@onready var weapon_reserve_label: Label = $BottomRight/WeaponCard/Margin/VBox/AmmoRow/ReserveAmmo
@onready var weapon_name_label: Label = $BottomRight/WeaponCard/Margin/VBox/WeaponName
@onready var grenade_count_label: Label = $BottomRight/GearRow/GrenadeBadge/HBox/Count
@onready var medkit_count_label: Label = $BottomRight/GearRow/MedkitBadge/HBox/Count

var _checklist_rows: Array[Dictionary] = []
var _target_player: Node3D = null
var _target_camera: Camera3D = null

func _ready() -> void:
	_setup_checklist_items()
	_apply_styles()


func _apply_styles() -> void:
	# Objective Card Style
	if objective_card:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.06, 0.10, 0.85)
		sb.border_color = Color(0.18, 0.40, 0.65, 0.75)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12.0
		sb.content_margin_top = 8.0
		sb.content_margin_right = 14.0
		sb.content_margin_bottom = 8.0
		objective_card.add_theme_stylebox_override("panel", sb)

	# Mission Progress Panel Style
	if progress_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.08, 0.12, 0.88)
		sb.border_color = Color(0.18, 0.38, 0.60, 0.80)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 14.0
		sb.content_margin_top = 10.0
		sb.content_margin_right = 14.0
		sb.content_margin_bottom = 12.0
		progress_panel.add_theme_stylebox_override("panel", sb)


func _setup_checklist_items() -> void:
	if not checklist_container:
		return
	for c in checklist_container.get_children():
		c.queue_free()
	_checklist_rows.clear()

	var default_tasks := [
		{"id": "ridge", "text": "Reach the ridge", "done": true},
		{"id": "snipers", "text": "Eliminate snipers", "done": false},
		{"id": "facility", "text": "Secure the facility", "done": false},
		{"id": "extract", "text": "Extract", "done": false}
	]

	for item in default_tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(18, 18)
		var sb_box := StyleBoxFlat.new()
		sb_box.set_corner_radius_all(3)
		sb_box.set_border_width_all(1)
		
		var icon_lbl := Label.new()
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 11)
		box.add_child(icon_lbl)
		
		var lbl := Label.new()
		lbl.text = item["text"]
		lbl.add_theme_font_size_override("font_size", 12)

		row.add_child(box)
		row.add_child(lbl)
		checklist_container.add_child(row)

		_checklist_rows.append({
			"id": item["id"],
			"box": box,
			"icon": icon_lbl,
			"label": lbl,
			"done": item["done"]
		})

	_refresh_checklist_visuals()


func _refresh_checklist_visuals() -> void:
	for row in _checklist_rows:
		var is_done: bool = row["done"]
		var box: PanelContainer = row["box"]
		var icon_lbl: Label = row["icon"]
		var lbl: Label = row["label"]
		
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		if is_done:
			sb.bg_color = Color(0.12, 0.65, 0.35, 0.95)
			sb.border_color = Color(0.25, 0.95, 0.50, 1.0)
			sb.set_border_width_all(1)
			icon_lbl.text = "✓"
			icon_lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		else:
			sb.bg_color = Color(0.03, 0.06, 0.10, 0.6)
			sb.border_color = Color(0.25, 0.42, 0.60, 0.75)
			sb.set_border_width_all(1)
			icon_lbl.text = ""
			lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.85))
		box.add_theme_stylebox_override("panel", sb)


func set_task_completed(task_id: String, completed: bool) -> void:
	for row in _checklist_rows:
		if row["id"] == task_id:
			row["done"] = completed
	_refresh_checklist_visuals()


func update_objective(desc: String, title: String = "CURRENT OBJECTIVE") -> void:
	if objective_title_label:
		objective_title_label.text = title
	if objective_desc_label:
		objective_desc_label.text = desc


func update_enemies_remaining(remaining: int) -> void:
	var safe_count := maxi(0, remaining)
	if not enemy_counter_label:
		enemy_counter_label = get_node_or_null("TopBar/EnemyCounterCard/Margin/HBox/CounterLabel") as Label
	if not hostile_icon_label:
		hostile_icon_label = get_node_or_null("TopBar/EnemyCounterCard/Margin/HBox/HostileIcon") as Label
	if enemy_counter_label:
		enemy_counter_label.text = "ENEMIES REMAINING: %02d" % safe_count
		if safe_count == 0:
			enemy_counter_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.55, 1.0))
			if hostile_icon_label:
				hostile_icon_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.55, 1.0))
				hostile_icon_label.text = "✓"
		else:
			enemy_counter_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.32, 1.0))
			if hostile_icon_label:
				hostile_icon_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25, 1.0))
				hostile_icon_label.text = "☠"

func update_hostiles_count(eliminated: int, total: int) -> void:
	var remaining := maxi(0, total - eliminated)
	update_enemies_remaining(remaining)


func update_health(current_hp: int, max_hp: int = 100) -> void:
	if health_number_label:
		health_number_label.text = str(maxi(0, current_hp))
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp


func update_ammo(current_ammo: int, reserve_ammo: int, weapon_name: String = "M4A1") -> void:
	if weapon_ammo_label:
		weapon_ammo_label.text = str(current_ammo)
	if weapon_reserve_label:
		weapon_reserve_label.text = "| %d" % reserve_ammo
	if weapon_name_label:
		weapon_name_label.text = "— %s —" % weapon_name.to_upper()


func update_gear(grenades: int, medkits: int) -> void:
	if grenade_count_label:
		grenade_count_label.text = str(grenades)
	if medkit_count_label:
		medkit_count_label.text = str(medkits)


func update_compass(heading_deg: float) -> void:
	var norm_deg := fposmod(heading_deg, 360.0)
	if compass_heading_label:
		compass_heading_label.text = "%d" % int(norm_deg)

	if compass_tape_label:
		# Build smooth tape around current heading
		# e.g.: W  285  300  NW | 310  345  N  15  S
		var tape_parts: Array[String] = []
		var sample_offsets := [-60.0, -45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0, 60.0]
		for offset in sample_offsets:
			var tick_deg := fposmod(norm_deg + offset, 360.0)
			var tick_rounded := roundf(tick_deg / 15.0) * 15.0
			var tag := _format_compass_tick(tick_rounded)
			if absf(offset) < 5.0:
				tape_parts.append("| %s" % tag)
			else:
				tape_parts.append(tag)
		compass_tape_label.text = "  ".join(tape_parts)


func _format_compass_tick(deg: float) -> String:
	var d := int(fposmod(deg, 360.0))
	match d:
		0, 360: return "N"
		45: return "NE"
		90: return "E"
		135: return "SE"
		180: return "S"
		225: return "SW"
		270: return "W"
		315: return "NW"
		_: return str(d)


func set_target_player(p: Node3D) -> void:
	_target_player = p
	if _target_player:
		if _target_player.has_node("Camera3D"):
			_target_camera = _target_player.get_node("Camera3D") as Camera3D
		elif _target_player.has_node("Head/Camera3D"):
			_target_camera = _target_player.get_node("Head/Camera3D") as Camera3D


func _process(_delta: float) -> void:
	if _target_camera:
		var forward := -_target_camera.global_transform.basis.z
		var angle_rad := atan2(forward.x, -forward.z)
		var deg := fposmod(rad_to_deg(angle_rad), 360.0)
		update_compass(deg)
