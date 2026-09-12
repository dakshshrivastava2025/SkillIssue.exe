extends Node2D

@onready var player: Player = $Player
@onready var boss: BossController = $Boss
@onready var hud: Control = $CanvasLayer/HUDController

func _ready() -> void:
	if player:
		player.health_changed.connect(hud.update_player_hp)
	if boss:
		boss.boss_health_changed.connect(hud.update_boss_hp)
