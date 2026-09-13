extends CharacterBody2D
## BossEnemy — The Adaptive Final Boss.
##
## Scene setup in Godot:
##   BossEnemy (CharacterBody2D) ← attach this script
##   ├── CollisionShape2D         ← CapsuleShape or RectangleShape (80×80)
##   ├── BossPolygon (Polygon2D)  ← placeholder visual (large dark purple square)
##   ├── DialogueLabel (Label)    ← floats above boss, shows trash-talk
##   ├── HealthBar (ProgressBar)  ← anchored top-center, shows HP
##   └── AoeIndicator (Polygon2D) ← circle hint shown before AoE (optional)
##
## State machine:
##   MONOLOGUE → OBSERVING → AGGRESSIVE → ADAPTIVE → ENRAGED (HP < 25%)
##
## AIDirector integration:
##   Reads: dominant_dodge, is_retreater, attack_is_rhythmic, is_aggressive
##   Reacts with movement, attack choice, and trash-talk dialogue.

signal died

# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------
enum State { MONOLOGUE, OBSERVING, AGGRESSIVE, ADAPTIVE, ENRAGED }

var state: State = State.MONOLOGUE

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------
@export var max_health: float  = 300.0
@export var base_speed: float  = 110.0

var health: float = 0.0

# ---------------------------------------------------------------------------
# Internal timers & flags
# ---------------------------------------------------------------------------
var _state_timer: float   = 0.0
var _phase_timer: float   = 0.0   # Resets within a state for periodic actions
var _attack_cd: float     = 0.0
var _aoe_cd: float        = 0.0
var _dodge_anticipation: String = ""
var _said: Dictionary = {}        # Prevents repeating the same trash-talk category
var _mono_index: int = 0

var _target: Node2D = null

# ---------------------------------------------------------------------------
# Dialogue content
# ---------------------------------------------------------------------------
const MONOLOGUE: Array[String] = [
	"Every monster you've killed...",
	"...every mistake you've made...",
	"...I've been learning.",
	"Let's see if you've learned anything.",
]

const TRASH_TALK: Dictionary = {
	"dodge_pattern": [
		"You always dodge that way.",
		"I told you.",
		"Predictable.",
	],
	"retreater": [
		"Are you planning to fight me, or just exercise?",
		"Running won't save you.",
		"Come back. I'm not done with you.",
	],
	"rhythm": [
		"You're becoming predictable.",
		"I can set a clock to your attacks.",
		"Same timing. Every. Single. Time.",
	],
	"aggressive": [
		"Brave. Stupid. But brave.",
		"You fight like you have nothing to lose.",
		"Speed isn't everything.",
	],
	"enrage": [
		"Enough games.",
		"No more holding back.",
		"NOW you'll see what I've learned.",
	],
}

# ---------------------------------------------------------------------------
# Node refs
# ---------------------------------------------------------------------------
@onready var dialogue_label: Label       = $DialogueLabel
@onready var health_bar: ProgressBar     = $HealthBar
@onready var boss_poly: Polygon2D        = $BossPolygon
var _hp_bar_fill: ColorRect = null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	health = max_health
	_target = get_tree().get_first_node_in_group("player")
	_setup_health_bar()

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = health
		health_bar.visible   = false   # Hidden during monologue
		health_bar.position  = Vector2(-60, -110)
		health_bar.size      = Vector2(120, 16)

	if dialogue_label:
		dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialogue_label.position = Vector2(-150, -80)
		dialogue_label.size     = Vector2(300, 40)

	# Visuals: Use dark_wizard.png if asset exists, otherwise fallback
	if ResourceLoader.exists("res://assets/dark_wizard.png"):
		var spr = Sprite2D.new()
		spr.name = "BossSprite"
		var tex = load("res://assets/dark_wizard.png") as Texture2D
		if tex:
			spr.texture = tex
			var s: float = 72.0 / float(max(1, tex.get_height()))
			spr.scale = Vector2(s, s)
		add_child(spr)
	elif ResourceLoader.exists("res://assets/wizard_boss/boss-cloak.png"):
		var spr = Sprite2D.new()
		spr.name = "BossSprite"
		spr.texture = load("res://assets/wizard_boss/boss-cloak.png")
		spr.scale = Vector2(2.0, 2.0)
		add_child(spr)
	elif not boss_poly:
		boss_poly = Polygon2D.new()
		boss_poly.name = "BossPolygon"
		boss_poly.polygon = PackedVector2Array([
			Vector2(-36, -36), Vector2(36, -36),
			Vector2(36, 36),   Vector2(-36, 36)
		])
		boss_poly.color = Color(0.35, 0.1, 0.55)
		add_child(boss_poly)

	_start_monologue()

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_state_timer += delta
	_phase_timer += delta

	match state:
		State.MONOLOGUE:
			pass   # Timer-driven, see _start_monologue
		State.OBSERVING:
			_do_observing(delta)
		State.AGGRESSIVE:
			_do_aggressive(delta)
		State.ADAPTIVE:
			_do_adaptive(delta)
		State.ENRAGED:
			_do_enraged(delta)

func _physics_process(_delta: float) -> void:
	if state == State.MONOLOGUE:
		return
	move_and_slide()

# ---------------------------------------------------------------------------
# States
# ---------------------------------------------------------------------------

func _do_observing(delta: float) -> void:
	_circle_target(80.0)
	_attack_cd -= delta
	if _state_timer >= 4.5:
		_adapt_to_profile()
		_change_state(State.AGGRESSIVE)

func _do_aggressive(delta: float) -> void:
	_move_toward_target(base_speed)
	_try_melee(delta)
	_check_enrage()
	if _state_timer >= 6.0:
		_change_state(State.ADAPTIVE)

func _do_adaptive(delta: float) -> void:
	_adapt_to_profile()
	_execute_adaptive()
	_try_melee(delta)
	_check_enrage()
	if _state_timer >= 9.0:
		_change_state(State.OBSERVING)

func _do_enraged(delta: float) -> void:
	_move_toward_target(base_speed * 1.85)
	_try_melee(delta)
	_try_aoe(delta)

# ---------------------------------------------------------------------------
# Behavior helpers
# ---------------------------------------------------------------------------

func _adapt_to_profile() -> void:
	var dir: String = AIDirector.dominant_dodge
	if dir != "" and not _said.get("dodge_" + dir, false):
		_said["dodge_" + dir] = true
		_dodge_anticipation = dir
		_say("dodge_pattern")

	if AIDirector.is_retreater and not _said.get("retreater", false):
		_said["retreater"] = true
		_say("retreater")

	if AIDirector.attack_is_rhythmic and not _said.get("rhythm", false):
		_said["rhythm"] = true
		_say("rhythm")

	if AIDirector.is_aggressive and not _said.get("aggressive", false):
		_said["aggressive"] = true
		_say("aggressive")

func _execute_adaptive() -> void:
	if AIDirector.is_retreater:
		# Chase aggressively — don't let them run
		_move_toward_target(base_speed * 1.45)
	elif AIDirector.is_aggressive:
		# AoE punishes clustering
		_try_aoe(get_process_delta_time())
		_circle_target(75.0)
	elif _dodge_anticipation != "":
		_cut_off_dodge()
	else:
		_move_toward_target(base_speed * 0.85)

func _check_enrage() -> void:
	if health / max_health <= 0.25 and state != State.ENRAGED:
		_say("enrage")
		_change_state(State.ENRAGED)

func _change_state(new_state: State) -> void:
	state = new_state
	_state_timer = 0.0
	_phase_timer = 0.0
	print("[Boss] State → %s" % State.keys()[new_state])

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _move_toward_target(spd: float) -> void:
	if not _target:
		return
	velocity = (_target.global_position - global_position).normalized() * spd

func _circle_target(spd: float) -> void:
	if not _target:
		return
	var to: Vector2 = _target.global_position - global_position
	velocity = Vector2(-to.y, to.x).normalized() * spd

func _cut_off_dodge() -> void:
	if not _target:
		return
	var offsets: Dictionary = {
		"left": Vector2(-130, 0), "right": Vector2(130, 0),
		"up":   Vector2(0, -130), "down":  Vector2(0, 130),
	}
	var off: Vector2 = offsets.get(_dodge_anticipation, Vector2.ZERO)
	var goal: Vector2 = _target.global_position + off
	velocity = (goal - global_position).normalized() * base_speed * 1.3

# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _try_melee(delta: float) -> void:
	_attack_cd -= delta
	if _attack_cd > 0.0 or not _target:
		return
	if global_position.distance_to(_target.global_position) > 68.0:
		return

	_attack_cd = 1.1
	# React to rhythm: occasionally dodge before striking
	if AIDirector.attack_is_rhythmic and randf() < 0.45:
		velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 160.0
		print("[Boss] Dodged rhythmic attack!")
		return

	if _target.has_method("take_damage"):
		_target.take_damage(18.0)
	print("[Boss] Melee hit!")

func _try_aoe(delta: float) -> void:
	_aoe_cd -= delta
	if _aoe_cd > 0.0 or not _target:
		return
	if global_position.distance_to(_target.global_position) > 130.0:
		return
	_aoe_cd = 4.5
	if _target.has_method("take_damage"):
		_target.take_damage(22.0)
	print("[Boss] AoE slam!")
	_show_dialogue("Too close.")

# ---------------------------------------------------------------------------
# Damage / Death
# ---------------------------------------------------------------------------

func _setup_health_bar() -> void:
	if get_node_or_null("MobHealthBar"):
		return
	var bar_root = Node2D.new()
	bar_root.name = "MobHealthBar"
	bar_root.position = Vector2(0, -65)
	bar_root.z_index = 5
	add_child(bar_root)

	# Background dark box
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.position = Vector2(-32, -3)
	bg.size = Vector2(64, 6)
	bg.color = Color(0.06, 0.06, 0.08, 0.9)
	bar_root.add_child(bg)

	# Border
	var border = ReferenceRect.new()
	border.position = Vector2(-32, -3)
	border.size = Vector2(64, 6)
	border.border_color = Color(0.3, 0.3, 0.35, 0.9)
	border.border_width = 1.0
	border.editor_only = false
	bar_root.add_child(border)

	# Red Fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.name = "Fill"
	_hp_bar_fill.position = Vector2(-30, -2)
	_hp_bar_fill.size = Vector2(60, 4)
	_hp_bar_fill.color = Color(0.95, 0.18, 0.18, 0.95)
	bar_root.add_child(_hp_bar_fill)

func _update_health_bar() -> void:
	if _hp_bar_fill and is_instance_valid(_hp_bar_fill):
		var ratio = clamp(health / max(1.0, max_health), 0.0, 1.0)
		_hp_bar_fill.size.x = ratio * 60.0

func take_damage(amount: float) -> void:
	health -= amount
	_update_health_bar()
	if health_bar:
		health_bar.value = health
	# Flash
	var spr = get_node_or_null("BossSprite")
	if spr:
		spr.modulate = Color.RED
		await get_tree().create_timer(0.07).timeout
		if is_instance_valid(spr):
			spr.modulate = Color.WHITE
	elif boss_poly:
		boss_poly.color = Color.WHITE
		await get_tree().create_timer(0.07).timeout
		if is_instance_valid(boss_poly):
			boss_poly.color = Color(0.35, 0.1, 0.55)
	print("[Boss] %.0f dmg → HP %.0f/%.0f" % [amount, health, max_health])
	if health <= 0.0:
		_die()

func _die() -> void:
	_show_dialogue("...Well played.")
	emit_signal("died")
	await get_tree().create_timer(2.5).timeout
	queue_free()

# ---------------------------------------------------------------------------
# Monologue
# ---------------------------------------------------------------------------

func _start_monologue() -> void:
	state = State.MONOLOGUE
	if health_bar:
		health_bar.visible = false
	_deliver_next_line()

func _deliver_next_line() -> void:
	if _mono_index >= MONOLOGUE.size():
		_end_monologue()
		return
	var line: String = MONOLOGUE[_mono_index]
	_mono_index += 1
	_show_dialogue(line)
	print("[Boss] 🗣  %s" % line)
	await get_tree().create_timer(2.6).timeout
	_deliver_next_line()

func _end_monologue() -> void:
	_show_dialogue("")
	if health_bar:
		health_bar.visible = true
	_change_state(State.OBSERVING)
	print("[Boss] Monologue complete. Fight begins.")

# ---------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------

func _show_dialogue(text: String) -> void:
	if not dialogue_label:
		return
	dialogue_label.text = text
	if text == "":
		return
	# Auto-clear after 3s (non-blocking)
	var t: float = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(3.2).timeout
	# Only clear if the label still shows this exact text
	if dialogue_label and dialogue_label.text == text:
		dialogue_label.text = ""

func _say(category: String) -> void:
	if not category in TRASH_TALK:
		return
	var pool: Array = TRASH_TALK[category]
	var line: String = pool[randi() % pool.size()]
	_show_dialogue(line)
	print("[Boss] 💬  %s" % line)
