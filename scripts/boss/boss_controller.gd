extends CharacterBody2D
class_name BossController

signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated()

@export var max_health: int = 700
@export var base_speed: float = 220.0

var current_health: int = 700
var player_target: CharacterBody2D = null

enum State { CHASE, TELEGRAPH_THIN, ATTACK_THIN, CHARGE_MEGA, ATTACK_MEGA, TELEGRAPH_MELEE, ATTACK_MELEE, DODGE_ROLL, RETREAT }
var current_state: State = State.CHASE
var state_timer: float = 0.0

# Smart combat parameters
var dodge_cooldown: float = 0.0
var mega_beam_cooldown: float = 5.0
var melee_cooldown: float = 0.0
var distance_from_player: float = 0.0
var locked_aim_direction: Vector2 = Vector2.RIGHT
var has_dealt_damage_this_attack: bool = false
var last_reacted_attack_count: int = 0
var last_dodged_attack_id: int = 0

# Node references
@onready var sprite: Sprite2D = $Sprite2D

@onready var melee_area: Area2D = $MeleeArea
@onready var melee_collision: CollisionShape2D = $MeleeArea/CollisionShape2D

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
	
	if melee_collision:
		melee_collision.disabled = true
	thin_beam_collision.disabled = true
	thin_beam_sprite.visible = false
	charged_beam_collision.disabled = true
	charged_beam_sprite.visible = false
	
	_set_state(State.CHASE, 1.2)


func _physics_process(delta: float) -> void:
	if not player_target:
		player_target = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	state_timer -= delta
	if dodge_cooldown > 0:
		dodge_cooldown -= delta
	if mega_beam_cooldown > 0:
		mega_beam_cooldown -= delta
	if melee_cooldown > 0:
		melee_cooldown -= delta
	
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
		
		# Exact Single-Roll Dodge Tiers per attack swing:
		# 1st attack: 45%
		# 2nd consecutive attack: 60%
		# 3rd+ consecutive attack (spam): 80%
		var current_player_attack_count = player_target.get("attack_count")
		if current_player_attack_count != null and current_player_attack_count > last_reacted_attack_count:
			last_reacted_attack_count = current_player_attack_count
			
			if distance_from_player < 140.0 and current_state != State.DODGE_ROLL and dodge_cooldown <= 0:
				var spam_count = player_target.get("attack_spam_streak")
				var dodge_chance = 0.45
				if spam_count == 2:
					dodge_chance = 0.60
				elif spam_count >= 3:
					dodge_chance = 0.80
					
				if randf() < dodge_chance:
					_perform_dodge_reaction(current_player_attack_count)
				else:
					dodge_cooldown = 0.8 # Window before next dodge on hit

	match current_state:
		State.CHASE:
			if player_target:
				var dir = (player_target.global_position - global_position).normalized()
				velocity = dir * active_speed
				
				# Smart 3-tier range engagement:
				# 1. Close-range melee burst if player is hugging boss (with cooldown & clear windup)
				if distance_from_player < 95.0 and melee_cooldown <= 0 and state_timer <= 0:
					_start_melee_telegraph()
				# 2. Long-range devastating mega-beam if player is camping/far away
				elif distance_from_player > 400.0 and mega_beam_cooldown <= 0:
					_start_mega_beam()
				# 3. Mid-range thin beam strike
				elif distance_from_player < 260.0 and state_timer <= 0:
					_start_thin_telegraph()
			else:
				velocity = Vector2.ZERO

		State.TELEGRAPH_MELEE:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			sprite.modulate = Color(3.5, 1.2, 0.2, 1.0) # Fiery orange melee charge
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_melee_attack()

		State.ATTACK_MELEE:
			velocity = Vector2.ZERO
			if not has_dealt_damage_this_attack:
				_check_single_damage_hit(melee_area, 35) # 35 DMG close strike
			if state_timer <= 0:
				melee_collision.disabled = true
				_set_state(State.RETREAT, 0.50) # Generous 0.50s retreat window to counter-attack

		State.TELEGRAPH_THIN:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			sprite.modulate = Color(3.0, 0.2, 0.2, 1.0)
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_thin_beam()
				
		State.CHARGE_MEGA:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			sprite.modulate = Color(1.2, 0.2, 3.5, 1.0)
			if state_timer <= 0:
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_execute_mega_beam()

		State.DODGE_ROLL:
			# Recovery after dodge: gives player room to react/re-engage
			if state_timer <= 0:
				_set_state(State.CHASE, 0.5)
				
		State.ATTACK_THIN:
			velocity = Vector2.ZERO
			if not has_dealt_damage_this_attack:
				_check_single_damage_hit(thin_beam_area, 25)
			if state_timer <= 0:
				thin_beam_collision.disabled = true
				thin_beam_sprite.visible = false
				_set_state(State.RETREAT, 0.45) # 0.45s retreat window

		State.ATTACK_MEGA:
			velocity = Vector2.ZERO
			if not has_dealt_damage_this_attack:
				_check_single_damage_hit(charged_beam_area, 50)
			if state_timer <= 0:
				charged_beam_collision.disabled = true
				charged_beam_sprite.visible = false
				_set_state(State.RETREAT, 0.6)
				
		State.RETREAT:
			if player_target:
				var away_dir = (global_position - player_target.global_position).normalized()
				velocity = away_dir * (active_speed * 1.1)
			if state_timer <= 0:
				_set_state(State.CHASE, 0.6) # 0.6s pause before boss can initiate next attack

	move_and_slide()

func _start_melee_telegraph() -> void:
	melee_cooldown = 4.0 # 4.0s cooldown so he can't spam melee
	if player_target:
		locked_aim_direction = (player_target.global_position - global_position).normalized()
		sprite.flip_h = (locked_aim_direction.x < 0)
	_set_state(State.TELEGRAPH_MELEE, 0.52) # Clear, readable 0.52s windup

func _execute_melee_attack() -> void:
	has_dealt_damage_this_attack = false
	_set_state(State.ATTACK_MELEE, 0.20)
	melee_collision.disabled = false
	
	if sfx_beam and sfx_beam.stream:
		sfx_beam.play()
		
	_check_single_damage_hit(melee_area, 35)

func _start_thin_telegraph() -> void:
	if player_target:
		locked_aim_direction = (player_target.global_position - global_position).normalized()
		thin_beam_area.rotation = locked_aim_direction.angle()
		sprite.flip_h = (locked_aim_direction.x < 0)
	_set_state(State.TELEGRAPH_THIN, 0.40) # 0.40s readable telegraph (gives player time to dodge!)

func _start_mega_beam() -> void:
	mega_beam_cooldown = 6.0 # 6.0s cooldown between mega beams
	if player_target:
		locked_aim_direction = (player_target.global_position - global_position).normalized()
		charged_beam_area.rotation = locked_aim_direction.angle()
		sprite.flip_h = (locked_aim_direction.x < 0)
	_set_state(State.CHARGE_MEGA, 0.90) # 0.90s visible purple charge


func _perform_dodge_reaction(attack_id: int = 0) -> void:
	last_dodged_attack_id = attack_id
	dodge_cooldown = 2.0
	var away = (global_position - player_target.global_position).normalized()
	var side_dodge = Vector2(-away.y, away.x) * (1.0 if randf() > 0.5 else -1.0)
	var dodge_vector = (away + side_dodge).normalized()
	velocity = dodge_vector * 520.0
	
	sprite.modulate = Color(2.0, 2.0, 0.5, 1.0)
	_set_state(State.DODGE_ROLL, 0.18)
	
	await get_tree().create_timer(0.18).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _execute_thin_beam() -> void:
	has_dealt_damage_this_attack = false
	_set_state(State.ATTACK_THIN, 0.28)
	thin_beam_collision.disabled = false
	thin_beam_sprite.visible = true
	
	if sfx_beam and sfx_beam.stream:
		sfx_beam.play()
		
	_check_single_damage_hit(thin_beam_area, 25)

func _execute_mega_beam() -> void:
	has_dealt_damage_this_attack = false
	_set_state(State.ATTACK_MEGA, 0.42)
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
	
	# Strict safety cleanup: guarantee beam visuals/colliders are disabled when not in attack state
	if new_state != State.ATTACK_THIN:
		thin_beam_collision.disabled = true
		thin_beam_sprite.visible = false
	if new_state != State.ATTACK_MEGA:
		charged_beam_collision.disabled = true
		charged_beam_sprite.visible = false
	if new_state != State.ATTACK_MELEE and melee_collision:
		melee_collision.disabled = true

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	boss_health_changed.emit(current_health, max_health)
	
	if sfx_hurt and sfx_hurt.stream:
		sfx_hurt.play()
		
	# If boss is winding up melee, getting hit staggers his windup
	if current_state == State.TELEGRAPH_MELEE:
		state_timer += 0.15 # Brief hit-flinch window
		
	sprite.modulate = Color(2.5, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.12).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if current_health <= 0:
		boss_defeated.emit()
		queue_free()

