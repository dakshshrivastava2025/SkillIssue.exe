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

func _get_room_foreground_path() -> String:
	return "res://assets/room5_foreground.png"

func _get_wall_colliders() -> Array[Rect2]:
	return [
		# Outer circular arena walls
		Rect2(0, -290, 1100, 70),  # Top wall
		Rect2(0, 310, 1100, 70),   # Bottom wall
		Rect2(-540, 0, 70, 680),   # Left curved wall
		Rect2(540, 0, 70, 680),    # Right curved wall
		# 8 Colosseum Stone Pillars (Player hides behind them; foreground layer renders above player)
		Rect2(-460, -180, 70, 90), # Top-Left outer
		Rect2(-240, -230, 70, 90), # Top-Left inner
		Rect2(240, -230, 70, 90),  # Top-Right inner
		Rect2(460, -180, 70, 90),  # Top-Right outer
		Rect2(-460, 180, 70, 90),  # Bottom-Left outer
		Rect2(-240, 230, 70, 90),  # Bottom-Left inner
		Rect2(240, 230, 70, 90),   # Bottom-Right inner
		Rect2(460, 180, 70, 90),   # Bottom-Right outer
	]

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
