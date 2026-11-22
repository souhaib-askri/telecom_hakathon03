extends CharacterBody2D
class_name SamiPlayer

@export var speed: float = 175.0
@export var health: int = 100
@export var max_health: int = 100

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var gun_sprite: Sprite2D = $WeaponPivot/GunSprite
@onready var muzzle_flash: Sprite2D = $WeaponPivot/MuzzleFlash
@onready var weld_audio: AudioStreamPlayer2D = $WeldAudio
@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio
@onready var health_bar: ProgressBar = $HealthBar

var bullet_scene = preload("res://scenes/entities/Bullet.tscn")

var current_scrap_pile: Node2D = null
var is_welding: bool = false
var shoot_cooldown: float = 0.0
const SHOOT_RATE: float = 0.12

var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
const INVULNERABILITY_DURATION: float = 0.35

# Mobile touch controls & target lock-on
var mobile_move_vector: Vector2 = Vector2.ZERO
var current_aim_dir: Vector2 = Vector2.RIGHT
var locked_target: Node2D = null
const TARGET_LOCK_RANGE: float = 280.0

func _ready() -> void:
	add_to_group("Player")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if muzzle_flash:
		muzzle_flash.visible = false
	if anim_sprite:
		anim_sprite.play("idle")
		anim_sprite.animation_finished.connect(_on_animation_finished)
		
	EventBus.scrap_purified.connect(_on_scrap_purified)

func _physics_process(delta: float) -> void:
	shoot_cooldown -= delta
	
	if is_invulnerable:
		invulnerability_timer -= delta
		if anim_sprite:
			anim_sprite.modulate = Color(1.8, 0.4, 0.4).lerp(Color.WHITE, 1.0 - max(0.0, invulnerability_timer / INVULNERABILITY_DURATION))
		if invulnerability_timer <= 0.0:
			is_invulnerable = false
			if anim_sprite:
				anim_sprite.modulate = Color.WHITE
	
	# Failsafe: if scrap pile was freed or became invalid, immediately clear lock
	if is_welding and (current_scrap_pile == null or not is_instance_valid(current_scrap_pile)):
		stop_welding()
		current_scrap_pile = null
	
	handle_movement()
	handle_actions()
	handle_aiming()

func handle_movement() -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# Combine with mobile on-screen joystick if active
	if mobile_move_vector != Vector2.ZERO:
		input_vector = mobile_move_vector
		
	# If player wants to move while welding, cancel welding immediately (never locked in!)
	if is_welding and input_vector.length_squared() > 0.05:
		stop_welding()
		
	if is_welding:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		current_aim_dir = input_vector
		if anim_sprite and anim_sprite.animation != "shoot":
			if anim_sprite.animation != "walk":
				anim_sprite.play("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		if anim_sprite and anim_sprite.animation != "shoot":
			if anim_sprite.animation != "idle":
				anim_sprite.play("idle")
		
	move_and_slide()

func handle_aiming() -> void:
	# 1. Target Lock-On (Mobile auto-aim assist)
	locked_target = find_nearest_target(TARGET_LOCK_RANGE)
	
	if locked_target and is_instance_valid(locked_target):
		current_aim_dir = (locked_target.global_position - global_position).normalized()
	else:
		# Use mouse cursor or last movement direction
		var mouse_pos = get_global_mouse_position()
		var to_mouse = (mouse_pos - global_position)
		if to_mouse.length_squared() > 100.0:
			current_aim_dir = to_mouse.normalized()
	
	if weapon_pivot:
		weapon_pivot.rotation = current_aim_dir.angle()
		if current_aim_dir.x < 0:
			weapon_pivot.scale.y = -1.0
			anim_sprite.flip_h = true
		else:
			weapon_pivot.scale.y = 1.0
			anim_sprite.flip_h = false

func find_nearest_target(max_range: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var nearest: Node2D = null
	var min_dist = max_range
	for e in enemies:
		if is_instance_valid(e) and e.health > 0:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func handle_actions() -> void:
	# Validate scrap pile
	if current_scrap_pile != null and not is_instance_valid(current_scrap_pile):
		current_scrap_pile = null
		if is_welding:
			stop_welding()
			
	# 1. Purify / Weld interaction
	if Input.is_action_pressed("interact_purify") and current_scrap_pile != null and is_instance_valid(current_scrap_pile):
		if not is_welding:
			start_welding()
	else:
		if is_welding:
			stop_welding()
			
	# 2. Shooting
	if Input.is_action_pressed("shoot") and not is_welding:
		if shoot_cooldown <= 0.0:
			shoot_weapon()

func start_welding() -> void:
	if current_scrap_pile == null or not is_instance_valid(current_scrap_pile):
		return
	is_welding = true
	if anim_sprite:
		anim_sprite.play("weld")
	if gun_sprite:
		gun_sprite.visible = false
	if weld_audio and not weld_audio.playing:
		weld_audio.play()
	if current_scrap_pile.has_method("start_purifying"):
		current_scrap_pile.start_purifying()

func stop_welding() -> void:
	is_welding = false
	if gun_sprite:
		gun_sprite.visible = true
	if anim_sprite:
		anim_sprite.play("idle")
	if weld_audio and weld_audio.playing:
		weld_audio.stop()
	if current_scrap_pile and is_instance_valid(current_scrap_pile) and current_scrap_pile.has_method("cancel_purifying"):
		current_scrap_pile.cancel_purifying()

func _on_scrap_purified(_pos: Vector2) -> void:
	# Failsafe unlock when scrap is purified
	stop_welding()
	current_scrap_pile = null

func shoot_weapon() -> void:
	shoot_cooldown = SHOOT_RATE
	
	# Spawn short-range welding arc / sparks along current aim direction
	var b = bullet_scene.instantiate()
	b.global_position = global_position + current_aim_dir * 18.0
	b.direction = current_aim_dir
	if b.has_method("setup_welder_arc"):
		b.setup_welder_arc(82.0)
	get_parent().add_child(b)
	
	if anim_sprite and anim_sprite.animation != "weld":
		anim_sprite.play("shoot")
	
	if shoot_audio:
		shoot_audio.pitch_scale = randf_range(1.15, 1.35)
		shoot_audio.play()
		
	if muzzle_flash:
		muzzle_flash.visible = true
		var timer = get_tree().create_timer(0.06)
		timer.timeout.connect(func(): if muzzle_flash: muzzle_flash.visible = false)

func _on_animation_finished() -> void:
	if anim_sprite.animation == "shoot":
		if velocity.length_squared() > 10.0:
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")

func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("ScrapPiles"):
		current_scrap_pile = area
		if area.has_method("set_player_nearby"):
			area.set_player_nearby(true)

func _on_interaction_area_exited(area: Area2D) -> void:
	if area == current_scrap_pile:
		if is_instance_valid(area) and area.has_method("set_player_nearby"):
			area.set_player_nearby(false)
		stop_welding()
		current_scrap_pile = null

func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable:
		return
		
	is_invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	
	# Taking damage interrupts welding
	if is_welding:
		stop_welding()
		
	health = max(0, health - amount)
	if health_bar:
		health_bar.value = health
		
	EventBus.player_health_changed.emit(health, max_health)
	
	if anim_sprite:
		anim_sprite.modulate = Color(1.8, 0.4, 0.4)
		
	if from_pos != Vector2.ZERO:
		var knock_dir = (global_position - from_pos).normalized()
		velocity = knock_dir * 120.0
		
	if health <= 0:
		die()

func die() -> void:
	stop_welding()
	health = max_health
	if health_bar:
		health_bar.value = health
	global_position = Vector2(1024, 820)
	is_invulnerable = true
	invulnerability_timer = 0.8
