extends Area2D
class_name TreasureChest

signal chest_opened(room_number: int)

@export var is_locked: bool = true
var is_open: bool = false

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
	modulate = Color(1.2, 1.2, 0.8, 1.0)
	label.text = "[E] Open Victory Chest & Advance"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_open:
		label.visible = true
		if is_locked:
			label.text = "[LOCKED] Defeat the Boss to Open"
		else:
			label.text = "[E] Open Victory Chest & Advance"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		if not is_locked and not is_open and label.visible:
			open_chest()

func open_chest() -> void:
	is_open = true
	sprite.frame = 1 # Open chest frame
	label.text = "PROCEEDING TO NEXT ROOM..."
	if sfx_open and sfx_open.stream:
		sfx_open.play()
	chest_opened.emit()
