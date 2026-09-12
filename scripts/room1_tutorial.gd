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

const ZombieScene = preload("res://scenes/enemies/Zombie.tscn")

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
	super._ready()
	_cycle_prompts()

func _spawn_enemies() -> void:
	for i in range(3):
		var z = ZombieScene.instantiate()
		z.speed = 48.0          # Very slow — let the player feel powerful
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
