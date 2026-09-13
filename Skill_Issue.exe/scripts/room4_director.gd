extends "res://scripts/room_base.gd"
## Room 4 — The Director Room: "The Dungeon Learns"
##
## This is the WOW room. The AI Director is fully active.
## On-screen messages reveal what the dungeon "noticed" about the player.
## The room reacts dynamically to Director signals during combat.
##
## Scene setup:
##   Room4_Director (Node2D) ← attach this script
##   ├── DirectorLabel (Label)    ← large, atmospheric label (center-ish)
##   ├── IceZone (Area2D)         ← starts disabled; enabled if player retreats
##   │   └── CollisionShape2D
##   └── SpawnPoints (Node2D)
##       └── Point1..4 (Node2D)

@onready var director_label: Label = $DirectorLabel
@onready var ice_zone: Area2D      = $IceZone

var _player_ref: Node = null
var _player_on_ice: bool    = false
var _wave_spawned: bool     = false   # Prevent double aggressive wave
var _ice_enabled: bool      = false

const SPAWN_FALLBACK: Array[Vector2] = [
	Vector2(-200, -80), Vector2(200, -80),
	Vector2(-180, 80),  Vector2(180, 80),
]

func _ready() -> void:
	room_name = "Room 4 — The Dungeon Learns"
	_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref and "invert_controls" in _player_ref:
		_player_ref.invert_controls = true
		print("[Room4] Player controls inverted!")
	if director_label:
		director_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		director_label.position = Vector2(-250, -220)
		director_label.size = Vector2(500, 60)
	super._ready()
	_connect_director_signals()
	_setup_ice_zone()
	tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	if _player_ref and is_instance_valid(_player_ref) and "invert_controls" in _player_ref:
		_player_ref.invert_controls = false
		print("[Room4] Player controls restored.")

func _get_theme_floor_color() -> Color:
	return Color(0.12, 0.06, 0.18) # Dark AI Director purple floor tint

func _get_room_bg_path() -> String:
	return "res://assets/room4_bg.png"

func _get_wall_colliders() -> Array[Rect2]:
	return [
		# Outer perimeter walls
		Rect2(0, -280, 1100, 70),  # Top wall
		Rect2(0, 310, 1100, 70),   # Bottom wall
		Rect2(-540, 0, 70, 680),   # Left curved wall
		Rect2(540, 0, 70, 680),    # Right curved wall
		# 4 Flame Pillar pedestals
		Rect2(-270, -110, 70, 80), # Top-Left Pillar
		Rect2(270, -110, 70, 80),  # Top-Right Pillar
		Rect2(-270, 190, 70, 80),  # Bottom-Left Pillar
		Rect2(270, 190, 70, 80),   # Bottom-Right Pillar
	]

func _physics_process(_delta: float) -> void:
	if _player_on_ice and _player_ref and _player_ref.has_method("apply_ice_effect"):
		_player_ref.apply_ice_effect(0.90)   # Slippier than Room 2

# ---------------------------------------------------------------------------
# Room lifecycle
# ---------------------------------------------------------------------------

func _spawn_enemies() -> void:
	for i in range(3):
		_spawn_zombie(_spawn_pos(i), 88.0)

func _apply_director_modifiers() -> void:
	await get_tree().create_timer(0.5).timeout
	_show_director_message("The dungeon is watching...", 3.0)

# ---------------------------------------------------------------------------
# Director signal handlers
# ---------------------------------------------------------------------------

func _connect_director_signals() -> void:
	AIDirector.player_is_aggressive.connect(_on_aggressive)
	AIDirector.player_is_retreater.connect(_on_retreater)
	AIDirector.player_dodge_pattern_detected.connect(_on_dodge_pattern)
	AIDirector.attack_rhythm_detected.connect(_on_rhythm)

func _on_aggressive() -> void:
	if _wave_spawned:
		return
	_wave_spawned = true
	await _show_director_message(
		"\"Player is aggressive.\"\nSpawning more enemies...", 3.0)
	for i in range(4):
		await get_tree().create_timer(0.45).timeout
		_spawn_zombie(Vector2(randf_range(-250, 250), randf_range(-180, 180)) + global_position, 95.0)

func _on_retreater() -> void:
	await _show_director_message(
		"\"Player relies on movement.\"\nIntroducing obstacles...", 3.0)
	_enable_ice()

func _on_dodge_pattern(direction: String) -> void:
	await _show_director_message(
		"\"Player prefers %s dodges.\"\nEnemies repositioning..." % direction, 3.0)
	# Spawn an enemy anticipating that dodge direction
	var offset_map: Dictionary = {
		"left": Vector2(-160, 0), "right": Vector2(160, 0),
		"up":   Vector2(0, -160), "down":  Vector2(0, 160),
	}
	var off: Vector2 = offset_map.get(direction, Vector2.ZERO)
	if _player_ref:
		_spawn_zombie(_player_ref.global_position + off, 100.0)

func _on_rhythm() -> void:
	await _show_director_message(
		"\"Player has a predictable attack pattern.\"\nEnemies adapting...", 3.0)
	# Boost all living enemy speeds slightly to break the pattern
	for e in get_tree().get_nodes_in_group("enemy"):
		if "speed_multiplier" in e:
			e.speed_multiplier = minf(e.speed_multiplier + 0.4, 2.0)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_zombie_scene() -> PackedScene:
	var paths = ["res://Scenes/enemies/zombie.tscn", "res://scenes/enemies/Zombie.tscn", "res://Scenes/enemies/Zombie.tscn"]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _spawn_zombie(pos: Vector2, spd: float = 88.0) -> void:
	var ZombieScene = _get_zombie_scene()
	if not ZombieScene:
		return
	var z = ZombieScene.instantiate()
	z.enemy_type = "dark_cultist" if randf() < 0.5 else "dark_wizard"
	z.is_ranged = true
	z.speed = spd
	z.position = pos
	add_child(z)
	register_enemy(z)

func _setup_ice_zone() -> void:
	if not ice_zone:
		return
	ice_zone.monitoring = false
	ice_zone.visible    = false
	ice_zone.body_entered.connect(_on_ice_entered)
	ice_zone.body_exited.connect(_on_ice_exited)

func _enable_ice() -> void:
	if _ice_enabled or not ice_zone:
		return
	_ice_enabled = true
	ice_zone.monitoring = true
	ice_zone.visible    = true
	print("[Room4] Ice zone activated by Director.")

func _on_ice_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_ice = true

func _on_ice_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_on_ice = false

## Shows a message on DirectorLabel and awaits its duration. Returns after duration.
func _show_director_message(text: String, duration: float) -> Signal:
	if director_label:
		director_label.text = text
	print("[Room4] ▶ %s" % text.replace("\n", " "))
	return get_tree().create_timer(duration).timeout

func _spawn_pos(i: int) -> Vector2:
	var pts = get_node_or_null("SpawnPoints")
	if pts and pts.get_child_count() > i:
		return pts.get_child(i).position
	return SPAWN_FALLBACK[i % SPAWN_FALLBACK.size()]
