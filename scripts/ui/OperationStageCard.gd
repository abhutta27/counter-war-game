extends Button
class_name OperationStageCard
## Compact, keyboard-accessible mission row. It selects a mission dossier only;
## launching is handled by the single action in Operations HQ.

signal mission_selected(stage_id: int)

const STATUS_LOCKED := "LOCKED"
const STATUS_AVAILABLE := "AVAILABLE"
const STATUS_COMPLETED := "COMPLETED"

var stage_id: int = -1
var operation_id: int = -1
var stage_status: String = STATUS_LOCKED

@onready var stage_number_label: Label = $Margin/Row/StageNumber
@onready var mission_title_label: Label = $Margin/Row/MissionTitle
@onready var best_score_label: Label = $Margin/Row/BestScore
@onready var status_label: Label = $Margin/Row/Status

func _ready() -> void:
	_clear_tooltips()
	pressed.connect(_on_pressed)

func configure(stage_info: Dictionary, status: String, best_score: int) -> void:
	stage_id = int(stage_info.get("stage_id", stage_info.get("id", -1)))
	operation_id = int(stage_info.get("operation_id", -1))
	stage_status = status if status in [STATUS_LOCKED, STATUS_AVAILABLE, STATUS_COMPLETED] else STATUS_LOCKED
	stage_number_label.text = "%02d" % stage_id
	mission_title_label.text = _short_title(str(stage_info.get("mission_title", stage_info.get("name", "CLASSIFIED"))))
	best_score_label.text = _format_score(best_score)
	status_label.text = stage_status
	_clear_tooltips()
	match stage_status:
		STATUS_COMPLETED:
			status_label.modulate = Color(0.42, 0.91, 0.62)
		STATUS_AVAILABLE:
			status_label.modulate = Color(0.42, 0.82, 1.0)
		_:
			status_label.modulate = Color(0.58, 0.62, 0.68)
			mission_title_label.modulate = Color(0.66, 0.69, 0.73)

func set_selected(is_selected: bool) -> void:
	set_pressed_no_signal(is_selected)
	if is_selected:
		grab_focus()

func get_best_score_text() -> String:
	return best_score_label.text

func _on_pressed() -> void:
	mission_selected.emit(stage_id)

func _clear_tooltips() -> void:
	tooltip_text = ""
	for descendant in find_children("*", "Control", true, false):
		(descendant as Control).tooltip_text = ""

func _short_title(full_title: String) -> String:
	return full_title.trim_prefix("OPERATION ")

func _format_score(score: int) -> String:
	var raw := str(maxi(0, score))
	var formatted := ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted
