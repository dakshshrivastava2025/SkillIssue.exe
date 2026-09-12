extends Control

## HUD Controller: Displays HP, Live AI Director Prompts,
## Active Debuff Badges, Boss Dialogue, and Full Death Screen.

@onready var player_hp_bar: ProgressBar = $HUD/PlayerHPBar
@onready var boss_hp_bar: ProgressBar = $HUD/BossHPBar
@onready var status_label: Label = $HUD/StatusLabel

# AI Director On-Screen Prompts & Dialogue
@onready var prompt_box: PanelContainer = $AIDirectorPrompt
@onready var prompt_label: Label = $AIDirectorPrompt/MarginContainer/PromptText
@onready var debuff_badge: Label = $HUD/DebuffBadge
@onready var dialogue_box: PanelContainer = $BossDialogue
@onready var dialogue_label: RichTextLabel = $BossDialogue/MarginContainer/DialogueText

# Death Screen
@onready var death_screen: Control = $DeathScreen
@onready var retry_btn: Button = $DeathScreen/VBoxContainer/RetryButton

var prompt_tween: Tween
var dialogue_tween: Tween

func _ready() -> void:
	prompt_box.visible = false
	dialogue_box.visible = false
	debuff_badge.visible = false
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
	if status_label:
		status_label.text = "YOU HAVE FALLEN"

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_director_intervention(action_name: String, description: String) -> void:
	prompt_box.visible = true
	prompt_label.text = "⚡ [AI DIRECTOR INTERVENTION]\n" + description
	
	prompt_box.modulate = Color(2.0, 0.4, 0.4, 1.0)
	
	if prompt_tween:
		prompt_tween.kill()
	prompt_tween = create_tween()
	prompt_tween.tween_property(prompt_box, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	prompt_tween.tween_interval(5.0)
	prompt_tween.tween_callback(func(): prompt_box.visible = false)

func _on_boss_dialogue(text: String, _trigger: String) -> void:
	dialogue_box.visible = true
	dialogue_label.text = "[b][color=#ff4444]DARK WIZARD:[/color][/b] " + text
	
	if dialogue_tween:
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_interval(5.0)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)

func _on_state_updated(state: Dictionary) -> void:
	var debuffs = state.get("active_debuffs", {})
	var active_list = []
	if debuffs.get("speed_debuff", false):
		active_list.append("[-45% SPEED]")
	if debuffs.get("damage_debuff", false):
		active_list.append("[-50% DAMAGE]")
	if debuffs.get("controls_inverted", false):
		active_list.append("[CONTROLS INVERTED]")
	var dis_dir = debuffs.get("disabled_direction", "")
	if dis_dir != "":
		active_list.append("[" + dis_dir.to_upper() + " DISABLED]")
		
	if active_list.size() > 0:
		debuff_badge.text = "ACTIVE DEBUFFS: " + " | ".join(active_list)
		debuff_badge.visible = true
	else:
		debuff_badge.visible = false
