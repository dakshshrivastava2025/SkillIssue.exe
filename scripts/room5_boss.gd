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

## Spawn the player at the center of the ritual circle, not near the bottom wall
func _get_player_spawn_position() -> Vector2:
	return Vector2(-20, 0)

## Remove the tunneling archways for the boss in the last level
func _should_have_archway_tunnels() -> bool:
	return false

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
	if not boss:
		boss = get_node_or_null("Boss")
	if boss:
		# Boss exists in scene — reposition it to the upper portion of the magic circle
		boss.position = Vector2(0, -200)
		register_enemy(boss)
	else:
		var boss_paths = [
			"res://Scenes/enemies/boss_enemy.tscn",
			"res://scenes/boss.tscn",
			"res://scenes/enemies/boss_enemy.tscn"
		]
		for bp in boss_paths:
			if ResourceLoader.exists(bp):
				var BossScene = load(bp)
				if BossScene:
					var b = BossScene.instantiate()
					b.name = "Boss"
					b.global_position = global_position + Vector2(0, -200)
					add_child(b)
					register_enemy(b)
					break
