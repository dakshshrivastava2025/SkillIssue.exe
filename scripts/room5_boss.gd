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

func _listen_to_boss_death() -> void:
	var boss = get_node_or_null("BossEnemy")
	if boss:
		# Boss exists in scene — reposition it to the upper portion of the magic circle
		boss.position = Vector2(0, -200)
		register_enemy(boss)
	else:
		var BossScene = load("res://Scenes/enemies/boss_enemy.tscn")
		if BossScene:
			var b = BossScene.instantiate()
			# Boss stands at the upper portion of the magic circle
			b.global_position = global_position + Vector2(0, -200)
			add_child(b)
			register_enemy(b)
