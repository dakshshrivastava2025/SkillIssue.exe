extends Control

## HUD Controller: Displays HP, Live AI Director Prompts,
## Active Debuff Badges, Boss Dialogue, and Full Death Screen.

@onready var player_hp_bar: ProgressBar = $HUD/PlayerHPBar
@onready var boss_hp_bar: ProgressBar = $HUD/BossHPBar
@onready var status_label: Label = $HUD/StatusLabel

# AI Director On-Screen Prompts & Dialogue
@onready var prompt_box: PanelContainer = $AIDirectorPrompt
@onready var prompt_label: Label = $AIDirectorPrompt/MarginContainer/PromptText

@onready var debuff_container: HBoxContainer = $HUD/DebuffContainer
@onready var dash_debuff_pill: PanelContainer = $HUD/DebuffContainer/DashDebuff
@onready var speed_debuff_pill: PanelContainer = $HUD/DebuffContainer/SpeedDebuff
@onready var damage_debuff_pill: PanelContainer = $HUD/DebuffContainer/DamageDebuff

@onready var dialogue_box: PanelContainer = $BossDialogue
@onready var dialogue_label: RichTextLabel = $BossDialogue/MarginContainer/DialogueText

# Death Screen
@onready var death_screen: Control = $DeathScreen
@onready var retry_btn: Button = $DeathScreen/VBoxContainer/RetryButton

var prompt_tween: Tween
var dialogue_tween: Tween
var boss_target: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_box.visible = false
	dialogue_box.visible = false
	death_screen.visible = false
	
	if retry_btn:
		retry_btn.pressed.connect(_on_retry_pressed)
	
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		ai.director_intervention_triggered.connect(_on_director_intervention)
		ai.boss_dialogue_generated.connect(_on_boss_dialogue)
		ai.state_space_updated.connect(_on_state_updated)

func update_player_hp(curr: int, max_val: int) -> void:
	player_hp_bar.max_value = max_val
	player_hp_bar.value = curr
	if curr <= 0:
		_show_death_screen()

func update_boss_hp(curr: int, max_val: int) -> void:
	boss_hp_bar.max_value = max_val
	boss_hp_bar.value = curr
	if curr <= 0 and status_label:
		status_label.text = "BOSS DEFEATED! Open the chest to proceed."

func _show_death_screen() -> void:
	death_screen.visible = true
	get_tree().paused = true
	if status_label:
		status_label.text = "YOU HAVE FALLEN"

func _on_retry_pressed() -> void:
	get_tree().paused = false
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		ai.reset_full_session()
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if death_screen.visible and event is InputEventKey and event.keycode == KEY_R and event.pressed:
		_on_retry_pressed()

func _on_director_intervention(action_name: String, description: String) -> void:
	prompt_box.visible = true
	prompt_label.text = "⚡ " + description
	
	prompt_box.modulate = Color(1.8, 0.4, 0.4, 0.0)
	
	if prompt_tween:
		prompt_tween.kill()
	prompt_tween = create_tween()
	# Smooth fade-in
	prompt_tween.tween_property(prompt_box, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
	prompt_tween.tween_interval(4.0)
	# Smooth fade-out
	prompt_tween.tween_property(prompt_box, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	prompt_tween.tween_callback(func(): prompt_box.visible = false)

func _on_boss_dialogue(text: String, _trigger: String) -> void:
	dialogue_box.visible = true
	dialogue_label.text = "[center][b][color=#ff5566]DARK WIZARD:[/color][/b] [color=#ffffff]\"" + text + "\"[/color][/center]"
	dialogue_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
	
	if dialogue_tween:
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	# Smooth subtitle fade-in
	dialogue_tween.tween_property(dialogue_box, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	dialogue_tween.tween_interval(4.5)
	# Smooth subtitle fade-out
	dialogue_tween.tween_property(dialogue_box, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)


func _on_state_updated(state: Dictionary) -> void:
	var debuffs = state.get("active_debuffs", {})
	
	# Distinct glowing status pill badges
	if dash_debuff_pill:
		dash_debuff_pill.visible = debuffs.get("dash_disabled", false)
	if speed_debuff_pill:
		speed_debuff_pill.visible = debuffs.get("speed_debuff", false)
	if damage_debuff_pill:
		damage_debuff_pill.visible = debuffs.get("damage_debuff", false)

