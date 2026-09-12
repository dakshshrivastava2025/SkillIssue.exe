extends CharacterBody2D
## GargoyleStatue — Dormant corner stone trap. Awakens into an animated flying demon.

signal died

@export var max_health: float = 50.0
@export var speed: float = 90.0
@export var damage: float = 22.0
@export var attack_range: float = 55.0
@export var attack_cooldown: float = 1.6

var health: float = 0.0
var is_awakened: bool = false
var _target: Node2D = null
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _attack_anim_timer: float = 0.0
var _facing_dir: String = "down"

var _anim_sprite: AnimatedSprite2D = null
var _fallback_sprite: Sprite2D = null
var _knockback: Vector2 = Vector2.ZERO

const CELL_SIZE: float = 96.0

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("statue")
	_target = get_tree().get_first_node_in_group("player")
	collision_layer = 2
	collision_mask = 1

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	col.shape = circle
	add_child(col)

	var sheet_path = "res://assets/gargoyle_clean_grid.png"
	if ResourceLoader.exists(sheet_path):
		var tex = load(sheet_path) as Texture2D
		if tex:
			_anim_sprite = AnimatedSprite2D.new()
			_anim_sprite.name = "GargoyleAnim"
			_anim_sprite.sprite_frames = _make_frames(tex)
			_anim_sprite.scale = Vector2(0.55, 0.55)
			# Stone grey tint when dormant
			_anim_sprite.modulate = Color(0.65, 0.68, 0.72)
			_anim_sprite.play("idle_down")
			add_child(_anim_sprite)
			return

	# Fallback
	_fallback_sprite = Sprite2D.new()
	_fallback_sprite.name = "GargoyleFallback"
	if ResourceLoader.exists("res://assets/gargoyle.png"):
		var ftex = load("res://assets/gargoyle.png") as Texture2D
		if ftex:
			_fallback_sprite.texture = ftex
			_fallback_sprite.scale = Vector2(0.5, 0.5)
	_fallback_sprite.modulate = Color(0.65, 0.68, 0.72)
	add_child(_fallback_sprite)

func _make_frames(tex: Texture2D) -> SpriteFrames:
	var sf = SpriteFrames.new()
	var defs = {
		"idle_down":   [0, 0, 3, 3.0, true],
		"idle_side":   [0, 3, 3, 3.0, true],
		"idle_up":     [0, 0, 3, 3.0, true],
		"walk_down":   [1, 0, 6, 8.0, true],
		"walk_side":   [1, 2, 5, 8.0, true],
		"walk_up":     [1, 0, 6, 8.0, true],
		"attack_down": [2, 0, 6, 10.0, false],
		"attack_side": [2, 0, 6, 10.0, false],
		"attack_up":   [2, 0, 6, 10.0, false],
	}

	for anim in defs:
		sf.add_animation(anim)
		var d = defs[anim]
		sf.set_animation_speed(anim, d[3])
		sf.set_animation_loop(anim, d[4])
		var row = d[0]
		var start_col = d[1]
		var count = d[2]
		for c in range(start_col, start_col + count):
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			sf.add_frame(anim, atlas)
	return sf

func awaken() -> void:
	if is_awakened:
		return
	is_awakened = true
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.play("walk_down")
	elif _fallback_sprite:
		_fallback_sprite.modulate = Color(1.0, 0.35, 0.35)
	print("[GargoyleStatue] ⚠️ AWAKENED!")

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _knockback.length_squared() > 1.0:
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 9.0)

	if not is_awakened:
		return

	if not _target or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		if not _target:
			return

	var to_target = _target.global_position - global_position
	var dist = to_target.length()

	if _is_attacking:
		_attack_anim_timer -= delta
		velocity = _knockback * 0.3
		move_and_slide()
		if _attack_anim_timer <= 0.0:
			_is_attacking = false
			_play_anim("idle")
		return

	var sep = _separation_vector()

	if dist < attack_range:
		_update_facing(to_target)
		velocity = _knockback + sep * 40.0
		if _attack_timer <= 0.0:
			_perform_attack(to_target)
		else:
			_play_anim("idle")
	else:
		var move_dir = (to_target.normalized() + sep * 0.7).normalized()
		velocity = move_dir * speed + _knockback
		_update_facing(move_dir)
		_play_anim("walk")

	move_and_slide()

func _update_facing(dir: Vector2) -> void:
	if abs(dir.y) > abs(dir.x) * 0.75:
		_facing_dir = "down" if dir.y > 0 else "up"
	else:
		_facing_dir = "side"
		if _anim_sprite:
			_anim_sprite.flip_h = dir.x < 0
		elif _fallback_sprite:
			_fallback_sprite.flip_h = dir.x < 0

func _play_anim(action: String) -> void:
	if not _anim_sprite:
		return
	var anim = "%s_%s" % [action, _facing_dir]
	if _anim_sprite.sprite_frames.has_animation(anim):
		if _anim_sprite.animation != anim:
			_anim_sprite.play(anim)
	else:
		var fb = "%s_down" % action
		if _anim_sprite.sprite_frames.has_animation(fb) and _anim_sprite.animation != fb:
			_anim_sprite.play(fb)

func _perform_attack(to_target: Vector2) -> void:
	_is_attacking = true
	_attack_anim_timer = 0.45
	_attack_timer = attack_cooldown
	_play_anim("attack")
	var aim = to_target.normalized()
	velocity = aim * 130.0
	if _target and _target.has_method("take_damage"):
		_target.take_damage(damage)
		if "velocity" in _target:
			_target.velocity += aim * 180.0

func _separation_vector() -> Vector2:
	var force = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n):
			continue
		var diff = global_position - n.global_position
		var d = diff.length()
		if d > 0.01 and d < 38.0:
			force += diff.normalized() * (1.0 - d / 38.0)
	return force

func take_damage(amount: float) -> void:
	if not is_awakened:
		awaken()
	health -= amount
	if _target and is_instance_valid(_target):
		_knockback = (global_position - _target.global_position).normalized() * 180.0
	var spr = _anim_sprite if _anim_sprite else _fallback_sprite
	if spr:
		spr.modulate = Color(2.0, 0.4, 0.4)
		var tw = create_tween()
		tw.tween_property(spr, "modulate", Color.WHITE, 0.14)
	if health <= 0.0:
		_die()

func _die() -> void:
	AIDirector.record_kill()
	emit_signal("died")
	queue_free()
