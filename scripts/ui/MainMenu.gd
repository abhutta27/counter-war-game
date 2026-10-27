extends Control
## MainMenu.gd
## Main Menu UI Controller displaying operative profile statistics and navigation buttons.

@onready var username_label: Label = $Panel/VBox/ProfileCard/VBox/UsernameVal
@onready var current_stage_label: Label = $Panel/VBox/ProfileCard/VBox/StageVal
@onready var highest_score_label: Label = $Panel/VBox/ProfileCard/VBox/HighestScoreVal
@onready var total_score_label: Label = $Panel/VBox/ProfileCard/VBox/TotalScoreVal

@onready var play_btn: Button = $Panel/VBox/Actions/PlayBtn
@onready var leaderboard_btn: Button = $Panel/VBox/Actions/LeaderboardBtn
@onready var refresh_btn: Button = $Panel/VBox/Actions/RefreshBtn
@onready var signout_btn: Button = $Panel/VBox/Actions/SignOutBtn
@onready var status_label: Label = $Panel/VBox/StatusLabel

func _ready() -> void:
	# Connect singleton signals
	if SupabaseManager:
		SupabaseManager.profile_updated.connect(_update_profile_display)
		SupabaseManager.auth_signed_out.connect(_on_signed_out)
		SupabaseManager.api_request_failed.connect(_on_api_error)
	
	# Connect UI buttons
	play_btn.pressed.connect(_on_play_pressed)
	leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	signout_btn.pressed.connect(_on_signout_pressed)
	
	# Initial display setup
	_update_profile_display(SupabaseManager.current_profile)
	
	# If profile is default or we need fresh stats, trigger fetch
	if SupabaseManager.is_authenticated():
		SupabaseManager.fetch_player_profile()
		status_label.text = "Syncing operative dossier..."
	else:
		status_label.text = "Offline Mode / Guest"

func _update_profile_display(profile: Dictionary) -> void:
	username_label.text = str(profile.get("username", "Operative"))
	current_stage_label.text = "Stage " + str(profile.get("current_stage", 1))
	highest_score_label.text = str(profile.get("highest_score", 0)) + " PTS"
	total_score_label.text = str(profile.get("total_score", 0)) + " PTS"
	status_label.text = "Operative Dossier Synchronized"
	status_label.modulate = Color.LIME_GREEN

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/StageSelection.tscn")

func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/LeaderboardUI.tscn")

func _on_refresh_pressed() -> void:
	status_label.text = "Refreshing cloud profile..."
	status_label.modulate = Color.CYAN
	if SupabaseManager.is_authenticated():
		SupabaseManager.fetch_player_profile()
	else:
		status_label.text = "Cannot refresh: Not authenticated."
		status_label.modulate = Color.ORANGE_RED

func _on_signout_pressed() -> void:
	SupabaseManager.sign_out()

func _on_signed_out() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/LoginRegisterScreen.tscn")

func _on_api_error(endpoint: String, error_msg: String) -> void:
	status_label.text = "Error: " + error_msg
	status_label.modulate = Color.ORANGE_RED
