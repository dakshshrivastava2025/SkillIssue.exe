extends CharacterBody2D
class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal ability_unlocked(ability_name: String)
signal player_died()

@export var max_health: int = 100
@export var speed: float = 240.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.18
@export var attack_damage: int = 25

var current_health: int = 100

# Direction & Animation States
# Row 0: Idle/Walk (Down=0-3, Up=4-7, Right=8-11, Left=12-15)
enum Direction { DOWN, UP, RIGHT, LEFT }
var current_dir: Direction = Direction.DOWN

var is_dashing: bool = false
var is_attacking: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var facing_vector: Vector2 = Vector2.DOWN
var attack_cooldown: float = 0.0
var invulnerable: bool = false

# Unlocked Abilities from Chests
var unlocked_abilities = {
	"dash": true,
	"fireball": false,
	"spin_slash": false,
	"shield": false
}

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_sprite: Sprite2D = $AttackArea/AttackSprite
@onready var sfx_hit: AudioStreamPlayer2D = $SFXHit
@onready var sfx_attack: AudioStreamPlayer2D = $SFXAttack

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	attack_collision.disabled = true
	attack_sprite.visible = false
	_update_sprite_direction()

func _physics_process(delta: float) -> void:
	# Dash state
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	# 2D Top-Down 8-directional Input Vector
	var input_vec = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if input_vec != Vector2.ZERO:
		input_vec = input_vec.normalized()
		facing_vector = input_vec
		
		# Set accurate direction
		if abs(input_vec.x) >= abs(input_vec.y):
			if input_vec.x > 0:
				current_dir = Direction.RIGHT
			else:
				current_dir = Direction.LEFT
		else:
			if input_vec.y > 0:
				current_dir = Direction.DOWN
			else:
				current_dir = Direction.UP
				
		_update_sprite_direction()
		
		# Position attack hitbox precisely in front of facing vector
		attack_area.position = facing_vector * 42.0
		attack_area.rotation = facing_vector.angle()
		
		velocity = input_vec * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)

	# Dash Trigger
	if Input.is_action_just_pressed("dash") and not is_dashing and unlocked_abilities["dash"]:
		_start_dash(facing_vector if input_vec == Vector2.ZERO else input_vec)

	# Primary Attack Trigger
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_dashing:
		_perform_attack()

	move_and_slide()

func _update_sprite_direction() -> void:
	match current_dir:
		Direction.DOWN:
			sprite.frame = 0
			sprite.flip_h = false
		Direction.UP:
			sprite.frame = 4
			sprite.flip_h = false
		Direction.RIGHT:
			sprite.frame = 8
			sprite.flip_h = false
		Direction.LEFT:
			sprite.frame = 12
			sprite.flip_h = false

func _start_dash(direction: Vector2) -> void:
	is_dashing = true
	dash_direction = direction
	dash_timer = dash_duration

func _perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 0.28
	attack_collision.disabled = false
	attack_sprite.visible = true
	
	if sfx_attack and sfx_attack.stream:
		sfx_attack.play()
	
	await get_tree().create_timer(0.12).timeout
	attack_collision.disabled = true
	attack_sprite.visible = false
	
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("boss") and body.has_method("take_damage"):
			body.take_damage(attack_damage)
			break
			
	is_attacking = false

func unlock_ability(ability_name: String) -> void:
	unlocked_abilities[ability_name] = true
	match ability_name:
		"attack_boost":
			attack_damage += 15
		"health_boost":
			max_health += 50
			current_health = max_health
			health_changed.emit(current_health, max_health)
		"speed_boots":
			speed += 60.0
	ability_unlocked.emit(ability_name)

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
	sprite.modulate = Color(2.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	invulnerable = false
