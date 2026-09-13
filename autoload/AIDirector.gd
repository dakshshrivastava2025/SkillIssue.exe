extends Node
## AIDirector — Unified Singleton (Autoload)
## Combines real-time player habit tracking (kills, dodges, rhythm, retreat time)
## with dynamic interventions (dash lock, slow speed, damage reduction),
## boss trash-talk generation (Gemini / mock LLM), and state-space telemetry.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal player_is_aggressive
signal player_is_retreater
signal player_dodge_pattern_detected(direction: String)
signal attack_rhythm_detected
signal state_space_updated(state_vector: Dictionary)
signal director_intervention_triggered(action_name: String, description: String)
signal boss_dialogue_generated(text: String, trigger_type: String)

# ---------------------------------------------------------------------------
# Raw tracking data
# ---------------------------------------------------------------------------
var kills: int = 0
var player_kills: int:
	get: return kills
	set(v): kills = v

var damage_dealt_total: float = 0.0
var damage_taken_total: float = 0.0
var damage_taken_recent: float = 0.0
var missed_attacks: int = 0
var hit_attacks: int = 0
var consecutive_misses: int = 0

var dodge_counts: Dictionary = {"left": 0, "right": 0, "up": 0, "down": 0}
var retreat_time: float = 0.0
var total_retreat_time: float:
	get: return retreat_time
	set(v): retreat_time = v
var retreat_timer_streak: float = 0.0
var attack_timestamps: Array[float] = []

var current_room: int = 1

# ---------------------------------------------------------------------------
# Derived profile
# ---------------------------------------------------------------------------
var dominant_dodge: String = ""
var is_aggressive: bool = false
var is_retreater: bool = false
var attack_is_rhythmic: bool = false

# Dynamic Gameplay Modifiers
var speed_debuff_active: bool = false
var damage_debuff_active: bool = false
var dash_disabled_active: bool = false

# Thresholds
const AGGRESSIVE_KILLS_PER_MINUTE: float = 4.0
const RETREATER_TIME_THRESHOLD: float   = 12.0
const RHYTHM_VARIANCE_THRESHOLD: float  = 0.18
const MIN_ATTACKS_FOR_RHYTHM: int       = 6
const MIN_DODGES_FOR_PATTERN: int       = 4

var _session_start: float = 0.0
var _signals_fired: Dictionary = {}
var intervention_cooldowns: Dictionary = {}

# LLM Configuration
@export var gemini_api_key: String = ""
@export var mock_mode: bool = true
var http_request: HTTPRequest

const MOCK_BOSS_LINES = {
	"dominant_dodge_left": [
		"Your left dodge is so predictable I'm cutting off that flank.",
		"Rolling left again? Truly inspiring tactical genius."
	],
	"dominant_dodge_right": [
		"Right dodge overused. How painfully predictable.",
		"Always dodging right? You can't outrun your incompetence."
	],
	"retreater": [
		"You spent 12 seconds running away. DASH SEALED & LEGS WEIGHED DOWN!",
		"Running away won't save you. Dash disabled: fight me head on!"
	],
	"miss_streak": [
		"5 missed attacks in a row. Attack power suppressed: -35% DAMAGE!",
		"Are you trying to hit the floor tiles? Try aiming."
	],
	"boss_intro": [
		"Welcome to the arena. Every habit you have will be used against you."
	]
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	_session_start = Time.get_ticks_msec() / 1000.0
	reset_full_session()
	print("[AIDirector] Ready. Watching the player...")

func _process(_delta: float) -> void:
	_update_aggression()
	_update_retreater()

# ---------------------------------------------------------------------------
# Public Telemetry API
# ---------------------------------------------------------------------------
func record_kill() -> void:
	kills += 1
	print("[AIDirector] Kill #%d recorded." % kills)
	_evaluate_state_space()

func record_attack() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	attack_timestamps.append(t)
	if attack_timestamps.size() > 10:
		attack_timestamps.pop_front()
	_check_rhythm()

func record_attack_hit(damage: float) -> void:
	hit_attacks += 1
	consecutive_misses = 0
	damage_dealt_total += damage
	_evaluate_state_space()

func record_attack_miss() -> void:
	missed_attacks += 1
	consecutive_misses += 1
	if consecutive_misses >= 5 and not _is_on_cooldown("miss_streak", 16.0):
		_trigger_intervention("reduce_damage", "5 Misses Streak: -35% Attack Damage for 5s!")
		request_boss_dialogue("miss_streak")
	_evaluate_state_space()

func record_dodge(direction: String) -> void:
	if direction in dodge_counts:
		dodge_counts[direction] += 1
	_check_dodge_pattern()
	
	var total_dodges = dodge_counts["left"] + dodge_counts["right"] + dodge_counts["up"] + dodge_counts["down"]
	if total_dodges >= 8:
		var left_ratio = float(dodge_counts["left"]) / float(total_dodges)
		var right_ratio = float(dodge_counts["right"]) / float(total_dodges)
		if left_ratio >= 0.70 and not _is_on_cooldown("dodge_left", 22.0):
			dominant_dodge = "left"
			_trigger_intervention("dodge_punish", "Dominant Left-Dodge: Boss pre-firing into left flank!")
			request_boss_dialogue("dominant_dodge_left")
		elif right_ratio >= 0.70 and not _is_on_cooldown("dodge_right", 22.0):
			dominant_dodge = "right"
			_trigger_intervention("dodge_punish", "Dominant Right-Dodge: Boss pre-firing into right flank!")
			request_boss_dialogue("dominant_dodge_right")
	
	_evaluate_state_space()

func record_retreat(delta: float) -> void:
	retreat_time += delta
	retreat_timer_streak += delta
	if retreat_timer_streak >= 12.0 and not _is_on_cooldown("retreater", 20.0):
		is_retreater = true
		retreat_timer_streak = 0.0
		_trigger_intervention("block_dash", "Chronic Retreating: DASH LOCKED & -35% SPEED for 5s!")
		request_boss_dialogue("retreater")
	_evaluate_state_space()

func record_damage_taken(amount: float) -> void:
	damage_taken_total += amount
	damage_taken_recent += amount
	_evaluate_state_space()
	get_tree().create_timer(6.0).timeout.connect(func(): damage_taken_recent = max(0.0, damage_taken_recent - amount))

func reset_full_session() -> void:
	reset()

func reset() -> void:
	current_room = 1
	kills = 0
	damage_dealt_total = 0.0
	damage_taken_total = 0.0
	damage_taken_recent = 0.0
	missed_attacks = 0
	hit_attacks = 0
	consecutive_misses = 0
	dodge_counts = {"left": 0, "right": 0, "up": 0, "down": 0}
	retreat_time = 0.0
	retreat_timer_streak = 0.0
	attack_timestamps.clear()
	dominant_dodge = ""
	is_aggressive = false
	is_retreater = false
	attack_is_rhythmic = false
	speed_debuff_active = false
	damage_debuff_active = false
	dash_disabled_active = false
	intervention_cooldowns.clear()
	_signals_fired.clear()
	_session_start = Time.get_ticks_msec() / 1000.0
	_evaluate_state_space()
	print("[AIDirector] Full Session Reset.")

func get_state_space_vector() -> Dictionary:
	var total_attacks = max(1, hit_attacks + missed_attacks)
	var accuracy = float(hit_attacks) / float(total_attacks)
	return {
		"room": current_room,
		"kills": kills,
		"accuracy_pct": round(accuracy * 100.0),
		"dominant_dodge": dominant_dodge if dominant_dodge != "" else "none",
		"retreat_time_sec": round(retreat_time),
		"consecutive_misses": consecutive_misses,
		"active_debuffs": {
			"speed_debuff": speed_debuff_active,
			"damage_debuff": damage_debuff_active,
			"dash_disabled": dash_disabled_active
		}
	}

func _evaluate_state_space() -> void:
	var state = get_state_space_vector()
	state_space_updated.emit(state)

func _trigger_intervention(action_type: String, description: String, duration: float = 5.0) -> void:
	intervention_cooldowns[action_type] = Time.get_ticks_msec()
	director_intervention_triggered.emit(action_type, description)
	match action_type:
		"block_dash":
			dash_disabled_active = true
			speed_debuff_active = true
			await get_tree().create_timer(duration).timeout
			dash_disabled_active = false
			speed_debuff_active = false
		"slow_movement":
			speed_debuff_active = true
			await get_tree().create_timer(duration).timeout
			speed_debuff_active = false
		"reduce_damage":
			damage_debuff_active = true
			await get_tree().create_timer(duration).timeout
			damage_debuff_active = false
	_evaluate_state_space()

func _is_on_cooldown(action: String, cooldown_sec: float) -> bool:
	if not intervention_cooldowns.has(action):
		return false
	var elapsed = (Time.get_ticks_msec() - intervention_cooldowns[action]) / 1000.0
	return elapsed < cooldown_sec

# ---------------------------------------------------------------------------
# LLM / Roasting Dialogue
# ---------------------------------------------------------------------------
func request_boss_dialogue(trigger_type: String) -> void:
	if mock_mode or gemini_api_key.is_empty():
		_dispatch_mock_dialogue(trigger_type)
		return
	_query_gemini(trigger_type)

func _dispatch_mock_dialogue(trigger_type: String) -> void:
	var lines = MOCK_BOSS_LINES.get(trigger_type, MOCK_BOSS_LINES["boss_intro"])
	var chosen = lines[randi() % lines.size()]
	await get_tree().create_timer(0.2).timeout
	boss_dialogue_generated.emit(chosen, trigger_type)

func _query_gemini(trigger_type: String) -> void:
	var state = get_state_space_vector()
	var prompt = "You are the Dark Wizard boss in 'Skill Issue'. " \
		+ "The player just triggered habit: " + trigger_type + ". " \
		+ "Player Telemetry: " + JSON.stringify(state) + ". " \
		+ "Deliver a ruthless, sarcastic, short 1-sentence roast (under 12 words). No quotes."
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + gemini_api_key
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"contents": [{ "parts": [{"text": prompt}] }]
	})
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			var text = data["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
			boss_dialogue_generated.emit(text, "gemini_live")
			return
	_dispatch_mock_dialogue("boss_intro")

# ---------------------------------------------------------------------------
# Internal Profile Updates
# ---------------------------------------------------------------------------
func _update_aggression() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _session_start
	if elapsed < 5.0:
		return
	var kpm: float = (float(kills) / elapsed) * 60.0
	var was: bool = is_aggressive
	is_aggressive = kpm >= AGGRESSIVE_KILLS_PER_MINUTE
	if is_aggressive and not was:
		print("[AIDirector] → AGGRESSIVE (%.1f kills/min)" % kpm)
		if not _signals_fired.get("aggressive", false):
			emit_signal("player_is_aggressive")
			_signals_fired["aggressive"] = true

func _update_retreater() -> void:
	var was: bool = is_retreater
	is_retreater = retreat_time >= RETREATER_TIME_THRESHOLD
	if is_retreater and not was:
		print("[AIDirector] → RETREATER (%.1fs running)" % retreat_time)
		if not _signals_fired.get("retreater", false):
			emit_signal("player_is_retreater")
			_signals_fired["retreater"] = true

func _check_dodge_pattern() -> void:
	var max_dir: String = ""
	var max_count: int = 0
	for dir in dodge_counts:
		if dodge_counts[dir] > max_count:
			max_count = dodge_counts[dir]
			max_dir = dir
	if max_count >= MIN_DODGES_FOR_PATTERN and dominant_dodge != max_dir:
		dominant_dodge = max_dir
		print("[AIDirector] → DODGE PATTERN: '%s' (%d times)" % [dominant_dodge, max_count])
		emit_signal("player_dodge_pattern_detected", dominant_dodge)

func _check_rhythm() -> void:
	if attack_timestamps.size() < MIN_ATTACKS_FOR_RHYTHM:
		return
	var intervals: Array[float] = []
	for i in range(1, attack_timestamps.size()):
		intervals.append(attack_timestamps[i] - attack_timestamps[i - 1])
	var mean: float = 0.0
	for v in intervals:
		mean += v
	mean /= float(intervals.size())
	var variance: float = 0.0
	for v in intervals:
		variance += (v - mean) * (v - mean)
	variance /= float(intervals.size())
	var std_dev: float = sqrt(variance)
	var was: bool = attack_is_rhythmic
	attack_is_rhythmic = std_dev < RHYTHM_VARIANCE_THRESHOLD
	if attack_is_rhythmic and not was:
		print("[AIDirector] → ATTACK RHYTHM detected (std_dev: %.3f)" % std_dev)
		if not _signals_fired.get("rhythm", false):
			emit_signal("attack_rhythm_detected")
			_signals_fired["rhythm"] = true

func get_profile_summary() -> String:
	return "Kills:%d | Retreat:%.0fs | Dodge:%s | Aggro:%s | Retreat:%s | Rhythm:%s" % [
		kills, retreat_time, dominant_dodge if dominant_dodge != "" else "none",
		str(is_aggressive), str(is_retreater), str(attack_is_rhythmic)
	]
