extends Control
## LeaderboardUI.gd
## UI Controller for fetching and rendering global operative leaderboards from Supabase.

@onready var list_container: VBoxContainer = $Panel/VBox/ScrollContainer/ListContainer
@onready var refresh_btn: Button = $Panel/VBox/Footer/RefreshBtn
@onready var back_btn: Button = $Panel/VBox/Footer/BackBtn
@onready var status_label: Label = $Panel/VBox/StatusLabel

func _ready() -> void:
	if SupabaseManager:
		SupabaseManager.leaderboard_loaded.connect(_on_leaderboard_loaded)
		SupabaseManager.api_request_failed.connect(_on_api_error)
	
	refresh_btn.pressed.connect(_on_refresh_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	_fetch_leaderboard()

func _fetch_leaderboard() -> void:
	status_label.text = "Querying global tactical database..."
	status_label.modulate = Color.CYAN
	refresh_btn.disabled = true
	
	SupabaseManager.fetch_global_leaderboard(10)

func _on_leaderboard_loaded(entries: Array) -> void:
	refresh_btn.disabled = false
	
	# Clear previous list
	for child in list_container.get_children():
		child.queue_free()
		
	if entries.is_empty():
		status_label.text = "No operative records found."
		status_label.modulate = Color.YELLOW
		return
		
	status_label.text = "Displaying Top " + str(entries.size()) + " Global Operatives"
	status_label.modulate = Color.LIME_GREEN
	
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var rank: int = i + 1
		var row := _create_leaderboard_row(rank, entry)
		list_container.add_child(row)

func _create_leaderboard_row(rank: int, data: Dictionary) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 44)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)
	
	# Rank Badge
	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.text = "#" + str(rank)
	rank_label.add_theme_font_size_override("font_size", 14)
	
	match rank:
		1:
			rank_label.modulate = Color(1.0, 0.84, 0.0) # Gold
		2:
			rank_label.modulate = Color(0.75, 0.75, 0.75) # Silver
		3:
			rank_label.modulate = Color(0.8, 0.5, 0.2) # Bronze
		_:
			rank_label.modulate = Color.WHITE
			
	hbox.add_child(rank_label)
	
	# Username
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = str(data.get("username", "Operative"))
	if data.get("id", "") == SupabaseManager.current_user_id:
		name_label.text += " (YOU)"
		name_label.modulate = Color.LIME_GREEN
	hbox.add_child(name_label)
	
	# Stage
	var stage_label := Label.new()
	stage_label.custom_minimum_size = Vector2(100, 0)
	stage_label.text = "Stage " + str(data.get("current_stage", 1))
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.modulate = Color(0.7, 0.8, 1.0)
	hbox.add_child(stage_label)
	
	# High Score
	var high_score_label := Label.new()
	high_score_label.custom_minimum_size = Vector2(120, 0)
	high_score_label.text = "Best: " + str(data.get("highest_score", 0))
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	high_score_label.modulate = Color(0.8, 0.8, 0.8)
	hbox.add_child(high_score_label)
	
	# Total Score
	var total_score_label := Label.new()
	total_score_label.custom_minimum_size = Vector2(140, 0)
	total_score_label.text = str(data.get("total_score", 0)) + " PTS"
	total_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_score_label.modulate = Color(1.0, 0.9, 0.4)
	hbox.add_child(total_score_label)
	
	return row_panel

func _on_refresh_pressed() -> void:
	_fetch_leaderboard()

func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/MainMenu.tscn"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	elif ResourceLoader.exists("res://scenes/ui/MainMenu.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_api_error(_endpoint: String, error_msg: String) -> void:
	refresh_btn.disabled = false
	status_label.text = "Leaderboard Query Failed: " + error_msg
	status_label.modulate = Color.ORANGE_RED
