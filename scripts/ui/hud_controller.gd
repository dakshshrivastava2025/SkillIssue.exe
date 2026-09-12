extends Control

## UI Controller managing Health Bars, Boss Dialogue, Glitch Screen Shaders,
## and psychological Fourth-Wall error popups.

@onready var player_hp_bar: ProgressBar = $HUD/PlayerHPBar
@onready var boss_hp_bar: ProgressBar = $HUD/BossHPBar
@onready var boss_dialogue_label: RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/DialogueLabel
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var popup_window: Window = $FakePopup
@onready var popup_label: Label = $FakePopup/MarginContainer/VBoxContainer/ErrorLabel
@onready var glitch_rect: ColorRect = $GlitchOverlay
@onready var event_notification: Label = $HUD/EventNotification

var dialogue_tween: Tween

func _ready() -> void:
	dialogue_box.visible = false
	popup_window.visible = false
	event_notification.visible = false
	
	if LLMConnector:
		LLMConnector.dialogue_generated.connect(_on_dialogue_received)
		
	if GaslightManager:
		GaslightManager.gaslight_event_started.connect(_on_gaslight_start)
		GaslightManager.gaslight_event_ended.connect(_on_gaslight_end)

func update_player_hp(curr: int, max_val: int) -> void:
	if GaslightManager.fake_hp_distortion:
		# Gaslight: Show misleading HP bar
		player_hp_bar.value = randi_range(5, 95)
	else:
		player_hp_bar.max_value = max_val
		player_hp_bar.value = curr

func update_boss_hp(curr: int, max_val: int) -> void:
	boss_hp_bar.max_value = max_val
	boss_hp_bar.value = curr

func _on_dialogue_received(text: String, _mood: String) -> void:
	dialogue_box.visible = true
	boss_dialogue_label.text = "[b][color=#ff4444]G.A.B:[/color][/b] " + text
	
	# Auto-hide after 5 seconds
	if dialogue_tween:
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_interval(5.0)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)

func _on_gaslight_start(event_name: String, desc: String) -> void:
	event_notification.text = "[!] " + desc.to_upper()
	event_notification.visible = true
	
	# Trigger shader glitch spike
	if glitch_rect.material:
		(glitch_rect.material as ShaderMaterial).set_shader_parameter("glitch_intensity", 0.6)
		(glitch_rect.material as ShaderMaterial).set_shader_parameter("chromatic_aberration", 0.02)
		
	if event_name == "fake_popup":
		popup_label.text = "CRITICAL MEMORY OVERFLOW:\nPlayer accuracy dropped below acceptable runtime threshold.\nAttempting hotfix..."
		popup_window.visible = true

func _on_gaslight_end(event_name: String) -> void:
	event_notification.visible = false
	if glitch_rect.material:
		(glitch_rect.material as ShaderMaterial).set_shader_parameter("glitch_intensity", 0.0)
		(glitch_rect.material as ShaderMaterial).set_shader_parameter("chromatic_aberration", 0.0)

func _on_fake_popup_close_requested() -> void:
	popup_window.visible = false
