extends CharacterBody2D
class_name BossController

signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated()

@export var max_health: int = 400
@export var base_speed: float = 130.0

var current_health: int = 400
var player_target: Node2D = null

enum State { IDLE, CHASE, TELEGRAPH, ATTACK_BEAM, RETREAT }
var current_state: State = State.IDLE
var state_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_beam_area: Area2D = $BeamArea
@onready var beam_collision: CollisionShape2D = $BeamArea/CollisionShape2D
@onready var beam_sprite: Sprite2D = $BeamArea/BeamSprite
@onready var sfx_beam: AudioStreamPlayer2D = $SFXBeam
@onready var sfx_hurt: AudioStreamPlayer2D = $SFXBossHurt

func _ready() -> void:
	add_to_group("boss")
	current_health = max_health
	boss_health_changed.emit(current_health, max_health)
	beam_collision.disabled = true
	beam_sprite.visible = false
	_set_state(State.IDLE, 1.0)

func _physics_process(delta: float) -> void:
	if not player_target:
		player_target = get_tree().get_first_node_in_group("player")
		
	state_timer -= delta
	
	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
			if state_timer <= 0:
				_pick_next_action()
				
		State.CHASE:
			if player_target:
				var dir = (player_target.global_position - global_position).normalized()
				velocity = dir * base_speed
				
				# Point beam attack towards player
				attack_beam_area.rotation = dir.angle()
				
				# If within range, prepare attack
				if global_position.distance_to(player_target.global_position) < 220.0:
					_set_state(State.TELEGRAPH, 0.5)
			if state_timer <= 0:
				_set_state(State.TELEGRAPH, 0.5)
				
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			sprite.modulate = Color(2.5, 0.3, 0.3, 1.0)
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_attack()
				
		State.ATTACK_BEAM:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				beam_collision.disabled = true
				beam_sprite.visible = false
				_set_state(State.RETREAT, 1.2)
				
		State.RETREAT:
			if player_target:
				var away_dir = (global_position - player_target.global_position).normalized()
				velocity = away_dir * (base_speed * 1.3)
			if state_timer <= 0:
				_set_state(State.IDLE, 0.8)

	move_and_slide()

func _pick_next_action() -> void:
	_set_state(State.CHASE, 2.5)

func _execute_attack() -> void:
	_set_state(State.ATTACK_BEAM, 0.45)
	beam_collision.disabled = false
	beam_sprite.visible = true
	
	if sfx_beam and sfx_beam.stream:
		sfx_beam.play()
		
	await get_tree().create_timer(0.12).timeout
	var overlapping = attack_beam_area.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(25)

func _set_state(new_state: State, duration: float) -> void:
	current_state = new_state
	state_timer = duration

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	boss_health_changed.emit(current_health, max_health)
	
	if sfx_hurt and sfx_hurt.stream:
		sfx_hurt.play()
		
	sprite.modulate = Color(2.0, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if current_health <= 0:
		boss_defeated.emit()
		queue_free()
