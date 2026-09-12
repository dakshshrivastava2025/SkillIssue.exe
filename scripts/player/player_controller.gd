extends CharacterBody2D
class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal player_died()

@export var max_health: int = 100
@export var speed: float = 320.0
@export var jump_velocity: float = -580.0
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.2
@export var attack_damage: int = 25

var current_health: int = 100
var gravity: float = 1400.0

# Movement states
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
@onready var sfx_hit: AudioStreamPlayer2D = $SFXHit
@onready var sfx_attack: AudioStreamPlayer2D = $SFXAttack

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	attack_collision.disabled = true

func _physics_process(delta: float) -> void:
	# Dash Handling
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_dir * dash_speed
		velocity.y = 0
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Pure raw input (A/D or Arrows)
	var input_axis = Input.get_axis("move_left", "move_right")

	# Facing & Sprite flipping
	if input_axis != 0:
		facing_dir = sign(input_axis)
		sprite.flip_h = (facing_dir < 0)
		attack_area.position.x = facing_dir * 32.0

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Dash
	if Input.is_action_just_pressed("dash") and not is_dashing:
		_start_dash(facing_dir if input_axis == 0 else sign(input_axis))

	# Run / Decelerate
	if input_axis != 0:
		velocity.x = input_axis * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 6.0 * delta)

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

func _perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 0.3
	attack_collision.disabled = false
	if sfx_attack and sfx_attack.stream:
		sfx_attack.play()
	
	# Brief active hitbox window
	await get_tree().create_timer(0.12).timeout
	attack_collision.disabled = true
	
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("boss") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			break
			
	is_attacking = false

func take_damage(amount: int) -> void:
	if invulnerable:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if sfx_hit and sfx_hit.stream:
		sfx_hit.play()
		
	_flash_hit()
	
	if current_health <= 0:
		player_died.emit()

func _flash_hit() -> void:
	invulnerable = true
	sprite.modulate = Color(1.5, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	invulnerable = false
