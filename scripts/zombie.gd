extends CharacterBody2D
## Zombie — Standard enemy.
##
## Properties:
##   speed            — base movement speed
##   speed_multiplier — Director can increase this
##   max_health       — hit points
##   is_ranged        — if true, stops and fires at player instead of charging
##   damage           — damage dealt on melee contact

signal died

@export var max_health: float    = 30.0
@export var speed: float         = 80.0
@export var speed_multiplier: float = 1.0
@export var damage: float        = 10.0
@export var is_ranged: bool      = false
@export var ranged_range: float  = 220.0
@export var ranged_cooldown: float = 2.2

var health: float = 0.0

var _target: Node2D = null
var _ranged_timer: float = 0.0

# Placeholder visual (Polygon2D square — art goes here later)
var _poly: Polygon2D = null

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	# Find player
	_target = get_tree().get_first_node_in_group("player")

	# Temporary visual: draw a red square
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14),
		Vector2(14, 14),   Vector2(-14, 14)
	])
	_poly.color = Color(0.85, 0.15, 0.15)
	add_child(_poly)

	# Collision shape
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	col.shape = rect
	add_child(col)

func _physics_process(delta: float) -> void:
	if not _target:
		_target = get_tree().get_first_node_in_group("player")
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

	if is_ranged and dist < ranged_range:
		velocity = Vector2.ZERO
		_ranged_timer -= delta
		if _ranged_timer <= 0.0:
			_fire_ranged()
			_ranged_timer = ranged_cooldown
	else:
		velocity = to_target.normalized() * speed * speed_multiplier

	move_and_slide()

func _fire_ranged() -> void:
	if _target and _target.has_method("take_damage"):
		_target.take_damage(damage * 0.6)
	print("[Zombie] Ranged shot!")

## Called when player touches this zombie (connect from Area2D or use body_entered).
func on_player_contact(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

## Receive damage from player attacks.
func take_damage(amount: float) -> void:
	health -= amount
	# Flash white briefly
	if _poly:
		_poly.color = Color.WHITE
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(_poly):
			_poly.color = Color(0.85, 0.15, 0.15)
	print("[Zombie] %.0f dmg → HP %.0f/%.0f" % [amount, health, max_health])
	if health <= 0.0:
		_die()

func _die() -> void:
	AIDirector.record_kill()
	emit_signal("died")
	queue_free()
