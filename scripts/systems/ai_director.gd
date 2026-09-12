extends Node
class_name AIDirectorNode

## AIDirector: Singleton managing State-Space telemetry, dynamic interventions,
## and real-time LLM trash-talk dialogue generation.

signal state_space_updated(state_vector: Dictionary)
signal director_intervention_triggered(action_name: String, description: String)
signal boss_dialogue_generated(text: String, trigger_type: String)

# --- 1. Raw Telemetry Data ---
var player_kills: int = 0
var damage_dealt_total: float = 0.0
var damage_taken_total: float = 0.0
var damage_taken_recent: float = 0.0
var missed_attacks: int = 0
var hit_attacks: int = 0
var consecutive_misses: int = 0

var dodge_counts = {"left": 0, "right": 0, "up": 0, "down": 0}
var total_retreat_time: float = 0.0
var retreat_timer_streak: float = 0.0

var current_room: int = 1

# --- 2. Derived State Profile ---
var dominant_dodge: String = ""
var is_retreater: bool = false

# --- 3. Dynamic Gameplay Modifiers ---
var speed_debuff_active: bool = false       # -35% movement speed
var damage_debuff_active: bool = false      # -35% attack damage
var controls_inverted: bool = false         # Inverted controls

# --- 4. LLM Configuration ---
@export var gemini_api_key: String = ""
@export var mock_mode: bool = true
var http_request: HTTPRequest

var intervention_cooldowns: Dictionary = {}

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
		"You spent 15 seconds running away. Legs weighed down: -35% SPEED!",
		"Cowards don't get full movement speed in my arena."
	],
	"miss_streak": [
		"5 missed attacks in a row. Attack power suppressed: -35% DAMAGE!",
		"Are you trying to hit the floor tiles? Try aiming."
	],
	"boss_intro": [
		"Welcome to the arena. Every habit you have will be used against you."
	]
}

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	reset_session_modifiers()

func reset_session_modifiers() -> void:
	speed_debuff_active = false
	damage_debuff_active = false
	controls_inverted = false
	consecutive_misses = 0
	retreat_timer_streak = 0.0
	intervention_cooldowns.clear()

# --- Telemetry Ingestion with Higher Statistical Thresholds ---
func record_kill() -> void:
	player_kills += 1
	_evaluate_state_space()

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
	if dodge_counts.has(direction):
		dodge_counts[direction] += 1
		
	var total_dodges = dodge_counts["left"] + dodge_counts["right"] + dodge_counts["up"] + dodge_counts["down"]
	
	# High threshold (10+ dodges, >= 70% bias) to establish genuine habit
	if total_dodges >= 10:
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
	total_retreat_time += delta
	retreat_timer_streak += delta
	
	if retreat_timer_streak >= 14.0 and not _is_on_cooldown("retreater", 22.0):
		is_retreater = true
		retreat_timer_streak = 0.0
		_trigger_intervention("slow_movement", "Chronic Retreating: -35% Movement Speed for 6s!")
		request_boss_dialogue("retreater")

func record_damage_taken(amount: float) -> void:
	damage_taken_total += amount
	damage_taken_recent += amount
	_evaluate_state_space()
	get_tree().create_timer(6.0).timeout.connect(func(): damage_taken_recent = max(0, damage_taken_recent - amount))

# --- State-Space Vector Formulation ---
func get_state_space_vector() -> Dictionary:
	var total_attacks = max(1, hit_attacks + missed_attacks)
	var accuracy = float(hit_attacks) / float(total_attacks)
	
	return {
		"room": current_room,
		"kills": player_kills,
		"accuracy_pct": round(accuracy * 100.0),
		"dominant_dodge": dominant_dodge if dominant_dodge != "" else "none",
		"retreat_time_sec": round(total_retreat_time),
		"consecutive_misses": consecutive_misses,
		"active_debuffs": {
			"speed_debuff": speed_debuff_active,
			"damage_debuff": damage_debuff_active,
			"controls_inverted": controls_inverted
		}
	}

func _evaluate_state_space() -> void:
	var state = get_state_space_vector()
	state_space_updated.emit(state)

# --- Interventions ---
func _trigger_intervention(action_type: String, description: String, duration: float = 5.0) -> void:
	intervention_cooldowns[action_type] = Time.get_ticks_msec()
	director_intervention_triggered.emit(action_type, description)
	
	match action_type:
		"slow_movement":
			speed_debuff_active = true
			await get_tree().create_timer(duration).timeout
			speed_debuff_active = false
		"reduce_damage":
			damage_debuff_active = true
			await get_tree().create_timer(duration).timeout
			damage_debuff_active = false
		"invert_controls":
			controls_inverted = true
			await get_tree().create_timer(duration).timeout
			controls_inverted = false
			
	_evaluate_state_space()

func _is_on_cooldown(action: String, cooldown_sec: float) -> bool:
	if not intervention_cooldowns.has(action):
		return false
	var elapsed = (Time.get_ticks_msec() - intervention_cooldowns[action]) / 1000.0
	return elapsed < cooldown_sec

# --- LLM Dialogue ---
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

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			var text = data["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
			boss_dialogue_generated.emit(text, "gemini_live")
			return
	_dispatch_mock_dialogue("boss_intro")
