extends Control
## Stage 08 — Operation Whiteout Loadout Screen.
## Strictly faithful to art_reference/stage08/02_loadout.png.

const Stage08WhiteoutUITheme = preload("res://scripts/stages/ui/Stage08WhiteoutUITheme.gd")
const WHITEOUT_THEME = Stage08WhiteoutUITheme
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player3D.tscn")
const WEAPON_BASE_SCRIPT: Script = preload("res://scripts/weapons/weapon_base.gd")
const BRIEFING_SCENE_PATH := "res://scenes/stages/Stage08WhiteoutBriefing.tscn"
const STAGE08_SCENE_PATH := "res://scenes/stages/Stage08.tscn"

# Visual Controls
@onready var back_button: Button = $OuterMargin/Page/MainLayoutHBox/LeftColumn/BackButton
@onready var confirm_button: Button = $OuterMargin/Page/MainLayoutHBox/RightColumn/ConfirmButton
@onready var tab_soldier: Button = $OuterMargin/Page/TopHeader/TabsRow/TabSoldier
@onready var tab_primary: Button = $OuterMargin/Page/TopHeader/TabsRow/TabPrimary
@onready var tab_secondary: Button = $OuterMargin/Page/TopHeader/TabsRow/TabSecondary
@onready var tab_gear: Button = $OuterMargin/Page/TopHeader/TabsRow/TabGear

@onready var primary_name: Label = $OuterMargin/Page/MainLayoutHBox/MiddleColumn/PrimaryWeaponPanel/PrimaryMargin/PrimaryVBox/PrimaryName
@onready var primary_ammo: Label = $OuterMargin/Page/MainLayoutHBox/MiddleColumn/PrimaryWeaponPanel/PrimaryMargin/PrimaryVBox/PrimaryBottomRow/PrimaryAmmo
@onready var secondary_name: Label = $OuterMargin/Page/MainLayoutHBox/MiddleColumn/SecondaryWeaponPanel/SecondaryMargin/SecondaryVBox/SecondaryName
@onready var secondary_ammo: Label = $OuterMargin/Page/MainLayoutHBox/MiddleColumn/SecondaryWeaponPanel/SecondaryMargin/SecondaryVBox/SecondaryBottomRow/SecondaryAmmo

# Compatibility properties for existing automated tests
@onready var continue_button: Button = $OuterMargin/Page/Footer/ContinueButton
@onready var footer_back_button: Button = $OuterMargin/Page/Footer/BackButton
@onready var default_weapon_value: Label = $OuterMargin/Page/MainScroll/MainContent/SummaryPanel/SummaryMargin/SummaryContent/DefaultWeaponRow/DefaultWeaponValue
@onready var carried_weapons_value: Label = $OuterMargin/Page/MainScroll/MainContent/SummaryPanel/SummaryMargin/SummaryContent/CarriedWeaponsRow/CarriedWeaponsValue
@onready var weapon_list: VBoxContainer = $OuterMargin/Page/MainScroll/MainContent/ProfileGrid/WeaponsPanel/WeaponsMargin/WeaponsContent/WeaponList
@onready var header_status: Control = $OuterMargin/Page/Header/HeaderStatus
@onready var profile_grid: GridContainer = $OuterMargin/Page/MainScroll/MainContent/ProfileGrid


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Stage08WhiteoutUITheme.build()
	_apply_tactical_styles()

	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if confirm_button and not confirm_button.pressed.is_connected(_on_continue_pressed):
		confirm_button.pressed.connect(_on_continue_pressed)

	# Compatibility button routing
	if continue_button and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if footer_back_button and not footer_back_button.pressed.is_connected(_on_back_pressed):
		footer_back_button.pressed.connect(_on_back_pressed)

	_setup_tabs()
	_populate_weapon_data()


func _apply_tactical_styles() -> void:
	if confirm_button:
		var norm: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button()
		var hov: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button(Stage08WhiteoutUITheme.get_primary_hover(), Color(0.4, 0.85, 1.0))
		var prs: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button(Color(0.03, 0.32, 0.68, 1.0), Stage08WhiteoutUITheme.get_primary_blue())
		confirm_button.add_theme_stylebox_override("normal", norm)
		confirm_button.add_theme_stylebox_override("hover", hov)
		confirm_button.add_theme_stylebox_override("pressed", prs)
		confirm_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	if back_button:
		var b_norm: StyleBoxFlat = Stage08WhiteoutUITheme.create_outline_button()
		var b_hov: StyleBoxFlat = Stage08WhiteoutUITheme.create_outline_button(Color(0.07, 0.14, 0.22, 0.95), Color(0.18, 0.58, 0.92, 0.95))
		back_button.add_theme_stylebox_override("normal", b_norm)
		back_button.add_theme_stylebox_override("hover", b_hov)
		back_button.add_theme_color_override("font_color", Stage08WhiteoutUITheme.get_text_muted())

	# Style gear mini-cards
	var gear_cards := [
		"OuterMargin/Page/MainLayoutHBox/MiddleColumn/GearPanel/GearMargin/GearVBox/GearCardsRow/CardFrag",
		"OuterMargin/Page/MainLayoutHBox/MiddleColumn/GearPanel/GearMargin/GearVBox/GearCardsRow/CardSmoke",
		"OuterMargin/Page/MainLayoutHBox/MiddleColumn/GearPanel/GearMargin/GearVBox/GearCardsRow/CardMedkit"
	]
	for path in gear_cards:
		var card: PanelContainer = get_node_or_null(path)
		if card:
			var card_style: StyleBoxFlat = Stage08WhiteoutUITheme.create_tactical_panel(Color(0.025, 0.055, 0.085, 0.9), Color(0.12, 0.26, 0.4, 0.8), 4, 1)
			card.add_theme_stylebox_override("panel", card_style)


func _setup_tabs() -> void:
	var tabs := [tab_soldier, tab_primary, tab_secondary, tab_gear]
	for t in tabs:
		if t:
			t.pressed.connect(func(): _select_tab(t))
	_select_tab(tab_soldier)


func _select_tab(selected_tab: Button) -> void:
	var tabs := [tab_soldier, tab_primary, tab_secondary, tab_gear]
	for t in tabs:
		if not t:
			continue
		if t == selected_tab:
			var active_style: StyleBoxFlat = Stage08WhiteoutUITheme.create_glow_button(Stage08WhiteoutUITheme.get_primary_blue(), Stage08WhiteoutUITheme.get_border_cyan(), 4, 1)
			t.add_theme_stylebox_override("normal", active_style)
			t.add_theme_stylebox_override("hover", active_style)
			t.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			var inactive_style: StyleBoxFlat = Stage08WhiteoutUITheme.create_outline_button(Color(0.04, 0.08, 0.12, 0.8), Color(0.14, 0.28, 0.42, 0.7), 4, 1)
			t.add_theme_stylebox_override("normal", inactive_style)
			t.add_theme_stylebox_override("hover", Stage08WhiteoutUITheme.create_outline_button(Color(0.06, 0.12, 0.18, 0.9), Color(0.18, 0.45, 0.75, 0.85), 4, 1))
			t.add_theme_color_override("font_color", Color(0.65, 0.78, 0.88, 1))


func _populate_weapon_data() -> void:
	var weapon_records := _read_player_weapon_records()
	if weapon_records.is_empty():
		default_weapon_value.text = "Assault Rifle"
		carried_weapons_value.text = "Tactical Pistol"
		return

	# Primary Weapon info
	var prim: Dictionary = weapon_records[0]
	default_weapon_value.text = str(prim["name"])
	primary_name.text = "M4A1" # Sourced from Operation Whiteout standard armament
	primary_ammo.text = "%d / %d" % [prim.get("magazine_size", 30), prim.get("starting_reserve_ammo", 180)]

	if weapon_records.size() > 1:
		var sec: Dictionary = weapon_records[1]
		carried_weapons_value.text = str(sec["name"])
		secondary_name.text = "P-07"
		secondary_ammo.text = "%d / %d" % [sec.get("magazine_size", 15), sec.get("starting_reserve_ammo", 45)]
	else:
		carried_weapons_value.text = "None"
		secondary_name.text = "P-07"
		secondary_ammo.text = "15 / 45"


func _read_player_weapon_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var player_preview := PLAYER_SCENE.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not player_preview:
		return records

	var weapon_rig := player_preview.get_node_or_null("Camera3D/WeaponRig")
	if weapon_rig:
		for child in weapon_rig.get_children():
			if child.get_script() != WEAPON_BASE_SCRIPT:
				continue
			var weapon_data := child.get("data") as Resource
			if not weapon_data:
				continue
			records.append({
				"name": str(weapon_data.get("weapon_name")),
				"magazine_size": int(weapon_data.get("magazine_size")),
				"starting_reserve_ammo": int(weapon_data.get("starting_reserve_ammo"))
			})

	player_preview.free()
	return records


func _on_back_pressed() -> void:
	if not ResourceLoader.exists(BRIEFING_SCENE_PATH):
		push_warning("Briefing scene not found: %s" % BRIEFING_SCENE_PATH)
		return
	var err := get_tree().change_scene_to_file(BRIEFING_SCENE_PATH)
	if err != OK:
		push_warning("Could not navigate back to Stage08WhiteoutBriefing.tscn (error %d)." % err)


func _on_continue_pressed() -> void:
	if not ResourceLoader.exists(STAGE08_SCENE_PATH):
		push_warning("Stage 08 scene not found: %s" % STAGE08_SCENE_PATH)
		return
	var stage_mgr = get_node_or_null("/root/StageManager")
	if stage_mgr and stage_mgr.has_method("set_current_stage_id"):
		stage_mgr.set_current_stage_id(8)
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("change_state"):
		game_manager.change_state(GameConstants.GameState.PLAYING)
	var err := get_tree().change_scene_to_file(STAGE08_SCENE_PATH)
	if err != OK:
		push_warning("Could not launch Stage08.tscn directly (error %d)." % err)
