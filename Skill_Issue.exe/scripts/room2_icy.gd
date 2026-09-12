extends "res://scripts/room_base.gd"
## Room 2 — Icy Floor: "Something Is Wrong"
##
## Scene setup in Godot:
##   Room2_IcyFloor (Node2D) ← attach this script
##   ├── WarningLabel (Label)     ← center screen
##   ├── IceZone (Area2D)         ← covers ~half the floor; CollisionShape2D inside
##   │   └── CollisionShape2D     ← RectangleShape covering ice area
##   └── SpawnPoints (Node2D)
##       ├── Point1..4 (Node2D)
##
## The ice effect: when the player is on the IceZone, their velocity carries
## extra momentum (the player script needs apply_ice_effect() or we handle it here).

@onready var warning_label: Label   = $WarningLabel
@onready var ice_zone: Area2D       = $IceZone

var _player_on_ice: bool  = false
var _player_ref: CharacterBody2D = null
# Ice drift carries previous velocity
var _ice_velocity: Vector2 = Vector2.ZERO
const ICE_FRICTION: float  = 0.92   # lower = more slippery
const ICE_TINT: Color      = Color(0.6, 0.85, 1.0, 0.35)

const SPAWN_FALLBACK: Array[Vector2] = [
	Vector2(-240, -100), Vector2(240, -100),
	Vector2(-200, 80),   Vector2(200, 80),
	Vector2(0, -80),     Vector2(0, 100),
]

func _ready() -> void:
	room_name = "Room 2 — Slippery Floor"
	_player_ref = get_tree().get_first_node_in_group("player")
	if warning_label:
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.position = Vector2(-200, -220)
		warning_label.size = Vector2(400, 50)
	super._ready()
	_show_warning()
	_connect_ice_zone()

func _get_theme_floor_color() -> Color:
	return Color(0.06, 0.14, 0.22) # Icy blue floor tint

func _get_room_bg_path() -> String:
	return "res://assets/room2_bg.png"

func _get_wall_colliders() -> Array[Rect2]:
	return [
		# North wall with central doorway arch
		Rect2(-330, -280, 520, 70), # North-Left wall
		Rect2(330, -280, 520, 70),  # North-Right wall
		# South wall with central doorway arch
		Rect2(-330, 310, 520, 70),  # South-Left wall
		Rect2(330, 310, 520, 70),   # South-Right wall
		# West & East walls with archway tunnels
		Rect2(-560, -180, 60, 240), # West-Top wall
		Rect2(-560, 180, 60, 240),  # West-Bottom wall
		Rect2(560, -180, 60, 240),  # East-Top wall
		Rect2(560, 180, 60, 240),   # East-Bottom wall
	]

func _physics_process(_delta: float) -> void:
	if _player_on_ice and _player_ref and _player_ref.has_method("apply_ice_effect"):
		_player_ref.apply_ice_effect(ICE_FRICTION)

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
	var count = randi_range(3, 6)
	var pool = ["res://assets/skeleton.png", "res://assets/goblin_spear.png", "res://assets/skeleton_knight.png"]
	for i in range(count):
		var z = ZombieScene.instantiate()
		z.speed = randf_range(65.0, 85.0)
		z.texture_path = pool[randi() % pool.size()]
		z.global_position = _spawn_pos(i)
		add_child(z)
		register_enemy(z)

func _apply_director_modifiers() -> void:
	pass  # Room 2: scripted difficulty only, no Director yet

# ---------------------------------------------------------------------------
# Ice zone
# ---------------------------------------------------------------------------

func _connect_ice_zone() -> void:
	if not ice_zone:
		push_warning("[Room2] IceZone Area2D not found — ice effect disabled.")
		return
	ice_zone.body_entered.connect(_on_ice_entered)
	ice_zone.body_exited.connect(_on_ice_exited)

func _on_ice_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_ice = true
		print("[Room2] Player entered ice zone!")

func _on_ice_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_ice = false
		print("[Room2] Player left ice zone.")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _show_warning() -> void:
	if not warning_label:
		return
	warning_label.text = "⚠️  SLIPPERY FLOOR"
	await get_tree().create_timer(3.5).timeout
	if warning_label:
		warning_label.text = ""

func _spawn_pos(i: int) -> Vector2:
	var pts = get_node_or_null("SpawnPoints")
	if pts and pts.get_child_count() > i:
		return pts.get_child(i).position
	return SPAWN_FALLBACK[i % SPAWN_FALLBACK.size()]
