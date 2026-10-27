extends "res://scripts/entities/Enemy3D.gd"
## Stage05 keeps this compatibility query for its focused regression suite.
## Actual damage resolution now lives in shared Enemy3D for all six stages.

func has_clear_stage05_fire_path() -> bool:
	return has_clear_enemy_fire_path()
