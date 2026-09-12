extends Node2D

@onready var player: Player = $Player
@onready var boss: BossController = $Boss
@onready var hud: Control = $CanvasLayer/HUDController

func _ready() -> void:
	if player:
		player.health_changed.connect(hud.update_player_hp)
	if boss:
		boss.boss_health_changed.connect(hud.update_boss_hp)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
		get_tree().reload_current_scene()
