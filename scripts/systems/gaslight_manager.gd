extends Node

## GaslightManager coordinates game rule alterations, control distortions,
## fake popups, UI illusions, and screen glitches in response to player habits.

signal gaslight_event_started(event_name: String, description: String)
signal gaslight_event_ended(event_name: String)

# Current active rule distortions
var controls_inverted: bool = false
var jump_disabled: bool = false
var fake_hp_distortion: bool = false
var screen_glitch_intensity: float = 0.0

var active_events: Array[String] = []

func _ready() -> void:
	if TelemetryManager:
		TelemetryManager.habit_detected.connect(_on_habit_detected)

func _on_habit_detected(habit_name: String, details: Dictionary) -> void:
	match habit_name:
		"jump_spam":
			trigger_invert_gravity_or_disable_jump()
		"left_dodge_bias", "right_dodge_bias":
			trigger_control_scramble()
		"panic_hp":
			trigger_hp_bar_gaslight()
		"miss_streak":
			trigger_fake_system_error("ATTACK_COLLIDER_NOT_FOUND")

func trigger_control_scramble(duration: float = 4.0) -> void:
	if controls_inverted:
		return
	controls_inverted = true
	gaslight_event_started.emit("controls_inverted", "Boss inverted your horizontal movement!")
	
	await get_tree().create_timer(duration).timeout
	controls_inverted = false
	gaslight_event_ended.emit("controls_inverted")

func trigger_invert_gravity_or_disable_jump(duration: float = 3.5) -> void:
	if jump_disabled:
		return
	jump_disabled = true
	gaslight_event_started.emit("jump_disabled", "Gravity overridden: Jumping suppressed.")
	
	await get_tree().create_timer(duration).timeout
	jump_disabled = false
	gaslight_event_ended.emit("jump_disabled")

func trigger_hp_bar_gaslight(duration: float = 6.0) -> void:
	fake_hp_distortion = true
	gaslight_event_started.emit("hp_distortion", "Health Bar manipulated.")
	
	await get_tree().create_timer(duration).timeout
	fake_hp_distortion = false
	gaslight_event_ended.emit("hp_distortion")

func trigger_fake_system_error(error_code: String = "EXCEPTION_SKILL_DEFICIT") -> void:
	gaslight_event_started.emit("fake_popup", "System Warning: " + error_code)
