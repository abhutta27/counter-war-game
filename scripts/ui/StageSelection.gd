extends Control
## StageSelection.gd
## UI Controller for selecting and launching campaign stages (1 to 5) with progression locks.

@onready var stage_container: GridContainer = $Panel/VBox/ScrollContainer/StageGrid
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var current_progress_label: Label = $Panel/VBox/ProgressHeader/ProgressVal

const TOTAL_STAGES: int = 5

# Stage meta info
const STAGE_INFO: Dictionary = {
	1: {"name": "OPERATION FIRST CONTACT", "desc": "Urban Target Training Zone", "targets": 5},
	2: {"name": "OPERATION SHADOW BARRACKS", "desc": "Hostile Compound Infiltration", "targets": 8},
	3: {"name": "OPERATION DESERT VIPER", "desc": "Perimeter Breach & Neutralization", "targets": 10},
	4: {"name": "OPERATION IRON STORM", "desc": "Fortified Heavy Sector Strike", "targets": 12},
	5: {"name": "OPERATION APEX TITAN", "desc": "Elite Commander Base Assault", "targets": 15}
}

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	render_stage_grid()

func render_stage_grid() -> void:
	# Clear existing children if re-rendering
	for child in stage_container.get_children():
		child.queue_free()
		
	var unlocked_stage: int = int(SupabaseManager.current_profile.get("current_stage", 1))
	current_progress_label.text = "Highest Stage Available: " + str(unlocked_stage)
	
	for stage_num in range(1, TOTAL_STAGES + 1):
		var stage_card := _create_stage_card(stage_num, unlocked_stage)
		stage_container.add_child(stage_card)

func _create_stage_card(stage_num: int, unlocked_stage: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	var is_unlocked: bool = (stage_num <= unlocked_stage)
	var info: Dictionary = STAGE_INFO.get(stage_num, {"name": "STAGE " + str(stage_num), "desc": "", "targets": 5})
	
	# Stage Title
	var title_lbl := Label.new()
	title_lbl.text = "STAGE " + str(stage_num) + ": " + info["name"]
	title_lbl.add_theme_font_size_override("font_size", 14)
	if is_unlocked:
		title_lbl.modulate = Color.WHITE
	else:
		title_lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
	vbox.add_child(title_lbl)
	
	# Briefing
	var desc_lbl := Label.new()
	desc_lbl.text = info["desc"] + "\nHostiles: " + str(info["targets"])
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.7, 0.8, 0.9, 1.0) if is_unlocked else Color(0.4, 0.4, 0.4, 1.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Action button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	if is_unlocked:
		btn.text = "LAUNCH MISSION"
		btn.disabled = false
		btn.pressed.connect(_on_stage_selected.bind(stage_num))
	else:
		btn.text = "LOCKED [CLASSIFIED]"
		btn.disabled = true
	vbox.add_child(btn)
	
	return card

func _on_stage_selected(stage_num: int) -> void:
	print("[StageSelection] Launching Stage ", stage_num)
	# Set current target stage metadata or load level
	# Level1 scene handles stage scaling or specific level scene
	var level_scene_path := "res://scenes/levels/Level1.tscn"
	if ResourceLoader.exists(level_scene_path):
		# We can pass stage number via a parameter or singleton before changing scene
		get_tree().set_meta("selected_stage_id", stage_num)
		get_tree().change_scene_to_file(level_scene_path)
	else:
		print("[StageSelection] Level scene not found: ", level_scene_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
