extends Node2D
## RoomBase — Base class for all rooms.
##
## Handles the enemy lifecycle:
##   1. Room is entered  → _apply_director_modifiers() then _spawn_enemies()
##   2. All enemies die  → emit room_completed signal
##
## Subclass each room and override _spawn_enemies() and _apply_director_modifiers().

signal room_completed

var room_name: String = "Base Room"
var _enemies: Array[Node] = []
var _room_active: bool = false

func _ready() -> void:
	_room_active = true
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
		cam.make_current()
		add_child(cam)

func _ensure_player() -> void:
	# Check if player already exists anywhere in scene
	var existing = get_tree().get_first_node_in_group("player")
	if is_instance_valid(existing):
		# Reparent player to this room so it stays with current room's coordinate space
		if existing.get_parent() != self:
			existing.get_parent().remove_child(existing)
			add_child(existing)
		existing.position = Vector2(0, 150)
		return

	# First time: create the player
	var player_script = load("res://scripts/player.gd")
	if player_script:
		var p = CharacterBody2D.new()
		p.name = "Player"
		p.set_script(player_script)
		p.position = Vector2(0, 150)
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

	# 3. Perimeter Walls & Custom Obstacle Colliders (StaticBody2D)
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

	# 3b. Foreground Layer (Pillars / Fences / Bars player hides behind)
	var fg_path = _get_room_foreground_path()
	if fg_path != "" and ResourceLoader.exists(fg_path):
		var fg_tex = load(fg_path) as Texture2D
		if fg_tex:
			var fg_spr = Sprite2D.new()
			fg_spr.name = "RoomForegroundSprite"
			fg_spr.texture = fg_tex
			fg_spr.position = Vector2.ZERO
			fg_spr.z_index = 20 # Render in front of player and enemies
			fg_spr.scale = Vector2(1280.0 / float(fg_tex.get_width()), 720.0 / float(fg_tex.get_height()))
			add_child(fg_spr)

	# 4. Interactive Room Exit Door Trigger (North Door)
	_build_exit_door(env)

	# 5. Archway Gate Tunnels (Phasing Tunnel Teleporters)
	_build_archway_tunnels(env)

	# 6. Gargoyle Statue Traps & Time Punishment Setup
	_spawn_statues(env)
	_start_room_timer()

	# 7. Room Entrance Audio
	if ResourceLoader.exists("res://assets/dungeon_discovery.wav"):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load("res://assets/dungeon_discovery.wav")
		sfx.volume_db = -12.0
		env.add_child(sfx)
		sfx.play()

func _build_archway_tunnels(env: Node2D) -> void:
	# Tunnel 1 (Left Wall)
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

	# Tunnel 2 (Right Wall)
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
	if body.is_in_group("player") or body.is_in_group("enemy"):
		body.global_position = target_pos + global_position
		print("[Tunnel] %s phased through Archway Tunnel!" % body.name)

func _build_exit_door(env: Node2D) -> void:
	var door = Area2D.new()
	door.name = "ExitDoorArea"
	door.position = Vector2(0, -330)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(120, 60)
	col.shape = shape
	door.add_child(col)
	
	door.body_entered.connect(_on_door_entered)
	env.add_child(door)

func _on_door_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if _enemies.is_empty():
			print("[%s] Player entered exit doorway -> Next room!" % room_name)
			_on_all_enemies_dead()
		else:
			print("[%s] Door locked! Defeat all enemies first." % room_name)

func _spawn_statues(env: Node2D) -> void:
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
	await get_tree().create_timer(16.0).timeout
	if _room_active and not _enemies.is_empty():
		print("[RoomBase] ⚠️ TIME IS UP! Gargoyle statues awaken as punishment!")
		for s in get_tree().get_nodes_in_group("statue"):
			if s.has_method("awaken"):
				s.awaken()

func _get_theme_floor_color() -> Color:
	return Color(0.1, 0.08, 0.14) # Default dark stone

func _get_room_bg_path() -> String:
	return "res://assets/room1_bg.png"

func _get_room_foreground_path() -> String:
	return ""

## Returns array of Rect2 (position, size) defining impassable wall colliders
func _get_wall_colliders() -> Array[Rect2]:
	# Default room dimensions matching the 1280x720 background
	return [
		Rect2(0, -260, 1140, 100), # North stone wall
		Rect2(0, 310, 1140, 90),   # South stone wall
		Rect2(-570, 0, 100, 720),  # West stone wall
		Rect2(570, 0, 100, 720),   # East stone wall
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
# Enemy tracking
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
	if _enemies.is_empty() and _room_active:
		_on_all_enemies_dead()

func _on_all_enemies_dead() -> void:
	_room_active = false
	print("[%s] All enemies dead — room complete!" % room_name)
	emit_signal("room_completed")
