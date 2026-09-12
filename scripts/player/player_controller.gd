extends CharacterBody2D
class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal ability_unlocked(ability_name: String)
signal player_died()

@export var max_health: int = 100
@export var base_speed: float = 240.0
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.25
@export var base_dash_cooldown: float = 0.75
@export var base_attack_damage: int = 25

var current_health: int = 100

# Direction & Animation
enum Direction { DOWN, UP, RIGHT, LEFT }
var current_dir: Direction = Direction.DOWN

var is_dashing: bool = false
var is_attacking: bool = false
var is_moving: bool = false
var is_dead: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var facing_vector: Vector2 = Vector2.DOWN
var attack_cooldown: float = 0.0
var invulnerable: bool = false

# Attack cadence & spam counter
var attack_spam_streak: int = 0
var last_attack_time: float = 0.0
var attack_count: int = 0

# Unlocked Abilities from Chests
var unlocked_abilities = {
	"dash": true,
	"attack_boost": false,
	"health_boost": false,
	"speed_boots": false
}

# Node references
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_sprite: Sprite2D = $AttackArea/AttackSprite
@onready var sfx_hit: AudioStreamPlayer2D = $SFXHit
@onready var sfx_attack: AudioStreamPlayer2D = $SFXAttack

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		Input.action_release("attack")
		Input.action_release("dash")
		is_dashing = false
		velocity = Vector2.ZERO
		is_moving = false

func _ready() -> void:
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)
	attack_collision.disabled = true
	attack_sprite.visible = false
	velocity = Vector2.ZERO
	_play_anim("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if dash_cooldown > 0:
		dash_cooldown -= delta

	# Dash state
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false
			invulnerable = false
			velocity = Vector2.ZERO
		move_and_slide()
		return

	# 100% direct physical hardware keyboard polling - immune to stuck engine action buffers
	var move_x: float = 0.0
	var move_y: float = 0.0

	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_y += 1.0

	var input_vec = Vector2(move_x, move_y)
	var ai = get_node_or_null("/root/AIDirector")
	var can_dash = unlocked_abilities["dash"] and dash_cooldown <= 0 and not is_dashing and not (ai and ai.dash_disabled_active)

	# ZERO movement if no movement keys are physically held
	if input_vec == Vector2.ZERO:
		is_moving = false
		velocity = Vector2.ZERO
		if not is_attacking and not is_dashing:
			_play_anim("idle")
		
		# Dash Trigger while stationary (dashes in facing direction)
		if (Input.is_action_just_pressed("dash") or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_K)) and can_dash:
			_start_dash(facing_vector)
		
		# Primary Attack Trigger
		if attack_cooldown > 0:
			attack_cooldown -= delta
		if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_dashing:
			_perform_attack()
			
		move_and_slide()
		return

	# If keys are actively pressed, handle movement
	is_moving = true
	input_vec = input_vec.normalized()
	facing_vector = input_vec

	var current_speed = base_speed
	if unlocked_abilities["speed_boots"]:
		current_speed += 60.0
	if ai and ai.speed_debuff_active:
		current_speed *= 0.65 # -35% speed penalty

	# Set accurate direction
	if abs(input_vec.x) >= abs(input_vec.y):
		if input_vec.x > 0.05:
			current_dir = Direction.RIGHT
		elif input_vec.x < -0.05:
			current_dir = Direction.LEFT
	else:
		if input_vec.y > 0.05:
			current_dir = Direction.DOWN
		elif input_vec.y < -0.05:
			current_dir = Direction.UP

	# Position attack hitbox precisely in front of facing vector
	attack_area.position = facing_vector * 42.0
	attack_area.rotation = facing_vector.angle()

	velocity = input_vec * current_speed

	# Track retreat habit (moving away from boss)
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and is_moving and ai:
		var to_boss = (boss.global_position - global_position).normalized()
		if velocity.dot(to_boss) < -0.4:
			ai.record_retreat(delta)

	# Reset attack spam streak if player pauses between attacks
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_attack_time > 1.2:
		attack_spam_streak = 0

	# Play walk animation
	if not is_attacking and not is_dashing:
		_play_anim("walk")

	# Dash Trigger while moving
	if (Input.is_action_just_pressed("dash") or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_K)) and can_dash:
		_start_dash(facing_vector if input_vec == Vector2.ZERO else input_vec)

	# Primary Attack Trigger
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_dashing:
		_perform_attack()

	move_and_slide()

func _play_anim(action: String) -> void:
	var dir_suffix = "down"
	var flip = false
	
	match current_dir:
		Direction.DOWN:
			dir_suffix = "down"
			flip = false
		Direction.UP:
			dir_suffix = "up"
			flip = false
		Direction.RIGHT:
			dir_suffix = "right"
			flip = false
		Direction.LEFT:
			dir_suffix = "right"
			flip = true
			
	anim_sprite.flip_h = flip
	var anim_name = action + "_" + dir_suffix
	if anim_sprite.animation != anim_name or not anim_sprite.is_playing():
		anim_sprite.play(anim_name)

func _start_dash(direction: Vector2) -> void:
	is_dashing = true
	invulnerable = true
	dash_cooldown = base_dash_cooldown
	dash_direction = direction
	dash_timer = dash_duration
	_play_anim("dash")
	
	# Record dodge telemetry to AIDirector
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		if abs(direction.x) >= abs(direction.y):
			ai.record_dodge("right" if direction.x > 0 else "left")
		else:
			ai.record_dodge("down" if direction.y > 0 else "up")

func _perform_attack() -> void:
	is_attacking = true
	# Deliberate, impactful attack cooldown: 0.52s between swings (decreased attack speed)
	attack_cooldown = 0.52
	attack_collision.disabled = false
	attack_sprite.visible = true
	
	last_attack_time = Time.get_ticks_msec() / 1000.0
	attack_spam_streak += 1
	attack_count += 1
	
	_play_anim("attack")
	
	if sfx_attack and sfx_attack.stream:
		sfx_attack.play()
	
	await get_tree().create_timer(0.20).timeout
	attack_collision.disabled = true
	attack_sprite.visible = false
	
	var damage = base_attack_damage
	if unlocked_abilities["attack_boost"]:
		damage += 15
		
	var ai = get_node_or_null("/root/AIDirector")
	if ai and ai.damage_debuff_active:
		damage = int(damage * 0.65)
		
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	var hit_enemy = false
	for body in overlapping_bodies:
		if body.is_in_group("boss") and body.has_method("take_damage"):
			body.take_damage(damage)
			hit_enemy = true
			if ai:
				ai.record_attack_hit(damage)
			break
			
	if not hit_enemy and ai:
		# Check if the boss actually dodged this attack
		var boss = get_tree().get_first_node_in_group("boss")
		var was_dodged = false
		if boss and boss.get("last_dodged_attack_id") == attack_count:
			was_dodged = true
		
		# Only record as a whiff/miss if it was NOT a boss reaction dodge!
		if not was_dodged:
			ai.record_attack_miss()
		
	is_attacking = false

func unlock_ability(ability_name: String) -> void:
	unlocked_abilities[ability_name] = true
	match ability_name:
		"attack_boost":
			base_attack_damage += 15
		"health_boost":
			max_health += 50
			current_health = max_health
			health_changed.emit(current_health, max_health)
		"speed_boots":
			base_speed += 60.0
	ability_unlocked.emit(ability_name)

func take_damage(amount: int) -> void:
	if invulnerable:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		ai.record_damage_taken(amount)
	
	if sfx_hit and sfx_hit.stream:
		sfx_hit.play()
		
	_flash_hit()
	
	if current_health <= 0 and not is_dead:
		is_dead = true
		velocity = Vector2.ZERO
		player_died.emit()

func _flash_hit() -> void:
	invulnerable = true
	anim_sprite.modulate = Color(2.0, 0.2, 0.2, 1.0)
	await get_tree().create_timer(0.2).timeout
	anim_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	invulnerable = false
