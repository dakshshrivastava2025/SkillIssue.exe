extends "res://scripts/room_base.gd"
## Room 1 — Tutorial: "Welcome, Hero"
##
## Scene setup in Godot:
##   Room1_Tutorial (Node2D) ← attach this script
##   ├── PromptLabel (Label)        ← center screen, large font
##   ├── WallsTileMap (TileMapLayer) ← or StaticBody2D walls
##   └── SpawnPoints (Node2D)
##       ├── Point1 (Node2D)  pos ≈ (-200, -150)
##       ├── Point2 (Node2D)  pos ≈ (200, -150)
##       └── Point3 (Node2D)  pos ≈ (0, 200)

@onready var prompt_label: Label = $PromptLabel

const PROMPTS: Array[String] = [
	"WASD — Move",
	"Mouse — Aim",
	"Left Click — Attack",
	"Kill all enemies to continue...",
]

const SPAWN_FALLBACK: Array[Vector2] = [
	Vector2(-220, -140),
	Vector2(220, -140),
	Vector2(0, 190),
]

func _ready() -> void:
	room_name = "Tutorial — Welcome, Hero"
	if prompt_label:
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.position = Vector2(-200, -200)
		prompt_label.size = Vector2(400, 50)
	super._ready()
	_cycle_prompts()

func _get_room_bg_path() -> String:
	return "res://assets/room1_bg.png"

func _get_door_half_open_path() -> String:
	return "res://assets/door_half_open.png"

func _get_door_fully_open_path() -> String:
	return "res://assets/door_fully_open.png"

func _get_door_scale() -> Vector2:
	return Vector2(1.25, 1.25)

func _get_door_position() -> Vector2:
	return Vector2(0, -210)

func _get_zombie_scene() -> PackedScene:
	var paths = ["res://Scenes/enemies/zombie.tscn", "res://scenes/enemies/Zombie.tscn", "res://Scenes/enemies/Zombie.tscn"]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _spawn_enemies() -> void:
	var ZombieScene = _get_zombie_scene()
	if not ZombieScene:
		push_error("[Room1] Zombie.tscn not found!")
		return
	for i in range(3):
		var z = ZombieScene.instantiate()
		z.enemy_type = "goblin"
		z.speed = 48.0
		z.max_health = 20.0
		z.global_position = _spawn_pos(i)
		add_child(z)
		register_enemy(z)

func _apply_director_modifiers() -> void:
	pass  # Tutorial: no Director interference

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _spawn_pos(i: int) -> Vector2:
	var pts = get_node_or_null("SpawnPoints")
	if pts and pts.get_child_count() > i:
		return pts.get_child(i).global_position
	return SPAWN_FALLBACK[i % SPAWN_FALLBACK.size()] + global_position

func _cycle_prompts() -> void:
	if not prompt_label:
		return
	for p in PROMPTS:
		prompt_label.text = p
		await get_tree().create_timer(2.2).timeout
	prompt_label.text = ""
