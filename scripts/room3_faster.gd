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
	if notice_label:
		notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice_label.position = Vector2(-200, -220)
		notice_label.size = Vector2(400, 50)
	super._ready()

func _get_theme_floor_color() -> Color:
	return Color(0.18, 0.08, 0.08) # Crimson tint for high danger

func _get_room_bg_path() -> String:
	return "res://assets/room3_bg.png"

func _get_door_half_open_path() -> String:
	return "res://assets/room3_door_half_open.png"

func _get_door_fully_open_path() -> String:
	return "res://assets/room3_door_fully_open.png"

func _get_door_scale() -> Vector2:
	return Vector2(1.0, 1.0)

func _get_door_position() -> Vector2:
	return Vector2(0, -266)

func _get_zombie_scene() -> PackedScene:
	var paths = ["res://scenes/enemies/zombie.tscn", "res://Scenes/enemies/zombie.tscn"]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _spawn_enemies() -> void:
	var ZombieScene = _get_zombie_scene()
	if not ZombieScene:
		return
	var count: int = randi_range(4, 7)
	if AIDirector.is_aggressive:
		count += EXTRA_COUNT
	var types = ["armored_skeleton", "skeleton", "goblin"]
	for i in range(count):
		var z = ZombieScene.instantiate()
		z.enemy_type = types[randi() % types.size()]
		z.speed = BASE_SPEED * randf_range(1.0, 1.3)
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

func _get_room_foreground_path() -> String:
	return "res://assets/room3_foreground.png"

func _get_wall_colliders() -> Array[Rect2]:
	return [
		# === PRECISE OCTAGONAL STEP COLLIDERS ALONG FENCE BARS ===
		# Top horizontal fence line
		Rect2(0, -210, 460, 40),
		# Bottom horizontal fence line
		Rect2(0,  220, 460, 40),
		# Left vertical fence line
		Rect2(-420, 0,  40, 120),
		# Right vertical fence line
		Rect2( 420, 0,  40, 120),

		# Top-Right diagonal fence steps
		Rect2( 240, -180, 40, 40), Rect2( 290, -145, 40, 40),
		Rect2( 340, -110, 40, 40), Rect2( 380,  -75, 40, 40),

		# Top-Left diagonal fence steps
		Rect2(-240, -180, 40, 40), Rect2(-290, -145, 40, 40),
		Rect2(-340, -110, 40, 40), Rect2(-380,  -75, 40, 40),

		# Bottom-Right diagonal fence steps
		Rect2( 240,  190, 40, 40), Rect2( 290,  155, 40, 40),
		Rect2( 340,  120, 40, 40), Rect2( 380,   85, 40, 40),

		# Bottom-Left diagonal fence steps
		Rect2(-240,  190, 40, 40), Rect2(-290,  155, 40, 40),
		Rect2(-340,  120, 40, 40), Rect2(-380,   85, 40, 40),
	]

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
