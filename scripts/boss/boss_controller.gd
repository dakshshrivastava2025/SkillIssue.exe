extends CharacterBody2D
class_name BossController

signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated()

@export var max_health: int = 700
@export var base_speed: float = 190.0

var current_health: int = 700
var player_target: CharacterBody2D = null

enum State { CHASE, TELEGRAPH_THIN, ATTACK_THIN, CHARGE_MEGA, ATTACK_MEGA, DODGE_ROLL, RETREAT }
var current_state: State = State.CHASE
var state_timer: float = 0.0

# Smart combat parameters
var dodge_cooldown: float = 0.0
var mega_beam_cooldown: float = 7.0
var distance_from_player: float = 0.0
var locked_aim_direction: Vector2 = Vector2.RIGHT
var has_dealt_damage_this_attack: bool = false

# Node references
@onready var sprite: Sprite2D = $Sprite2D

@onready var thin_beam_area: Area2D = $ThinBeamArea
@onready var thin_beam_collision: CollisionShape2D = $ThinBeamArea/CollisionShape2D
@onready var thin_beam_sprite: Sprite2D = $ThinBeamArea/ThinBeamSprite

@onready var charged_beam_area: Area2D = $ChargedBeamArea
@onready var charged_beam_collision: CollisionShape2D = $ChargedBeamArea/CollisionShape2D
@onready var charged_beam_sprite: Sprite2D = $ChargedBeamArea/ChargedBeamSprite

@onready var sfx_beam: AudioStreamPlayer2D = $SFXBeam
@onready var sfx_hurt: AudioStreamPlayer2D = $SFXBossHurt

func _ready() -> void:
	add_to_group("boss")
	current_health = max_health
	boss_health_changed.emit(current_health, max_health)
	
	thin_beam_collision.disabled = true
	thin_beam_sprite.visible = false
	charged_beam_collision.disabled = true
	charged_beam_sprite.visible = false
	
	_set_state(State.CHASE, 2.0)

func _physics_process(delta: float) -> void:
	if not player_target:
		player_target = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	state_timer -= delta
	if dodge_cooldown > 0:
		dodge_cooldown -= delta
	if mega_beam_cooldown > 0:
		mega_beam_cooldown -= delta
	
	var active_speed = base_speed
	if current_health < max_health * 0.4:
		active_speed *= 1.3
	
	if player_target:
		distance_from_player = global_position.distance_to(player_target.global_position)
		var live_dir = (player_target.global_position - global_position).normalized()
		
		# In CHASE mode, actively track player
		if current_state == State.CHASE:
			locked_aim_direction = live_dir
			thin_beam_area.rotation = live_dir.angle()
			charged_beam_area.rotation = live_dir.angle()
			sprite.flip_h = (live_dir.x < 0)
		
		# 35% chance to dodge player melee attacks
		if player_target.is_attacking and dodge_cooldown <= 0:
			if distance_from_player < 130.0 and current_state != State.DODGE_ROLL:
				if randf() < 0.35:
					_perform_dodge_reaction()
				else:
					dodge_cooldown = 1.5

	match current_state:
		State.CHASE:
			if player_target:
				var dir = (player_target.global_position - global_position).normalized()
				velocity = dir * active_speed
				
				# If player is far away, prepare devastating mega beam
				if distance_from_player > 420.0 and mega_beam_cooldown <= 0:
					_start_mega_beam()
				# If closed in within strike range, unleash thin beam
				elif distance_from_player < 240.0 and state_timer <= 0:
					_start_thin_telegraph()
			else:
				velocity = Vector2.ZERO

		State.TELEGRAPH_THIN:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			sprite.modulate = Color(3.0, 0.2, 0.2, 1.0)
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_thin_beam()
				
		State.CHARGE_MEGA:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			sprite.modulate = Color(1.2, 0.2, 3.5, 1.0)
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_mega_beam()

		State.DODGE_ROLL:
			if state_timer <= 0:
				_set_state(State.CHASE, 1.2)
				
		State.ATTACK_THIN:
			velocity = Vector2.ZERO
			if not has_dealt_damage_this_attack:
				_check_single_damage_hit(thin_beam_area, 25) # Restored to full 25 DMG
			if state_timer <= 0:
				thin_beam_collision.disabled = true
				thin_beam_sprite.visible = false
				_set_state(State.RETREAT, 0.7)

		State.ATTACK_MEGA:
			velocity = Vector2.ZERO
			if not has_dealt_damage_this_attack:
				_check_single_damage_hit(charged_beam_area, 50) # Heavy 50 DMG punish
			if state_timer <= 0:
				charged_beam_collision.disabled = true
				charged_beam_sprite.visible = false
				_set_state(State.RETREAT, 1.0)
				
		State.RETREAT:
			if player_target:
				var away_dir = (global_position - player_target.global_position).normalized()
				velocity = away_dir * (active_speed * 1.2)
			if state_timer <= 0:
				_set_state(State.CHASE, 2.0)

	move_and_slide()

func _start_thin_telegraph() -> void:
	if player_target:
		locked_aim_direction = (player_target.global_position - global_position).normalized()
		thin_beam_area.rotation = locked_aim_direction.angle()
	_set_state(State.TELEGRAPH_THIN, 0.45)

func _start_mega_beam() -> void:
	mega_beam_cooldown = 7.0
	if player_target:
		locked_aim_direction = (player_target.global_position - global_position).normalized()
		charged_beam_area.rotation = locked_aim_direction.angle()
	_set_state(State.CHARGE_MEGA, 1.0)

func _perform_dodge_reaction() -> void:
	dodge_cooldown = 3.0
	var away = (global_position - player_target.global_position).normalized()
	var side_dodge = Vector2(-away.y, away.x) * (1.0 if randf() > 0.5 else -1.0)
	var dodge_vector = (away + side_dodge).normalized()
	velocity = dodge_vector * 520.0
	
	sprite.modulate = Color(2.0, 2.0, 0.5, 1.0)
	_set_state(State.DODGE_ROLL, 0.22)
	
	await get_tree().create_timer(0.22).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _execute_thin_beam() -> void:
	has_dealt_damage_this_attack = false
	_set_state(State.ATTACK_THIN, 0.35)
	thin_beam_collision.disabled = false
	thin_beam_sprite.visible = true
	
	if sfx_beam and sfx_beam.stream:
		sfx_beam.play()
		
	_check_single_damage_hit(thin_beam_area, 25)

func _execute_mega_beam() -> void:
	has_dealt_damage_this_attack = false
	_set_state(State.ATTACK_MEGA, 0.5)
	charged_beam_collision.disabled = false
	charged_beam_sprite.visible = true
	
	if sfx_beam and sfx_beam.stream:
		sfx_beam.play()
		
	_check_single_damage_hit(charged_beam_area, 50)

func _check_single_damage_hit(area: Area2D, dmg: int) -> void:
	if has_dealt_damage_this_attack:
		return
	var overlapping = area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(dmg)
			has_dealt_damage_this_attack = true
			break

func _set_state(new_state: State, duration: float) -> void:
	current_state = new_state
	state_timer = duration

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	boss_health_changed.emit(current_health, max_health)
	
	if sfx_hurt and sfx_hurt.stream:
		sfx_hurt.play()
		
	sprite.modulate = Color(2.5, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.12).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if current_health <= 0:
		boss_defeated.emit()
		queue_free()
