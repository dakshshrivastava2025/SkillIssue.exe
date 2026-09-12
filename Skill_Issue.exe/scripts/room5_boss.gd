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
		# === OUTER COLOSSEUM STONE WALLS ===
		# Top arch wall (narrower — pillars sit at corners)
		Rect2(0,    -270, 700,  65),  # Top arch centre
		Rect2(0,     275, 800,  65),  # Bottom wall
		Rect2(-510,  -20,  65, 530),  # Left outer stone wall (extended to reach bottom)
		Rect2( 510,  -20,  65, 530),  # Right outer stone wall (extended to reach bottom)
		# Top-Left corner pillar cluster
		Rect2(-430, -195, 180,  65),
		Rect2(-475, -150,  65, 110),
		# Top-Right corner pillar cluster
		Rect2( 430, -195, 180,  65),
		Rect2( 475, -150,  65, 110),
		# Bottom-Left corner seal (closes the gap between side wall and bottom wall)
		Rect2(-440,  240, 140,  65),
		# Bottom-Right corner seal
		Rect2( 440,  240, 140,  65),
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
