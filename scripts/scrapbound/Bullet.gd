extends Area2D
class_name ScrapboundBullet

@export var speed: float = 520.0
@export var damage: int = 25
@export var lifetime: float = 2.0
@export var is_piercing: bool = false
@export var shooter_player_id: int = 1
@export var max_range: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var distance_travelled: float = 0.0
var is_welder_arc: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var pierced_count: int = 0
const MAX_PIERCE: int = 3

func _ready() -> void:
	add_to_group("Projectiles")
	rotation = direction.angle()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func set_bullet_color(color: Color) -> void:
	if sprite:
		sprite.modulate = color

func setup_welder_arc(shooter_id: int, arc_range: float = 82.0) -> void:
	is_welder_arc = true
	max_range = arc_range
	speed = 360.0
	is_piercing = true
	lifetime = 0.24
	shooter_player_id = shooter_id
	
	var spark_tex = preload("res://assets/sprites/fx/welding_spark.png")
	if sprite:
		sprite.texture = spark_tex
		if shooter_id == 1:
			sprite.modulate = Color(0.3, 0.95, 1.8, 1.0)
		else:
			sprite.modulate = Color(1.8, 0.75, 0.2, 1.0)
			
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = 12.0

func _physics_process(delta: float) -> void:
	var move_step = speed * delta
	position += direction * move_step
	
	if max_range > 0.0:
		distance_travelled += move_step
		if is_welder_arc:
			var progress = clamp(distance_travelled / max_range, 0.0, 1.0)
			scale = Vector2.ONE * lerp(0.85, 1.75, progress)
			modulate.a = lerp(1.0, 0.0, progress)
		if distance_travelled >= max_range:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _handle_hit(target: Node2D) -> void:
	if target.is_in_group("Enemies"):
		if collision_shape and not is_piercing:
			collision_shape.set_deferred("disabled", true)
		if target.has_method("take_damage"):
			target.take_damage(damage, shooter_player_id)
		
		if not is_piercing:
			queue_free()
		else:
			pierced_count += 1
			if pierced_count >= MAX_PIERCE:
				if collision_shape:
					collision_shape.set_deferred("disabled", true)
				queue_free()
	elif target.is_in_group("Obstacles") or target.is_in_group("WorldBounds"):
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		queue_free()
