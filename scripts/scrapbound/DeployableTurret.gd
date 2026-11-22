extends StaticBody2D
class_name DeployableTurret

signal turret_destroyed(turret: Node2D)

@export var turret_id: int = 1
@export var team_id: int = 1
@export var max_health: int = 300
var health: int = 300

@export var attack_range: float = 260.0
@export var fire_rate: float = 0.35
@export var bullet_damage: int = 22
var fire_cooldown: float = 0.0

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var gun_sprite: Sprite2D = $GunSprite
@onready var muzzle: Marker2D = $GunSprite/Muzzle
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var prompt_label: Label = $PromptLabel
@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio

var bullet_scene = preload("res://scenes/scrapbound/Bullet.tscn")
var current_target: Node2D = null

func _ready() -> void:
	add_to_group("Turrets")
	add_to_group("Defenses")
	health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		
	if name_label:
		name_label.text = "SENTRY TURRET [P%d]" % team_id
		name_label.modulate = Color(0.2, 0.85, 1.0)
		
	if prompt_label:
		prompt_label.visible = false

func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
		
	if not multiplayer.is_server():
		return
		
	if health <= 0:
		return
		
	# Find closest monster in same sector
	_find_nearest_target()
	
	if current_target and is_instance_valid(current_target):
		var target_pos = current_target.global_position
		var dir = (target_pos - global_position).normalized()
		
		# Rotate gun towards target
		sync_gun_rotation_net.rpc(dir.angle())
		
		if fire_cooldown <= 0.0:
			fire_cooldown = fire_rate
			var spawn_p = muzzle.global_position if muzzle else global_position + dir * 18.0
			fire_turret_bullet_net.rpc(spawn_p, dir)

func _find_nearest_target() -> void:
	current_target = null
	var min_dist = attack_range
	var monsters = get_tree().get_nodes_in_group("Monsters")
	for m in monsters:
		if is_instance_valid(m) and m is Node2D:
			# Verify monster is in this team's sector
			if abs(m.global_position.x - global_position.x) < 800.0:
				var d = global_position.distance_to(m.global_position)
				if d < min_dist:
					min_dist = d
					current_target = m

@rpc("call_local", "unreliable")
func sync_gun_rotation_net(rot: float) -> void:
	if gun_sprite:
		gun_sprite.rotation = rot

@rpc("call_local", "reliable")
func fire_turret_bullet_net(spawn_p: Vector2, dir: Vector2) -> void:
	if shoot_audio:
		shoot_audio.play()
		
	var b = bullet_scene.instantiate()
	b.global_position = spawn_p
	b.direction = dir
	b.damage = bullet_damage
	b.speed = 540.0
	b.is_piercing = false
	b.shooter_player_id = team_id
	b.lifetime = 1.2
	b.set_bullet_color(Color(0.2, 0.9, 1.0))
	get_parent().add_child(b)
	
	# Muzzle recoil tween
	if gun_sprite:
		var tw = create_tween()
		tw.tween_property(gun_sprite, "position", Vector2(-3, 0), 0.05)
		tw.tween_property(gun_sprite, "position", Vector2.ZERO, 0.08)

func take_damage_server(amount: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	health = max(0, health - amount)
	sync_turret_health_net.rpc(health)
	
	if health <= 0:
		destroy_turret_net.rpc()

@rpc("call_local", "reliable")
func sync_turret_health_net(new_hp: int) -> void:
	health = new_hp
	if health_bar:
		health_bar.value = health
	if gun_sprite:
		gun_sprite.modulate = Color(2.0, 0.4, 0.4)
		var t = get_tree().create_timer(0.1)
		t.timeout.connect(func():
			if is_instance_valid(gun_sprite): gun_sprite.modulate = Color.WHITE
		)

@rpc("call_local", "reliable")
func destroy_turret_net() -> void:
	turret_destroyed.emit(self)
	# Play explosion particles / sound if available
	queue_free()

func repair_server(amount: int = 50) -> void:
	if not multiplayer.is_server():
		return
	health = min(max_health, health + amount)
	sync_turret_health_net.rpc(health)
