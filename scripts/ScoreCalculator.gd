extends Node
## Deterministic mission scoring. This observes combat metrics and never changes gameplay.

const KILL_POINTS: int = 100
const HEADSHOT_KILL_POINTS: int = 50
const MISSION_COMPLETE_POINTS: int = 500
const HEALTH_BONUS_MULTIPLIER: float = 3.0
const ACCURACY_BONUS_MULTIPLIER: float = 3.0
const MAX_HEALTH_BONUS: int = 300
const MAX_ACCURACY_BONUS: int = 300

func calculate_accuracy(shots_fired: int, shots_hit: int) -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf((float(shots_hit) / float(shots_fired)) * 100.0, 0.0, 100.0)

func get_mission_score_breakdown(
	kills: int,
	headshot_hits: int,
	shots_fired: int,
	shots_hit: int,
	remaining_health: int,
	max_health: int,
	is_victory: bool = true
) -> Dictionary:
	var safe_kills := maxi(0, kills)
	var safe_headshots := maxi(0, headshot_hits)
	var safe_shots_fired := maxi(0, shots_fired)
	var safe_shots_hit := clampi(shots_hit, 0, safe_shots_fired)
	var accuracy := calculate_accuracy(safe_shots_fired, safe_shots_hit)
	var health_percent := 0.0
	if max_health > 0:
		health_percent = clampf((float(remaining_health) / float(max_health)) * 100.0, 0.0, 100.0)

	var kill_score := safe_kills * KILL_POINTS
	var headshot_bonus := safe_headshots * HEADSHOT_KILL_POINTS
	var health_bonus := clampi(int(round(health_percent * HEALTH_BONUS_MULTIPLIER)), 0, MAX_HEALTH_BONUS)
	var accuracy_bonus := clampi(int(round(accuracy * ACCURACY_BONUS_MULTIPLIER)), 0, MAX_ACCURACY_BONUS)
	var mission_complete_score := MISSION_COMPLETE_POINTS if is_victory else 0
	var final_score := kill_score + headshot_bonus + health_bonus + accuracy_bonus + mission_complete_score

	return {
		"kills": safe_kills,
		"headshots": safe_headshots,
		"shots_fired": safe_shots_fired,
		"shots_hit": safe_shots_hit,
		"accuracy_percent": accuracy,
		"remaining_health": maxi(0, remaining_health),
		"max_health": maxi(0, max_health),
		"health_percent": health_percent,
		"kill_score": kill_score,
		"headshot_bonus": headshot_bonus,
		"health_bonus": health_bonus,
		"accuracy_bonus": accuracy_bonus,
		"mission_complete_score": mission_complete_score,
		"final_score": final_score
	}

# Compatibility for older non-campaign callers. Time is intentionally no longer scored.
func get_score_breakdown(targets_eliminated: int, accuracy_percent: float, _time_seconds: float, remaining_health: int) -> Dictionary:
	var result := get_mission_score_breakdown(
		targets_eliminated, 0, 100, clampi(int(round(accuracy_percent)), 0, 100),
		remaining_health, 100, true
	)
	result["targets_eliminated"] = result["kills"]
	result["target_score"] = result["kill_score"]
	result["accuracy_score"] = result["accuracy_bonus"]
	result["health_score"] = result["health_bonus"]
	result["time_seconds"] = 0.0
	result["time_remaining_bonus_seconds"] = 0.0
	result["time_score"] = result["mission_complete_score"]
	return result

func calculate_stage_score(targets_eliminated: int, accuracy_percent: float, time_seconds: float, remaining_health: int) -> int:
	return int(get_score_breakdown(targets_eliminated, accuracy_percent, time_seconds, remaining_health).final_score)
