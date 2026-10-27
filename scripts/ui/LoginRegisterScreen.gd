extends Control
## LoginRegisterScreen.gd
## UI Controller for User Authentication (Sign Up & Sign In)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var mode_tabs: HBoxContainer = $Panel/VBox/ModeTabs
@onready var tab_login_btn: Button = $Panel/VBox/ModeTabs/TabLoginBtn
@onready var tab_register_btn: Button = $Panel/VBox/ModeTabs/TabRegisterBtn

@onready var username_container: VBoxContainer = $Panel/VBox/UsernameContainer
@onready var username_input: LineEdit = $Panel/VBox/UsernameContainer/UsernameInput

@onready var email_input: LineEdit = $Panel/VBox/EmailContainer/EmailInput
@onready var password_input: LineEdit = $Panel/VBox/PasswordContainer/PasswordInput

@onready var submit_btn: Button = $Panel/VBox/SubmitBtn
@onready var feedback_label: Label = $Panel/VBox/FeedbackLabel

var is_register_mode: bool = false

func _ready() -> void:
	# Connect signals from SupabaseManager singleton
	if SupabaseManager:
		SupabaseManager.auth_signed_in.connect(_on_auth_signed_in)
		SupabaseManager.auth_signed_up.connect(_on_auth_signed_up)
		SupabaseManager.auth_error.connect(_on_auth_error)
	
	# Connect UI events
	tab_login_btn.pressed.connect(_set_mode.bind(false))
	tab_register_btn.pressed.connect(_set_mode.bind(true))
	submit_btn.pressed.connect(_on_submit_pressed)
	
	# Default mode: Login
	_set_mode(false)
	feedback_label.text = ""

func _set_mode(register_mode: bool) -> void:
	is_register_mode = register_mode
	username_container.visible = is_register_mode
	
	if is_register_mode:
		title_label.text = "CREATE OPERATIVE ACCOUNT"
		submit_btn.text = "REGISTER ACCOUNT"
		tab_register_btn.disabled = true
		tab_login_btn.disabled = false
	else:
		title_label.text = "OPERATIVE AUTHENTICATION"
		submit_btn.text = "AUTHENTICATE & ENTER"
		tab_register_btn.disabled = false
		tab_login_btn.disabled = true
		
	feedback_label.text = ""

func _on_submit_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text
	var username := username_input.text.strip_edges()
	
	# Client-side validations
	if email.is_empty():
		_show_feedback("Please enter your email address.", Color.ORANGE_RED)
		return
	if not email.contains("@") or not email.contains("."):
		_show_feedback("Please provide a valid email format.", Color.ORANGE_RED)
		return
	if password.length() < 6:
		_show_feedback("Password must be at least 6 characters.", Color.ORANGE_RED)
		return
	if is_register_mode and username.length() < 3:
		_show_feedback("Username must be at least 3 characters.", Color.ORANGE_RED)
		return
		
	_set_ui_busy(true, "Connecting to tactical network...")
	
	if is_register_mode:
		SupabaseManager.sign_up(email, password, username)
	else:
		SupabaseManager.sign_in(email, password)

func _set_ui_busy(busy: bool, message: String = "") -> void:
	submit_btn.disabled = busy
	tab_login_btn.disabled = busy or (not is_register_mode)
	tab_register_btn.disabled = busy or is_register_mode
	email_input.editable = not busy
	password_input.editable = not busy
	username_input.editable = not busy
	
	if busy:
		_show_feedback(message, Color.CYAN)

func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.modulate = color

func _on_auth_signed_in(_profile_data: Dictionary) -> void:
	_set_ui_busy(false)
	_show_feedback("Authentication successful. Welcome Operative!", Color.LIME_GREEN)
	
	# Navigate to Main Menu
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_auth_signed_up(_user_data: Dictionary) -> void:
	_set_ui_busy(false)
	_show_feedback("Registration complete! Check verification email or sign in.", Color.LIME_GREEN)
	_set_mode(false)

func _on_auth_error(error_msg: String) -> void:
	_set_ui_busy(false)
	_show_feedback("Error: " + error_msg, Color.ORANGE_RED)
