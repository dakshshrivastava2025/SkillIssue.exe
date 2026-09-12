extends Control

## Clean HUD for Core 2D Boss Battle

@onready var player_hp_bar: ProgressBar = $HUD/PlayerHPBar
@onready var boss_hp_bar: ProgressBar = $HUD/BossHPBar
@onready var status_label: Label = $HUD/StatusLabel

func _ready() -> void:
	if status_label:
		status_label.text = "DEFEAT THE BOSS"

func update_player_hp(curr: int, max_val: int) -> void:
	player_hp_bar.max_value = max_val
	player_hp_bar.value = curr
	if curr <= 0 and status_label:
		status_label.text = "YOU DIED (Press R to Restart)"

func update_boss_hp(curr: int, max_val: int) -> void:
	boss_hp_bar.max_value = max_val
	boss_hp_bar.value = curr
	if curr <= 0 and status_label:
		status_label.text = "BOSS DEFEATED!"
