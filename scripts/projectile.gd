extends Area2D
class_name Projectile

## Projectile — Used by ranged enemies (Dark Cultist / Witch / Wizard / Goblin Spear).
## Moves in a straight direction, damages the player on impact, and despawns on walls.

var direction: Vector2 = Vector2.DOWN
var speed: float = 230.0
var damage: float = 12.0
var projectile_type: String = "magic" # "magic", "bomb", "spear"

var _lifetime: float = 3.5
var _sfx_hit: AudioStreamPlayer2D = null

func setup(dir: Vector2, spd: float, dmg: float, ptype: String = "magic") -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	projectile_type = ptype
	rotation = direction.angle()

func _ready() -> void:
	# Layer 4 (projectile), Mask 3 (Layer 1 = walls, Layer 2 = player)
	collision_layer = 4
	collision_mask = 3
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	_build_visuals_and_collision()
	
	# Load hit sound if available
	if ResourceLoader.exists("res://assets/hit_00.wav"):
		_sfx_hit = AudioStreamPlayer2D.new()
		_sfx_hit.stream = load("res://assets/hit_00.wav")
		_sfx_hit.volume_db = -4.0
		add_child(_sfx_hit)

func _build_visuals_and_collision() -> void:
	# 1. Collision shape
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	col.shape = circle
	add_child(col)

	# 2. Glowing visual core & aura
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Outer glow
	var glow = ColorRect.new()
	glow.name = "Glow"
	glow.size = Vector2(16, 16)
	glow.position = Vector2(-8, -8)
	if projectile_type == "magic" or projectile_type == "bomb":
		glow.color = Color(0.85, 0.2, 0.95, 0.6) # Arcane Purple Glow
	else:
		glow.color = Color(1.0, 0.6, 0.2, 0.6) # Fire/Spear Amber Glow
	visual.add_child(glow)

	# Inner core
	var core = ColorRect.new()
	core.name = "Core"
	core.size = Vector2(8, 8)
	core.position = Vector2(-4, -4)
	core.color = Color(1.0, 1.0, 1.0, 0.95) # Bright white core
	visual.add_child(core)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Don't hit enemies who fired or friendly mobs
	if body.is_in_group("enemy") or body.is_in_group("boss"):
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("[Projectile] Witch magic hit player for %.1f damage!" % damage)
		if _sfx_hit and is_instance_valid(_sfx_hit):
			_sfx_hit.play()
		_destroy()
		return

	# Collided with dungeon wall
	if body is StaticBody2D or body.name.begins_with("Dungeon") or body.name.begins_with("Arena"):
		_destroy()

func _on_area_entered(_area: Area2D) -> void:
	pass

func _destroy() -> void:
	# Small fade out
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()
