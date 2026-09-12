extends CharacterBody2D
class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal player_died()

@export var max_health: int = 100
@export var speed: float = 300.0
@export var jump_velocity: float = -550.0
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.2
@export var attack_damage: int = 25

var current_health: int = 100
var gravity: float = 1400.0

# States
var is_dashing: bool = false
var is_attacking: bool = false
var dash_timer: float = 0.0
var dash_dir: float = 1.0
var facing_dir: float = 1.0
var attack_cooldown: float = 0.0
var invulnerable: bool = false

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sfx_hit: AudioStreamPlayer2D = $SFXHit
@onready var sfx_attack: AudioStreamPlayer2D = $SFXAttack

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	attack_collision.disabled = true

func _physics_process(delta: float) -> void:
	# Handle Dash
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_dir * dash_speed
		velocity.y = 0
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Gaslight Rule: Invert Controls check
	var input_axis = Input.get_axis("move_left", "move_right")
	if GaslightManager.controls_inverted:
		input_axis = -input_axis

	# Facing direction & Sprite flipping
	if input_axis != 0:
		facing_dir = sign(input_axis)
		sprite.flip_h = (facing_dir < 0)
		attack_area.position.x = facing_dir * 32.0

	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not GaslightManager.jump_disabled:
			velocity.y = jump_velocity
			TelemetryManager.record_action("jump")
		else:
			# Boss suppressed jump - slight hop fail effect
			velocity.y = jump_velocity * 0.15

	# Dashing
	if Input.is_action_just_pressed("dash") and not is_dashing:
		_start_dash(facing_dir if input_axis == 0 else sign(input_axis))

	# Horizontal Movement
	if input_axis != 0:
		velocity.x = input_axis * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 4.0 * delta)

	# Attack Handling
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		_perform_attack()

	move_and_slide()

func _start_dash(direction: float) -> void:
	is_dashing = true
	dash_dir = direction
	dash_timer = dash_duration
	if direction < 0:
		TelemetryManager.record_action("dash_left")
	else:
		TelemetryManager.record_action("dash_right")

func _perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 0.35
	attack_collision.disabled = false
	if sfx_attack and sfx_attack.stream:
		sfx_attack.play()
	
	# Check if hit anything after brief activation
	await get_tree().create_timer(0.1).timeout
	attack_collision.disabled = true
	
	# Check if attack hit or whiffed
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	var hit_enemy = false
	for body in overlapping_bodies:
		if body.is_in_group("boss") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			hit_enemy = true
			break
			
	if hit_enemy:
		TelemetryManager.record_action("attack_hit")
	else:
		TelemetryManager.record_action("attack_miss")
	
	is_attacking = false

func take_damage(amount: int) -> void:
	if invulnerable:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	TelemetryManager.record_action("damage_taken", {
		"hp_percent": float(current_health) / float(max_health)
	})
	
	if sfx_hit and sfx_hit.stream:
		sfx_hit.play()
		
	_flash_hit()
	
	if current_health <= 0:
		player_died.emit()

func _flash_hit() -> void:
	invulnerable = true
	sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	invulnerable = false
