extends Area2D
class_name TreasureChest

signal chest_opened(reward: Dictionary)

@export var is_locked: bool = true
var is_open: bool = false

# Pool of progressive rewards from chests
const REWARDS = [
	{ "name": "Ancient Greatsword", "ability": "attack_boost", "desc": "+15 Attack Damage" },
	{ "name": "Heart of Iron", "ability": "health_boost", "desc": "+50 Max Health & Full Heal" },
	{ "name": "Wind Strider Boots", "ability": "speed_boots", "desc": "+60 Movement Speed" }
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $InteractPrompt
@onready var sfx_open: AudioStreamPlayer2D = $SFXOpen

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.visible = false
	sprite.frame = 0

func unlock_chest() -> void:
	is_locked = false
	modulate = Color(1.3, 1.3, 0.8, 1.0)
	label.text = "[E] Open Victory Chest"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_open:
		label.visible = true
		if is_locked:
			label.text = "[LOCKED] Defeat the Boss to Open"
		else:
			label.text = "[E] Open Victory Chest"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		if not is_locked and not is_open and label.visible:
			open_chest()

func open_chest() -> void:
	is_open = true
	sprite.frame = 1
	var reward = REWARDS[randi() % REWARDS.size()]
	label.text = "OBTAINED: " + reward["name"] + " (" + reward["desc"] + ")!"
	
	if sfx_open and sfx_open.stream:
		sfx_open.play()
		
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unlock_ability"):
		player.unlock_ability(reward["ability"])
		
	chest_opened.emit(reward)
