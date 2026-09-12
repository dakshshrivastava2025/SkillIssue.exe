extends Node2D
## RoomBase — Base class for all rooms.
##
## Handles the enemy lifecycle:
##   1. Room is entered  → _apply_director_modifiers() then _spawn_enemies()
##   2. All enemies die  → emit room_completed signal
##
## Subclass each room and override _spawn_enemies() and _apply_director_modifiers().

signal room_completed

var room_name: String = "Base Room"
var _enemies: Array[Node] = []
var _room_active: bool = false

func _ready() -> void:
	_room_active = true
	print("[%s] Entered." % room_name)
	_apply_director_modifiers()
	_spawn_enemies()

# ---------------------------------------------------------------------------
# Override in subclasses
# ---------------------------------------------------------------------------

## Override to spawn enemies appropriate for this room.
func _spawn_enemies() -> void:
	pass

## Override to apply any Director-driven modifiers before enemies spawn.
func _apply_director_modifiers() -> void:
	pass

# ---------------------------------------------------------------------------
# Enemy tracking
# ---------------------------------------------------------------------------

## Register an enemy so the room tracks its death.
func register_enemy(enemy: Node) -> void:
	_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	else:
		push_warning("[RoomBase] Enemy '%s' has no 'died' signal — room may never complete." % enemy.name)

func _on_enemy_died(enemy: Node) -> void:
	_enemies.erase(enemy)
	print("[%s] Enemy died. Remaining: %d" % [room_name, _enemies.size()])
	if _enemies.is_empty() and _room_active:
		_on_all_enemies_dead()

func _on_all_enemies_dead() -> void:
	_room_active = false
	print("[%s] All enemies dead — room complete!" % room_name)
	emit_signal("room_completed")
