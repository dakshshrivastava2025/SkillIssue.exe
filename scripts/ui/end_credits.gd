extends CanvasLayer
## EndCredits — Dynamic, Retro Pixel-Art Victory & Credits Screen
## Perfectly centered across any resolution, fast-scrolling, auto-terminates cleanly,
## and returns to title screen automatically at the end or on [R] / [SPACE] / [ENTER] / Click.

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"name": "DAKSH SHRIVASTAVA",
		"role": "PITCH LEAD & GAME DESIGNER",
		"quote": "\"Dynamic AI Director is the future of adaptive gaming!\"",
		"color": Color(1.0, 0.85, 0.3)
	},
	{
		"name": "ARK MAHESHWARI",
		"role": "CORE ENGINE & ROOM ARCHITECTURE",
		"quote": "\"5 rooms, zero bugs, zero friction on ice!\"",
		"color": Color(0.4, 0.9, 1.0)
	},
	{
		"name": "NEEV AGRAWAL",
		"role": "AI INTEGRATION SPECIALIST & TELEMETRY",
		"quote": "\"We saw you dodge right 42 times... adapt or die!\"",
		"color": Color(1.0, 0.45, 0.45)
	},
	{
		"name": "BURHANUDDIN HITAWALA",
		"role": "UI / UX & VISUAL DESIGN LEAD",
		"quote": "\"Making retro telemetry look sleek & dynamic!\"",
		"color": Color(0.7, 0.5, 1.0)
	},
	{
		"name": "JACOB CHERRY",
		"role": "GAME ASSETS & SOUND DESIGNER",
		"quote": "\"Retro pixel art & atmospheric dungeon soundscapes!\"",
		"color": Color(0.4, 1.0, 0.6)
	}
]

var _scroll_container: Control = null
var _credits_content: VBoxContainer = null
var _scroll_speed: float = 135.0 # Fast, crisp retro pace
var _is_scrolling: bool = true
var _particles: CPUParticles2D = null
var _time_elapsed: float = 0.0
var _bg_rect: TextureRect = null
var _prompt_label: Label = null
var _is_ending: bool = false
var _auto_end_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_structure()
	_populate_credits()
	_start_music_or_sfx()
	print("[EndCredits] Retro Pixel End Credits Roll started!")

func _build_ui_structure() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0:
		viewport_size = Vector2(1280, 720)

	# 1. Atmospheric Pixel Dungeon Texture Background with Dark Tint
	_bg_rect = TextureRect.new()
	_bg_rect.name = "Background"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.anchor_right = 1.0
	_bg_rect.anchor_bottom = 1.0
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/title_screen/title_bg.png"):
		_bg_rect.texture = load("res://assets/title_screen/title_bg.png")
	add_child(_bg_rect)

	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.color = Color(0.04, 0.02, 0.06, 0.90)
	add_child(vignette)

	# 2. Atmospheric Floating Ember Particles
	_particles = CPUParticles2D.new()
	_particles.name = "Embers"
	_particles.position = Vector2(viewport_size.x * 0.5, viewport_size.y)
	_particles.amount = 65
	_particles.lifetime = 3.5
	_particles.preprocess = 2.0
	_particles.speed_scale = 1.3
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(viewport_size.x * 0.5, 10)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 28.0
	_particles.gravity = Vector2(0, -25)
	_particles.initial_velocity_min = 45.0
	_particles.initial_velocity_max = 115.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 5.5
	
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.85, 0.2, 0.95))
	grad.add_point(0.5, Color(1.0, 0.35, 0.1, 0.85))
	grad.add_point(1.0, Color(0.5, 0.05, 0.8, 0.0))
	_particles.color_ramp = grad
	add_child(_particles)

	# 3. Main Center Alignment Container (Guarantees true center on any screen width/height)
	_scroll_container = Control.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.anchor_right = 1.0
	_scroll_container.anchor_bottom = 1.0
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll_container)

	_credits_content = VBoxContainer.new()
	_credits_content.name = "CreditsContent"
	# Anchor horizontally centered with fixed width 780px
	_credits_content.anchor_left = 0.5
	_credits_content.anchor_right = 0.5
	_credits_content.offset_left = -390.0
	_credits_content.offset_right = 390.0
	_credits_content.offset_top = viewport_size.y # Start below screen
	_credits_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_credits_content.add_theme_constant_override("separation", 10)
	_scroll_container.add_child(_credits_content)

	# 4. Top Sticky Retro Prompt Box
	var top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 0.0
	top_bar.offset_right = 0.0
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 44.0
	
	var sb_top = StyleBoxFlat.new()
	sb_top.bg_color = Color(0.08, 0.03, 0.08, 0.94)
	sb_top.border_color = Color(0.95, 0.75, 0.25, 0.95)
	sb_top.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", sb_top)
	
	_prompt_label = Label.new()
	_prompt_label.text = "⚡  PRESS [R] OR [SPACE] TO SKIP TO TITLE SCREEN  ⚡"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_prompt_label)
	add_child(top_bar)

func _populate_credits() -> void:
	_add_spacer(40)

	# 1. Logo or Hero Title
	if ResourceLoader.exists("res://assets/title_screen/title_logo.png"):
		var logo_center = CenterContainer.new()
		logo_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var logo_tex = TextureRect.new()
		logo_tex.texture = load("res://assets/title_screen/title_logo.png")
		logo_tex.custom_minimum_size = Vector2(380, 105)
		logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_center.add_child(logo_tex)
		_credits_content.add_child(logo_center)
		_add_spacer(10)
	else:
		_add_header("⚔️  SKILL ISSUE  ⚔️", 42, Color(1.0, 0.85, 0.3))

	_add_subheader("THE ADAPTIVE AI DUNGEON CRAWLER", 18, Color(0.92, 0.92, 0.96))
	_add_spacer(20)

	# 2. Victory Banner Card
	var vic_card = _create_retro_card(
		"👑  VICTORY CONQUERED!  👑\n\n" +
		"ALL 5 DUNGEON ROOMS MASTERED\n" +
		"DARK WIZARD DEFEATED & THREAT ELIMINATED",
		Color(1.0, 0.92, 0.38),
		Color(0.28, 0.16, 0.04, 0.92),
		Color(1.0, 0.8, 0.25, 1.0),
		720, 95
	)
	_credits_content.add_child(vic_card)
	_add_spacer(25)

	# 3. Live AI Director Telemetry Stats Summary
	var ai = get_node_or_null("/root/AIDirector")
	var kills = ai.get("kills") if ai else 0
	var misses = ai.get("missed_attacks") if ai else 0
	var hits = ai.get("hit_attacks") if ai else 0
	var retreat = ai.get("retreat_time") if ai else 0.0
	var dom_dodge = ai.get("dominant_dodge") if ai else ""
	if dom_dodge == null or str(dom_dodge) == "":
		dom_dodge = "BALANCED"

	var stats_text = "📊  RUN TELEMETRY SUMMARY\n\n" + \
		"Total Foes Slain: %d  •  Attacks Connected: %d  •  Whiffs: %d\n" % [kills if kills != null else 0, hits if hits != null else 0, misses if misses != null else 0] + \
		"Dominant Dodge Habit: %s  •  Total Retreat Duration: %.1fs" % [str(dom_dodge).to_upper(), retreat if retreat != null else 0.0]

	var stats_card = _create_retro_card(
		stats_text,
		Color(0.45, 0.95, 1.0),
		Color(0.04, 0.14, 0.24, 0.92),
		Color(0.35, 0.75, 1.0, 0.9),
		740, 100
	)
	_credits_content.add_child(stats_card)
	_add_spacer(30)

	# 4. Team Contributor Roll
	_add_header("DEVELOPMENT TEAM", 28, Color(1.0, 0.85, 0.3))
	_add_divider()
	_add_spacer(15)

	for member in TEAM_MEMBERS:
		var member_box = _create_member_card(member)
		_credits_content.add_child(member_box)
		_add_spacer(15)

	_add_divider()
	_add_spacer(20)

	# 5. Technology & Architecture
	_add_header("ENGINE & ARCHITECTURE", 22, Color(1.0, 1.0, 1.0))
	_add_subheader("Godot Engine 4.4 • Real-Time Adaptive AI Director", 16, Color(0.88, 0.88, 0.92))
	_add_subheader("Dynamic State-Space Interventions • Procedural Buff Systems", 14, Color(0.75, 0.75, 0.82))
	_add_spacer(30)

	# 6. Final Thank You Box
	var ty_card = _create_retro_card(
		"🌟  THANK YOU FOR PLAYING!  🌟\n\n" +
		"RETURNING TO TITLE SCREEN...",
		Color(1.0, 0.95, 0.6),
		Color(0.20, 0.06, 0.12, 0.95),
		Color(1.0, 0.4, 0.5, 0.95),
		720, 95
	)
	_credits_content.add_child(ty_card)
	_add_spacer(180)

func _create_member_card(member: Dictionary) -> Control:
	var container = CenterContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 100)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.10, 0.94)
	sb.border_color = member.get("color", Color.WHITE)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = member["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", member.get("color", Color.WHITE))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = "— " + member["role"] + " —"
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 14)
	role_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(role_lbl)

	var quote_lbl = Label.new()
	quote_lbl.text = member["quote"]
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.add_theme_font_size_override("font_size", 13)
	quote_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(quote_lbl)

	container.add_child(panel)
	return container

func _create_retro_card(text: String, font_color: Color, bg_color: Color, border_color: Color, width: int = 720, height: int = 90) -> Control:
	var container = CenterContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(lbl)

	container.add_child(panel)
	return container

func _add_header(text: String, size: int, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	_credits_content.add_child(l)

func _add_subheader(text: String, size: int, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	_credits_content.add_child(l)

func _add_spacer(height: int) -> void:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	_credits_content.add_child(c)

func _add_divider() -> void:
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(580, 2)
	line.color = Color(0.85, 0.35, 0.45, 0.8)
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(line)
	_credits_content.add_child(container)

func _process(delta: float) -> void:
	_time_elapsed += delta

	# Prompt pulsing effect
	if _prompt_label:
		var pulse = (sin(_time_elapsed * 4.0) + 1.0) * 0.5
		_prompt_label.modulate = Color(1.0, 1.0, 1.0, lerp(0.7, 1.0, pulse))

	# Fast, smooth upwards scroll
	if _is_scrolling and _credits_content:
		_credits_content.offset_top -= _scroll_speed * delta
		
		# Get total height of content
		var total_height = _credits_content.get_minimum_size().y
		if total_height <= 0:
			total_height = 2200.0
			
		# When the last card reaches the middle/top of the screen, pause and smoothly auto-return
		var viewport_h = get_viewport().get_visible_rect().size.y
		if viewport_h <= 0:
			viewport_h = 720.0
			
		# When content has scrolled so the final "THANK YOU" card is nicely displayed
		if _credits_content.offset_top < -(total_height - (viewport_h * 0.65)):
			_is_scrolling = false
			_start_auto_end_sequence()

func _start_auto_end_sequence() -> void:
	if _is_ending:
		return
	_is_ending = true
	print("[EndCredits] Roll completed! Auto-transitioning to Title Screen in 3.0s...")
	
	# Smoothly fade out screen after a brief rest
	await get_tree().create_timer(2.8).timeout
	var fade_rect = ColorRect.new()
	fade_rect.name = "EndFade"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.color = Color(0, 0, 0, 0)
	add_child(fade_rect)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.8)
	await tween.finished
	_return_to_title_screen()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_return_to_title_screen()
	elif event is InputEventMouseButton and event.pressed:
		_return_to_title_screen()

func _start_music_or_sfx() -> void:
	if ResourceLoader.exists("res://assets/title_screen/waves.mp3"):
		var bgm = AudioStreamPlayer.new()
		bgm.stream = load("res://assets/title_screen/waves.mp3")
		bgm.volume_db = -6.0
		add_child(bgm)
		bgm.play()
	elif ResourceLoader.exists("res://assets/level_up_jingle.wav"):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load("res://assets/level_up_jingle.wav")
		sfx.volume_db = -4.0
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
