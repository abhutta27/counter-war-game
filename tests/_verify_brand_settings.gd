extends SceneTree

func _init() -> void:
	assert(ProjectSettings.get_setting("application/config/icon") == "res://assets/branding/cw_mark_512.png")
	assert(ProjectSettings.get_setting("application/config/windows_native_icon") == "res://assets/branding/counter_war.ico")
	assert(ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/branding/counter_war_splash.png")
	assert(ProjectSettings.get_setting("application/boot_splash/show_image") == true)
	assert(ProjectSettings.get_setting("application/boot_splash/stretch_mode") == 1)
	assert(ProjectSettings.get_setting("application/config/name") == "Counter_War_Game", "Internal name must preserve existing user:// location")
	print("[BrandSettings] PASS: icon, native icon, splash, and original user directory identity")
	quit(0)
