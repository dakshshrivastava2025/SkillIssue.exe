extends Node
## AIDirector — Singleton (Autoload)
##
## The brain of the dungeon. Tracks player behavior in real-time and
## exposes a profile that rooms and the boss use to adapt difficulty.
##
## INTEGRATION (for the other dev):
##   Call AIDirector.record_kill()           → when player kills an enemy
##   Call AIDirector.record_attack()         → when player fires/swings
##   Call AIDirector.record_dodge(direction) → when player dashes ("left","right","up","down")
##   AIDirector.record_retreat(delta)        → called automatically by PlayerBehaviorTracker

# ---------------------------------------------------------------------------
# Signals — subscribe from rooms or boss
# ---------------------------------------------------------------------------
signal player_is_aggressive
signal player_is_retreater
signal player_dodge_pattern_detected(direction: String)
signal attack_rhythm_detected

# ---------------------------------------------------------------------------
# Raw tracking data
# ---------------------------------------------------------------------------
var kills: int = 0
var dodge_counts: Dictionary = {"left": 0, "right": 0, "up": 0, "down": 0}
var retreat_time: float = 0.0
var attack_timestamps: Array[float] = []

# ---------------------------------------------------------------------------
# Derived profile (recomputed every frame)
# ---------------------------------------------------------------------------
var dominant_dodge: String = ""
var is_aggressive: bool = false
var is_retreater: bool = false
var attack_is_rhythmic: bool = false

# ---------------------------------------------------------------------------
# Thresholds (tune these freely)
# ---------------------------------------------------------------------------
const AGGRESSIVE_KILLS_PER_MINUTE: float = 4.0
const RETREATER_TIME_THRESHOLD: float   = 12.0   # seconds retreating
const RHYTHM_VARIANCE_THRESHOLD: float  = 0.18   # seconds std-dev
const MIN_ATTACKS_FOR_RHYTHM: int       = 6
const MIN_DODGES_FOR_PATTERN: int       = 4

var _session_start: float = 0.0
var _signals_fired: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_session_start = Time.get_ticks_msec() / 1000.0
	print("[AIDirector] Ready. Watching the player...")

func _process(_delta: float) -> void:
	_update_aggression()
	_update_retreater()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Call when the player kills an enemy.
func record_kill() -> void:
	kills += 1
	print("[AIDirector] Kill #%d recorded." % kills)

## Call when the player attacks (swing, shoot, etc.)
func record_attack() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	attack_timestamps.append(t)
	if attack_timestamps.size() > 10:
		attack_timestamps.pop_front()
	_check_rhythm()

## Call when the player dodges. direction = "left" | "right" | "up" | "down"
func record_dodge(direction: String) -> void:
	if direction in dodge_counts:
		dodge_counts[direction] += 1
	_check_dodge_pattern()

## Call with delta when the player is moving away from the nearest enemy.
## PlayerBehaviorTracker handles this automatically.
func record_retreat(delta: float) -> void:
	retreat_time += delta

## Resets all tracking data (e.g. on new game).
func reset() -> void:
	kills = 0
	dodge_counts = {"left": 0, "right": 0, "up": 0, "down": 0}
	retreat_time = 0.0
	attack_timestamps.clear()
	dominant_dodge = ""
	is_aggressive  = false
	is_retreater   = false
	attack_is_rhythmic = false
	_signals_fired.clear()
	_session_start = Time.get_ticks_msec() / 1000.0
	print("[AIDirector] Reset.")

## Returns a one-line debug summary of the current profile.
func get_profile_summary() -> String:
	return "Kills:%d | Retreat:%.0fs | Dodge:%s | Aggro:%s | Retreat:%s | Rhythm:%s" % [
		kills, retreat_time, dominant_dodge if dominant_dodge != "" else "none",
		str(is_aggressive), str(is_retreater), str(attack_is_rhythmic)
	]

# ---------------------------------------------------------------------------
# Internal — profile updates
# ---------------------------------------------------------------------------

func _update_aggression() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _session_start
	if elapsed < 5.0:
		return  # Don't trigger too early
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
