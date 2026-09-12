extends Node

## TelemetryManager tracks player combat metrics, patterns, and habits in real-time
## and feeds data to GaslightManager & LLMConnector.

signal habit_detected(habit_name: String, details: Dictionary)
signal stats_updated(summary: Dictionary)

# Rolling metrics
var jump_count: int = 0
var attack_count: int = 0
var missed_attack_count: int = 0
var hit_attack_count: int = 0
var dash_left_count: int = 0
var dash_right_count: int = 0
var damage_taken_count: int = 0
var corner_time: float = 0.0

# History tracking
var consecutive_misses: int = 0
var consecutive_jumps: int = 0
var action_history: Array[String] = []
var max_history_len: int = 30

# Habit flags to prevent instant repetition
var triggered_habits: Dictionary = {}

func record_action(action: String, metadata: Dictionary = {}) -> void:
	action_history.append(action)
	if action_history.size() > max_history_len:
		action_history.pop_front()
		
	match action:
		"jump":
			jump_count += 1
			consecutive_jumps += 1
			if consecutive_jumps >= 4 and not _is_on_cooldown("jump_spam"):
				_trigger_habit("jump_spam", {"count": consecutive_jumps})
		"dash_left":
			dash_left_count += 1
			consecutive_jumps = 0
			_check_dodge_bias()
		"dash_right":
			dash_right_count += 1
			consecutive_jumps = 0
			_check_dodge_bias()
		"attack_miss":
			missed_attack_count += 1
			consecutive_misses += 1
			if consecutive_misses >= 3 and not _is_on_cooldown("miss_streak"):
				_trigger_habit("miss_streak", {"misses": consecutive_misses})
		"attack_hit":
			hit_attack_count += 1
			consecutive_misses = 0
		"damage_taken":
			damage_taken_count += 1
			if metadata.get("hp_percent", 1.0) < 0.3 and not _is_on_cooldown("panic_hp"):
				_trigger_habit("panic_hp", {"hp": metadata.get("hp_percent")})

func _check_dodge_bias() -> void:
	var total_dashes = dash_left_count + dash_right_count
	if total_dashes >= 5:
		var left_ratio = float(dash_left_count) / float(total_dashes)
		if left_ratio >= 0.8 and not _is_on_cooldown("left_dodge_bias"):
			_trigger_habit("left_dodge_bias", {"ratio": left_ratio, "left_count": dash_left_count})
		elif left_ratio <= 0.2 and not _is_on_cooldown("right_dodge_bias"):
			_trigger_habit("right_dodge_bias", {"ratio": 1.0 - left_ratio, "right_count": dash_right_count})

func _trigger_habit(habit_name: String, details: Dictionary) -> void:
	triggered_habits[habit_name] = Time.get_ticks_msec()
	habit_detected.emit(habit_name, details)
	print("[Telemetry] Triggered habit: ", habit_name, " -> ", details)

func _is_on_cooldown(habit_name: String, cooldown_ms: float = 12000.0) -> bool:
	if not triggered_habits.has(habit_name):
		return false
	var elapsed = Time.get_ticks_msec() - triggered_habits[habit_name]
	return elapsed < cooldown_ms

func get_telemetry_snapshot() -> Dictionary:
	return {
		"jumps": jump_count,
		"attacks": hit_attack_count + missed_attack_count,
		"missed_attacks": missed_attack_count,
		"accuracy": (float(hit_attack_count) / float(max(1, hit_attack_count + missed_attack_count))) * 100.0,
		"consecutive_misses": consecutive_misses,
		"dash_left": dash_left_count,
		"dash_right": dash_right_count,
		"damage_taken": damage_taken_count,
		"recent_actions": action_history.slice(-10)
	}

func reset_session() -> void:
	jump_count = 0
	attack_count = 0
	missed_attack_count = 0
	hit_attack_count = 0
	dash_left_count = 0
	dash_right_count = 0
	damage_taken_count = 0
	consecutive_misses = 0
	consecutive_jumps = 0
	action_history.clear()
	triggered_habits.clear()
