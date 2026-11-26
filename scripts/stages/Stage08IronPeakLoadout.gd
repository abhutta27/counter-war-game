class_name Stage08IronPeakLoadout
extends Control
## Stage 08 — Operation Iron Peak Loadout Screen
## Matches the top-right panel of the reference UI collage.

const STAGE_SCENE := "res://scenes/stages/Stage08.tscn"
const BRIEFING_SCENE := "res://scenes/stages/Stage08IronPeakBriefing.tscn"

const WEAPONS_DATA := [
	{
		"id": "cw08_rifle",
		"name": "CW-08 ASSAULT RIFLE",
		"category": "ASSAULT RIFLE // PRIMARY EXCLUSIVE",
		"desc": "High-precision gas-operated 5.56x45mm NATO assault rifle engineered for alpine and rugged operations. Outfitted with holographic optic, foregrip, and integrated tactical illuminator.",
		"damage": 82,
		"fire_rate": 78,
		"range": 75,
		"mobility": 80,
		"image": "res://assets/ui/stage08_iron_peak/weapons/cw08_assault_rifle_showcase.png"
	},
	{
		"id": "dmr_sniper",
		"name": "MK-14 DMR",
		"category": "DESIGNATED MARKSMAN // 7.62 NATO",
		"desc": "Long-range semi-automatic rifle with high velocity round and thermal scope for neutralizing alpine ridge sentries at distance.",
		"damage": 94,
		"fire_rate": 42,
		"range": 95,
		"mobility": 60,
		"image": "res://assets/ui/stage08_iron_peak/weapons/cw08_rifle_preview.png"
	},
	{
		"id": "tactical_shotgun",
		"name": "BREACHER-12",
		"category": "COMBAT SHOTGUN // 12 GAUGE",
		"desc": "Heavy-duty pump-action shotgun loaded with armor-piercing slugs for bunker clearing and CQB outpost engagements.",
		"damage": 90,
		"fire_rate": 45,
		"range": 40,
		"mobility": 72,
		"image": "res://assets/ui/stage08_iron_peak/weapons/cw08_rifle_preview.png"
	},
	{
		"id": "cqb_smg",
		"name": "VECTOR-9 SMG",
		"category": "SUBMACHINE GUN // 9x19mm",
		"desc": "Ultra high cyclic rate submachine gun with super recoil mitigation, tuned for fast mountain assaults and tight stairwells.",
		"damage": 66,
		"fire_rate": 96,
		"range": 52,
		"mobility": 92,
		"image": "res://assets/ui/stage08_iron_peak/weapons/cw08_rifle_preview.png"
	}
]

var selected_index: int = 0

@onready var title_label: Label = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/WeaponTitle
@onready var category_label: Label = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/WeaponCategory
@onready var desc_label: Label = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/WeaponDesc
@onready var weapon_preview: TextureRect = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/PreviewPanel/WeaponPreview
@onready var bar_damage: ProgressBar = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/StatsGrid/DamageBar
@onready var bar_fire_rate: ProgressBar = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/StatsGrid/FireRateBar
@onready var bar_range: ProgressBar = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/StatsGrid/RangeBar
@onready var bar_mobility: ProgressBar = $Margin/Card/Margin/VBox/ContentHBox/DetailsVBox/StatsGrid/MobilityBar

@onready var btn_weapon_0: Button = $Margin/Card/Margin/VBox/ContentHBox/ListVBox/WeaponBtn0
@onready var btn_weapon_1: Button = $Margin/Card/Margin/VBox/ContentHBox/ListVBox/WeaponBtn1
@onready var btn_weapon_2: Button = $Margin/Card/Margin/VBox/ContentHBox/ListVBox/WeaponBtn2
@onready var btn_weapon_3: Button = $Margin/Card/Margin/VBox/ContentHBox/ListVBox/WeaponBtn3

@onready var confirm_btn: Button = $Margin/Card/Margin/VBox/FooterHBox/ConfirmButton
@onready var back_btn: Button = $Margin/Card/Margin/VBox/HeaderHBox/BackButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_buttons()
	_apply_styles()
	select_weapon(0)

func _setup_buttons() -> void:
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	
	if btn_weapon_0:
		btn_weapon_0.pressed.connect(func(): select_weapon(0))
	if btn_weapon_1:
		btn_weapon_1.pressed.connect(func(): select_weapon(1))
	if btn_weapon_2:
		btn_weapon_2.pressed.connect(func(): select_weapon(2))
	if btn_weapon_3:
		btn_weapon_3.pressed.connect(func(): select_weapon(3))

func _apply_styles() -> void:
	if confirm_btn:
		Stage08IronPeakUITheme.apply_yellow_button_style(confirm_btn)
	if back_btn:
		Stage08IronPeakUITheme.apply_outline_button_style(back_btn)
	
	var list_buttons = [btn_weapon_0, btn_weapon_1, btn_weapon_2, btn_weapon_3]
	for b in list_buttons:
		if b:
			Stage08IronPeakUITheme.apply_outline_button_style(b)

func select_weapon(index: int) -> void:
	selected_index = clampi(index, 0, WEAPONS_DATA.size() - 1)
	var data: Dictionary = WEAPONS_DATA[selected_index]
	
	if title_label:
		title_label.text = data["name"]
	if category_label:
		category_label.text = data["category"]
	if desc_label:
		desc_label.text = data["desc"]
	if bar_damage:
		bar_damage.value = data["damage"]
	if bar_fire_rate:
		bar_fire_rate.value = data["fire_rate"]
	if bar_range:
		bar_range.value = data["range"]
	if bar_mobility:
		bar_mobility.value = data["mobility"]
	
	if weapon_preview and ResourceLoader.exists(data["image"]):
		weapon_preview.texture = load(data["image"])
	
	# Update button focus/highlighting
	var list_buttons = [btn_weapon_0, btn_weapon_1, btn_weapon_2, btn_weapon_3]
	for i in range(list_buttons.size()):
		var b = list_buttons[i]
		if b:
			if i == selected_index:
				b.add_theme_color_override("font_color", Stage08IronPeakUITheme.COLOR_ACCENT_YELLOW)
			else:
				b.add_theme_color_override("font_color", Stage08IronPeakUITheme.COLOR_TEXT_WHITE)

func _on_confirm_pressed() -> void:
	get_tree().change_scene_to_file(STAGE_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(BRIEFING_SCENE)
