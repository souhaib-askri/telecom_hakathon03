extends Node2D
class_name ScrapboundMain

@export var match_duration: float = 120.0
var match_timer: float = 120.0
var is_match_running: bool = true

var p1_score: int = 0
var p1_kills: int = 0
var p2_score: int = 0
var p2_kills: int = 0

var spawn_timer: float = 1.0
var spawn_interval: float = 3.5
var next_entity_id: int = 1

var monster_scene = preload("res://scenes/scrapbound/Monster.tscn")
var scrap_item_scene = preload("res://scenes/scrapbound/ScrapItem.tscn")
var barrier_scene = preload("res://scenes/scrapbound/Barrier.tscn")
var defense_tower_scene = preload("res://scenes/scrapbound/DefenseTower.tscn")
var deployable_turret_scene = preload("res://scenes/scrapbound/DeployableTurret.tscn")

# Raid System & Day/Night Cycle
enum RaidPhase { DAY, DUSK, NIGHT_RAID }
var raid_phase: RaidPhase = RaidPhase.DAY
var current_day: int = 1
var day_timer: float = 35.0
const DAY_DURATION: float = 35.0
const DUSK_DURATION: float = 6.0
var raid_monsters_total: int = 6
var raid_monsters_spawned: int = 0
var raid_monsters_alive: int = 0
var raid_spawn_timer: float = 0.5
var raids_cleared_count: int = 0
var day_scrap_spawn_timer: float = 2.0

@onready var p1: ScrapboundPlayer = $Player1
@onready var p2: ScrapboundPlayer = $Player2
@onready var tower1: ScrapboundTower = $Tower1
@onready var tower2: ScrapboundTower = $Tower2
@onready var recycler1: ScrapRecycler = $Recycler1
@onready var recycler2: ScrapRecycler = $Recycler2
@onready var hud: ScrapboundHUD = $CanvasLayer/ScrapboundHUD
@onready var camera: Camera2D = $Camera2D
@onready var workshop1: Area2D = get_node_or_null("Workshop1")
@onready var workshop2: Area2D = get_node_or_null("Workshop2")
@onready var day_night_modulate: CanvasModulate = get_node_or_null("DayNightModulate")
@onready var day_bgm: AudioStreamPlayer = get_node_or_null("DayBGM")
@onready var dusk_siren: AudioStreamPlayer = get_node_or_null("DuskSiren")
@onready var battle_bgm: AudioStreamPlayer = get_node_or_null("BattleBGM")

var local_target_player: ScrapboundPlayer = null

func _ready() -> void:
	match_timer = match_duration
	is_match_running = true
	if hud:
		hud.update_timer(match_timer)
	
	# Dynamically bind user-requested urban telecom compound arena background (Gemini_Generated_Image_kxgbg3)
	var map_path = ProjectSettings.globalize_path("res://assets/sprites/environment/map_kxgbg3.png")
	if not FileAccess.file_exists(map_path):
		map_path = ProjectSettings.globalize_path("res://assets/sprites/environment/map_t4395k.png")
	if FileAccess.file_exists(map_path):
		var img = Image.new()
		var err = img.load(map_path)
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			var bg1 = get_node_or_null("MapEnvironment/ArenaMapBg1") as TextureRect
			if bg1: bg1.texture = tex
			var bg2 = get_node_or_null("MapEnvironment/ArenaMapBg2") as TextureRect
			if bg2: bg2.texture = tex
			print("[SCRAPBOUND MAP] Successfully bound high-res urban telecom arena map (2816x1536) to both player sectors!")
	
	# Determine peer authorities cleanly for host and client
	var client_peer_id = 1
	if multiplayer.is_server():
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			client_peer_id = peers[0]
		else:
			for id in NetworkManager.players:
				if id != 1:
					client_peer_id = id
					break
	else:
		client_peer_id = multiplayer.get_unique_id()
			
	if p1: p1.setup_network_authority(1, 1)
	if p2: p2.setup_network_authority(client_peer_id, 2)
	
	var my_local_id = 1 if multiplayer.is_server() else 2
	local_target_player = p1 if my_local_id == 1 else p2
	
	# Smooth camera tracking bounded strictly to each player's OWN map!
	if camera and local_target_player:
		camera.position = local_target_player.position
		camera.zoom = Vector2(1.05, 1.05)
		if my_local_id == 1:
			camera.limit_left = 0
			camera.limit_right = 2816
			camera.limit_top = 0
			camera.limit_bottom = 1536
		else:
			camera.limit_left = 2816
			camera.limit_right = 5632
			camera.limit_top = 0
			camera.limit_bottom = 1536
	
	if hud:
		hud.set_local_player(my_local_id)
		hud.rematch_requested.connect(_on_rematch_pressed)
	if hud.has_signal("skip_day_requested"):
		hud.skip_day_requested.connect(_on_skip_day_pressed)

	if multiplayer.is_server():
		start_day_phase()
	else:
		if hud:
			hud.update_day_phase(current_day, day_timer)
		
	if tower1: tower1.tower_destroyed.connect(_on_tower_destroyed)
	if tower2: tower2.tower_destroyed.connect(_on_tower_destroyed)
	
	_broadcast_full_hud_sync()
	print("[SCRAPBOUND ONLINE] Arena loaded! Local Player ID: %d | Is Host: %s | Client Peer ID: %d" % [my_local_id, multiplayer.is_server(), client_peer_id])

func _physics_process(delta: float) -> void:
	if not is_match_running:
		return
		
	# Smoothly track local player with the camera
	if camera and local_target_player and is_instance_valid(local_target_player):
		camera.position = camera.position.lerp(local_target_player.position, delta * 6.0)
		
	# Daylight modulation interpolation
	var target_modulate: Color = Color(1.05, 1.02, 0.95, 1.0)
	match raid_phase:
		RaidPhase.DAY:
			target_modulate = Color(1.05, 1.02, 0.95, 1.0)
		RaidPhase.DUSK:
			target_modulate = Color(1.0, 0.65, 0.42, 1.0)
		RaidPhase.NIGHT_RAID:
			target_modulate = Color(0.38, 0.42, 0.62, 1.0)

	if day_night_modulate:
		day_night_modulate.color = day_night_modulate.color.lerp(target_modulate, delta * 2.5)

	# Match timing and monster spawning are strictly server-authoritative
	if multiplayer.is_server():
		match_timer -= delta
		sync_timer_net.rpc(match_timer)
		if hud:
			hud.update_timer(match_timer)

		if match_timer <= 0.0:
			end_match_server()
			return

		match raid_phase:
			RaidPhase.DAY:
				day_timer -= delta
				if hud:
					hud.update_day_phase(current_day, day_timer)
				sync_day_timer_net.rpc(day_timer)

				day_scrap_spawn_timer -= delta
				if day_scrap_spawn_timer <= 0.0:
					day_scrap_spawn_timer = randf_range(3.0, 5.0)
					_spawn_prep_scrap()

				if day_timer <= 0.0:
					start_dusk_phase()

			RaidPhase.DUSK:
				day_timer -= delta
				if hud:
					hud.update_dusk_phase(day_timer)
				sync_day_timer_net.rpc(day_timer)
				if day_timer <= 0.0:
					start_night_raid()

			RaidPhase.NIGHT_RAID:
				if raid_monsters_spawned < raid_monsters_total:
					raid_spawn_timer -= delta
					if raid_spawn_timer <= 0.0:
						raid_spawn_timer = randf_range(0.8, 1.4)
						_spawn_raid_wave()
	else:
		# Client side smooth countdown fallback between server RPC ticks
		match_timer = max(0.0, match_timer - delta)
		if hud:
			hud.update_timer(match_timer)

@rpc("call_local", "unreliable")
func sync_timer_net(time_left: float) -> void:
	match_timer = time_left
	if hud:
		hud.update_timer(match_timer)

func _spawn_monster_server() -> void:
	if not multiplayer.is_server():
		return
		
	# Spawn assault wave on Map 1 (Player 1 side: X from 300 to 2500, Y from 300 to 1400)
	var x1 = randf_range(300.0, 2500.0)
	var y1 = randf_range(300.0, 1400.0)
	var pos1 = Vector2(x1, y1)
	if tower1 and pos1.distance_to(tower1.global_position) < 320.0:
		pos1.y += 350.0
	next_entity_id += 1
	spawn_monster_net.rpc(next_entity_id, pos1)
	
	# Spawn assault wave on Map 2 (Player 2 side: X from 3116 to 5316, Y from 300 to 1400)
	var x2 = randf_range(3116.0, 5316.0)
	var y2 = randf_range(300.0, 1400.0)
	var pos2 = Vector2(x2, y2)
	if tower2 and pos2.distance_to(tower2.global_position) < 320.0:
		pos2.y += 350.0
	next_entity_id += 1
	spawn_monster_net.rpc(next_entity_id, pos2)

@rpc("call_local", "reliable")
func spawn_monster_net(m_id: int, pos: Vector2) -> void:
	var m = monster_scene.instantiate()
	m.name = "Monster_%d" % m_id
	m.global_position = pos
	add_child(m)

func on_monster_destroyed_server(_monster: Node2D, killer_id: int, pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
		
	if killer_id == 1:
		p1_kills += 1
		p1_score += 100
	elif killer_id == 2:
		p2_kills += 1
		p2_score += 100

	if raid_phase == RaidPhase.NIGHT_RAID:
		raid_monsters_alive = max(0, raid_monsters_alive - 1)
		sync_day_timer_net.rpc(float(raid_monsters_alive))
		if raid_monsters_spawned >= raid_monsters_total and raid_monsters_alive <= 0:
			raids_cleared_count += 1
			current_day += 1
			start_day_phase()
		
	# Monsters drop garbage/scraps upon dying!
	next_entity_id += 1
	spawn_scrap_drop_net.rpc(next_entity_id, "scrap", randi_range(10, 16), pos)
	
	# Extra scrap cluster
	if randf() < 0.6:
		next_entity_id += 1
		var offset = Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
		spawn_scrap_drop_net.rpc(next_entity_id, "scrap", randi_range(8, 14), pos + offset)
	
	_broadcast_full_hud_sync()

@rpc("call_local", "reliable")
func spawn_scrap_drop_net(item_id: int, item_type: String, qty: int, pos: Vector2) -> void:
	var item = scrap_item_scene.instantiate()
	item.name = "ScrapItem_%d" % item_id
	item.global_position = pos
	item.setup(item_type, qty)
	add_child(item)

# Client -> Server: Request to collect scrap
@rpc("any_peer", "call_local", "reliable")
func request_collect_scrap(item_node_name: String, collector_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var item_node = get_node_or_null(item_node_name) as ScrapItem
	if item_node and is_instance_valid(item_node) and not item_node.is_queued_for_deletion():
		var target_player = p1 if collector_id == 1 else p2
		if target_player:
			var qty = item_node.amount
			target_player.add_resource("scrap", qty)
			sync_inventory_net.rpc(collector_id, target_player.inventory)
			collect_scrap_fx_net.rpc(item_node.global_position, item_node_name, collector_id, qty)

@rpc("call_local", "reliable")
func collect_scrap_fx_net(_pos: Vector2, item_node_name: String, collector_id: int, qty: int) -> void:
	var item_node = get_node_or_null(item_node_name)
	if item_node and is_instance_valid(item_node):
		item_node.queue_free()
		
	var p = p1 if collector_id == 1 else p2
	if is_instance_valid(p):
		p.on_scrap_collected_feedback(qty)
	_broadcast_full_hud_sync()

@rpc("call_local", "reliable")
func remove_scrap_item_net(item_node_name: String) -> void:
	var item_node = get_node_or_null(item_node_name)
	if item_node and is_instance_valid(item_node):
		item_node.queue_free()

# Client -> Server: Request to refine garbage into a RANDOM raw material (wood, iron, plastic)
@rpc("any_peer", "call_local", "reliable")
func request_refine(player_id: int, _target_material: String = "random") -> void:
	if not multiplayer.is_server():
		return

	var target_player = p1 if player_id == 1 else p2
	if not target_player or target_player.inventory.get("scrap", 0) < 1:
		return

	var r_id = player_id
	var recycler = recycler1 if r_id == 1 else recycler2
	if not recycler:
		return

	# Check distance: player must take scraps to their team's Refinery to recycle!
	if target_player.global_position.distance_to(recycler.global_position) > 180.0:
		return

	target_player.inventory["scrap"] -= 1

	# User requirement: 4 sorting outputs (wood: 32%, iron: 32%, plastic: 24%, battery: 12%)
	var roll = randi_range(1, 100)
	var reward = "wood"
	if roll <= 32:
		reward = "iron"
	elif roll <= 64:
		reward = "wood"
	elif roll <= 88:
		reward = "plastic"
	else:
		reward = "battery"

	target_player.add_resource(reward, 1)

	if recycler:
		recycler.play_recycle_effect_net.rpc(reward)
	sync_inventory_net.rpc(player_id, target_player.inventory)
	_broadcast_full_hud_sync()

# Client -> Server: Request to recycle/refine scrap from world refinery interaction
@rpc("any_peer", "call_local", "reliable")
func request_recycle(r_id: int, player_id: int) -> void:
	request_refine(player_id, "random")

# Client -> Server: Request to craft weapon
@rpc("any_peer", "call_local", "reliable")
func request_craft_recipe(player_id: int, recipe_type: String) -> void:
	if not multiplayer.is_server():
		return
		
	var p = p1 if player_id == 1 else p2
	if not p: return
	
	var can_craft = false
	if recipe_type == "RapidFire" or recipe_type == "auto":
		# Cost: 1 Iron + 1 Plastic (or 1 Mat A + 1 Mat B)
		if p.inventory["iron"] >= 1 and p.inventory["plastic"] >= 1:
			p.inventory["iron"] -= 1
			p.inventory["plastic"] -= 1
			can_craft = true
		elif p.inventory["material_a"] >= 1 and p.inventory["material_b"] >= 1:
			p.inventory["material_a"] -= 1
			p.inventory["material_b"] -= 1
			can_craft = true
		if can_craft:
			_unlock_and_equip_weapon(p, player_id, "RapidFire")
			return
			
	if recipe_type == "HighDamage" or recipe_type == "auto":
		# Cost: 2 Iron + 1 Wood (or 1 Mat A + 1 Mat C)
		if p.inventory["iron"] >= 2 and p.inventory["wood"] >= 1:
			p.inventory["iron"] -= 2
			p.inventory["wood"] -= 1
			can_craft = true
		elif p.inventory["material_a"] >= 1 and p.inventory["material_c"] >= 1:
			p.inventory["material_a"] -= 1
			p.inventory["material_c"] -= 1
			can_craft = true
		if can_craft:
			_unlock_and_equip_weapon(p, player_id, "HighDamage")
			return
			
	if recipe_type == "Shotgun":
		# Cost: 1 Wood + 1 Iron + 1 Plastic
		if p.inventory["wood"] >= 1 and p.inventory["iron"] >= 1 and p.inventory["plastic"] >= 1:
			p.inventory["wood"] -= 1
			p.inventory["iron"] -= 1
			p.inventory["plastic"] -= 1
			_unlock_and_equip_weapon(p, player_id, "Shotgun")
			return
			
	if recipe_type == "PlasmaSniper":
		# Cost: 2 Plastic + 1 Iron
		if p.inventory["plastic"] >= 2 and p.inventory["iron"] >= 1:
			p.inventory["plastic"] -= 2
			p.inventory["iron"] -= 1
			_unlock_and_equip_weapon(p, player_id, "PlasmaSniper")
			return

func _unlock_and_equip_weapon(p: ScrapboundPlayer, player_id: int, weapon_name: String) -> void:
	if not (weapon_name in p.unlocked_weapons):
		p.unlocked_weapons.append(weapon_name)
	p.set_weapon(weapon_name)
	sync_weapon_net.rpc(player_id, weapon_name, p.inventory, p.unlocked_weapons)
	_broadcast_full_hud_sync()

# Client -> Server: Request to switch to next unlocked weapon
@rpc("any_peer", "call_local", "reliable")
func request_switch_weapon(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	var p = p1 if player_id == 1 else p2
	if not p or p.unlocked_weapons.size() <= 1:
		return
	var cur_idx = p.unlocked_weapons.find(p.current_weapon)
	if cur_idx == -1: cur_idx = 0
	var next_idx = (cur_idx + 1) % p.unlocked_weapons.size()
	var next_weapon = p.unlocked_weapons[next_idx]
	p.set_weapon(next_weapon)
	sync_weapon_net.rpc(player_id, next_weapon, p.inventory, p.unlocked_weapons)
	_broadcast_full_hud_sync()

# Client -> Server: Request to equip a specific owned weapon
@rpc("any_peer", "call_local", "reliable")
func request_equip_weapon(player_id: int, weapon_name: String) -> void:
	if not multiplayer.is_server():
		return
	var p = p1 if player_id == 1 else p2
	if not p: return
	if weapon_name in p.unlocked_weapons:
		p.set_weapon(weapon_name)
		sync_weapon_net.rpc(player_id, weapon_name, p.inventory, p.unlocked_weapons)
		_broadcast_full_hud_sync()

@rpc("any_peer", "call_local", "reliable")
func request_craft(player_id: int) -> void:
	request_craft_recipe(player_id, "auto")

@rpc("call_local", "reliable")
func sync_weapon_net(player_id: int, weapon_name: String, updated_inv: Dictionary, unlocked_list: Array = []) -> void:
	var p = p1 if player_id == 1 else p2
	if p:
		p.set_weapon(weapon_name)
		p.inventory = updated_inv
		if unlocked_list.size() > 0:
			p.unlocked_weapons = unlocked_list
	_broadcast_full_hud_sync()

# Client -> Server: Request to build barrier
@rpc("any_peer", "call_local", "reliable")
func request_build_barrier(builder_id: int, spawn_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
		
	var p = p1 if builder_id == 1 else p2
	if not p: return
	
	var total_mats = p.inventory["wood"] + p.inventory["plastic"] + p.inventory["iron"]
	if total_mats < 2:
		return
		
	var needed = 2
	for mat in ["wood", "plastic", "iron"]:
		while p.inventory[mat] > 0 and needed > 0:
			p.inventory[mat] -= 1
			needed -= 1
			
	var clamped_pos = spawn_pos
	if builder_id == 1:
		clamped_pos.x = clampf(clamped_pos.x, 80.0, 2736.0)
	else:
		clamped_pos.x = clampf(clamped_pos.x, 2896.0, 5550.0)
	clamped_pos.y = clampf(clamped_pos.y, 80.0, 1450.0)
	
	next_entity_id += 1
	spawn_barrier_net.rpc(next_entity_id, clamped_pos, builder_id, p.inventory)

@rpc("call_local", "reliable")
func spawn_barrier_net(b_id: int, spawn_pos: Vector2, builder_id: int, updated_inv: Dictionary) -> void:
	var p = p1 if builder_id == 1 else p2
	if p:
		p.inventory = updated_inv
		
	var b = barrier_scene.instantiate()
	b.name = "Barrier_%d" % b_id
	b.global_position = spawn_pos
	b.setup(builder_id)
	add_child(b)
	_broadcast_full_hud_sync()

# Client -> Server: Request to build defense sentry mini-tower
@rpc("any_peer", "call_local", "reliable")
func request_build_tower(builder_id: int, spawn_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var p = p1 if builder_id == 1 else p2
	if not p: return
	
	# Cost: 2 Iron + 1 Plastic
	if p.inventory["iron"] < 2 or p.inventory["plastic"] < 1:
		return
	p.inventory["iron"] -= 2
	p.inventory["plastic"] -= 1
	
	var clamped_pos = spawn_pos
	if builder_id == 1:
		clamped_pos.x = clampf(clamped_pos.x, 80.0, 2736.0)
	else:
		clamped_pos.x = clampf(clamped_pos.x, 2896.0, 5550.0)
	clamped_pos.y = clampf(clamped_pos.y, 80.0, 1450.0)
	
	next_entity_id += 1
	spawn_defense_tower_net.rpc(next_entity_id, clamped_pos, builder_id, p.inventory)

@rpc("call_local", "reliable")
func spawn_defense_tower_net(t_id: int, spawn_pos: Vector2, builder_id: int, updated_inv: Dictionary) -> void:
	var p = p1 if builder_id == 1 else p2
	if p:
		p.inventory = updated_inv
	var dt = defense_tower_scene.instantiate()
	dt.name = "DefenseTower_%d" % t_id
	dt.global_position = spawn_pos
	dt.setup(builder_id)
	add_child(dt)
	_broadcast_full_hud_sync()

# Client -> Server: Request to repair base tower
@rpc("any_peer", "call_local", "reliable")
func request_repair_tower(builder_id: int) -> void:
	if not multiplayer.is_server():
		return
	var p = p1 if builder_id == 1 else p2
	if not p: return
	var target_tower = tower1 if builder_id == 1 else tower2
	if not target_tower or target_tower.health >= target_tower.max_health:
		return
		
	# Cost: 2 Wood + 1 Iron
	if p.inventory["wood"] < 2 or p.inventory["iron"] < 1:
		return
	p.inventory["wood"] -= 2
	p.inventory["iron"] -= 1
	
	target_tower.repair_server(250)
	_broadcast_full_hud_sync()

@rpc("call_local", "reliable")
func sync_inventory_net(player_id: int, updated_inv: Dictionary) -> void:
	var p = p1 if player_id == 1 else p2
	if p:
		p.inventory = updated_inv
		p._update_scrap_badge()
	_broadcast_full_hud_sync()

func _broadcast_full_hud_sync() -> void:
	if not is_instance_valid(hud):
		return
		
	var p1_hp = p1.health if is_instance_valid(p1) else 0
	var p1_wpn = p1.current_weapon if is_instance_valid(p1) else "Basic"
	var p1_inv = p1.inventory if is_instance_valid(p1) else {}
	var p1_unl = p1.unlocked_weapons if is_instance_valid(p1) else ["Basic"]
	var t1_hp = tower1.health if is_instance_valid(tower1) else 0
	
	var p2_hp = p2.health if is_instance_valid(p2) else 0
	var p2_wpn = p2.current_weapon if is_instance_valid(p2) else "Basic"
	var p2_inv = p2.inventory if is_instance_valid(p2) else {}
	var p2_unl = p2.unlocked_weapons if is_instance_valid(p2) else ["Basic"]
	var t2_hp = tower2.health if is_instance_valid(tower2) else 0
	
	if multiplayer.is_server():
		sync_hud_net.rpc(
			p1_hp, p1_score, p1_kills, t1_hp, p1_wpn, p1_inv,
			p2_hp, p2_score, p2_kills, t2_hp, p2_wpn, p2_inv,
			p1_unl, p2_unl
		)
	else:
		hud.update_player_ui(
			p1_hp, p1_score, p1_kills, t1_hp, p1_wpn, p1_inv,
			p2_hp, p2_score, p2_kills, t2_hp, p2_wpn, p2_inv,
			p1_unl, p2_unl
		)

@rpc("call_local", "reliable")
func sync_hud_net(
	p1_hp: int, p1_sc: int, p1_k: int, t1_hp: int, p1_wpn: String, p1_inv: Dictionary,
	p2_hp: int, p2_sc: int, p2_k: int, t2_hp: int, p2_wpn: String, p2_inv: Dictionary,
	p1_unl: Array = ["Basic"], p2_unl: Array = ["Basic"]
) -> void:
	p1_score = p1_sc
	p1_kills = p1_k
	p2_score = p2_sc
	p2_kills = p2_k
	if is_instance_valid(p1):
		p1.unlocked_weapons = p1_unl
		p1.current_weapon = p1_wpn
	if is_instance_valid(p2):
		p2.unlocked_weapons = p2_unl
		p2.current_weapon = p2_wpn
	if hud:
		hud.update_player_ui(
			p1_hp, p1_sc, p1_k, t1_hp, p1_wpn, p1_inv,
			p2_hp, p2_sc, p2_k, t2_hp, p2_wpn, p2_inv,
			p1_unl, p2_unl
		)

func _on_tower_destroyed(destroyed_tower_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[SCRAPBOUND ONLINE] Tower %d destroyed! Concluding match." % destroyed_tower_id)
	end_match_server()

func end_match_server() -> void:
	if not multiplayer.is_server() or not is_match_running:
		return
	is_match_running = false
	var t1_hp = tower1.health if is_instance_valid(tower1) else 0
	var t2_hp = tower2.health if is_instance_valid(tower2) else 0
	sync_match_results_net.rpc(p1_kills, p1_score, t1_hp, p2_kills, p2_score, t2_hp)

@rpc("call_local", "reliable")
func sync_match_results_net(p1_k: int, p1_sc: int, t1_hp: int, p2_k: int, p2_sc: int, t2_hp: int) -> void:
	is_match_running = false
	if hud:
		hud.show_results(p1_k, p1_sc, t1_hp, p2_k, p2_sc, t2_hp)

func _on_rematch_pressed() -> void:
	if multiplayer.is_server():
		return_to_lobby_net.rpc()
	else:
		return_to_lobby_net()

@rpc("call_local", "reliable")
func return_to_lobby_net() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/scrapbound/Lobby.tscn")

# -------------------------------------------------------------------------
# RAID CYCLE & ADVANCED FABRICATION / TURRET SYSTEM
# -------------------------------------------------------------------------
func start_day_phase() -> void:
	raid_phase = RaidPhase.DAY
	day_timer = DAY_DURATION
	if day_bgm and not day_bgm.playing:
		day_bgm.play()
	if battle_bgm and battle_bgm.playing:
		battle_bgm.stop()
	sync_raid_phase_net.rpc(RaidPhase.DAY, current_day, DAY_DURATION, 0)
	_broadcast_full_hud_sync()

func start_dusk_phase() -> void:
	raid_phase = RaidPhase.DUSK
	day_timer = DUSK_DURATION
	if dusk_siren:
		dusk_siren.play()
	sync_raid_phase_net.rpc(RaidPhase.DUSK, current_day, DUSK_DURATION, 0)
	_broadcast_full_hud_sync()

func start_night_raid() -> void:
	raid_phase = RaidPhase.NIGHT_RAID
	day_timer = 0.0
	raid_monsters_total = 6 + (current_day - 1) * 3
	raid_monsters_spawned = 0
	raid_monsters_alive = raid_monsters_total
	raid_spawn_timer = 0.5
	if day_bgm and day_bgm.playing:
		day_bgm.stop()
	if battle_bgm and not battle_bgm.playing:
		battle_bgm.play()
	sync_raid_phase_net.rpc(RaidPhase.NIGHT_RAID, current_day, 0.0, raid_monsters_total)
	_broadcast_full_hud_sync()

func _on_skip_day_pressed() -> void:
	if not is_match_running or raid_phase != RaidPhase.DAY:
		return
	if multiplayer.is_server():
		start_dusk_phase()
	else:
		request_skip_day_net.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_skip_day_net() -> void:
	if not multiplayer.is_server():
		return
	if is_match_running and raid_phase == RaidPhase.DAY:
		start_dusk_phase()

@rpc("call_local", "reliable")
func sync_raid_phase_net(phase_val: int, day_num: int, timer_val: float, foes_alive: int) -> void:
	raid_phase = phase_val as RaidPhase
	current_day = day_num
	day_timer = timer_val
	if hud:
		match raid_phase:
			RaidPhase.DAY:
				hud.update_day_phase(current_day, day_timer)
			RaidPhase.DUSK:
				hud.update_dusk_phase(day_timer)
			RaidPhase.NIGHT_RAID:
				hud.update_night_raid_phase(current_day, foes_alive)

@rpc("call_local", "reliable")
func sync_day_timer_net(timer_val: float) -> void:
	day_timer = timer_val
	if hud:
		match raid_phase:
			RaidPhase.DAY:
				hud.update_day_phase(current_day, day_timer)
			RaidPhase.DUSK:
				hud.update_dusk_phase(day_timer)
			RaidPhase.NIGHT_RAID:
				hud.update_night_raid_phase(current_day, int(day_timer))

func _spawn_prep_scrap() -> void:
	if not multiplayer.is_server(): return
	var p1_pos = Vector2(randf_range(400.0, 2400.0), randf_range(300.0, 1300.0))
	next_entity_id += 1
	spawn_scrap_drop_net.rpc(next_entity_id, "scrap", randi_range(6, 12), p1_pos)

	var p2_pos = Vector2(randf_range(3216.0, 5216.0), randf_range(300.0, 1300.0))
	next_entity_id += 1
	spawn_scrap_drop_net.rpc(next_entity_id, "scrap", randi_range(6, 12), p2_pos)

func _spawn_raid_wave() -> void:
	if not multiplayer.is_server() or raid_monsters_spawned >= raid_monsters_total:
		return

	var y1 = randf_range(300.0, 1300.0)
	var x1 = randf_range(200.0, 600.0) if randf() < 0.5 else randf_range(2200.0, 2600.0)
	next_entity_id += 1
	spawn_monster_net.rpc(next_entity_id, Vector2(x1, y1))
	raid_monsters_spawned += 1

	if raid_monsters_spawned < raid_monsters_total:
		var y2 = randf_range(300.0, 1300.0)
		var x2 = randf_range(3016.0, 3416.0) if randf() < 0.5 else randf_range(5016.0, 5416.0)
		next_entity_id += 1
		spawn_monster_net.rpc(next_entity_id, Vector2(x2, y2))
	raid_monsters_spawned += 1

	sync_day_timer_net.rpc(float(raid_monsters_alive))

# Workshop Crafting RPC
@rpc("any_peer", "call_local", "reliable")
func request_craft_item(p_id: int, item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var player = p1 if p_id == 1 else p2
	if not player or not is_instance_valid(player):
		return

	var inv = player.inventory
	var wood = inv.get("wood", 0)
	var iron = inv.get("iron", 0)
	var plastic = inv.get("plastic", 0)
	var battery = inv.get("battery", 0)

	var success = false
	var msg = ""

	match item_id:
		"Welder":
			player.set_weapon("Welder")
			success = true
			msg = "Welder Tool equipped!"
		"Rifle":
			if iron >= 1:
				player.inventory["iron"] -= 1
				_unlock_and_equip_weapon(player, p_id, "Rifle")
				success = true
				msg = "Assault Rifle crafted & equipped!"
			else:
				msg = "Need 1 Iron to craft Rifle!"
		"Shotgun":
			if wood >= 1 and iron >= 1:
				player.inventory["wood"] -= 1
				player.inventory["iron"] -= 1
				_unlock_and_equip_weapon(player, p_id, "Shotgun")
				success = true
				msg = "Pump Shotgun crafted & equipped!"
			else:
				msg = "Need 1 Wood & 1 Iron for Shotgun!"
		"Flamethrower":
			if plastic >= 1 and iron >= 1:
				player.inventory["plastic"] -= 1
				player.inventory["iron"] -= 1
				_unlock_and_equip_weapon(player, p_id, "Flamethrower")
				success = true
				msg = "Flamethrower crafted & equipped!"
			else:
				msg = "Need 1 Plastic & 1 Iron for Flamethrower!"
		"TowerRepair":
			if wood >= 1 and plastic >= 1:
				var tower = tower1 if p_id == 1 else tower2
				if tower and is_instance_valid(tower):
					player.inventory["wood"] -= 1
					player.inventory["plastic"] -= 1
					tower.health = min(1000, tower.health + 250)
					tower.sync_tower_hp_net.rpc(tower.health)
					success = true
					msg = "Tower repaired (+250 HP)!"
				else:
					msg = "Tower not available!"
			else:
				msg = "Need 1 Wood & 1 Plastic for Tower Repair!"
		"PlayerHeal":
			if plastic >= 1:
				if player.health < player.max_health:
					player.inventory["plastic"] -= 1
					player.health = min(player.max_health, player.health + 40)
					player.sync_health_net.rpc(player.health)
					success = true
					msg = "Suit repaired (+40 HP)!"
				else:
					msg = "Player already at full HP!"
			else:
				msg = "Need 1 Plastic for Suit Medikit!"
		"Turret":
			if iron >= 1 and wood >= 1 and battery >= 1:
				player.inventory["iron"] -= 1
				player.inventory["wood"] -= 1
				player.inventory["battery"] -= 1
				player.inventory["turrets"] = player.inventory.get("turrets", 0) + 1
				success = true
				msg = "Sentry Turret built! Press [B] to deploy!"
			elif iron >= 2 and wood >= 1:
				player.inventory["iron"] -= 2
				player.inventory["wood"] -= 1
				player.inventory["turrets"] = player.inventory.get("turrets", 0) + 1
				success = true
				msg = "Sentry Turret built! Press [B] to deploy!"
			else:
				msg = "Need (1 Iron + 1 Wood + 1 Battery) or (2 Iron + 1 Wood)!"
		_:
			msg = "Unknown craft item: " + item_id

	_broadcast_full_hud_sync()

	var peer_id = player.get_multiplayer_authority()
	notify_craft_result_net.rpc_id(peer_id, success, msg)

@rpc("call_local", "reliable")
func notify_craft_result_net(success: bool, msg: String) -> void:
	if hud and hud.has_method("show_craft_feedback"):
		hud.show_craft_feedback(success, msg)

# Deployable Turret RPC
@rpc("any_peer", "call_local", "reliable")
func request_deploy_turret(builder_id: int, spawn_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var player = p1 if builder_id == 1 else p2
	if not player or not is_instance_valid(player):
		return

	var turrets_count = player.inventory.get("turrets", 0)
	if turrets_count < 1:
		var inv = player.inventory
		var iron = inv.get("iron", 0)
		var wood = inv.get("wood", 0)
		var battery = inv.get("battery", 0)
		if iron >= 1 and wood >= 1 and battery >= 1:
			player.inventory["iron"] -= 1
			player.inventory["wood"] -= 1
			player.inventory["battery"] -= 1
		elif iron >= 2 and wood >= 1:
			player.inventory["iron"] -= 2
			player.inventory["wood"] -= 1
		else:
			var peer = player.get_multiplayer_authority()
			notify_craft_result_net.rpc_id(peer, false, "Need Sentry Turret in inventory or materials!")
			return
	else:
		player.inventory["turrets"] -= 1

	next_entity_id += 1
	spawn_turret_net.rpc(next_entity_id, spawn_pos, builder_id, player.inventory)

@rpc("call_local", "reliable")
func spawn_turret_net(t_id: int, spawn_pos: Vector2, builder_id: int, updated_inv: Dictionary) -> void:
	var p = p1 if builder_id == 1 else p2
	if p:
		p.inventory = updated_inv

	var t = deployable_turret_scene.instantiate()
	t.name = "Turret_%d" % t_id
	t.global_position = spawn_pos
	t.team_id = builder_id
	add_child(t)
	_broadcast_full_hud_sync()
