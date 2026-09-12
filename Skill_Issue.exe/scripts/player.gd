extends CharacterBody2D
## Player — Top-down player character controller.
##
## Features:
##   - Smooth 8-direction WASD / Arrow movement
##   - Clean visual player dot & direction indicator
##   - Melee attack (Left Click / J / Space)
##   - Dodge / Dash (Shift / Right Click)
##   - Ice floor sliding support
##   - Integrates with PlayerBehaviorTracker for AI Director analysis

signal health_changed(new_health: float, max_health: float)
signal died

@export var speed: float = 210.0
@export var max_health: float = 100.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 65.0
@export var dash_speed: float = 480.0
@export var dash_duration: float = 0.18

var health: float = 100.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _ice_drift: Vector2 = Vector2.ZERO
var _is_on_ice: bool = false
var _facing_direction: Vector2 = Vector2.DOWN

var _tracker: Node = null
var _attack_cooldown: float = 0.0

func _ready() -> void:
	health = max_health
	add_to_group("player")
	z_index = 10
	queue_redraw()

	# Player only collides with walls (layer 1), not enemy bodies (layer 2)
	collision_layer = 1
	collision_mask = 1

	if not get_node_or_null("CollisionShape2D"):
		var col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var circle = CircleShape2D.new()
		circle.radius = 14.0
		col.shape = circle
		add_child(col)

	# Attach PlayerBehaviorTracker if not present
	var tracker_script = load("res://scripts/player_behavior_tracker.gd")
	if tracker_script and not get_node_or_null("PlayerBehaviorTracker"):
		var tracker = Node.new()
		tracker.name = "PlayerBehaviorTracker"
		tracker.set_script(tracker_script)
		add_child(tracker)
		_tracker = tracker

func _draw() -> void:
	# 1. Outer subtle aura ring
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.8, 1.0, 0.25))
	# 2. Main player dot body (vibrant cyan core)
	draw_circle(Vector2.ZERO, 12.0, Color(0.1, 0.85, 0.95))
	# 3. Inner highlight
	draw_circle(Vector2(-3, -3), 4.0, Color(1.0, 1.0, 1.0, 0.8))
	# 4. Facing / Aim indicator pointer
	var aim_dir = _facing_direction.normalized()
	var ptr_end = aim_dir * 18.0
	draw_line(Vector2.ZERO, ptr_end, Color(1.0, 0.95, 0.3), 3.0)
	draw_circle(ptr_end, 3.5, Color(1.0, 0.95, 0.3))

func _physics_process(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	var input_dir: Vector2 = _get_input_vector()

	if input_dir.length_squared() > 0.01:
		_facing_direction = input_dir.normalized()

	# Always redraw so cyan dot + pointer stays visible in all rooms
	queue_redraw()

	# Aim toward mouse in world space
	var mouse_world = get_global_mouse_position()
	var to_mouse = mouse_world - global_position
	if to_mouse.length_squared() > 4.0:
		_facing_direction = to_mouse.normalized()

	# Handle Dash / Dodge
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_direction * dash_speed
		if _dash_timer <= 0.0:
			_is_dashing = false
	else:
		if _is_on_ice:
			_ice_drift = _ice_drift.lerp(input_dir * speed, 0.08)
			velocity = _ice_drift
			_is_on_ice = false
		else:
			_ice_drift = input_dir * speed
			velocity = input_dir * speed

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Attack Input (Left click or Space or J)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_perform_attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J or event.keycode == KEY_Z:
			_perform_attack()
		elif event.keycode == KEY_SHIFT or event.keycode == KEY_C:
			_perform_dodge()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_perform_dodge()

func _get_input_vector() -> Vector2:
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir.normalized()

func _perform_attack() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = 0.28

	# Notify Tracker
	if _tracker and _tracker.has_method("on_attack"):
		_tracker.on_attack()

	# Visual attack feedback: small flash
	modulate = Color(1.5, 1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

	# Check hits against nearby enemies
	var aim_dir = _facing_direction.normalized()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		# Hit if within range and roughly in front
		if dist <= attack_range:
			if dist < 25.0 or aim_dir.dot(to_enemy.normalized()) > 0.15:
				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)
				print("[Player] Hit %s for %.1f damage!" % [enemy.name, attack_damage])

func _perform_dodge() -> void:
	if _is_dashing:
		return
	var input_dir = _get_input_vector()
	var dodge_dir = input_dir if input_dir != Vector2.ZERO else _facing_direction
	_dash_direction = dodge_dir.normalized()
	_is_dashing = true
	_dash_timer = dash_duration

	# Notify Tracker
	if _tracker and _tracker.has_method("on_dodge"):
		_tracker.on_dodge(_dash_direction)
	print("[Player] Dodged towards %s" % _dash_direction)

## Called by IceZone in Room 2 & Room 4
func apply_ice_effect(friction: float) -> void:
	_is_on_ice = true
	_ice_drift = _ice_drift * friction

func take_damage(amount: float) -> void:
	health -= amount
	emit_signal("health_changed", health, max_health)
	print("[Player] Took %.1f damage! HP: %.1f/%.1f" % [amount, health, max_health])
	
	# Red damage flash
	modulate = Color(1.0, 0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

	if health <= 0.0:
		emit_signal("died")
		print("[Player] Player died!")
