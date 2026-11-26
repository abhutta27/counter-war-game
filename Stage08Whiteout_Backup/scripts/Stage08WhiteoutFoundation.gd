class_name Stage08WhiteoutFoundation
extends "res://scripts/LevelBase3D.gd"
## Stage08WhiteoutFoundation.gd
## Dedicated playable bootstrap testing integration of Player3D, WeaponManager,
## TacticalHUD, and LevelBase3D for Stage 08.

func _ready() -> void:
	# Ensure foundation identification is applied if not overridden by StageManager
	if stage_id <= 1:
		stage_id = 8
	if stage_name.is_empty():
		stage_name = "OPERATION WHITEOUT (FOUNDATION)"
	super._ready()
