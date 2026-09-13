extends Node2D
## RoomBase — Base class for all rooms.
##
## Handles the enemy lifecycle & room progression:
##   1. Room is entered  → _apply_director_modifiers() then _spawn_enemies()
##   2. All enemies die  → North exit gate unlocks with sound & visual cue
##   3. Player enters North gate → emit room_completed signal to transition to next level
##
## Subclass each room and override _spawn_enemies() and _apply_director_modifiers().

signal room_completed

var room_name: String = "Base Room"
var _enemies: Array[Node] = []
var _room_active: bool = false
var _is_cleared: bool = false
var _last_locked_warning_time: float = -10.0

var _locked_sfx: AudioStreamPlayer = null
var _unlock_sfx: AudioStreamPlayer = null
var _door_overlay: Node2D = null  # Holds animated door-open sprites
var _door_blocker: StaticBody2D = null  # Solid collision barrier blocking exit until cleared
var _door_blocker_col: CollisionShape2D = null
var _room_chest: Area2D = null

func _ready() -> void:
	_room_active = true
	_is_cleared = false
	_ensure_camera()
	_ensure_player()
	_build_environment()
	print("[%s] Entered." % room_name)
	_apply_director_modifiers()
	_spawn_enemies()

func _ensure_camera() -> void:
	if not get_node_or_null("RoomCamera"):
		var cam = Camera2D.new()
		cam.name = "RoomCamera"
		cam.position = Vector2.ZERO
		add_child(cam)
		cam.make_current()

func _ensure_player() -> void:
	# Check if player already exists anywhere in scene
	var existing = get_tree().get_first_node_in_group("player")
	if is_instance_valid(existing):
		# Reparent player to this room so it stays with current room's coordinate space
		if existing.get_parent() != self:
			existing.get_parent().remove_child(existing)
			add_child(existing)
		existing.position = _get_player_spawn_position()
		if existing.get("is_dead") or existing.get("health") <= 0.0:
			if existing.has_method("reset_state"):
				existing.reset_state()
		return

	# First time: create the player from player.tscn scene if available
	var player_scene = null
	for p_path in ["res://scenes/player.tscn", "res://Scenes/player.tscn"]:
		if ResourceLoader.exists(p_path):
			player_scene = load(p_path)
			break

	if player_scene:
		var p = player_scene.instantiate()
		p.name = "Player"
		p.position = _get_player_spawn_position()
		add_child(p)
	else:
		var player_script = load("res://scripts/player/player_controller.gd")
		if player_script:
			var p = CharacterBody2D.new()
			p.name = "Player"
			p.set_script(player_script)
			p.position = _get_player_spawn_position()
			add_child(p)

## Automatically constructs dungeon environment using res://assets/
func _build_environment() -> void:
	if get_node_or_null("DungeonEnv"):
		return
		
	var env = Node2D.new()
	env.name = "DungeonEnv"
	env.z_index = -10
	add_child(env)

	# 1. Base floor background color
	var floor_bg = ColorRect.new()
	floor_bg.name = "FloorBG"
	floor_bg.position = Vector2(-700, -450)
	floor_bg.size = Vector2(1400, 900)
	floor_bg.color = _get_theme_floor_color()
	env.add_child(floor_bg)

	# 2. Full Room Background Image
	var bg_path = _get_room_bg_path()
	if ResourceLoader.exists(bg_path):
		var bg_tex = load(bg_path) as Texture2D
		if bg_tex:
			var bg_spr = Sprite2D.new()
			bg_spr.name = "RoomBGSprite"
			bg_spr.texture = bg_tex
			bg_spr.position = Vector2.ZERO
			bg_spr.scale = Vector2(1280.0 / float(bg_tex.get_width()), 720.0 / float(bg_tex.get_height()))
			env.add_child(bg_spr)

	# 3. Perimeter Walls (Solid barrier preventing walking over perimeter walls)
	var static_body = StaticBody2D.new()
	static_body.name = "DungeonWalls"
	static_body.collision_layer = 1
	static_body.collision_mask = 3
	
	var wall_rects = _get_wall_colliders()
	for rect in wall_rects:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		col.position = rect.position
		static_body.add_child(col)
		
	env.add_child(static_body)

	# 3b. Foreground Layer (Pillars / Fences / Bars)
	var fg_path = _get_room_foreground_path()
	if fg_path != "" and ResourceLoader.exists(fg_path):
		var fg_tex = load(fg_path) as Texture2D
		if fg_tex:
			var fg_spr = Sprite2D.new()
			fg_spr.name = "RoomForegroundSprite"
			fg_spr.texture = fg_tex
			fg_spr.position = Vector2.ZERO
			fg_spr.z_index = 2
			fg_spr.z_as_relative = false
			env.add_child(fg_spr)

	# 4. Interactive Room Exit Door Trigger (North Door in Blue Box)
	_build_exit_door(env)

	# 5. Archway Gate Tunnels (Phasing Tunnel Teleporters on Left and Right Doors)
	if _should_have_archway_tunnels():
		_build_archway_tunnels(env)

	# 6. Gargoyle Statue Traps & Time Punishment Setup
	_spawn_statues(env)
	_start_room_timer()

	# 7. Room Entrance Audio & Gate Audio
	if ResourceLoader.exists("res://assets/dungeon_discovery.wav"):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load("res://assets/dungeon_discovery.wav")
		sfx.volume_db = -12.0
		env.add_child(sfx)
		sfx.play()

	if ResourceLoader.exists("res://assets/locked_door.wav"):
		_locked_sfx = AudioStreamPlayer.new()
		_locked_sfx.stream = load("res://assets/locked_door.wav")
		_locked_sfx.volume_db = -6.0
		env.add_child(_locked_sfx)

	if ResourceLoader.exists("res://assets/unlock_door.wav"):
		_unlock_sfx = AudioStreamPlayer.new()
		_unlock_sfx.stream = load("res://assets/unlock_door.wav")
		_unlock_sfx.volume_db = -4.0
		env.add_child(_unlock_sfx)
	elif ResourceLoader.exists("res://assets/bars_open.wav"):
		_unlock_sfx = AudioStreamPlayer.new()
		_unlock_sfx.stream = load("res://assets/bars_open.wav")
		_unlock_sfx.volume_db = -4.0
		env.add_child(_unlock_sfx)

	# 8. Room Buff Treasure Chest
	_build_treasure_chest(env)

func _build_archway_tunnels(env: Node2D) -> void:
	# Tunnel 1 (Left Wall Open Doorway)
	var tunnel1 = Area2D.new()
	tunnel1.name = "Tunnel1"
	tunnel1.position = Vector2(-540, 0)
	var col1 = CollisionShape2D.new()
	var s1 = RectangleShape2D.new()
	s1.size = Vector2(80, 100)
	col1.shape = s1
	tunnel1.add_child(col1)
	tunnel1.body_entered.connect(_phase_teleport.bind(Vector2(480, 0)))
	env.add_child(tunnel1)

	# Tunnel 2 (Right Wall Open Doorway)
	var tunnel2 = Area2D.new()
	tunnel2.name = "Tunnel2"
	tunnel2.position = Vector2(540, 0)
	var col2 = CollisionShape2D.new()
	var s2 = RectangleShape2D.new()
	s2.size = Vector2(80, 100)
	col2.shape = s2
	tunnel2.add_child(col2)
	tunnel2.body_entered.connect(_phase_teleport.bind(Vector2(-480, 0)))
	env.add_child(tunnel2)

func _phase_teleport(body: Node, target_pos: Vector2) -> void:
	if body.is_in_group("boss") or body.name == "BossEnemy" or body.name.begins_with("Boss"):
		return
	if body.is_in_group("player") or (body.is_in_group("enemy") and not body.is_in_group("boss")):
		body.global_position = target_pos + global_position
		print("[Tunnel] %s phased through Archway Tunnel!" % body.name)

func _build_exit_door(env: Node2D) -> void:
	var door = Area2D.new()
	door.name = "ExitDoorArea"
	door.position = _get_exit_door_position()
	# Must detect player (collision layer 2) and walls (layer 1)
	door.collision_layer = 0
	door.collision_mask = 2  # player is on layer 2
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var d_size = _get_exit_door_size()
	shape.size = d_size
	col.shape = shape
	door.add_child(col)
	
	door.body_entered.connect(_on_door_entered)
	door.z_as_relative = false
	door.z_index = 3
	add_child(door)

	# Physical door blocker: prevents player and mobs from passing through before room is cleared
	if _should_block_exit_until_cleared():
		_door_blocker = StaticBody2D.new()
		_door_blocker.name = "DoorBlocker"
		_door_blocker.position = _get_exit_door_position()
		_door_blocker.collision_layer = 0xFFFFFFFF  # Solid against all collision layers (world, player, mobs)
		_door_blocker.collision_mask = 0
		_door_blocker.add_to_group("door_blocker")
		
		_door_blocker_col = CollisionShape2D.new()
		var b_shape = RectangleShape2D.new()
		b_shape.size = _get_exit_door_size()
		_door_blocker_col.shape = b_shape
		_door_blocker.add_child(_door_blocker_col)
		add_child(_door_blocker)

	# Door opening / breaking animation overlay
	var intact_path = _get_door_intact_path()
	var half_path = _get_door_half_open_path()
	var open_path = _get_door_fully_open_path()
	var has_overlay = (intact_path != "" and ResourceLoader.exists(intact_path)) or \
	                  (half_path != "" and ResourceLoader.exists(half_path)) or \
	                  (open_path != "" and ResourceLoader.exists(open_path))

	if has_overlay:
		_door_overlay = Node2D.new()
		_door_overlay.name = "DoorOverlay"
		_door_overlay.position = _get_door_position()
		_door_overlay.z_as_relative = false
		_door_overlay.z_index = 2
		_door_overlay.visible = (intact_path != "")
		add_child(_door_overlay)

		if intact_path != "" and ResourceLoader.exists(intact_path):
			var spr_intact = Sprite2D.new()
			spr_intact.name = "DoorIntact"
			spr_intact.texture = load(intact_path)
			spr_intact.scale = _get_door_scale()
			spr_intact.position = Vector2.ZERO
			spr_intact.visible = true
			_door_overlay.add_child(spr_intact)

		if half_path != "" and ResourceLoader.exists(half_path):
			var spr_half = Sprite2D.new()
			spr_half.name = "DoorHalfOpen"
			spr_half.texture = load(half_path)
			spr_half.scale = _get_door_scale()
			spr_half.position = Vector2.ZERO
			spr_half.visible = (intact_path == "")
			spr_half.modulate.a = 0.0 if intact_path != "" else 1.0
			_door_overlay.add_child(spr_half)

		if open_path != "" and ResourceLoader.exists(open_path):
			var spr_open = Sprite2D.new()
			spr_open.name = "DoorFullyOpen"
			spr_open.texture = load(open_path)
			spr_open.scale = _get_door_scale()
			spr_open.position = Vector2.ZERO
			spr_open.modulate.a = 0.0  # Start transparent; fades in after half-open
			_door_overlay.add_child(spr_open)

func _on_door_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
		
	if _is_cleared:
		if not _room_active:
			return
		_room_active = false
		print("[%s] Player stepped through North Gate -> Next Level!" % room_name)
		if _unlock_sfx and is_instance_valid(_unlock_sfx):
			_unlock_sfx.play()
		emit_signal("room_completed")
	else:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - _last_locked_warning_time > 1.5:
			_last_locked_warning_time = current_time
			print("[%s] North Gate is locked! Defeat all enemies first." % room_name)
			if _locked_sfx and is_instance_valid(_locked_sfx):
				_locked_sfx.play()

func _should_have_statues() -> bool:
	return true

func _spawn_statues(env: Node2D) -> void:
	if not _should_have_statues():
		return
	var statue_script = load("res://scripts/gargoyle_statue.gd")
	if not statue_script:
		return

	# Genuine 4 room corners inside the dungeon walls
	var pos_list = [
		Vector2(-500, -250), # Top-Left Corner
		Vector2(500, -250),  # Top-Right Corner
		Vector2(-500, 240),  # Bottom-Left Corner
		Vector2(500, 240)   # Bottom-Right Corner
	]
	for p in pos_list:
		var statue = CharacterBody2D.new()
		statue.set_script(statue_script)
		statue.global_position = p + global_position
		env.add_child(statue)

func _start_room_timer() -> void:
	if not _should_have_statues():
		return
	await get_tree().create_timer(16.0).timeout
	if _room_active and not _is_cleared and not _enemies.is_empty():
		print("[RoomBase] ⚠️ TIME IS UP! Gargoyle statues awaken as punishment!")
		for s in get_tree().get_nodes_in_group("statue"):
			if s.has_method("awaken"):
				s.awaken()

func _get_theme_floor_color() -> Color:
	return Color(0.1, 0.08, 0.14) # Default dark stone

func _get_room_bg_path() -> String:
	return "res://assets/room1_bg.png"

## Path to an intact/closed door overlay sprite (shown during combat before opening).
func _get_door_intact_path() -> String:
	return ""

## Path to the half-open door overlay sprite. Override in subclasses for different doors.
func _get_door_half_open_path() -> String:
	return ""

## Path to the fully-open door overlay sprite. Override in subclasses for different doors.
func _get_door_fully_open_path() -> String:
	return ""

## Scale for the door overlay sprites. Override in subclasses.
func _get_door_scale() -> Vector2:
	return Vector2(1.0, 1.0)

## Position for the door overlay node in local space. Override in subclasses.
func _get_door_position() -> Vector2:
	return Vector2(0, -210)

## Position for the exit door area trigger. Override in subclasses (e.g. Room 4 in center).
func _get_exit_door_position() -> Vector2:
	return Vector2(0, -195)

## Size for the exit door collision shape. Override in subclasses.
func _get_exit_door_size() -> Vector2:
	return Vector2(160, 65)

## Override to customise where the player spawns when entering this room.
func _get_player_spawn_position() -> Vector2:
	return Vector2(0, 150)

## Override to return true if a physical solid collider should block the exit area until cleared.
## Blocks both the player and all mobs on Layer 1.
func _should_block_exit_until_cleared() -> bool:
	return _get_door_intact_path() != ""

## Override to return false if this room should NOT build archway side tunnels (e.g. Room 5 Boss Arena).
func _should_have_archway_tunnels() -> bool:
	return true

func _get_room_foreground_path() -> String:
	return ""

## Returns array of Rect2 (position, size) defining impassable wall colliders. Override in subclasses.
func _get_wall_colliders() -> Array[Rect2]:
	return [
		Rect2(-360, -250, 560, 40), # Top-Left wall
		Rect2(360, -250, 560, 40),  # Top-Right wall
		Rect2(0, -250, 200, 40),    # Top Gate wall behind door
		Rect2(0, 350, 1280, 40),    # Bottom wall
		Rect2(-630, 0, 40, 720),    # Left wall
		Rect2(630, 0, 40, 720),     # Right wall
	]

# ---------------------------------------------------------------------------
# Override in subclasses
# ---------------------------------------------------------------------------

## Override to spawn enemies appropriate for this room.
func _spawn_enemies() -> void:
	pass

## Override to apply any Director-driven modifiers before enemies spawn.
func _apply_director_modifiers() -> void:
	pass

# ---------------------------------------------------------------------------
# Enemy tracking & Gate Unlocking
# ---------------------------------------------------------------------------

## Register an enemy so the room tracks its death.
func register_enemy(enemy: Node) -> void:
	_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	else:
		push_warning("[RoomBase] Enemy '%s' has no 'died' signal — room may never complete." % enemy.name)

func _on_enemy_died(enemy: Node) -> void:
	_enemies.erase(enemy)
	print("[%s] Enemy died. Remaining: %d" % [room_name, _enemies.size()])
	if _enemies.is_empty() and _room_active and not _is_cleared:
		_on_room_cleared()

## Called when all enemies in the room are defeated. Unlocks the North Gate.
func _on_room_cleared() -> void:
	_is_cleared = true
	print("[%s] All enemies defeated! North Gate unlocked." % room_name)

	# Remove physical door blocker so player can pass through / step onto exit
	if _door_blocker_col and is_instance_valid(_door_blocker_col):
		_door_blocker_col.set_deferred("disabled", true)
	if _door_blocker and is_instance_valid(_door_blocker):
		_door_blocker.queue_free()
		_door_blocker = null

	if _unlock_sfx and is_instance_valid(_unlock_sfx):
		_unlock_sfx.play()

	# Unlock victory treasure chest with room buff
	if _room_chest and is_instance_valid(_room_chest) and _room_chest.has_method("unlock_chest"):
		_room_chest.unlock_chest()

	# Animate door opening
	_animate_door_opening()

	# Check if player is already standing in the exit portal (distance-based, since
	# get_overlapping_bodies() requires a physics step to be reliable)
	var door = get_node_or_null("ExitDoorArea")
	if not door:
		door = get_node_or_null("DungeonEnv/ExitDoorArea")
	var player = get_tree().get_first_node_in_group("player")
	if door and player and is_instance_valid(player):
		var dist = player.global_position.distance_to(door.global_position)
		if dist < 100.0:
			_on_door_entered(player)

## Plays a 3-stage door opening animation: closed / intact → breaking / half-open → fully open / broken.
func _animate_door_opening() -> void:
	if not _door_overlay or not is_instance_valid(_door_overlay):
		return
	var spr_intact = _door_overlay.get_node_or_null("DoorIntact")
	var spr_half = _door_overlay.get_node_or_null("DoorHalfOpen")
	var spr_open = _door_overlay.get_node_or_null("DoorFullyOpen")
	if not spr_intact and not spr_half and not spr_open:
		return

	# Stage 1 — slight delay for drama after kill, then show half-open / breaking overlay
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	_door_overlay.visible = true

	if spr_intact and spr_half:
		spr_half.visible = true
		var shake = create_tween()
		shake.tween_property(spr_intact, "position:x", -5.0, 0.05)
		shake.tween_property(spr_intact, "position:x",  5.0, 0.05)
		shake.tween_property(spr_intact, "position:x", -3.0, 0.05)
		shake.tween_property(spr_intact, "position:x",  0.0, 0.05)
		shake.tween_property(spr_half, "modulate:a", 1.0, 0.25)
		shake.parallel().tween_property(spr_intact, "modulate:a", 0.0, 0.25)
	elif spr_half:
		spr_half.modulate = Color.WHITE
		var shake_tween = create_tween()
		shake_tween.tween_property(spr_half, "position:x", -4.0, 0.06)
		shake_tween.tween_property(spr_half, "position:x",  4.0, 0.06)
		shake_tween.tween_property(spr_half, "position:x", -3.0, 0.05)
		shake_tween.tween_property(spr_half, "position:x",  0.0, 0.05)

	# Stage 2 — after a moment, cross-fade to fully open
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self):
		return
	if spr_open:
		var fade = create_tween()
		fade.set_parallel(true)
		fade.tween_property(spr_open, "modulate:a", 1.0, 0.4)
		if spr_half:
			fade.tween_property(spr_half, "modulate:a", 0.0, 0.4)
		if spr_intact:
			fade.tween_property(spr_intact, "modulate:a", 0.0, 0.4)

func _get_room_number() -> int:
	var lower_name = room_name.to_lower()
	var path = scene_file_path.to_lower()
	if "room_1" in path or "1" in lower_name or "tutorial" in lower_name or "training" in lower_name:
		return 1
	if "room_2" in path or "2" in lower_name or "icy" in lower_name or "frozen" in lower_name:
		return 2
	if "room_3" in path or "3" in lower_name or "faster" in lower_name or "accelerated" in lower_name:
		return 3
	if "room_4" in path or "4" in lower_name or "director" in lower_name or "inverted" in lower_name:
		return 4
	if "room_5" in path or "5" in lower_name or "boss" in lower_name or "throne" in lower_name:
		return 5
	return 1

func _get_chest_spawn_position() -> Vector2:
	if _get_room_number() == 4:
		return Vector2(0, -150)
	return Vector2(0, -60)

func _build_treasure_chest(env: Node2D) -> void:
	if get_node_or_null("TreasureChest") or env.get_node_or_null("TreasureChest"):
		return
	var chest_scene = null
	for cp in ["res://scenes/treasure_chest.tscn", "res://Scenes/treasure_chest.tscn"]:
		if ResourceLoader.exists(cp):
			chest_scene = load(cp)
			break
	if not chest_scene:
		return
	var chest = chest_scene.instantiate()
	chest.name = "TreasureChest"
	if "room_number" in chest:
		chest.room_number = _get_room_number()
	chest.position = _get_chest_spawn_position()
	if "is_locked" in chest:
		chest.is_locked = true
	env.add_child(chest)
	_room_chest = chest

