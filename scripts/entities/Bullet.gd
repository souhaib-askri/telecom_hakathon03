extends Area2D
class_name Bullet

@export var speed: float = 650.0
@export var damage: int = 35
@export var lifetime: float = 1.5
@export var max_range: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var distance_travelled: float = 0.0
var is_welder_arc: bool = false

func _ready() -> void:
	rotation = direction.angle()
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func setup_welder_arc(custom_range: float = 82.0) -> void:
	is_welder_arc = true
	max_range = custom_range
	speed = 380.0
	lifetime = 0.24
	damage = 25
	var spr = get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.texture = preload("res://assets/sprites/fx/welding_spark.png")
		spr.modulate = Color(0.3, 0.95, 1.8, 1.0)
		spr.scale = Vector2(0.9, 0.9)

func _physics_process(delta: float) -> void:
	var move_step = speed * delta
	position += direction * move_step
	if max_range > 0.0:
		distance_travelled += move_step
		if is_welder_arc:
			var progress = clamp(distance_travelled / max_range, 0.0, 1.0)
			scale = Vector2.ONE * lerp(0.85, 1.7, progress)
			modulate.a = lerp(1.0, 0.0, progress)
		if distance_travelled >= max_range:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if not is_welder_arc:
			queue_free()
	elif body is StaticBody2D or body is TileMapLayer:
		queue_free()
