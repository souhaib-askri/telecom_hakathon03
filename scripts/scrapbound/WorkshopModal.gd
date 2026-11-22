extends Control
class_name WorkshopModal

@onready var btn_close: Button = %BtnClose
@onready var mats_label: Label = %MatsLabel
@onready var log_label: Label = %LogLabel
@onready var audio_click: AudioStreamPlayer = $AudioClick

# Craft buttons
@onready var btn_craft_rifle: Button = %BtnCraftRifle
@onready var btn_craft_shotgun: Button = %BtnCraftShotgun
@onready var btn_craft_flame: Button = %BtnCraftFlame
@onready var btn_craft_repair: Button = %BtnCraftRepair
@onready var btn_craft_medikit: Button = %BtnCraftMedikit
@onready var btn_craft_turret: Button = %BtnCraftTurret

var local_player: ScrapboundPlayer = null

func _ready() -> void:
	visible = false
	if btn_close:
		btn_close.pressed.connect(close_modal)
		
	if btn_craft_rifle:
		btn_craft_rifle.pressed.connect(func(): _request_craft("Rifle"))
	if btn_craft_shotgun:
		btn_craft_shotgun.pressed.connect(func(): _request_craft("Shotgun"))
	if btn_craft_flame:
		btn_craft_flame.pressed.connect(func(): _request_craft("Flamethrower"))
	if btn_craft_repair:
		btn_craft_repair.pressed.connect(func(): _request_craft("TowerRepair"))
	if btn_craft_medikit:
		btn_craft_medikit.pressed.connect(func(): _request_craft("PlayerHeal"))
	if btn_craft_turret:
		btn_craft_turret.pressed.connect(func(): _request_craft("Turret"))

func _find_local_player() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if is_instance_valid(p) and p is ScrapboundPlayer:
			if p.is_multiplayer_authority():
				local_player = p
				return

func open_modal() -> void:
	visible = true
	_find_local_player()
	update_ui()
	if log_label:
		log_label.text = "Select a weapon, defense turret, or utility tool to fabricate."
		log_label.modulate = Color(0.9, 0.9, 0.95)

func close_modal() -> void:
	visible = false

func toggle_modal() -> void:
	if visible:
		close_modal()
	else:
		open_modal()

func update_ui() -> void:
	if not visible:
		return
	if not local_player or not is_instance_valid(local_player):
		_find_local_player()
	if not local_player:
		return
		
	var inv = local_player.inventory
	var wood = inv.get("wood", 0)
	var iron = inv.get("iron", 0)
	var plastic = inv.get("plastic", 0)
	var battery = inv.get("battery", 0)
	var scrap = inv.get("scrap", 0)
	var turrets = inv.get("turrets", 0)
	
	if mats_label:
		mats_label.text = "MATERIALS:  🪵 Wood: %d   ⚙️ Iron: %d   🧪 Plastic: %d   🔋 Battery: %d   🎒 Scrap: %d   🛡️ Turrets: %d" % [
			wood, iron, plastic, battery, scrap, turrets
		]
		
	# Recipe verification:
	# 1. Rifle: 1 Iron
	if btn_craft_rifle:
		btn_craft_rifle.disabled = (iron < 1)
		
	# 2. Shotgun: 1 Wood + 1 Iron
	if btn_craft_shotgun:
		btn_craft_shotgun.disabled = (wood < 1 or iron < 1)
		
	# 3. Flamethrower: 1 Plastic + 1 Iron
	if btn_craft_flame:
		btn_craft_flame.disabled = (plastic < 1 or iron < 1)
		
	# 4. Tower Repair: 1 Wood + 1 Plastic
	if btn_craft_repair:
		btn_craft_repair.disabled = (wood < 1 or plastic < 1)
		
	# 6. Player Heal: 1 Plastic
	if btn_craft_medikit:
		btn_craft_medikit.disabled = (plastic < 1 or local_player.health >= local_player.max_health)
		
	# 7. Sentry Turret: 1 Iron + 1 Wood + 1 Battery (or 2 Iron + 1 Wood)
	if btn_craft_turret:
		var can_turret = (iron >= 1 and wood >= 1 and battery >= 1) or (iron >= 2 and wood >= 1)
		btn_craft_turret.disabled = not can_turret

func _request_craft(item_id: String) -> void:
	if audio_click:
		audio_click.play()
	if not local_player:
		_find_local_player()
	if not local_player:
		return
		
	var main = get_parent().get_parent() # HUD -> CanvasLayer -> ScrapboundMain
	if not main or not main.has_method("request_craft_item"):
		main = get_tree().get_first_node_in_group("Main")
		
	if main and main.has_method("request_craft_item"):
		main.request_craft_item.rpc_id(1, local_player.player_id, item_id)

func show_feedback(success: bool, msg: String) -> void:
	if log_label:
		log_label.text = msg
		log_label.modulate = Color(0.3, 1.0, 0.5) if success else Color(1.0, 0.4, 0.4)
	update_ui()
