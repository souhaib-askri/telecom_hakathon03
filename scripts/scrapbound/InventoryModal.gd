extends Control
class_name InventoryModal

signal weapon_equip_requested(weapon_name: String)
signal turret_deploy_requested()

@onready var btn_close: Button = %BtnClose
@onready var btn_deploy_turret: Button = %BtnDeployTurret

# Resource count labels
@onready var lbl_scrap_count: Label = %LblScrapCount
@onready var lbl_wood_count: Label = %LblWoodCount
@onready var lbl_iron_count: Label = %LblIronCount
@onready var lbl_plastic_count: Label = %LblPlasticCount
@onready var lbl_battery_count: Label = %LblBatteryCount
@onready var lbl_turret_count: Label = %LblTurretCount

# Weapon equip buttons
@onready var btn_equip_welder: Button = %BtnEquipWelder
@onready var btn_equip_rifle: Button = %BtnEquipRifle
@onready var btn_equip_shotgun: Button = %BtnEquipShotgun
@onready var btn_equip_flame: Button = %BtnEquipFlame

var local_player: ScrapboundPlayer = null

func _ready() -> void:
	visible = false
	if btn_close:
		btn_close.pressed.connect(close_modal)
	if btn_deploy_turret:
		btn_deploy_turret.pressed.connect(_on_deploy_turret_pressed)
		
	if btn_equip_welder:
		btn_equip_welder.pressed.connect(func(): _request_equip("Welder"))
	if btn_equip_rifle:
		btn_equip_rifle.pressed.connect(func(): _request_equip("Rifle"))
	if btn_equip_shotgun:
		btn_equip_shotgun.pressed.connect(func(): _request_equip("Shotgun"))
	if btn_equip_flame:
		btn_equip_flame.pressed.connect(func(): _request_equip("Flamethrower"))

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

func close_modal() -> void:
	visible = false

func toggle_modal() -> void:
	if visible:
		close_modal()
	else:
		open_modal()

func _on_deploy_turret_pressed() -> void:
	turret_deploy_requested.emit()
	if local_player and local_player.has_method("deploy_turret_action"):
		local_player.deploy_turret_action()
	close_modal()

func _request_equip(weapon_name: String) -> void:
	if not local_player:
		_find_local_player()
	if local_player and weapon_name in local_player.unlocked_weapons:
		local_player.set_weapon(weapon_name)
		weapon_equip_requested.emit(weapon_name)
		update_ui()

func update_ui() -> void:
	if not visible:
		return
	if not local_player or not is_instance_valid(local_player):
		_find_local_player()
	if not local_player:
		return
		
	var inv = local_player.inventory
	if lbl_scrap_count: lbl_scrap_count.text = "x%d" % inv.get("scrap", 0)
	if lbl_wood_count: lbl_wood_count.text = "x%d" % inv.get("wood", 0)
	if lbl_iron_count: lbl_iron_count.text = "x%d" % inv.get("iron", 0)
	if lbl_plastic_count: lbl_plastic_count.text = "x%d" % inv.get("plastic", 0)
	if lbl_battery_count: lbl_battery_count.text = "x%d" % inv.get("battery", 0)
	
	var turrets = inv.get("turrets", 0)
	if lbl_turret_count: lbl_turret_count.text = "x%d In Stock" % turrets
	if btn_deploy_turret:
		var has_mats = (inv.get("iron", 0) >= 1 and inv.get("wood", 0) >= 1 and inv.get("battery", 0) >= 1) or (inv.get("iron", 0) >= 2 and inv.get("wood", 0) >= 1)
		btn_deploy_turret.disabled = (turrets < 1 and not has_mats)
		btn_deploy_turret.text = "DEPLOY [B]" if turrets > 0 else ("AUTO-BUILD [B]" if has_mats else "LOCKED")
		
	var curr = local_player.current_weapon
	var unlocked = local_player.unlocked_weapons
	
	_update_weapon_btn(btn_equip_welder, "Welder", curr, unlocked)
	_update_weapon_btn(btn_equip_rifle, "Rifle", curr, unlocked)
	_update_weapon_btn(btn_equip_shotgun, "Shotgun", curr, unlocked)
	_update_weapon_btn(btn_equip_flame, "Flamethrower", curr, unlocked)

func _update_weapon_btn(btn: Button, w_name: String, current_w: String, unlocked: Array) -> void:
	if not btn: return
	if w_name == current_w:
		btn.text = "EQUIPPED"
		btn.disabled = true
		btn.modulate = Color(0.2, 0.9, 1.0)
	elif w_name in unlocked:
		btn.text = "EQUIP"
		btn.disabled = false
		btn.modulate = Color.WHITE
	else:
		btn.text = "CRAFT IN WORKSHOP"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
