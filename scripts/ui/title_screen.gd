extends Control

## TitleScreen — Main Menu Controller for Skill Issue.exe
## Manages atmospheric intro music, menu buttons, sound effects, and instructions.

@onready var title_banner: TextureRect = $CenterContainer/VBoxContainer/TitleBanner
@onready var btn_start: Button = $CenterContainer/VBoxContainer/Buttons/BtnStart
@onready var btn_guide: Button = $CenterContainer/VBoxContainer/Buttons/BtnGuide
@onready var btn_quit: Button = $CenterContainer/VBoxContainer/Buttons/BtnQuit
@onready var guide_modal: Control = $GuideModal
@onready var btn_close_guide: Button = $GuideModal/Panel/BtnCloseGuide

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_focus: AudioStreamPlayer = $SFXFocus
@onready var sfx_select: AudioStreamPlayer = $SFXSelect

var _is_starting: bool = false

func _ready() -> void:
	# Ensure time scale is normal
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	if guide_modal:
		guide_modal.visible = false
		
	_setup_audio()
	_setup_animations()
	_connect_buttons()

func _setup_audio() -> void:
	if ResourceLoader.exists("res://assets/title_screen/waves.mp3"):
		music_player.stream = load("res://assets/title_screen/waves.mp3")
		music_player.volume_db = -8.0
		music_player.play()
		
	if ResourceLoader.exists("res://assets/title_screen/menu_focus.wav"):
		sfx_focus.stream = load("res://assets/title_screen/menu_focus.wav")
		sfx_focus.volume_db = -6.0
		
	if ResourceLoader.exists("res://assets/title_screen/menu_select.wav"):
		sfx_select.stream = load("res://assets/title_screen/menu_select.wav")
		sfx_select.volume_db = -4.0

func _setup_animations() -> void:
	if title_banner:
		# Floating sinusoidal bob animation
		var tw = create_tween().set_loops()
		tw.tween_property(title_banner, "position:y", -6.0, 1.8).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(title_banner, "position:y", 6.0, 1.8).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _connect_buttons() -> void:
	var buttons = [btn_start, btn_guide, btn_quit]
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(_on_button_hover.bind(btn))
			btn.focus_entered.connect(_on_button_hover.bind(btn))
			
	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)
	if btn_guide:
		btn_guide.pressed.connect(_on_guide_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
	if btn_close_guide:
		btn_close_guide.pressed.connect(_on_close_guide_pressed)
		btn_close_guide.mouse_entered.connect(_on_button_hover.bind(btn_close_guide))

func _on_button_hover(btn: Button) -> void:
	if _is_starting:
		return
	if sfx_focus and sfx_focus.stream:
		sfx_focus.play()
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)

func _on_button_exit(btn: Button) -> void:
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _on_start_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	
	if sfx_select and sfx_select.stream:
		sfx_select.play()
		
	# Smoothly fade out music and fade to black
	var fade_tw = create_tween()
	fade_tw.set_parallel(true)
	fade_tw.tween_property(music_player, "volume_db", -40.0, 0.6)
	
	var overlay = $FadeOverlay
	if overlay:
		overlay.visible = true
		fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.6)
		
	await get_tree().create_timer(0.65).timeout
	
	# Reset AI Director telemetry before starting fresh run
	var ai = get_node_or_null("/root/AIDirector")
	if ai and ai.has_method("reset_all_data"):
		ai.reset_all_data()
		
	get_tree().change_scene_to_file("res://scenes/enemies/main.tscn")

func _on_guide_pressed() -> void:
	if sfx_select and sfx_select.stream:
		sfx_select.play()
	if guide_modal:
		guide_modal.visible = true
		guide_modal.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(guide_modal, "modulate:a", 1.0, 0.2)

func _on_close_guide_pressed() -> void:
	if sfx_select and sfx_select.stream:
		sfx_select.play()
	if guide_modal:
		var tw = create_tween()
		tw.tween_property(guide_modal, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): guide_modal.visible = false)

func _on_quit_pressed() -> void:
	if sfx_select and sfx_select.stream:
		sfx_select.play()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()
