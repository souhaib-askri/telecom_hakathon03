extends Area2D
class_name ScrapRecycler

@export var recycler_id: int = 1
@export var scrap_cost_per_cycle: int = 10

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var prompt_label: Label = $PromptLabel
@onready var process_audio: AudioStreamPlayer2D = $ProcessAudio
@onready var craft_audio: AudioStreamPlayer2D = $CraftAudio
@onready var zone_circle: Line2D = $ZoneCircle

var active_local_player: ScrapboundPlayer = null
var auto_recycle_timer: float = 0.0

func _ready() -> void:
	add_to_group("Recyclers")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		
	var team_color = Color(0.2, 0.85, 1.0) if recycler_id == 1 else Color(1.0, 0.6, 0.2)
	label.text = "REFINERY P%d (DROP-OFF)" % recycler_id
	label.modulate = team_color
	if zone_circle:
		zone_circle.default_color = Color(team_color.r, team_color.g, team_color.b, 0.5)

func _physics_process(delta: float) -> void:
	if not active_local_player or not is_instance_valid(active_local_player):
		return
		
	var scrap_held = active_local_player.inventory.get("scrap", 0)
	if scrap_held >= 1:
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "♻ SORTING SCRAP BAG (%d)..." % scrap_held
			prompt_label.modulate = Color(0.3, 1.0, 0.5)
			
		auto_recycle_timer -= delta
		if auto_recycle_timer <= 0.0:
			auto_recycle_timer = 0.45
			var main = get_tree().get_first_node_in_group("Main") as ScrapboundMain
			if not main:
				main = get_parent() as ScrapboundMain
			if main:
				main.request_refine.rpc_id(1, active_local_player.player_id, "random")
	else:
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "GATHER SCRAP TO SORT!"
			prompt_label.modulate = Color(1.0, 0.7, 0.3)

func _on_body_entered(body: Node2D) -> void:
	if body is ScrapboundPlayer and body.is_multiplayer_authority():
		if body.player_id == recycler_id:
			active_local_player = body
			body.nearby_recycler = self
			auto_recycle_timer = 0.2 # quick first trigger

func _on_body_exited(body: Node2D) -> void:
	if body == active_local_player:
		active_local_player.nearby_recycler = null
		active_local_player = null
		if prompt_label:
			prompt_label.visible = false

@rpc("any_peer", "call_local", "reliable")
func play_recycle_effect_net(reward: String) -> void:
	if process_audio:
		process_audio.pitch_scale = randf_range(0.95, 1.05)
		process_audio.play()
	if craft_audio:
		craft_audio.pitch_scale = randf_range(1.0, 1.15)
		craft_audio.play()
		
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", TAU * 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(sprite):
		sprite.rotation = 0.0
	
	# Spawn floating reward banner
	_show_floating_reward(reward)

func _show_floating_reward(reward: String) -> void:
	var lbl = Label.new()
	var icon = "🪵"
	if reward == "wood": icon = "🪵"
	elif reward == "iron": icon = "⚙️"
	elif reward == "plastic": icon = "🧪"
	elif reward == "battery": icon = "🔋"
	lbl.text = "%s +1 %s PRODUCED!" % [icon, reward.to_upper()]
	lbl.modulate = Color(0.3, 1.0, 0.4)
	lbl.set("theme_override_font_sizes/font_size", 9)
	lbl.position = Vector2(-70, -65)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(140, 18)
	add_child(lbl)
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)
