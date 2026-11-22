extends CharacterBody2D
class_name ScrapboundMonster

signal monster_killed(monster: Node2D, killer_player_id: int)

@export var max_health: int = 80
@export var speed: float = 72.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 64.0

var health: int = 80
var is_attacking: bool = false
var attack_timer: float = 0.0
var is_dead: bool = false

var target_node: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var last_hit_by_player: int = 1

var remote_pos: Vector2 = Vector2.ZERO

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var audio_attack: AudioStreamPlayer2D = $AudioAttack
@onready var audio_hit: AudioStreamPlayer2D = $AudioHit

func _ready() -> void:
	add_to_group("Enemies")
	health = max_health
	remote_pos = global_position
	is_dead = false
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		
	if anim_sprite:
		anim_sprite.play("walk")
		anim_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if multiplayer.is_server():
		_physics_process_server(delta)
	else:
		_physics_process_client(delta)

func _physics_process_server(delta: float) -> void:
	if is_dead:
		return
		
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	attack_timer -= delta
	_update_ai_target()
	
	var dir = (target_position - global_position)
	var dist = dir.length()
	
	if dist > attack_range:
		var desired_dir = dir.normalized()
		# Obstacle avoidance: if bumping into cars or barricades, glide along tangent
		if is_on_wall():
			var normal = get_wall_normal()
			var tangent = Vector2(-normal.y, normal.x)
			if tangent.dot(dir) < 0.0:
				tangent = -tangent
			elif abs(tangent.dot(dir)) < 0.05:
				tangent = Vector2(0, 1) if target_position.y >= global_position.y else Vector2(0, -1)
			desired_dir = (tangent * 0.82 + desired_dir * 0.18).normalized()

		velocity = desired_dir * speed
		if anim_sprite and anim_sprite.animation != "walk":
			anim_sprite.play("walk")
		if anim_sprite:
			if velocity.x < -1.0:
				anim_sprite.flip_h = true
			elif velocity.x > 1.0:
				anim_sprite.flip_h = false
	else:
		velocity = Vector2.ZERO
		if anim_sprite:
			if dir.x < -1.0:
				anim_sprite.flip_h = true
			elif dir.x > 1.0:
				anim_sprite.flip_h = false
		if attack_timer <= 0.0:
			_start_attack_server()
		elif anim_sprite and anim_sprite.animation != "idle" and anim_sprite.animation != "attack":
			anim_sprite.play("idle")
			
	move_and_slide()
	
	# Broadcast position and animation to clients
	if not is_dead and is_instance_valid(self):
		var anim_name = anim_sprite.animation if anim_sprite else "walk"
		var flip = anim_sprite.flip_h if anim_sprite else false
		sync_monster_state.rpc(global_position, anim_name, flip)

func _physics_process_client(delta: float) -> void:
	if is_dead:
		return
	var d = global_position.distance_to(remote_pos)
	if d > 200.0:
		global_position = remote_pos
	elif d > 0.5:
		global_position = global_position.lerp(remote_pos, delta * 15.0)

@rpc("any_peer", "unreliable_ordered")
func sync_monster_state(pos: Vector2, anim: String, flip: bool) -> void:
	if multiplayer.is_server() or is_dead:
		return
	remote_pos = pos
	if anim_sprite:
		if anim_sprite.animation != anim:
			anim_sprite.play(anim)
		anim_sprite.flip_h = flip

func _update_ai_target() -> void:
	var my_side = 1 if global_position.x < 2816.0 else 2
	var candidates: Array = []
	var towers = get_tree().get_nodes_in_group("Towers")
	for t in towers:
		if is_instance_valid(t) and t.health > 0:
			var side = 1 if t.global_position.x < 2816.0 else 2
			if side == my_side:
				candidates.append(t)
			
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			var side = 1 if p.global_position.x < 2816.0 else 2
			if side == my_side:
				candidates.append(p)
			
	var barriers = get_tree().get_nodes_in_group("Barriers")
	for b in barriers:
		if is_instance_valid(b) and b.health > 0:
			var side = 1 if b.global_position.x < 2816.0 else 2
			if side == my_side and global_position.distance_to(b.global_position) < 80.0:
				candidates.append(b)

	var defenses = get_tree().get_nodes_in_group("Defenses")
	for df in defenses:
		if is_instance_valid(df) and df.health > 0:
			var side = 1 if df.global_position.x < 2816.0 else 2
			if side == my_side and global_position.distance_to(df.global_position) < 120.0:
				candidates.append(df)
				
	var nearest: Node2D = null
	var min_dist = 99999.0
	for c in candidates:
		var d = global_position.distance_to(c.global_position)
		if d < min_dist:
			min_dist = d
			nearest = c
			
	if nearest:
		target_node = nearest
		target_position = nearest.global_position
	else:
		target_position = Vector2(1408, 860) if my_side == 1 else Vector2(4224, 860)

func _start_attack_server() -> void:
	if is_dead:
		return
	is_attacking = true
	velocity = Vector2.ZERO
	play_attack_net.rpc()
	
	var strike_timer = get_tree().create_timer(0.22)
	strike_timer.timeout.connect(_deliver_attack_server)

@rpc("any_peer", "call_local", "reliable")
func play_attack_net() -> void:
	if anim_sprite:
		anim_sprite.play("attack")
	if audio_attack:
		audio_attack.pitch_scale = randf_range(0.9, 1.1)
		audio_attack.play()

func _deliver_attack_server() -> void:
	if not is_instance_valid(self) or is_dead:
		return
	if target_node and is_instance_valid(target_node):
		var d = global_position.distance_to(target_node.global_position)
		if d <= attack_range + 30.0:
			if target_node is ScrapboundPlayer:
				target_node.take_damage_server(attack_damage)
			elif target_node is ScrapboundTower:
				target_node.take_damage_server(attack_damage)
			elif target_node is ScrapboundBarrier:
				target_node.take_damage_server(attack_damage)
			elif target_node.has_method("take_damage_server"):
				target_node.take_damage_server(attack_damage)

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == "attack":
		is_attacking = false
		attack_timer = attack_cooldown
		anim_sprite.play("walk")

func take_damage(amount: int, player_id: int = 1) -> void:
	if not multiplayer.is_server() or is_dead or health <= 0:
		return
	last_hit_by_player = player_id
	health -= amount
	sync_monster_hit_net.rpc(health)
	
	if health <= 0:
		die_server()

@rpc("any_peer", "call_local", "reliable")
func sync_monster_hit_net(new_hp: int) -> void:
	health = new_hp
	if health_bar:
		health_bar.value = health
	if audio_hit:
		audio_hit.pitch_scale = randf_range(0.95, 1.05)
		audio_hit.play()
	if anim_sprite:
		anim_sprite.modulate = Color(2.0, 0.4, 0.4)
		var t = get_tree().create_timer(0.1)
		t.timeout.connect(func(): if is_instance_valid(self) and anim_sprite: anim_sprite.modulate = Color.WHITE)

func die_server() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	monster_killed.emit(self, last_hit_by_player)
	var main = get_parent() as ScrapboundMain
	if main:
		main.on_monster_destroyed_server(self, last_hit_by_player, global_position)
	remove_monster_net.rpc()

@rpc("any_peer", "call_local", "reliable")
func remove_monster_net() -> void:
	is_dead = true
	set_physics_process(false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	visible = false
	var t = get_tree().create_timer(0.25)
	t.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
