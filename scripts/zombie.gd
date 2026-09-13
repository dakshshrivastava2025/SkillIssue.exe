extends CharacterBody2D
## Enemy — Top-down dungeon enemy with clean 96x96 sprite sheet animations, directional movement, attacks & separation.

signal died

@export var enemy_type: String = "goblin"
@export var max_health: float = 30.0
@export var speed: float = 85.0
@export var speed_multiplier: float = 1.0
@export var damage: float = 12.0
@export var is_ranged: bool = false
@export var ranged_range: float = 230.0
@export var ranged_cooldown: float = 2.2
@export var melee_range: float = 52.0
@export var melee_cooldown: float = 1.2
@export var texture_path: String = ""
## Delay in seconds between the attack animation starting and damage actually landing.
## Gives the player a visual cue to react. Set to 0.0 for instant attacks.
@export var attack_startup_delay: float = 0.3

var health: float = 0.0
var _target: Node2D = null
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _attack_anim_timer: float = 0.0
var _facing_dir: String = "down" # "down", "side", "up"

var _anim_sprite: AnimatedSprite2D = null
var _single_sprite: Sprite2D = null
var _knockback: Vector2 = Vector2.ZERO
var _hp_bar_fill: ColorRect = null

const CELL_SIZE: float = 96.0

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	_target = get_tree().get_first_node_in_group("player")
	_resolve_enemy_type()
	_setup_visuals()
	_setup_health_bar()

	collision_layer = 2
	collision_mask = 1
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	add_child(col)

func _resolve_enemy_type() -> void:
	if texture_path == "":
		return
	if "skeleton_knight" in texture_path or "armored" in texture_path:
		enemy_type = "armored_skeleton"
	elif "skeleton" in texture_path:
		enemy_type = "skeleton"
	elif "cultist" in texture_path:
		enemy_type = "dark_cultist"
		is_ranged = true
	elif "wizard" in texture_path:
		enemy_type = "dark_wizard"
		is_ranged = true
	elif "gargoyle" in texture_path:
		enemy_type = "gargoyle"
	elif "goblin" in texture_path:
		enemy_type = "goblin"

func _setup_visuals() -> void:
	var clean_sheet = "res://assets/%s_clean_grid.png" % enemy_type
	if not ResourceLoader.exists(clean_sheet):
		clean_sheet = "res://assets/goblin_clean_grid.png"

	if ResourceLoader.exists(clean_sheet):
		var tex = load(clean_sheet) as Texture2D
		if tex:
			_anim_sprite = AnimatedSprite2D.new()
			_anim_sprite.name = "EnemyAnim"
			_anim_sprite.sprite_frames = _build_sprite_frames(tex)
			# Scale 96px cell down to ~48px in-game character height
			_anim_sprite.scale = Vector2(0.52, 0.52)
			_anim_sprite.play("idle_down")
			add_child(_anim_sprite)
			return

	# Fallback
	_single_sprite = Sprite2D.new()
	var ftex = load(texture_path) if texture_path != "" and ResourceLoader.exists(texture_path) else null
	if ftex:
		_single_sprite.texture = ftex
		_single_sprite.scale = Vector2(0.5, 0.5)
	add_child(_single_sprite)

func _build_sprite_frames(tex: Texture2D) -> SpriteFrames:
	var sf = SpriteFrames.new()
	var total_w = tex.get_width()
	var total_h = tex.get_height()
	var cols = int(total_w / CELL_SIZE)
	var rows = int(total_h / CELL_SIZE)

	# Build animations according to enemy type grid layout
	var anim_map = _get_anim_defs(enemy_type, cols, rows)
	for anim_name in anim_map:
		sf.add_animation(anim_name)
		var cfg = anim_map[anim_name]
		var r = cfg[0]
		var start_c = cfg[1]
		var count = cfg[2]
		var fps = cfg[3]
		var loop = cfg[4]
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)

		if r < rows:
			for c in range(start_c, min(start_c + count, cols)):
				var atlas = AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(c * CELL_SIZE, r * CELL_SIZE, CELL_SIZE, CELL_SIZE)
				sf.add_frame(anim_name, atlas)
	return sf

func _get_anim_defs(type: String, cols: int, rows: int) -> Dictionary:
	# [row, start_col, num_frames, fps, loop]
	match type:
		"skeleton":
			return {
				"idle_down":   [0, 0, 4, 4.0, true],
				"idle_side":   [1, 0, 4, 4.0, true],
				"idle_up":     [2, 0, 4, 4.0, true],
				"walk_down":   [3, 0, 6, 8.0, true],
				"walk_side":   [4, 0, 6, 8.0, true],
				"walk_up":     [5, 0, 6, 8.0, true],
				"attack_down": [0, 4, min(cols - 4, 6), 10.0, false],
				"attack_side": [1, 4, min(cols - 4, 6), 10.0, false],
				"attack_up":   [2, 4, min(cols - 4, 6), 10.0, false],
			}
		"armored_skeleton":
			return {
				"idle_down":   [0, 0, 4, 4.0, true],
				"idle_side":   [2, 0, 3, 4.0, true],
				"idle_up":     [3, 0, 3, 4.0, true],
				"walk_down":   [1, 0, 6, 8.0, true],
				"walk_side":   [2, 3, 5, 8.0, true],
				"walk_up":     [3, 3, 5, 8.0, true],
				"attack_down": [4, 0, 6, 10.0, false],
				"attack_side": [4, 0, 6, 10.0, false],
				"attack_up":   [5, 0, 6, 10.0, false],
			}
		"dark_cultist":
			return {
				"idle_down":   [0, 0, 4, 4.0, true],
				"idle_side":   [1, 0, 4, 4.0, true],
				"idle_up":     [3, 0, 4, 4.0, true],
				"walk_down":   [0, 0, 6, 8.0, true],
				"walk_side":   [1, 0, 6, 8.0, true],
				"walk_up":     [3, 0, 6, 8.0, true],
				"attack_down": [0, 6, 4, 9.0, false],
				"attack_side": [1, 6, 4, 9.0, false],
				"attack_up":   [2, 6, 4, 9.0, false],
			}
		"dark_wizard":
			return {
				"idle_down":   [0, 0, 4, 4.0, true],
				"idle_side":   [1, 0, 4, 4.0, true],
				"idle_up":     [2, 0, 4, 4.0, true],
				"walk_down":   [0, 0, 6, 8.0, true],
				"walk_side":   [1, 0, 6, 8.0, true],
				"walk_up":     [2, 0, 6, 8.0, true],
				"attack_down": [3, 0, 6, 9.0, false],
				"attack_side": [4, 0, 6, 9.0, false],
				"attack_up":   [5, 0, 6, 9.0, false],
			}
		"gargoyle":
			return {
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
		_: # goblin (default)
			return {
				"idle_down":   [0, 0, 4, 4.0, true],
				"idle_side":   [1, 0, 4, 4.0, true],
				"idle_up":     [3, 0, 4, 4.0, true],
				"walk_down":   [0, 0, 8, 8.0, true],
				"walk_side":   [2, 0, 8, 9.0, true],
				"walk_up":     [3, 0, 8, 8.0, true],
				"attack_down": [4, 0, 6, 11.0, false],
				"attack_side": [5, 0, 6, 11.0, false],
				"attack_up":   [6, 0, 5, 11.0, false],
			}

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _knockback.length_squared() > 1.0:
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 9.0)

	if not _target or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		if not _target:
			return

	var to_target = _target.global_position - global_position
	var dist = to_target.length()

	# Lock during attack animation
	if _is_attacking:
		_attack_anim_timer -= delta
		velocity = _knockback * 0.3
		move_and_slide()
		if _attack_anim_timer <= 0.0:
			_is_attacking = false
			_play_anim("idle")
		return

	var separation = _separation_vector()

	if is_ranged and dist < ranged_range:
		# Strafe sideways + keep distance
		var perp = Vector2(-to_target.y, to_target.x).normalized()
		velocity = perp * speed * 0.4 + separation * 35.0 + _knockback
		_update_facing(to_target)
		if _attack_timer <= 0.0:
			_perform_ranged_attack(to_target)
		else:
			_play_anim("idle")
	elif not is_ranged and dist < melee_range:
		velocity = _knockback + separation * 40.0
		_update_facing(to_target)
		if _attack_timer <= 0.0:
			_perform_melee_attack(to_target)
		else:
			_play_anim("idle")
	else:
		var move_dir = (to_target.normalized() + separation * 0.8).normalized()
		velocity = move_dir * speed * speed_multiplier + _knockback
		_update_facing(move_dir)
		_play_anim("walk")

	move_and_slide()

func _update_facing(dir: Vector2) -> void:
	if abs(dir.y) > abs(dir.x) * 0.8:
		_facing_dir = "down" if dir.y > 0 else "up"
	else:
		_facing_dir = "side"
		if _anim_sprite:
			_anim_sprite.flip_h = dir.x < 0
		elif _single_sprite:
			_single_sprite.flip_h = dir.x < 0

func _play_anim(action: String) -> void:
	if not _anim_sprite:
		return
	var anim = "%s_%s" % [action, _facing_dir]
	if _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation(anim):
		if _anim_sprite.animation != anim:
			_anim_sprite.play(anim)
	else:
		var fallback = "%s_down" % action
		if _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation(fallback):
			if _anim_sprite.animation != fallback:
				_anim_sprite.play(fallback)

func _perform_melee_attack(to_target: Vector2) -> void:
	_is_attacking = true
	_attack_anim_timer = 0.42
	_attack_timer = melee_cooldown
	var aim = to_target.normalized()
	velocity = aim * 90.0
	_play_anim("attack")
	# Wait for startup delay before dealing damage (gives player time to react)
	if attack_startup_delay > 0.0:
		await get_tree().create_timer(attack_startup_delay).timeout
		if not is_instance_valid(self):
			return
	if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(damage)
		if "velocity" in _target:
			_target.velocity += aim * 120.0

func _perform_ranged_attack(to_target: Vector2) -> void:
	_is_attacking = true
	_attack_anim_timer = 0.45
	_attack_timer = ranged_cooldown
	_play_anim("attack")
	# Wait for startup delay before firing projectile
	if attack_startup_delay > 0.0:
		await get_tree().create_timer(attack_startup_delay).timeout
		if not is_instance_valid(self):
			return
	var proj_script = load("res://scripts/projectile.gd")
	if proj_script:
		var proj = Area2D.new()
		proj.set_script(proj_script)
		proj.global_position = global_position + to_target.normalized() * 18.0
		var ptype = "bomb" if enemy_type == "dark_cultist" else ("magic" if enemy_type == "dark_wizard" else "spear")
		proj.setup(to_target, 200.0, damage * 0.7, ptype)
		get_tree().current_scene.add_child(proj)

func _separation_vector() -> Vector2:
	var force = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n):
			continue
		var diff = global_position - n.global_position
		var d = diff.length()
		if d > 0.01 and d < 36.0:
			force += diff.normalized() * (1.0 - d / 36.0)

	# Actively steer mobs away from the locked door / grill blocker
	for b in get_tree().get_nodes_in_group("door_blocker"):
		if is_instance_valid(b):
			var b_diff = global_position - b.global_position
			var b_dist = b_diff.length()
			if b_dist < 110.0 and b_dist > 0.01:
				force += b_diff.normalized() * (1.0 - b_dist / 110.0) * 4.0
	return force

func _setup_health_bar() -> void:
	if get_node_or_null("MobHealthBar"):
		return
	var bar_root = Node2D.new()
	bar_root.name = "MobHealthBar"
	bar_root.position = Vector2(0, -32)
	bar_root.z_index = 5
	add_child(bar_root)

	# Background dark box
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.position = Vector2(-16, -2)
	bg.size = Vector2(32, 4)
	bg.color = Color(0.06, 0.06, 0.08, 0.9)
	bar_root.add_child(bg)

	# Border
	var border = ReferenceRect.new()
	border.position = Vector2(-16, -2)
	border.size = Vector2(32, 4)
	border.border_color = Color(0.25, 0.25, 0.3, 0.85)
	border.border_width = 0.8
	border.editor_only = false
	bar_root.add_child(border)

	# Red Fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.name = "Fill"
	_hp_bar_fill.position = Vector2(-15, -1.25)
	_hp_bar_fill.size = Vector2(30, 2.5)
	_hp_bar_fill.color = Color(0.95, 0.18, 0.18, 0.95)
	bar_root.add_child(_hp_bar_fill)

func _update_health_bar() -> void:
	if _hp_bar_fill and is_instance_valid(_hp_bar_fill):
		var ratio = clamp(health / max(1.0, max_health), 0.0, 1.0)
		_hp_bar_fill.size.x = ratio * 30.0

func take_damage(amount: float) -> void:
	health -= amount
	_update_health_bar()
	if _target and is_instance_valid(_target):
		_knockback = (global_position - _target.global_position).normalized() * 200.0
	var spr = _anim_sprite if _anim_sprite else _single_sprite
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
