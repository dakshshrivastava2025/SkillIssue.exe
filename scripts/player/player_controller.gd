extends CharacterBody2D
class_name Player

## Integrated Player Character Controller
## Combines 8-direction movement, sprite frame animations, attack hitbox with visual slash effect,
## dash dodge with invulnerability, health system with flash feedback, ice floor physics,
## ability unlocking, and telemetry tracking with PlayerBehaviorTracker.

signal health_changed(new_health: float, max_health: float)
signal ability_unlocked(ability_name: String)
signal died()
signal player_died()

@export var max_health: float = 100.0
@export var speed: float = 240.0
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.25
@export var attack_damage: float = 25.0
@export var attack_range: float = 65.0

var health: float = 100.0:
	get:
		return _current_hp
	set(value):
		_current_hp = value

var current_health: float:
	get:
		return _current_hp
	set(value):
		_current_hp = value

var _current_hp: float = 100.0

# Direction & Animation
enum Direction { DOWN, UP, RIGHT, LEFT }
var current_dir: Direction = Direction.DOWN

var is_dead: bool = false
var is_dashing: bool = false
var is_attacking: bool = false
var is_moving: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var facing_vector: Vector2 = Vector2.DOWN
var attack_cooldown: float = 0.0
var invulnerable: bool = false

var _is_on_ice: bool = false
var _ice_drift: Vector2 = Vector2.ZERO
var _tracker: Node = null
var invert_controls: bool = false

# Attack cadence & spam counter (used by Boss for reactive dodging)
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
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_collision: CollisionShape2D = get_node_or_null("AttackArea/CollisionShape2D")
@onready var attack_sprite: Sprite2D = get_node_or_null("AttackArea/AttackSprite")
@onready var sfx_hit: AudioStreamPlayer2D = get_node_or_null("SFXHit")
@onready var sfx_attack: AudioStreamPlayer2D = get_node_or_null("SFXAttack")

func _ready() -> void:
	_current_hp = max_health
	health_changed.emit(_current_hp, max_health)
	add_to_group("player")
	z_index = 10

	# Collision settings: Player is layer 2 (and collides with layer 1 walls)
	collision_layer = 2
	collision_mask = 1

	_ensure_components()

	if attack_collision:
		attack_collision.disabled = true
	if attack_sprite:
		attack_sprite.visible = false

	_play_anim("idle")

func reset_state() -> void:
	is_dead = false
	invulnerable = false
	is_dashing = false
	is_attacking = false
	_is_on_ice = false
	_ice_drift = Vector2.ZERO
	attack_cooldown = 0.0
	_current_hp = max_health
	health_changed.emit(_current_hp, max_health)
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE
	else:
		modulate = Color.WHITE
	_play_anim("idle")
	print("[Player] State & Health reset to %.1f/%.1f" % [_current_hp, max_health])

func reset_health() -> void:
	reset_state()

func respawn(spawn_pos: Vector2 = Vector2(0, 150)) -> void:
	position = spawn_pos
	reset_state()

func _ensure_components() -> void:
	if not get_node_or_null("CollisionShape2D"):
		var col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var capsule = CapsuleShape2D.new()
		capsule.radius = 20.0
		capsule.height = 50.0
		col.shape = capsule
		add_child(col)

	# Attach PlayerBehaviorTracker if not present
	var tracker_script = load("res://scripts/player_behavior_tracker.gd")
	if tracker_script and not get_node_or_null("PlayerBehaviorTracker"):
		var tracker = Node.new()
		tracker.name = "PlayerBehaviorTracker"
		tracker.set_script(tracker_script)
		add_child(tracker)
		_tracker = tracker
	elif get_node_or_null("PlayerBehaviorTracker"):
		_tracker = get_node("PlayerBehaviorTracker")

	# Audio defaults
	if sfx_attack and not sfx_attack.stream and ResourceLoader.exists("res://assets/SwordSwoosh.wav"):
		sfx_attack.stream = load("res://assets/SwordSwoosh.wav")
	if sfx_hit and not sfx_hit.stream and ResourceLoader.exists("res://assets/hit_player.wav"):
		sfx_hit.stream = load("res://assets/hit_player.wav")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Dash state
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0.0:
			is_dashing = false
			invulnerable = false
		move_and_slide()
		return

	# Attack cooldown countdown
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# 2D Top-Down 8-directional Input Vector
	var input_vec = _get_input_vector()
	is_moving = (input_vec != Vector2.ZERO)

	if is_moving:
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
		
		# Position attack hitbox precisely in front of facing vector
		if attack_area:
			attack_area.position = facing_vector * 42.0
			attack_area.rotation = facing_vector.angle()
		
		if _is_on_ice:
			# Ice drifting: wide turning arcs and frictionless gliding
			_ice_drift = _ice_drift.lerp(input_vec * speed * 1.12, 0.035)
			velocity = _ice_drift
			_is_on_ice = false
		else:
			_ice_drift = input_vec * speed
			velocity = input_vec * speed
	else:
		if _is_on_ice:
			# Ice slide: prolonged drift when releasing input
			_ice_drift = _ice_drift.lerp(Vector2.ZERO, 0.015)
			velocity = _ice_drift
			_is_on_ice = false
		else:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)
			_ice_drift = Vector2.ZERO

	# Play appropriate animation state if not attacking or dashing
	if not is_attacking and not is_dashing:
		if is_moving:
			_play_anim("walk")
		else:
			_play_anim("idle")

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# Attack Input (Left click, Space, J, Z, or action "attack")
	if event.is_action_pressed("attack"):
		if attack_cooldown <= 0.0 and not is_dashing:
			_perform_attack()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if attack_cooldown <= 0.0 and not is_dashing:
			_perform_attack()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_J or event.keycode == KEY_Z or event.keycode == KEY_SPACE) and attack_cooldown <= 0.0 and not is_dashing:
			_perform_attack()
		elif (event.keycode == KEY_SHIFT or event.keycode == KEY_C or event.keycode == KEY_K) and not is_dashing and unlocked_abilities.get("dash", true):
			var in_vec = _get_input_vector()
			_start_dash(facing_vector if in_vec == Vector2.ZERO else in_vec)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not is_dashing and unlocked_abilities.get("dash", true):
			var in_vec = _get_input_vector()
			_start_dash(facing_vector if in_vec == Vector2.ZERO else in_vec)

func _get_input_vector() -> Vector2:
	var dir = Vector2.ZERO
	# Check mapped actions first
	if Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		dir.x += 1.0
	if Input.is_action_pressed("move_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		dir.y += 1.0

	# Direct key fallbacks
	if dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0

	if invert_controls:
		dir = -dir

	return dir.normalized()

func _play_anim(action: String) -> void:
	if not anim_sprite:
		return
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
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name or not anim_sprite.is_playing():
			anim_sprite.play(anim_name)

func _start_dash(direction: Vector2) -> void:
	is_dashing = true
	invulnerable = true
	dash_direction = direction.normalized()
	dash_timer = dash_duration
	_play_anim("dash")

	# Notify AI Director Tracker
	if _tracker and _tracker.has_method("on_dodge"):
		_tracker.on_dodge(dash_direction)

func _perform_attack() -> void:
	is_attacking = true
	attack_cooldown = 0.30

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_attack_time > 1.2:
		attack_spam_streak = 0
	last_attack_time = now
	attack_spam_streak += 1
	attack_count += 1

	# Notify AI Director Tracker
	if _tracker and _tracker.has_method("on_attack"):
		_tracker.on_attack()
	var ai = get_node_or_null("/root/AIDirector")
	if ai and ai.has_method("record_attack"):
		ai.record_attack()

	if attack_collision:
		attack_collision.disabled = false
	if attack_sprite:
		attack_sprite.visible = true
	
	_play_anim("attack")
	
	if sfx_attack and sfx_attack.stream:
		sfx_attack.play()
	
	# Visual attack effect duration
	get_tree().create_timer(0.18).timeout.connect(func():
		if attack_collision:
			attack_collision.disabled = true
		if attack_sprite:
			attack_sprite.visible = false
		is_attacking = false
	)
	
	# Hit detection: Area2D overlap check + directional range fallback
	var hit_targets = []
	if attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body != self and body not in hit_targets and (body.is_in_group("enemy") or body.is_in_group("boss")):
				hit_targets.append(body)
		for area in attack_area.get_overlapping_areas():
			var parent = area.get_parent()
			if parent and parent != self and parent not in hit_targets and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
				hit_targets.append(parent)

	# Also scan enemies within attack_range in front of player
	var aim_dir = facing_vector.normalized()
	for enemy in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(enemy) and enemy != self and enemy not in hit_targets:
			var to_enemy = enemy.global_position - global_position
			var dist = to_enemy.length()
			if dist <= attack_range:
				if dist < 30.0 or aim_dir.dot(to_enemy.normalized()) > 0.15:
					hit_targets.append(enemy)

	for target in hit_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(attack_damage)
			print("[Player] Hit %s for %.1f damage!" % [target.name, attack_damage])

## Called by IceZone in Room 2 & Room 4
func apply_ice_effect(friction: float) -> void:
	_is_on_ice = true
	_ice_drift = _ice_drift * friction

func unlock_ability(ability_name: String) -> void:
	unlocked_abilities[ability_name] = true
	match ability_name:
		"attack_boost":
			attack_damage += 15.0
		"health_boost":
			max_health += 50.0
			_current_hp = max_health
			health_changed.emit(_current_hp, max_health)
		"speed_boots":
			speed += 60.0
	ability_unlocked.emit(ability_name)

func take_damage(amount: float) -> void:
	if invulnerable or is_dead or _current_hp <= 0.0:
		return
	_current_hp = max(0.0, _current_hp - amount)
	health_changed.emit(_current_hp, max_health)
	print("[Player] Took %.1f damage! HP: %.1f/%.1f" % [amount, _current_hp, max_health])
	
	if sfx_hit and sfx_hit.stream:
		sfx_hit.play()
		
	_flash_hit()
	
	if _current_hp <= 0.0:
		is_dead = true
		died.emit()
		player_died.emit()
		print("[Player] Player died! Press R to restart.")

func _flash_hit() -> void:
	invulnerable = true
	if anim_sprite:
		anim_sprite.modulate = Color(2.0, 0.2, 0.2, 1.0)
	else:
		modulate = Color(2.0, 0.2, 0.2, 1.0)

	await get_tree().create_timer(0.2).timeout

	if anim_sprite:
		anim_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	invulnerable = false
