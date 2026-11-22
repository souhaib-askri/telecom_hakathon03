extends CharacterBody2D
class_name ScrapboundPlayer

signal player_died(player_id: int, respawn_time: float)
signal player_respawned(player_id: int)
signal inventory_changed(player_id: int, inventory: Dictionary)
signal weapon_upgraded(player_id: int, weapon_name: String)

@export var player_id: int = 1
@export var speed: float = 190.0
@export var max_health: int = 100
var health: int = 100

var death_count: int = 0
var is_dead: bool = false
var respawn_timer: float = 0.0

var current_weapon: String = "Basic"
var unlocked_weapons: Array = ["Basic"]
var was_switch_key_down: bool = false
var was_craft_key_down: bool = false
var shoot_cooldown: float = 0.0
var shoot_rate: float = 0.12
var bullet_damage: int = 22
var bullet_speed: float = 380.0
var bullet_range: float = 82.0
var is_piercing: bool = true

var aim_direction: Vector2 = Vector2.RIGHT
var current_aim_angle: float = 0.0
var weapon_recoil: float = 0.0
var walk_cycle: float = 0.0
var is_facing_left: bool = false

var inventory: Dictionary = {
	"scrap": 0,
	"battery": 0,
	"wood": 0,
	"plastic": 0,
	"iron": 0,
	"turrets": 0
}

var nearby_recycler: Node2D = null
var nearby_workshop: Node2D = null
var was_deploy_key_down: bool = false
var was_skip_day_key_down: bool = false

var mobile_move_vector: Vector2 = Vector2.ZERO
var is_mobile_shooting: bool = false

var bullet_scene = preload("res://scenes/scrapbound/Bullet.tscn")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var respawn_label: Label = $RespawnLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var gun_sprite: Sprite2D = $WeaponPivot/GunSprite
@onready var shoot_audio: AudioStreamPlayer2D = $ShootAudio
@onready var pickup_audio: AudioStreamPlayer2D = $PickupAudio
@onready var scrap_badge: Label = $ScrapBadge

# Target transform for remote interpolation
var remote_target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("Players")
	health = max_health
	remote_target_pos = global_position
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		
	if respawn_label:
		respawn_label.visible = false
		
	set_weapon("Basic")
	_apply_visual_theme()

func setup_network_authority(peer_id: int, assigned_id: int) -> void:
	player_id = assigned_id
	set_multiplayer_authority(peer_id)
	is_facing_left = (player_id != 1)
	aim_direction = Vector2.RIGHT if player_id == 1 else Vector2.LEFT
	current_aim_angle = aim_direction.angle()
	remote_target_pos = global_position
	
	visible = true
	if anim_sprite:
		anim_sprite.visible = true
		anim_sprite.flip_h = is_facing_left
	if weapon_pivot: weapon_pivot.visible = true
	if health_bar: health_bar.visible = true
	if name_label: name_label.visible = true
	_apply_visual_theme()
	_update_scrap_badge()

func _apply_visual_theme() -> void:
	if not is_inside_tree():
		return
	if player_id == 1:
		if name_label:
			name_label.text = "P1 (YOU)" if is_multiplayer_authority() else "P1"
			name_label.modulate = Color(0.2, 0.85, 1.0)
		if anim_sprite:
			anim_sprite.self_modulate = Color(0.65, 0.9, 1.0)
		if gun_sprite:
			gun_sprite.modulate = Color(0.4, 0.9, 1.0)
	else:
		if name_label:
			name_label.text = "P2 (YOU)" if is_multiplayer_authority() else "P2"
			name_label.modulate = Color(1.0, 0.6, 0.2)
		if anim_sprite:
			anim_sprite.self_modulate = Color(1.0, 0.75, 0.5)
		if gun_sprite:
			gun_sprite.modulate = Color(1.0, 0.65, 0.3)

func _physics_process(delta: float) -> void:
	if is_dead:
		if multiplayer.is_server():
			_process_respawn_server(delta)
		return
		
	shoot_cooldown -= delta
	
	# Only the player who owns this character processes local inputs
	if is_multiplayer_authority():
		_handle_local_input(delta)
		# Broadcast position, animation state, facing direction, and aim direction
		var anim_name = anim_sprite.animation if anim_sprite else "idle"
		var flip_h = is_facing_left
		sync_transform.rpc(global_position, velocity, anim_name, flip_h, aim_direction)
	else:
		# Remote puppet: smoothly interpolate towards received network position and weapon state
		_process_remote_puppet(delta)

@rpc("any_peer", "unreliable_ordered")
func sync_transform(pos: Vector2, vel: Vector2, anim: String, flip: bool, aim_dir: Vector2) -> void:
	if is_multiplayer_authority():
		return
	remote_target_pos = pos
	velocity = vel
	aim_direction = aim_dir
	is_facing_left = flip
	if anim_sprite:
		if anim_sprite.animation != anim:
			anim_sprite.play(anim)
		anim_sprite.flip_h = flip

func _process_remote_puppet(delta: float) -> void:
	var dist = global_position.distance_to(remote_target_pos)
	if dist > 150.0:
		global_position = remote_target_pos
	elif dist > 0.5:
		global_position = global_position.lerp(remote_target_pos, delta * 20.0)

	var is_moving = velocity.length_squared() > 100.0
	if is_moving:
		walk_cycle += delta * 12.0
	else:
		walk_cycle = 0.0

	var facing_left = anim_sprite.flip_h if anim_sprite else is_facing_left
	_update_weapon_transform(delta, facing_left, is_moving)

func _update_weapon_transform(delta: float, facing_left: bool, is_moving: bool) -> void:
	if not weapon_pivot:
		return

	# Hand socket anchor:
	# Sami sprite center is at (0, -12). Hands are at X = -6 when facing left, +6 when facing right, Y = -13.
	var hand_x = -6.0 if facing_left else 6.0
	var hand_y = -13.0
	
	# Gentle walking bobbing synchronized with footsteps:
	if is_moving:
		hand_y += sin(walk_cycle) * 1.5

	weapon_pivot.position = weapon_pivot.position.lerp(Vector2(hand_x, hand_y), delta * 30.0)

	# Smooth rotational interpolation (no snapping):
	var target_angle = aim_direction.angle()
	current_aim_angle = lerp_angle(current_aim_angle, target_angle, delta * 35.0)
	weapon_pivot.rotation = current_aim_angle

	# Mirror gun vertically when aiming left (2nd or 3rd quadrant) so the rifle stays upright:
	var gun_aiming_left = abs(current_aim_angle) > (PI * 0.5)
	weapon_pivot.scale.y = -1.0 if gun_aiming_left else 1.0

	# Apply recoil kickback and smooth recovery:
	weapon_recoil = move_toward(weapon_recoil, 0.0, delta * 35.0)
	if gun_sprite:
		gun_sprite.position.x = 16.0 - weapon_recoil

func _handle_local_input(delta: float) -> void:
	var move_vec = Vector2.ZERO
	
	# Analog joystick / Touch vector
	if mobile_move_vector != Vector2.ZERO:
		move_vec = mobile_move_vector
	
	# Unified controls: WASD or Arrow Keys
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
		
	var is_moving = move_vec != Vector2.ZERO
	if is_moving:
		move_vec = move_vec.normalized()
		velocity = move_vec * speed
		walk_cycle += delta * 12.0
		if anim_sprite and anim_sprite.animation != "walk":
			anim_sprite.play("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)
		walk_cycle = 0.0
		if anim_sprite and anim_sprite.animation != "idle":
			anim_sprite.play("idle")

	# Aiming & Facing: Synchronized directly with movement direction & facing state (No cursor lock)
	if is_moving:
		aim_direction = move_vec
		if move_vec.x < -0.01:
			is_facing_left = true
		elif move_vec.x > 0.01:
			is_facing_left = false
	else:
		# When idle, retain the current aim direction and facing direction
		if aim_direction == Vector2.ZERO:
			aim_direction = Vector2.LEFT if is_facing_left else Vector2.RIGHT

	if anim_sprite:
		anim_sprite.flip_h = is_facing_left

	# Synchronize weapon transform:
	_update_weapon_transform(delta, is_facing_left, is_moving)

	move_and_slide()
	
	# Attack: Space OR Left Click OR K OR Enter OR Mobile Shoot
	var want_shoot = is_mobile_shooting \
		or Input.is_action_pressed("shoot") \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_K) \
		or Input.is_key_pressed(KEY_ENTER)

	if want_shoot and shoot_cooldown <= 0.0:
		shoot_cooldown = shoot_rate
		weapon_recoil = 3.5 # Electric torch vibration recoil
		var shoot_dir = aim_direction.normalized() if aim_direction != Vector2.ZERO else (Vector2.LEFT if is_facing_left else Vector2.RIGHT)
		var shoot_origin = weapon_pivot.global_position + shoot_dir * 36.0
		request_shoot.rpc_id(1, shoot_origin, shoot_dir)
		
	# Interact: E or L (Workshop or Recycler)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_L):
		var main = get_parent() as ScrapboundMain
		if nearby_workshop and is_instance_valid(nearby_workshop):
			if main and main.hud and main.hud.has_method("open_workshop_modal"):
				main.hud.open_workshop_modal()
		elif nearby_recycler and is_instance_valid(nearby_recycler):
			if main:
				main.request_recycle.rpc_id(1, nearby_recycler.recycler_id, player_id)

	# Deploy Sentry Turret: B
	if Input.is_key_pressed(KEY_B):
		if not was_deploy_key_down:
			was_deploy_key_down = true
			deploy_turret_action()
	else:
		was_deploy_key_down = false

	# Fast-forward / Skip Day: F
	if Input.is_key_pressed(KEY_F):
		if not was_skip_day_key_down:
			was_skip_day_key_down = true
			var main = get_parent() as ScrapboundMain
			if main and main.has_method("request_skip_day_net"):
				main.request_skip_day_net.rpc_id(1)
	else:
		was_skip_day_key_down = false

	# Toggle Inventory Modal: TAB
	if Input.is_key_pressed(KEY_TAB):
		var main = get_parent() as ScrapboundMain
		if main and main.hud and main.hud.has_method("toggle_inventory_modal"):
			main.hud.toggle_inventory_modal()

	# Switch Weapon: R or X
	if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_X):
		if not was_switch_key_down:
			was_switch_key_down = true
			var main = get_parent() as ScrapboundMain
			if main:
				main.request_switch_weapon.rpc_id(1, player_id)
	else:
		was_switch_key_down = false
		
	# Toggle Crafting Inventory: C or I
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_I):
		if not was_craft_key_down:
			was_craft_key_down = true
			var main = get_parent() as ScrapboundMain
			if main and main.hud:
				main.hud.toggle_crafting_panel()
	else:
		was_craft_key_down = false
				
	# Build Barrier: Q or O
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_O):
		var main = get_parent() as ScrapboundMain
		if main:
			main.request_build_barrier.rpc_id(1, player_id, global_position + aim_direction * 56.0)
			
	# Build Defense Tower: T
	if Input.is_key_pressed(KEY_T):
		var main = get_parent() as ScrapboundMain
		if main:
			main.request_build_tower.rpc_id(1, player_id, global_position + aim_direction * 56.0)

@rpc("any_peer", "call_local", "reliable")
func request_shoot(spawn_pos: Vector2, dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	# Server validates and broadcasts bullet spawn
	if current_weapon == "Shotgun":
		var spread_angles = [-0.15, 0.0, 0.15]
		for a in spread_angles:
			spawn_bullet_net.rpc(spawn_pos, dir.rotated(a), bullet_damage, bullet_speed, is_piercing, player_id, current_weapon, bullet_range)
	elif current_weapon == "Basic" or current_weapon == "Welder":
		# Main concentrated short-range welding arc
		spawn_bullet_net.rpc(spawn_pos, dir, bullet_damage, bullet_speed, true, player_id, "Welder", bullet_range)
		# Secondary welding sparks fanning out in close combat
		var s1 = randf_range(-0.16, -0.04)
		var s2 = randf_range(0.04, 0.16)
		spawn_bullet_net.rpc(spawn_pos, dir.rotated(s1), int(bullet_damage * 0.4), bullet_speed * 0.88, true, player_id, "Welder", bullet_range * 0.9)
		spawn_bullet_net.rpc(spawn_pos, dir.rotated(s2), int(bullet_damage * 0.4), bullet_speed * 0.88, true, player_id, "Welder", bullet_range * 0.9)
	else:
		spawn_bullet_net.rpc(spawn_pos, dir, bullet_damage, bullet_speed, is_piercing, player_id, current_weapon, bullet_range)

@rpc("any_peer", "call_local", "reliable")
func spawn_bullet_net(spawn_pos: Vector2, dir: Vector2, dmg: int, spd: float, pierce: bool, shooter_id: int, weapon_name: String = "Welder", custom_range: float = 82.0) -> void:
	var b = bullet_scene.instantiate()
	b.global_position = spawn_pos
	b.direction = dir
	b.damage = dmg
	b.speed = spd
	b.is_piercing = pierce
	b.shooter_player_id = shooter_id
	
	if weapon_name == "Welder" or weapon_name == "Basic":
		if b.has_method("setup_welder_arc"):
			b.setup_welder_arc(shooter_id, custom_range)
	else:
		b.set_bullet_color(Color(0.3, 0.85, 1.0) if shooter_id == 1 else Color(1.0, 0.6, 0.2))
		if custom_range > 0.0 and "max_range" in b:
			b.max_range = custom_range

	var main = get_parent()
	if main:
		main.add_child(b)
		var shooter_node = main.get_node_or_null("Player%d" % shooter_id) as ScrapboundPlayer
		if shooter_node and is_instance_valid(shooter_node):
			shooter_node.weapon_recoil = 3.5
			if shooter_node.has_node("WeaponPivot/WelderSpark"):
				var spk = shooter_node.get_node("WeaponPivot/WelderSpark") as Sprite2D
				spk.visible = true
				var t = shooter_node.get_tree().create_timer(0.06)
				t.timeout.connect(func(): if is_instance_valid(spk): spk.visible = false)
	
	if shoot_audio:
		if weapon_name == "Welder" or weapon_name == "Basic":
			shoot_audio.pitch_scale = randf_range(1.15, 1.35)
		else:
			shoot_audio.pitch_scale = randf_range(0.95, 1.05)
		shoot_audio.play()

func take_damage_server(amount: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	health = max(0, health - amount)
	sync_health_net.rpc(health)
	
	if health <= 0:
		die_server()

@rpc("any_peer", "call_local", "reliable")
func sync_health_net(new_hp: int) -> void:
	health = new_hp
	if health_bar:
		health_bar.value = health
	if anim_sprite:
		anim_sprite.modulate = Color(2.0, 0.4, 0.4)
		var t = get_tree().create_timer(0.12)
		t.timeout.connect(func():
			if is_instance_valid(self) and anim_sprite: anim_sprite.modulate = Color.WHITE
		)

func die_server() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	is_dead = true
	death_count += 1
	respawn_timer = death_count * 5.0
	sync_death_net.rpc(respawn_timer)

@rpc("any_peer", "call_local", "reliable")
func sync_death_net(duration: float) -> void:
	is_dead = true
	respawn_timer = duration
	if anim_sprite: anim_sprite.visible = false
	if weapon_pivot: weapon_pivot.visible = false
	if health_bar: health_bar.visible = false
	if collision_shape: collision_shape.set_deferred("disabled", true)
	if respawn_label and is_multiplayer_authority():
		respawn_label.visible = true
		respawn_label.text = "RESPAWN: %ds" % int(ceil(respawn_timer))
	player_died.emit(player_id, respawn_timer)

func _process_respawn_server(delta: float) -> void:
	respawn_timer -= delta
	sync_respawn_timer_net.rpc(respawn_timer)
	if respawn_timer <= 0.0:
		respawn_server()

@rpc("any_peer", "call_local", "unreliable")
func sync_respawn_timer_net(time_left: float) -> void:
	respawn_timer = time_left
	if respawn_label and is_multiplayer_authority():
		respawn_label.text = "RESPAWN: %ds" % int(ceil(max(0.0, respawn_timer)))

func respawn_server() -> void:
	if not multiplayer.is_server():
		return
	is_dead = false
	health = max_health
	
	var spawn_pos = Vector2(1408, 1000) if player_id == 1 else Vector2(4224, 1000)
	var main = get_parent() as ScrapboundMain
	if main:
		var t = main.tower1 if player_id == 1 else main.tower2
		if t and is_instance_valid(t):
			spawn_pos = t.get_spawn_position()
	sync_respawn_net.rpc(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func sync_respawn_net(spawn_pos: Vector2) -> void:
	is_dead = false
	health = max_health
	global_position = spawn_pos
	remote_target_pos = spawn_pos
	if collision_shape: collision_shape.set_deferred("disabled", false)
	
	visible = true
	if health_bar:
		health_bar.value = health
		health_bar.visible = true
	if anim_sprite:
		anim_sprite.visible = true
		anim_sprite.modulate = Color.WHITE
	if weapon_pivot: weapon_pivot.visible = true
	if respawn_label: respawn_label.visible = false
	
	player_respawned.emit(player_id)

func set_weapon(weapon_type: String) -> void:
	current_weapon = weapon_type
	if weapon_type == "RapidFire" or weapon_type == "Rifle":
		current_weapon = "Rifle"
		shoot_rate = 0.11
		bullet_damage = 18
		bullet_speed = 620.0
		bullet_range = 0.0
		is_piercing = false
	elif weapon_type == "HighDamage" or weapon_type == "Flamethrower":
		current_weapon = "Flamethrower"
		shoot_rate = 0.38
		bullet_damage = 60
		bullet_speed = 460.0
		bullet_range = 0.0
		is_piercing = true
	elif weapon_type == "Shotgun":
		current_weapon = "Shotgun"
		shoot_rate = 0.34
		bullet_damage = 22
		bullet_speed = 480.0
		bullet_range = 0.0
		is_piercing = false
	elif weapon_type == "PlasmaSniper":
		current_weapon = "PlasmaSniper"
		shoot_rate = 0.52
		bullet_damage = 85
		bullet_speed = 720.0
		bullet_range = 0.0
		is_piercing = true
	else:
		current_weapon = "Welder"
		shoot_rate = 0.12
		bullet_damage = 22
		bullet_speed = 380.0
		bullet_range = 82.0
		is_piercing = true
	weapon_upgraded.emit(player_id, current_weapon)

func deploy_turret_action() -> void:
	if not is_multiplayer_authority():
		return
	var main = get_tree().get_first_node_in_group("Main")
	if not main:
		main = get_parent() as ScrapboundMain
	if main and main.has_method("request_deploy_turret"):
		var shoot_dir = aim_direction.normalized() if aim_direction != Vector2.ZERO else (Vector2.LEFT if is_facing_left else Vector2.RIGHT)
		var spawn_pos = global_position + shoot_dir * 48.0
		main.request_deploy_turret.rpc_id(1, player_id, spawn_pos)

func add_resource(res_name: String, amount: int = 1) -> void:
	var key = res_name.to_lower()
	if key == "garbage":
		key = "scrap"
	if key in inventory:
		inventory[key] += amount
		inventory_changed.emit(player_id, inventory)
		_update_scrap_badge()

func on_scrap_collected_feedback(qty: int) -> void:
	if is_multiplayer_authority():
		if pickup_audio:
			pickup_audio.pitch_scale = randf_range(0.95, 1.1)
			pickup_audio.play()
		show_floating_text("+%d SCRAP! 🎒" % qty, Color(1.0, 0.9, 0.25))
	_update_scrap_badge()

func _update_scrap_badge() -> void:
	if not scrap_badge:
		return
	if is_dead:
		scrap_badge.visible = false
		return
		
	var scrap_count = inventory.get("scrap", 0)
	if scrap_count <= 0:
		scrap_badge.visible = false
	elif scrap_count >= 10:
		scrap_badge.visible = true
		scrap_badge.text = "🎒 %d SCRAP ➡ RECYCLER" % scrap_count
		scrap_badge.modulate = Color(0.3, 1.0, 0.4)
	else:
		scrap_badge.visible = true
		scrap_badge.text = "🎒 %d/10 SCRAP" % scrap_count
		scrap_badge.modulate = Color(1.0, 0.85, 0.3)

func show_floating_text(msg: String, col: Color = Color.WHITE) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = col
	lbl.set("theme_override_font_sizes/font_size", 12)
	lbl.position = Vector2(-50, -80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(100, 18)
	add_child(lbl)
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 25.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.2)
	tween.tween_callback(lbl.queue_free)
