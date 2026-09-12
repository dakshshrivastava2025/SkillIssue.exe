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
	Vector2(-200, -100), Vector2(200, -100),
	Vector2(-220, 60),   Vector2(220, 60),
	Vector2(-120, -40),  Vector2(120, -40),
	Vector2(0, -100),
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

func _get_room_foreground_path() -> String:
	return "res://assets/room3_foreground.png"

func _get_wall_colliders() -> Array[Rect2]:
	return [
		# Outer octagon perimeter stone walls
		Rect2(0, -320, 1200, 60),  # Top wall
		Rect2(0, 320, 1200, 60),   # Bottom wall
		Rect2(-590, 0, 60, 720),   # Left wall
		Rect2(590, 0, 60, 720),    # Right wall
		# Inner Iron Cage Fence (Pillars & Bars with gate opening in center)
		Rect2(-240, -180, 240, 30), # Top-Left iron fence
		Rect2(240, -180, 240, 30),  # Top-Right iron fence
		Rect2(-360, 0, 30, 280),    # West iron cage bars
		Rect2(360, 0, 30, 280),     # East iron cage bars
		Rect2(-220, 190, 220, 30),  # Bottom-Left iron fence
		Rect2(220, 190, 220, 30),   # Bottom-Right iron fence
	]

func _get_zombie_scene() -> PackedScene:
	var paths = ["res://Scenes/enemies/zombie.tscn", "res://scenes/enemies/Zombie.tscn", "res://Scenes/enemies/Zombie.tscn"]
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
		return pts.get_child(i).position
	return SPAWN_FALLBACK[i % SPAWN_FALLBACK.size()]
