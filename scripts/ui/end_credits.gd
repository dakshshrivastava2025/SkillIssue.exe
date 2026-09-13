extends CanvasLayer
## EndCredits — Retro Dynamic End Credits Roll with Interactive Floating Sprite Easter Eggs
##
## Features:
##   - Dynamic Contributor Roll from team data arrays (Member, Role, Quote, Icon/Sprite)
##   - Upward scrolling text roll with custom styling, headers, and section dividers
##   - Interactive Floating Easter Egg Sprites floating across screen:
##       - Click on or shoot/hit them with mouse cursor
##       - Plays random mini sound effects (item pickup, chest open, sword swoosh, level up)
##       - Spawns floating pop-up Developer Quote bubbles over the clicked sprite
##   - End of credits option: Press R or ENTER to restart game / return to Title Screen

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"name": "Daksh Shrivastava",
		"role": "Pitch Lead & Game Designer",
		"quote": "\"Dynamic AI Director is the future of adaptive gaming!\"",
		"color": Color(1.0, 0.85, 0.3) # Gold
	},
	{
		"name": "Ark Maheshwari",
		"role": "Core Engine & Room Architecture",
		"quote": "\"5 rooms, zero bugs, infinite friction on ice!\"",
		"color": Color(0.3, 0.9, 1.0) # Cyan
	},
	{
		"name": "Neev Agrawal",
		"role": "AI Integration Specialist & Telemetry",
		"quote": "\"We saw you dodge right 42 times... adapt or die!\"",
		"color": Color(0.9, 0.4, 1.0) # Purple
	},
	{
		"name": "Burhanuddin Hitawala",
		"role": "UI / UX & Visual Design Lead",
		"quote": "\"Making retro telemetry look sleek & dynamic!\"",
		"color": Color(0.4, 1.0, 0.5) # Emerald
	},
	{
		"name": "Jacob Cherry",
		"role": "Game Assets & Sound Designer",
		"quote": "\"Retro pixel art & atmospheric dungeon soundscapes!\"",
		"color": Color(1.0, 0.5, 0.4) # Coral / Orange
	}
]

const SECRET_QUOTES: Array[String] = [
	"💬 \"Skill Issue? No, it's an AI Director feature!\"",
	"💬 \"You found a hidden dev quote! +100 Honor!\"",
	"💬 \"The goblins were trained on 10,000 player deaths!\"",
	"💬 \"Did you try dodging left for once?\"",
	"💬 \"Hackbattle 2026 Champion Build!\"",
	"💬 \"AI Director watched your every move!\""
]

const SPRITE_TEXTURES: Array[String] = [
	"res://assets/goblin.png",
	"res://assets/skeleton.png",
	"res://assets/gargoyle.png",
	"res://assets/dark_wizard.png",
	"res://assets/dark_cultist.png",
	"res://assets/treasure-chest.png"
]

const SFX_PATHS: Array[String] = [
	"res://assets/item_pickup.wav",
	"res://assets/treasure-open.wav",
	"res://assets/SwordSwoosh.wav",
	"res://assets/hp-up.wav",
	"res://assets/bars_open.wav"
]

var _scroll_container: Control = null
var _credits_content: VBoxContainer = null
var _floating_container: Control = null
var _quote_container: Control = null
var _scroll_speed: float = 38.0
var _is_scrolling: bool = true
var _spawn_timer: float = 0.0
var _floating_sprites: Array[Node2D] = []

func _ready() -> void:
	_build_ui_structure()
	_populate_credits()
	_start_music_or_sfx()
	print("[EndCredits] Interactive Credits Roll started!")

func _build_ui_structure() -> void:
	# Dark semi-transparent background overlay
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.08, 0.92)
	add_child(bg)

	# Container for floating interactive sprite easter eggs
	_floating_container = Control.new()
	_floating_container.name = "FloatingSpritesContainer"
	_floating_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floating_container)

	# Scroll Container for text roll
	_scroll_container = Control.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll_container)

	_credits_content = VBoxContainer.new()
	_credits_content.name = "CreditsContent"
	_credits_content.position = Vector2(0, 740) # Start below bottom screen
	_credits_content.size = Vector2(1280, 2000)
	_credits_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll_container.add_child(_credits_content)

	# Container for pop-up quote speech bubbles
	_quote_container = Control.new()
	_quote_container.name = "QuoteContainer"
	_quote_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quote_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quote_container)

	# Prompt overlay at top
	var prompt = Label.new()
	prompt.text = "🎯 CLICK OR SHOOT FLOATING MONSTERS FOR EASTER EGGS! | PRESS [R] TO RESTART"
	prompt.position = Vector2(0, 15)
	prompt.size = Vector2(1280, 30)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.85))
	prompt.add_theme_font_size_override("font_size", 14)
	add_child(prompt)

func _populate_credits() -> void:
	_add_spacer(60)

	# Title Banner
	_add_header("SKILL ISSUE", 38, Color(1.0, 0.85, 0.2))
	_add_subheader("An Adaptive AI Dungeon Crawler", 20, Color(0.8, 0.8, 0.9))
	_add_spacer(30)

	_add_divider()
	_add_header("VICTORY CONQUEROR", 24, Color(0.4, 1.0, 0.5))
	_add_subheader("You Have Cleared All 5 Rooms & Defeated The Adaptive Dark Wizard!", 16, Color(0.9, 0.9, 1.0))
	_add_divider()
	_add_spacer(40)

	# Dynamic Contributor Roll
	_add_header("DEVELOPMENT TEAM", 28, Color(0.3, 0.9, 1.0))
	_add_spacer(20)

	for member in TEAM_MEMBERS:
		var name_label = Label.new()
		name_label.text = member["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", member["color"])
		_credits_content.add_child(name_label)

		var role_label = Label.new()
		role_label.text = "— " + member["role"] + " —"
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 16)
		role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		_credits_content.add_child(role_label)

		var quote_label = Label.new()
		quote_label.text = member["quote"]
		quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quote_label.add_theme_font_size_override("font_size", 14)
		quote_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 0.9))
		_credits_content.add_child(quote_label)

		_add_spacer(35)

	_add_divider()
	_add_spacer(30)

	# Special Thanks & Tech Stack
	_add_header("TECHNOLOGY & ENGINE", 24, Color(0.9, 0.4, 1.0))
	_add_subheader("Built with Godot Engine 4.4 Stable", 16, Color(0.8, 0.8, 0.9))
	_add_subheader("Powered by Real-Time Heuristic Telemetry AI Director", 15, Color(0.7, 0.9, 1.0))
	_add_spacer(40)

	# Final Thank You
	_add_header("THANK YOU FOR PLAYING!", 32, Color(1.0, 0.85, 0.3))
	_add_subheader("Press [R] or [SPACE] to return to Main Menu / Restart Run", 16, Color(1.0, 1.0, 1.0, 0.8))
	_add_spacer(200)

func _add_header(text: String, size: int, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_credits_content.add_child(l)

func _add_subheader(text: String, size: int, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_credits_content.add_child(l)

func _add_spacer(height: int) -> void:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	_credits_content.add_child(c)

func _add_divider() -> void:
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(400, 2)
	line.color = Color(0.5, 0.5, 0.6, 0.5)
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(line)
	_credits_content.add_child(container)

func _process(delta: float) -> void:
	# 1. Scroll credits text upwards
	if _is_scrolling and _credits_content:
		_credits_content.position.y -= _scroll_speed * delta
		if _credits_content.position.y < -_credits_content.size.y + 300:
			_scroll_speed = 10.0 # Slow down at very end

	# 2. Spawn interactive floating easter egg sprites periodically
	_spawn_timer += delta
	if _spawn_timer >= 2.2:
		_spawn_timer = 0.0
		_spawn_floating_sprite()

	# 3. Update floating sprites positions
	for sprite in _floating_sprites:
		if is_instance_valid(sprite):
			var speed = sprite.get_meta("speed", Vector2(100, 0))
			sprite.position += speed * delta
			# Float sine wave bobbing
			var base_y = sprite.get_meta("base_y", sprite.position.y)
			sprite.position.y = base_y + sin(Time.get_ticks_msec() * 0.003 + sprite.get_instance_id()) * 18.0

			# Remove if floated off-screen
			if sprite.position.x > 1380 or sprite.position.x < -100:
				_floating_sprites.erase(sprite)
				sprite.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_restart_game()

func _spawn_floating_sprite() -> void:
	if _floating_sprites.size() >= 8:
		return

	var tex_path = SPRITE_TEXTURES.pick_random()
	if not ResourceLoader.exists(tex_path):
		return

	var tex = load(tex_path) as Texture2D
	if not tex:
		return

	# Create interactive Area2D node for floating sprite
	var container = Area2D.new()
	container.name = "EasterEggSprite"

	# Set input pickable so clicks are registered directly
	container.input_pickable = true

	var spr = Sprite2D.new()
	spr.texture = tex
	# Handle spritesheets if present
	if tex.get_width() > 128:
		spr.hframes = max(1, tex.get_width() / 32)
		spr.frame = 0
	spr.scale = Vector2(2.0, 2.0)
	container.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 28.0
	col.shape = shape
	container.add_child(col)

	# Decide side (Left to Right or Right to Left)
	var from_left = (randf() > 0.5)
	var start_x = -60.0 if from_left else 1340.0
	var start_y = randf_range(120.0, 600.0)
	var speed_x = randf_range(80.0, 160.0) * (1.0 if from_left else -1.0)

	container.position = Vector2(start_x, start_y)
	container.set_meta("speed", Vector2(speed_x, 0))
	container.set_meta("base_y", start_y)

	# Connect click event
	container.input_event.connect(_on_sprite_clicked.bind(container))

	_floating_container.add_child(container)
	_floating_sprites.append(container)

func _on_sprite_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, sprite_node: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_easter_egg(sprite_node)

func _trigger_easter_egg(sprite_node: Node2D) -> void:
	if not is_instance_valid(sprite_node):
		return

	# Play random mini sound effect
	_play_random_sfx()

	# Pick quote
	var quote = SECRET_QUOTES.pick_random()
	# If clicked Daksh/dev sprite, use specific dev quote
	if sprite_node.has_meta("dev_name"):
		quote = "💬 " + sprite_node.get_meta("dev_name") + ": " + sprite_node.get_meta("dev_quote")

	# Spawn floating quote speech bubble over sprite
	_spawn_quote_bubble(sprite_node.global_position, quote)

	# Visual popup effect on sprite
	var tw = create_tween()
	tw.tween_property(sprite_node, "scale", Vector2(2.8, 2.8), 0.1)
	tw.tween_property(sprite_node, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_floating_sprites.erase(sprite_node)
		sprite_node.queue_free()
	)

func _play_random_sfx() -> void:
	var path = SFX_PATHS.pick_random()
	if ResourceLoader.exists(path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(path)
		sfx.volume_db = -4.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _spawn_quote_bubble(pos: Vector2, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.position = pos + Vector2(-120, -40)
	label.size = Vector2(240, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", 14)
	_quote_container.add_child(label)

	# Animate quote floating upwards and fading out
	var tw = create_tween()
	tw.parallel().tween_property(label, "position:y", label.position.y - 60.0, 1.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.8)
	tw.tween_callback(func(): label.queue_free())

func _start_music_or_sfx() -> void:
	if ResourceLoader.exists("res://assets/level_up_jingle.wav"):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load("res://assets/level_up_jingle.wav")
		sfx.volume_db = -6.0
		add_child(sfx)
		sfx.play()

func _restart_game() -> void:
	print("[EndCredits] Restarting game...")
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("restart_run"):
		gm.restart_run()
		queue_free()
	else:
		get_tree().reload_current_scene()
