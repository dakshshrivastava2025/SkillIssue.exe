extends Area2D
## Projectile — Reusable spell / spear / bomb projectile for enemies.

@export var speed: float = 240.0
@export var damage: float = 12.0
@export var lifetime: float = 3.5
@export var projectile_type: String = "magic" # "spear", "bomb", "magic", "fireball"

var direction: Vector2 = Vector2.RIGHT
var _timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(dir: Vector2, spd: float = 240.0, dmg: float = 12.0, ptype: String = "magic") -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	projectile_type = ptype
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func _draw() -> void:
	if projectile_type == "spear":
		# Spear projectile
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.6, 0.4, 0.2), 3.0)
		draw_line(Vector2(6, -4), Vector2(14, 0), Color(0.9, 0.9, 0.9), 2.5)
		draw_line(Vector2(6, 4), Vector2(14, 0), Color(0.9, 0.9, 0.9), 2.5)
	elif projectile_type == "bomb":
		# Glowing dark bomb / flask
		draw_circle(Vector2.ZERO, 7.0, Color(0.2, 0.85, 0.2))
		draw_circle(Vector2(-2, -2), 3.0, Color(0.8, 1.0, 0.4))
	elif projectile_type == "fireball":
		# Flaming fireball
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.35, 0.05, 0.85))
		draw_circle(Vector2(-2, 0), 5.0, Color(1.0, 0.9, 0.2))
	else:
		# Purple dark magic orb
		draw_circle(Vector2.ZERO, 8.0, Color(0.6, 0.1, 0.9, 0.8))
		draw_circle(Vector2.ZERO, 4.0, Color(0.9, 0.5, 1.0))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body.name == "DungeonWalls" or body is StaticBody2D:
		queue_free()
