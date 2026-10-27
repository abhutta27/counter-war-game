extends Node
## ScoreCalculator.gd
## Autoload Singleton for standard score calculations across all game stages.

# Base constants for the score calculation formula
const TARGET_MULTIPLIER: int = 500
const ACCURACY_MULTIPLIER: int = 100
const TIME_LIMIT_BENCHMARK: float = 300.0 # 5 minutes benchmark
const TIME_BONUS_MULTIPLIER: int = 10
const HEALTH_MULTIPLIER: int = 20

## Compute final stage score based on combat performance metrics
## Formula: Final Score = (Targets * 500) + (Accuracy% * 100) + Max(0, 300 - Time) * 10 + (Health * 20)
func calculate_stage_score(
	targets_eliminated: int,
	accuracy_percent: float,
	time_seconds: float,
	remaining_health: int
) -> int:
	var breakdown := get_score_breakdown(targets_eliminated, accuracy_percent, time_seconds, remaining_health)
	return breakdown.final_score

## Returns a structured dictionary with sub-scores and final total for UI display
func get_score_breakdown(
	targets_eliminated: int,
	accuracy_percent: float,
	time_seconds: float,
	remaining_health: int
) -> Dictionary:
	var clamped_accuracy: float = clampf(accuracy_percent, 0.0, 100.0)
	var clamped_health: int = maxi(0, remaining_health)
	
	var target_score: int = targets_eliminated * TARGET_MULTIPLIER
	var accuracy_score: int = int(round(clamped_accuracy * ACCURACY_MULTIPLIER))
	
	var time_remaining: float = maxf(0.0, TIME_LIMIT_BENCHMARK - time_seconds)
	var time_score: int = int(round(time_remaining * TIME_BONUS_MULTIPLIER))
	
	var health_score: int = clamped_health * HEALTH_MULTIPLIER
	
	var total: int = target_score + accuracy_score + time_score + health_score
	
	return {
		"targets_eliminated": targets_eliminated,
		"target_score": target_score,
		"accuracy_percent": clamped_accuracy,
		"accuracy_score": accuracy_score,
		"time_seconds": time_seconds,
		"time_remaining_bonus_seconds": time_remaining,
		"time_score": time_score,
		"remaining_health": clamped_health,
		"health_score": health_score,
		"final_score": total
	}

## Calculates shooting accuracy percentage safely
func calculate_accuracy(shots_fired: int, shots_hit: int) -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf((float(shots_hit) / float(shots_fired)) * 100.0, 0.0, 100.0)
