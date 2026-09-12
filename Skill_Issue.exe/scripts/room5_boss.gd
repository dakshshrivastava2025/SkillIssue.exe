extends "res://scripts/room_base.gd"
## Room 5 — Boss Arena: "The Adaptive Boss"

func _ready() -> void:
	room_name = "Room 5 — Final Boss Arena"
	super._ready()
	_listen_to_boss_death()

func _get_theme_floor_color() -> Color:
	return Color(0.15, 0.06, 0.22) # Dark Royal Purple Boss Floor

func _get_room_bg_path() -> String:
	return "res://assets/room5_bg.png"

func _listen_to_boss_death() -> void:
	var boss = get_node_or_null("BossEnemy")
	if boss:
		register_enemy(boss)
	else:
		var BossScene = load("res://Scenes/enemies/boss_enemy.tscn")
		if BossScene:
			var b = BossScene.instantiate()
			b.global_position = global_position
			add_child(b)
			register_enemy(b)
