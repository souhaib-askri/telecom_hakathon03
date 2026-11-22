extends Area2D
class_name ScrapboundWorkshop

@export var workshop_id: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var prompt_label: Label = $PromptLabel
@onready var audio: AudioStreamPlayer2D = $Audio

func _ready() -> void:
	add_to_group("Workshops")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		
	label.text = "FIELD WORKSHOP P%d" % workshop_id
	label.modulate = Color(0.2, 0.85, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body is ScrapboundPlayer and body.is_multiplayer_authority():
		body.nearby_workshop = self
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "[E] ACCESS WORKSHOP & CRAFTING"
			prompt_label.modulate = Color(0.3, 1.0, 0.6)

func _on_body_exited(body: Node2D) -> void:
	if body is ScrapboundPlayer and body.nearby_workshop == self:
		body.nearby_workshop = null
		if prompt_label:
			prompt_label.visible = false
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("close_workshop_modal"):
			hud.close_workshop_modal()
