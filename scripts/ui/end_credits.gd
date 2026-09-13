extends CanvasLayer
## EndCredits — Clean, Monochromatic End Credits Roll

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"name": "Daksh Shrivastava",
		"role": "Pitch Lead & Game Designer",
		"quote": "\"Dynamic AI Director is the future of adaptive gaming!\""
	},
	{
		"name": "Ark Maheshwari",
		"role": "Core Engine & Room Architecture",
		"quote": "\"5 rooms, zero bugs, infinite friction on ice!\""
	},
	{
		"name": "Neev Agrawal",
		"role": "AI Integration Specialist & Telemetry",
		"quote": "\"We saw you dodge right 42 times... adapt or die!\""
	},
	{
		"name": "Burhanuddin Hitawala",
		"role": "UI / UX & Visual Design Lead",
		"quote": "\"Making retro telemetry look sleek & dynamic!\""
	},
	{
		"name": "Jacob Cherry",
		"role": "Game Assets & Sound Designer",
		"quote": "\"Retro pixel art & atmospheric dungeon soundscapes!\""
	}
]

var _scroll_container: Control = null
var _credits_content: VBoxContainer = null
var _scroll_speed: float = 38.0
var _is_scrolling: bool = true

func _ready() -> void:
	_build_ui_structure()
	_populate_credits()
	_start_music_or_sfx()
	print("[EndCredits] Clean End Credits Roll started!")

func _build_ui_structure() -> void:
	# Dark background overlay
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.05, 0.95)
	add_child(bg)

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

	# Prompt overlay at top
	var prompt = Label.new()
	prompt.text = "PRESS [R] OR [SPACE] TO RETURN TO TITLE SCREEN"
	prompt.position = Vector2(0, 20)
	prompt.size = Vector2(1280, 30)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	prompt.add_theme_font_size_override("font_size", 14)
	add_child(prompt)

func _populate_credits() -> void:
	_add_spacer(60)

	# Title Banner
	_add_header("SKILL ISSUE", 38, Color.WHITE)
	_add_subheader("An Adaptive AI Dungeon Crawler", 18, Color(0.85, 0.85, 0.85))
	_add_spacer(30)

	_add_divider()
	_add_header("VICTORY CONQUEROR", 22, Color.WHITE)
	_add_subheader("You Have Cleared All 5 Rooms & Defeated The Adaptive Dark Wizard!", 15, Color(0.85, 0.85, 0.85))
	_add_divider()
	_add_spacer(40)

	# Dynamic Contributor Roll
	_add_header("DEVELOPMENT TEAM", 26, Color.WHITE)
	_add_spacer(25)

	for member in TEAM_MEMBERS:
		var name_label = Label.new()
		name_label.text = member["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		_credits_content.add_child(name_label)

		var role_label = Label.new()
		role_label.text = "— " + member["role"] + " —"
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 15)
		role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_credits_content.add_child(role_label)

		var quote_label = Label.new()
		quote_label.text = member["quote"]
		quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quote_label.add_theme_font_size_override("font_size", 13)
		quote_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_credits_content.add_child(quote_label)

		_add_spacer(35)

	_add_divider()
	_add_spacer(30)

	# Special Thanks & Tech Stack
	_add_header("TECHNOLOGY & ENGINE", 22, Color.WHITE)
	_add_subheader("Built with Godot Engine 4.4 Stable", 15, Color(0.85, 0.85, 0.85))
	_add_subheader("Powered by Real-Time Heuristic Telemetry AI Director", 14, Color(0.8, 0.8, 0.8))
	_add_spacer(40)

	# Final Thank You
	_add_header("THANK YOU FOR PLAYING!", 28, Color.WHITE)
	_add_subheader("Press [R] or [SPACE] to return to Title Screen", 15, Color(0.85, 0.85, 0.85))
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
	line.custom_minimum_size = Vector2(400, 1)
	line.color = Color(0.5, 0.5, 0.5, 0.4)
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(line)
	_credits_content.add_child(container)

func _process(delta: float) -> void:
	# Scroll credits text upwards
	if _is_scrolling and _credits_content:
		_credits_content.position.y -= _scroll_speed * delta
		if _credits_content.position.y < -_credits_content.size.y + 300:
			_scroll_speed = 10.0 # Slow down at very end

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_return_to_title_screen()

func _start_music_or_sfx() -> void:
	if ResourceLoader.exists("res://assets/level_up_jingle.wav"):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load("res://assets/level_up_jingle.wav")
		sfx.volume_db = -6.0
		add_child(sfx)
		sfx.play()

func _return_to_title_screen() -> void:
	print("[EndCredits] Returning to Title Screen...")
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		if ai.has_method("reset_full_session"):
			ai.reset_full_session()
		elif ai.has_method("reset"):
			ai.reset()
	queue_free()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
