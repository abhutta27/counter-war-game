extends Area2D
## TargetDummy.gd
## Tactical hostile target dummy that registers player hits, plays impact feedback, and tracks health.

signal target_destroyed(target_node: Node2D)
signal target_hit(is_headshot: bool)

@export var max_health: int = 100
@export var is_active: bool = true

var current_health: int = 100
var is_dead: bool = false

@onready var visual_body: ColorRect = $VisualContainer/BodyRect
@onready var visual_head: ColorRect = $VisualContainer/HeadRect
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

## Receive hit from player weapon
func take_damage(amount: int, is_headshot: bool = false) -> void:
	if is_dead or not is_active:
		return
		
	var actual_damage: int = amount * 2 if is_headshot else amount
	current_health = maxi(0, current_health - actual_damage)
	
	if health_bar:
		health_bar.value = current_health
		
	emit_signal("target_hit", is_headshot)
	_play_hit_flash(is_headshot)
	
	if current_health <= 0:
		_die()

func _play_hit_flash(is_headshot: bool) -> void:
	var flash_color := Color.YELLOW if is_headshot else Color.RED
	var original_body_color := visual_body.color
	var original_head_color := visual_head.color
	
	visual_body.color = flash_color
	visual_head.color = flash_color
	
	var tween := create_tween()
	tween.tween_property(visual_body, "color", original_body_color, 0.1)
	tween.parallel().tween_property(visual_head, "color", original_head_color, 0.1)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("target_destroyed", self)
	
	# Death fade out tween
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
