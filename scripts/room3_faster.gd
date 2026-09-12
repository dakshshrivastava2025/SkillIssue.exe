extends "res://scripts/room_base.gd"
## Room 3 — Faster Enemies: "Combat"
##
## First room where AIDirector data influences the spawn.
## If the player is already aggressive → 2 extra enemies spawn.
##
## Scene setup:
##   Room3_FasterEnemies (Node2D) ← attach this script
##   ├── NoticeLabel (Label)   ← subtle Director hint label
##   └── SpawnPoints (Node2D)
##       └── Point1..6 (Node2D)

const ZombieScene = preload("res://scenes/enemies/Zombie.tscn")

@onready var notice_label: Label = $NoticeLabel

const BASE_SPEED: float    = 108.0
const SPEED_MULT: float    = 1.55
const BASE_COUNT: int      = 4
const EXTRA_COUNT: int     = 2   # Added if player is aggressive

const SPAWN_FALLBACK: Array[Vector2] = [
	Vector2(-220, -160), Vector2(0, -160), Vector2(220, -160),
	Vector2(-220, 160),  Vector2(0, 160),  Vector2(220, 160),
]

func _ready() -> void:
	room_name = "Room 3 — Faster Enemies"
	super._ready()

func _spawn_enemies() -> void:
	var count: int = BASE_COUNT
	if AIDirector.is_aggressive:
		count += EXTRA_COUNT
	for i in range(count):
		var z = ZombieScene.instantiate()
		z.speed = BASE_SPEED
		z.speed_multiplier = SPEED_MULT
		z.global_position = _spawn_pos(i)
		add_child(z)
		register_enemy(z)

func _apply_director_modifiers() -> void:
	if AIDirector.is_aggressive:
		print("[Room3] Director: Player is aggressive → %d extra enemies" % EXTRA_COUNT)
		_show_notice("The dungeon noticed your aggression...", 3.5)
	else:
		_show_notice("These ones move faster.", 2.5)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _show_notice(text: String, duration: float) -> void:
	if not notice_label:
		return
	notice_label.text = text
	await get_tree().create_timer(duration).timeout
	if notice_label:
		notice_label.text = ""

func _spawn_pos(i: int) -> Vector2:
	var pts = get_node_or_null("SpawnPoints")
	if pts and pts.get_child_count() > i:
		return pts.get_child(i).global_position
	return SPAWN_FALLBACK[i % SPAWN_FALLBACK.size()] + global_position
