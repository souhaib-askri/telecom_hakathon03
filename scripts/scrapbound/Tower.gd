extends StaticBody2D
class_name ScrapboundTower

signal tower_health_changed(tower_id: int, current_hp: int, max_hp: int)
signal tower_destroyed(tower_id: int)

@export var tower_id: int = 1:
	set(val):
		tower_id = val
		if is_node_ready():
			_update_team_visuals()

@export var max_health: int = 1000
var health: int = 1000

@onready var tower_sprite: Sprite2D = $TowerSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var emission_glow: Sprite2D = get_node_or_null("EmissionGlow")
@onready var radar_station: Node2D = get_node_or_null("RadarStation")

func _ready() -> void:
	add_to_group("Towers")
	y_sort_enabled = true
	health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		
	_update_team_visuals()

func _update_team_visuals() -> void:
	var main_tex = "res://assets/sprites/environment/telecom_big_tower_isolated.png"
	if not ResourceLoader.exists(main_tex):
		main_tex = "res://assets/sprites/environment/telecom_tower_gemini_p1.png" if tower_id == 1 else "res://assets/sprites/environment/telecom_tower_gemini_p2.png"

	if tower_sprite and ResourceLoader.exists(main_tex):
		tower_sprite.texture = load(main_tex)
		tower_sprite.modulate = Color.WHITE

	if tower_sprite and tower_sprite.texture:
		if tower_sprite.texture.resource_path.contains("big_tower"):
			tower_sprite.position = Vector2(0, -320)
			tower_sprite.scale = Vector2(1.0, 1.0)
		elif tower_sprite.texture.get_height() > 1000:
			tower_sprite.position = Vector2(0, -48)
			tower_sprite.scale = Vector2(0.24, 0.24)
		else:
			tower_sprite.position = Vector2(0, -20)
			tower_sprite.scale = Vector2(0.42, 0.42)

	var team_color = Color(0.2, 0.85, 1.0) if tower_id == 1 else Color(1.0, 0.65, 0.2)
	if name_label:
		name_label.text = "P1 TELECOM TOWER" if tower_id == 1 else "P2 TELECOM TOWER"
		name_label.modulate = team_color
	if emission_glow:
		emission_glow.modulate = Color(team_color.r, team_color.g, team_color.b, 0.8)
	
	if radar_station:
		var ping = radar_station.get_node_or_null("RadarPing") as Sprite2D
		if ping:
			ping.modulate = Color(team_color.r, team_color.g, team_color.b, 0.5)

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.001
	if emission_glow:
		var epulse = sin(t * 8.0) * 0.12 + 0.88
		emission_glow.scale = Vector2(0.6, 0.6) * epulse

	if radar_station:
		var radar_sprite = radar_station.get_node_or_null("RadarSprite") as Sprite2D
		if radar_sprite:
			radar_sprite.rotation = sin(t * 2.2) * 0.18
		var ping = radar_station.get_node_or_null("RadarPing") as Sprite2D
		if ping:
			var phase = fmod(t, 2.5) / 2.5
			ping.scale = Vector2.ONE * (0.05 + phase * 0.5)
			var team_c = Color(0.2, 0.85, 1.0) if tower_id == 1 else Color(1.0, 0.65, 0.2)
			ping.modulate = Color(team_c.r, team_c.g, team_c.b, (1.0 - phase) * 0.6)

func take_damage_server(amount: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	health = max(0, health - amount)
	sync_tower_hp_net.rpc(health)
	
	if health <= 0:
		tower_destroyed.emit(tower_id)

func repair_server(amount: int) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	health = min(max_health, health + amount)
	sync_tower_hp_net.rpc(health)

@rpc("call_local", "reliable")
func sync_tower_hp_net(new_hp: int) -> void:
	health = new_hp
	if health_bar:
		health_bar.value = health
		
	tower_health_changed.emit(tower_id, health, max_health)
	
	# Damage impact flash
	if tower_sprite:
		tower_sprite.modulate = Color(2.4, 0.4, 0.4)
		var t = get_tree().create_timer(0.14)
		t.timeout.connect(func():
			if is_instance_valid(self) and tower_sprite:
				tower_sprite.modulate = Color.WHITE
		)

func get_spawn_position() -> Vector2:
	if spawn_point:
		return spawn_point.global_position
	return global_position + Vector2(65 if tower_id == 1 else -65, 80)
