extends Node

## LLMConnector interfaces with Generative AI / Gemini API to fetch dynamic
## psychological gaslighting dialogue based on live telemetry snapshots.
## Includes built-in mock fallback for offline/instant playability.

signal dialogue_generated(dialogue: String, mood: String)

@export var api_key: String = ""
@export var mock_mode: bool = true # Default to true so game runs without API keys

var http_request: HTTPRequest

const MOCK_GASLIGHT_LINES = {
	"jump_spam": [
		"Gravity is a privilege, mortal, not a right.",
		"You have jumped 5 times without hitting anything. Are you practicing gymnastics or dying?",
		"The floor isn't lava, but your decision making definitely is."
	],
	"left_dodge_bias": [
		"Fun fact: Your right arrow key still works. I checked.",
		"Dodging to the left every single time is not a strategy; it's a personality flaw.",
		"Keep rolling left. There's a wall and your inevitable defeat waiting there."
	],
	"right_dodge_bias": [
		"Always running right? You can't outrun your incompetence.",
		"Right again? How predictably tragic."
	],
	"miss_streak": [
		"You missed 4 attacks in a row. Is this a strategy or a tradition?",
		"Did you want me to stand still so you could feel a sense of achievement?",
		"My hitboxes are right here. Are you fighting my shadow or your inner demons?"
	],
	"panic_hp": [
		"Look at that health bar shake. Almost feels unfair, doesn't it?",
		"Error 404: Skill Not Found. Would you like to submit a bug report?",
		"I'm considering reducing my difficulty, but you'd probably miss that setting too."
	],
	"generic": [
		"I am rewriting your keyboard mapping in real-time. Good luck.",
		"The pause button won't save you.",
		"Did you really think this fight had fair rules?"
	]
}

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# Connect to TelemetryManager habit events
	if TelemetryManager:
		TelemetryManager.habit_detected.connect(_on_habit_detected)

func _on_habit_detected(habit_name: String, details: Dictionary) -> void:
	request_gaslight_dialogue(habit_name, details)

func request_gaslight_dialogue(trigger_type: String, details: Dictionary = {}) -> void:
	if mock_mode or api_key.is_empty():
		_dispatch_mock_dialogue(trigger_type)
		return
	
	_query_gemini_api(trigger_type, details)

func _dispatch_mock_dialogue(trigger_type: String) -> void:
	var lines = MOCK_GASLIGHT_LINES.get(trigger_type, MOCK_GASLIGHT_LINES["generic"])
	var chosen_line = lines[randi() % lines.size()]
	
	# Small simulated delay to feel organic
	await get_tree().create_timer(0.4).timeout
	dialogue_generated.emit(chosen_line, trigger_type)

func _query_gemini_api(trigger_type: String, details: Dictionary) -> void:
	var snapshot = TelemetryManager.get_telemetry_snapshot()
	var prompt = "You are 'G.A.B.' (Gaslighting AI Boss), a malicious, sarcastic, condescending AI boss in a 2D game. " \
		+ "The player just triggered habit: " + trigger_type + " with details: " + JSON.stringify(details) + ". " \
		+ "Player telemetry: " + JSON.stringify(snapshot) + ". " \
		+ "Generate a SINGLE short, razor-sharp, mocking, 4th-wall-breaking gaslighting sentence (maximum 15 words). Do not include quotes."
	
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + api_key
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"contents": [{
			"parts": [{"text": prompt}]
		}]
	})
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var data = json.get_data()
			var text = data["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
			dialogue_generated.emit(text, "llm_live")
			return
	
	# Fallback if API fails
	_dispatch_mock_dialogue("generic")
