extends Area2D
class_name TreasureChest

signal chest_opened(reward: Dictionary)

@export var room_number: int = 1
@export var is_locked: bool = true
var is_open: bool = false

# Custom room-specific buff configuration
const ROOM_BUFFS = {
	1: {
		"name": "Gladiator's Whetstone",
		"ability": "strength_buff",
		"desc": "+12 Attack Damage",
		"message": "⚔️ STRENGTH BUFF ACQUIRED: +12 Attack Damage!"
	},
	2: {
		"name": "Frostbite Aegis",
		"ability": "resistance_buff",
		"desc": "+35% Damage Resistance",
		"message": "🛡️ RESISTANCE BUFF ACQUIRED: Take 35% less damage from all attacks!"
	},
	3: {
		"name": "Windstrider Boots",
		"ability": "speed_boots",
		"desc": "+50 Movement Speed & +8 Damage",
		"message": "⚡ AGILITY BUFF ACQUIRED: +50 Movement Speed & +8 Damage!"
	},
	4: {
		"name": "Titan's Heart",
		"ability": "health_and_resistance",
		"desc": "+50 Max HP, Full Heal & +15% Resistance",
		"message": "💖 VITALITY BUFF ACQUIRED: +50 Max HP, Full Heal & +15% Resistance!"
	},
	5: {
		"name": "Crown of the Dungeon Conqueror",
		"ability": "victory",
		"desc": "Ultimate Victory Reward",
		"message": "👑 VICTORY: You have conquered the Dungeon and defeated the Dark Wizard!"
	}
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $InteractPrompt
@onready var sfx_open: AudioStreamPlayer2D = $SFXOpen

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if label:
		label.visible = false
	if sprite:
		sprite.frame = 0
		
	# Subtle idle breathing shine
	if is_locked:
		modulate = Color(0.85, 0.85, 0.9, 1.0)

var _player_overlapping: bool = false

func unlock_chest() -> void:
	is_locked = false
	# Golden glowing pulse
	var tw = create_tween()
	tw.set_loops(3)
	tw.tween_property(self, "modulate", Color(2.0, 1.8, 0.8, 1.0), 0.3)
	tw.tween_property(self, "modulate", Color(1.3, 1.2, 0.9, 1.0), 0.3)
	
	if label and label.visible:
		label.text = "[E] Open Victory Chest (Buff Inside!)"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_open:
		_player_overlapping = true
		if label:
			label.visible = true
			if is_locked:
				label.text = "[LOCKED] Clear all enemies to unlock"
			else:
				label.text = "[E] Open Victory Chest (Buff Inside!)"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_overlapping = false
		if label:
			label.visible = false

func _process(_delta: float) -> void:
	if _player_overlapping and not is_locked and not is_open:
		if Input.is_key_pressed(KEY_E) or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			open_chest()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		if not is_locked and not is_open and label and label.visible:
			open_chest()

func open_chest() -> void:
	if is_open:
		return
	is_open = true
	
	if sprite:
		sprite.frame = 1
	modulate = Color(1.1, 1.1, 1.1, 1.0)
	
	var reward = ROOM_BUFFS.get(room_number, ROOM_BUFFS[1])
	if label:
		label.text = "OBTAINED: %s (%s)!" % [reward["name"], reward["desc"]]
	
	if sfx_open and sfx_open.stream:
		sfx_open.play()
		
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("unlock_ability"):
		player.unlock_ability(reward["ability"])
		
	# Trigger HUD intervention toast notification
	var ai = get_node_or_null("/root/AIDirector")
	if ai and ai.has_signal("director_intervention_triggered"):
		ai.director_intervention_triggered.emit("buff", reward["message"])
		
	print("[TreasureChest] Room %d Chest opened! Reward: %s" % [room_number, reward["name"]])
	chest_opened.emit(reward)
