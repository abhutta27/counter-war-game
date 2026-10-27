extends Node
## SupabaseManager.gd
## Autoload Singleton handling Supabase GoTrue Authentication & PostgREST Database operations.

# Default Supabase configuration credentials
var supabase_url: String = "https://euczxerzdwvmmtxcoutv.supabase.co"
var supabase_anon_key: String = "sb_publishable_D-S4BC-fOzDG4OwcWxLajQ_jBNRCWAY"

# Session state
var access_token: String = ""
var refresh_token: String = ""
var current_user_id: String = ""
var current_user_email: String = ""
var current_profile: Dictionary = {
	"id": "",
	"username": "Operative",
	"current_stage": 1,
	"total_score": 0,
	"highest_score": 0
}

# Signals for UI and Game State observation
signal auth_signed_up(user_data: Dictionary)
signal auth_signed_in(profile_data: Dictionary)
signal auth_signed_out()
signal auth_error(error_message: String)

signal profile_updated(profile_data: Dictionary)
signal stage_score_saved(result_data: Dictionary)
signal leaderboard_loaded(leaderboard_data: Array)
signal api_request_failed(endpoint: String, error_message: String)

func _ready() -> void:
	load_config_from_file()

## Load optional credentials config override from user:// or res://
func load_config_from_file() -> void:
	var config_paths: Array[String] = ["user://supabase_config.json", "res://supabase_config.json"]
	for path in config_paths:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				var json := JSON.new()
				if json.parse(content) == OK and json.data is Dictionary:
					var cfg: Dictionary = json.data
					if cfg.has("supabase_url") and not cfg["supabase_url"].is_empty():
						supabase_url = cfg["supabase_url"].trim_suffix("/")
					if cfg.has("supabase_anon_key") and not cfg["supabase_anon_key"].is_empty():
						supabase_anon_key = cfg["supabase_anon_key"]
					print("[SupabaseManager] Loaded config from: ", path)
					return

## Check if user is currently authenticated
func is_authenticated() -> bool:
	return not access_token.is_empty() and not current_user_id.is_empty()

## Build base HTTP request headers
func _get_headers(use_auth: bool = true) -> PackedStringArray:
	var token: String = access_token if (use_auth and not access_token.is_empty()) else supabase_anon_key
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + supabase_anon_key,
		"Authorization: Bearer " + token
	])
	return headers

# ==============================================================================
# 1. AUTHENTICATION (GoTrue API)
# ==============================================================================

## Register new user with email, password, and custom username
func sign_up(email: String, password: String, username: String) -> void:
	var endpoint := supabase_url + "/auth/v1/signup"
	var payload := {
		"email": email.strip_edges(),
		"password": password,
		"data": {
			"username": username.strip_edges()
		}
	}
	
	_make_http_request(
		endpoint,
		HTTPClient.METHOD_POST,
		_get_headers(false),
		JSON.stringify(payload),
		Callable(self, "_on_sign_up_completed")
	)

func _on_sign_up_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_json = _parse_json_body(body)
	
	if response_code in [200, 201]:
		print("[SupabaseManager] Sign up succeeded.")
		if response_json is Dictionary and response_json.has("access_token"):
			# Auto signed in if email confirmation is disabled in Supabase
			_process_auth_token_response(response_json)
		else:
			emit_signal("auth_signed_up", response_json if response_json is Dictionary else {})
	else:
		var error_msg := _extract_error_message(response_json, response_code, "Sign up failed")
		print("[SupabaseManager] Sign up failed: ", error_msg)
		emit_signal("auth_error", error_msg)

## Sign in with existing email and password
func sign_in(email: String, password: String) -> void:
	var endpoint := supabase_url + "/auth/v1/token?grant_type=password"
	var payload := {
		"email": email.strip_edges(),
		"password": password
	}
	
	_make_http_request(
		endpoint,
		HTTPClient.METHOD_POST,
		_get_headers(false),
		JSON.stringify(payload),
		Callable(self, "_on_sign_in_completed")
	)

func _on_sign_in_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_json = _parse_json_body(body)
	
	if response_code == 200 and response_json is Dictionary:
		print("[SupabaseManager] Sign in succeeded. Parsing session token...")
		_process_auth_token_response(response_json)
	else:
		var error_msg := _extract_error_message(response_json, response_code, "Sign in failed")
		print("[SupabaseManager] Sign in error: ", error_msg)
		emit_signal("auth_error", error_msg)

## Processes successful token payload and fetches profile
func _process_auth_token_response(data: Dictionary) -> void:
	access_token = data.get("access_token", "")
	refresh_token = data.get("refresh_token", "")
	
	if data.has("user") and data["user"] is Dictionary:
		current_user_id = data["user"].get("id", "")
		current_user_email = data["user"].get("email", "")
	
	# Fetch the database profile record
	fetch_player_profile(current_user_id)

## Sign out user and reset local state
func sign_out() -> void:
	access_token = ""
	refresh_token = ""
	current_user_id = ""
	current_user_email = ""
	current_profile = {
		"id": "",
		"username": "Operative",
		"current_stage": 1,
		"total_score": 0,
		"highest_score": 0
	}
	emit_signal("auth_signed_out")
	print("[SupabaseManager] User signed out.")

# ==============================================================================
# 2. PROFILE MANAGEMENT (PostgREST API)
# ==============================================================================

## Fetch player profile from profiles table
func fetch_player_profile(user_id: String = "") -> void:
	var target_id := user_id if not user_id.is_empty() else current_user_id
	if target_id.is_empty():
		emit_signal("auth_error", "No user ID specified to fetch profile.")
		return
		
	var endpoint := supabase_url + "/rest/v1/profiles?id=eq." + target_id + "&select=*"
	
	_make_http_request(
		endpoint,
		HTTPClient.METHOD_GET,
		_get_headers(true),
		"",
		Callable(self, "_on_profile_fetched").bind(target_id)
	)

func _on_profile_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, target_id: String) -> void:
	var response_json = _parse_json_body(body)
	
	if response_code in [200, 206] and response_json is Array:
		if response_json.size() > 0:
			var profile: Dictionary = response_json[0]
			if target_id == current_user_id:
				current_profile = profile
				emit_signal("auth_signed_in", current_profile)
				emit_signal("profile_updated", current_profile)
				print("[SupabaseManager] Profile loaded for: ", current_profile.get("username", ""))
			else:
				emit_signal("profile_updated", profile)
		else:
			print("[SupabaseManager] Profile not found in database, creating placeholder...")
			current_profile["id"] = target_id
			emit_signal("auth_signed_in", current_profile)
	else:
		var error_msg := _extract_error_message(response_json, response_code, "Failed to load profile")
		emit_signal("api_request_failed", "fetch_profile", error_msg)

# ==============================================================================
# 3. STAGE SCORE POSTING & UNLOCKS
# ==============================================================================

## Save or update stage score record in stage_scores table
func save_stage_score(stage_id: int, score: int, accuracy: float, time_seconds: float) -> void:
	if not is_authenticated():
		emit_signal("api_request_failed", "save_stage_score", "User is not authenticated.")
		return
		
	var endpoint := supabase_url + "/rest/v1/stage_scores?on_conflict=user_id,stage_id"
	
	var custom_headers := _get_headers(true)
	custom_headers.append("Prefer: resolution=merge-duplicates,return=representation")
	
	var payload := {
		"user_id": current_user_id,
		"stage_id": stage_id,
		"high_score": score,
		"accuracy": accuracy,
		"fastest_time": time_seconds,
		"updated_at": Time.get_datetime_string_from_system(true, false) + "Z"
	}
	
	_make_http_request(
		endpoint,
		HTTPClient.METHOD_POST,
		custom_headers,
		JSON.stringify(payload),
		Callable(self, "_on_stage_score_saved").bind(stage_id, score)
	)

func _on_stage_score_saved(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, stage_id: int, score: int) -> void:
	var response_json = _parse_json_body(body)
	
	if response_code in [200, 201] and response_json is Array:
		var saved_record: Dictionary = response_json[0] if response_json.size() > 0 else {}
		print("[SupabaseManager] Stage ", stage_id, " score saved: ", score)
		emit_signal("stage_score_saved", saved_record)
		
		# Refetch profile to receive updated total score and unlocked current_stage from Postgres triggers
		fetch_player_profile(current_user_id)
	else:
		var error_msg := _extract_error_message(response_json, response_code, "Failed to save stage score")
		print("[SupabaseManager] Save score error: ", error_msg)
		emit_signal("api_request_failed", "save_stage_score", error_msg)

# ==============================================================================
# 4. GLOBAL LEADERBOARD
# ==============================================================================

## Fetch top players sorted by total_score descending
func fetch_global_leaderboard(limit: int = 10) -> void:
	var endpoint := supabase_url + "/rest/v1/profiles?select=id,username,current_stage,total_score,highest_score&order=total_score.desc&limit=" + str(limit)
	
	_make_http_request(
		endpoint,
		HTTPClient.METHOD_GET,
		_get_headers(false),
		"",
		Callable(self, "_on_leaderboard_fetched")
	)

func _on_leaderboard_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_json = _parse_json_body(body)
	
	if response_code == 200 and response_json is Array:
		print("[SupabaseManager] Global Leaderboard loaded (", response_json.size(), " entries).")
		emit_signal("leaderboard_loaded", response_json)
	else:
		var error_msg := _extract_error_message(response_json, response_code, "Failed to load leaderboard")
		emit_signal("api_request_failed", "fetch_leaderboard", error_msg)

# ==============================================================================
# 5. INTERNAL HTTP DISPATCHER & JSON HELPERS
# ==============================================================================

## Dynamic non-blocking HTTPRequest creator
func _make_http_request(url: String, method: int, headers: PackedStringArray, body: String, callback: Callable) -> void:
	var http_node := HTTPRequest.new()
	add_child(http_node)
	
	http_node.request_completed.connect(
		func(res: int, code: int, hdrs: PackedStringArray, b: PackedByteArray):
			callback.call(res, code, hdrs, b)
			http_node.queue_free()
	)
	
	var err := http_node.request(url, headers, method, body)
	if err != OK:
		print("[SupabaseManager] HTTPRequest failed to start. Error code: ", err)
		http_node.queue_free()
		emit_signal("api_request_failed", url, "Failed to initiate HTTP request (Error " + str(err) + ")")

## Parse JSON response safely
func _parse_json_body(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return null
	var json_string := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	return null

## Format standard readable error message from response
func _extract_error_message(data: Variant, code: int, fallback: String) -> String:
	if data is Dictionary:
		if data.has("msg"):
			return str(data["msg"])
		elif data.has("message"):
			return str(data["message"])
		elif data.has("error_description"):
			return str(data["error_description"])
		elif data.has("error"):
			return str(data["error"])
	return fallback + " (HTTP Status " + str(code) + ")"
