extends Control
## TitleScreen — Main Title & Menu for SkillIssue.exe.
##
## Features:
##   - Atmospheric 16-bit retro background with subtle camera breathing
##   - Floating dungeon embers & arcane dust particles
##   - CRT / chromatic aberration glitch shader overlay
##   - Floating retro pixel art logo with pulsing glow
##   - Retro arcade buttons with hover/focus sound effects
##   - Smooth transition into Room 1 (res://scenes/enemies/main.tscn)
##   - Controls & Mechanics modal dialog

const GAME_SCENE_PATH: String = "res://scenes/enemies/main.tscn"

# UI References
@onready var bg_texture: TextureRect = $BackgroundLayer/Background
@onready var logo_texture: TextureRect = $UILayer/ContentContainer/TitleContainer/Logo
@onready var prompt_label: Label = $UILayer/ContentContainer/TitleContainer/PromptLabel
@onready var start_btn: Button = $UILayer/ContentContainer/MenuButtons/StartButton
@onready var controls_btn: Button = $UILayer/ContentContainer/MenuButtons/ControlsButton
@onready var quit_btn: Button = $UILayer/ContentContainer/MenuButtons/QuitButton
@onready var controls_modal: Control = $UILayer/ControlsModal
@onready var close_modal_btn: Button = $UILayer/ControlsModal/Panel/Margin/VBox/CloseButton
@onready var glitch_rect: ColorRect = $GlitchLayer/GlitchRect
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay

# Audio References
@onready var bgm_player: AudioStreamPlayer = $Audio/BGMPlayer
@onready var sfx_focus: AudioStreamPlayer = $Audio/FocusSFX
@onready var sfx_select: AudioStreamPlayer = $Audio/SelectSFX

var _is_transitioning: bool = false
var _time_elapsed: float = 0.0
var _base_logo_pos_y: float = 0.0
var _cursor_blink_time: float = 0.0
var _cursor_visible: bool = true

func _ready() -> void:
	# Ensure audio can play even if tree was previously paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	# Setup initial fade-in from black
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var fade_in = create_tween()
		fade_in.tween_property(fade_overlay, "modulate:a", 0.0, 0.8)
		fade_in.tween_callback(func(): fade_overlay.visible = false)

	# Store initial logo position for floating animation
	if logo_texture:
		_base_logo_pos_y = logo_texture.position.y

	# Style buttons with retro arcade aesthetics
	_setup_button_styles()

	# Connect button events
	_connect_button_signals()

	# Controls modal initial state
	if controls_modal:
		controls_modal.visible = false

	# Start BGM loop
	if bgm_player and not bgm_player.playing:
		bgm_player.volume_db = -12.0
		bgm_player.play()
		var bgm_fade = create_tween()
		bgm_fade.tween_property(bgm_player, "volume_db", -4.0, 1.5)

	# Focus start button for immediate keyboard/gamepad readiness
	start_btn.grab_focus()

func _process(delta: float) -> void:
	_time_elapsed += delta

	# Subtle floating bob animation for the logo
	if logo_texture and not _is_transitioning:
		var bob = sin(_time_elapsed * 2.2) * 6.0
		logo_texture.position.y = _base_logo_pos_y + bob

	# Gentle camera breathing zoom on the background
	if bg_texture:
		var scale_var = 1.0 + (sin(_time_elapsed * 0.8) * 0.015)
		bg_texture.scale = Vector2(scale_var, scale_var)

	# Blinking terminal cursor for the subtitle prompt
	_cursor_blink_time += delta
	if _cursor_blink_time >= 0.45:
		_cursor_blink_time = 0.0
		_cursor_visible = !_cursor_visible
		if prompt_label:
			var base_text = ">> ADAPTIVE THREAT PROTOCOL ACTIVE // THE ADAPTIVE AI DUNGEON"
			prompt_label.text = base_text + (" _" if _cursor_visible else "")

	# Subtle glitch breathing
	if glitch_rect and glitch_rect.material and not _is_transitioning:
		var mat = glitch_rect.material as ShaderMaterial
		if mat:
			var base_aberration = 0.0015 + abs(sin(_time_elapsed * 1.5)) * 0.0012
			mat.set_shader_parameter("chromatic_aberration", base_aberration)
			mat.set_shader_parameter("glitch_intensity", 0.02 if int(_time_elapsed * 3.0) % 7 == 0 else 0.0)

func _setup_button_styles() -> void:
	var buttons = [start_btn, controls_btn, quit_btn, close_modal_btn]
	for btn in buttons:
		if not btn:
			continue
		
		# Normal style
		var sb_normal = StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.08, 0.05, 0.07, 0.85)
		sb_normal.border_color = Color(0.75, 0.60, 0.25, 0.8)
		sb_normal.set_border_width_all(2)
		sb_normal.set_corner_radius_all(6)
		sb_normal.content_margin_left = 16
		sb_normal.content_margin_right = 16
		sb_normal.content_margin_top = 10
		sb_normal.content_margin_bottom = 10

		# Hover style
		var sb_hover = StyleBoxFlat.new()
		sb_hover.bg_color = Color(0.24, 0.08, 0.12, 0.95)
		sb_hover.border_color = Color(1.0, 0.85, 0.35, 1.0)
		sb_hover.set_border_width_all(2)
		sb_hover.set_corner_radius_all(6)
		sb_hover.content_margin_left = 16
		sb_hover.content_margin_right = 16
		sb_hover.content_margin_top = 10
		sb_hover.content_margin_bottom = 10

		# Pressed style
		var sb_pressed = StyleBoxFlat.new()
		sb_pressed.bg_color = Color(0.45, 0.12, 0.18, 1.0)
		sb_pressed.border_color = Color(1.0, 0.95, 0.6, 1.0)
		sb_pressed.set_border_width_all(3)
		sb_pressed.set_corner_radius_all(6)
		sb_pressed.content_margin_left = 16
		sb_pressed.content_margin_right = 16
		sb_pressed.content_margin_top = 10
		sb_pressed.content_margin_bottom = 10

		# Focus style
		var sb_focus = StyleBoxFlat.new()
		sb_focus.bg_color = Color(0.18, 0.06, 0.10, 0.9)
		sb_focus.border_color = Color(0.4, 0.85, 1.0, 1.0)
		sb_focus.set_border_width_all(2)
		sb_focus.set_corner_radius_all(6)

		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_stylebox_override("focus", sb_focus)

		btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.4))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(0.5, 0.9, 1.0))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		btn.add_theme_constant_override("shadow_offset_x", 1)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.add_theme_font_size_override("font_size", 16)

	# Give start button an extra highlighted hero look
	if start_btn:
		var sb_start = start_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		sb_start.bg_color = Color(0.22, 0.06, 0.09, 0.94)
		sb_start.border_color = Color(1.0, 0.85, 0.25, 1.0)
		sb_start.set_border_width_all(3)
		start_btn.add_theme_stylebox_override("normal", sb_start)
		start_btn.add_theme_font_size_override("font_size", 19)
		start_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	# Style the Controls modal panel
	if controls_modal:
		var panel = controls_modal.get_node_or_null("Panel") as PanelContainer
		if panel:
			var sb_panel = StyleBoxFlat.new()
			sb_panel.bg_color = Color(0.06, 0.03, 0.05, 0.96)
			sb_panel.border_color = Color(0.95, 0.75, 0.25, 1.0)
			sb_panel.set_border_width_all(3)
			sb_panel.set_corner_radius_all(10)
			panel.add_theme_stylebox_override("panel", sb_panel)

func _connect_button_signals() -> void:
	var btns = [start_btn, controls_btn, quit_btn, close_modal_btn]
	for b in btns:
		if not b:
			continue
		b.mouse_entered.connect(_on_button_hovered)
		b.focus_entered.connect(_on_button_hovered)

	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	if close_modal_btn:
		close_modal_btn.pressed.connect(_on_close_modal_pressed)

func _on_button_hovered() -> void:
	if _is_transitioning:
		return
	if sfx_focus:
		sfx_focus.pitch_scale = randf_range(0.95, 1.05)
		sfx_focus.play()

func _play_select_sfx() -> void:
	if sfx_select:
		sfx_select.pitch_scale = 1.0
		sfx_select.play()

func _on_start_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_select_sfx()

	# Disable buttons
	start_btn.disabled = true
	controls_btn.disabled = true
	quit_btn.disabled = true

	# Button flash animation
	var btn_flash = create_tween()
	btn_flash.tween_property(start_btn, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	btn_flash.tween_property(start_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

	# Glitch spike during transition
	if glitch_rect and glitch_rect.material:
		var mat = glitch_rect.material as ShaderMaterial
		if mat:
			var glitch_tween = create_tween()
			glitch_tween.tween_property(mat, "shader_parameter/glitch_intensity", 0.45, 0.25)
			glitch_tween.tween_property(mat, "shader_parameter/chromatic_aberration", 0.025, 0.25)

	# Fade out BGM and Screen
	if bgm_player:
		var bgm_fade = create_tween()
		bgm_fade.tween_property(bgm_player, "volume_db", -40.0, 0.6)

	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate = Color(0.0, 0.0, 0.0, 0.0)
		var screen_fade = create_tween()
		screen_fade.tween_property(fade_overlay, "modulate:a", 1.0, 0.65)
		await screen_fade.finished

	# Change scene to main game
	print("[TitleScreen] Launching dungeon crawl: %s" % GAME_SCENE_PATH)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_controls_pressed() -> void:
	if _is_transitioning:
		return
	_play_select_sfx()
	if controls_modal:
		controls_modal.visible = true
		controls_modal.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var t = create_tween()
		t.tween_property(controls_modal, "modulate:a", 1.0, 0.2)
		if close_modal_btn:
			close_modal_btn.grab_focus()

func _on_close_modal_pressed() -> void:
	_play_select_sfx()
	if controls_modal:
		var t = create_tween()
		t.tween_property(controls_modal, "modulate:a", 0.0, 0.15)
		t.tween_callback(func():
			controls_modal.visible = false
			if controls_btn:
				controls_btn.grab_focus()
		)

func _on_quit_pressed() -> void:
	if _is_transitioning:
		return
	_play_select_sfx()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if controls_modal and controls_modal.visible:
				_on_close_modal_pressed()
				get_viewport().set_input_as_handled()
