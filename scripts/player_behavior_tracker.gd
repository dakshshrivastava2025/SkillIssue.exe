extends Node
## PlayerBehaviorTracker — Attach as a child of the Player node.
##
## Automatically reports retreat behavior to AIDirector.
## The player script must call:
##   $PlayerBehaviorTracker.on_attack()           → every time an attack is made
##   $PlayerBehaviorTracker.on_dodge(direction)   → every time a dash/dodge happens
##                                                   direction: Vector2 (movement direction)

var _player: Node2D = null
var _nearest_enemy: Node2D = null
var _last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_player = get_parent()
	if _player:
		_last_position = _player.global_position
	print("[BehaviorTracker] Attached to player.")

func _physics_process(delta: float) -> void:
	if not _player:
		return
	_update_nearest_enemy()
	_track_retreat(delta)
	_last_position = _player.global_position

# ---------------------------------------------------------------------------
# Called by Player script
# ---------------------------------------------------------------------------

## Call this every time the player attacks (swing, shoot, etc.)
func on_attack() -> void:
	AIDirector.record_attack()

## Call this every time the player dodges / dashes.
## Pass the movement direction vector (e.g. input direction).
func on_dodge(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	AIDirector.record_dodge(_vec_to_dir(direction))

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _track_retreat(delta: float) -> void:
	if not _nearest_enemy:
		return
	var to_enemy: Vector2 = _nearest_enemy.global_position - _player.global_position
	var movement: Vector2 = _player.global_position - _last_position
	# Moving away from the nearest enemy = retreating
	if movement.length() > 1.5 and movement.dot(to_enemy) < 0.0:
		AIDirector.record_retreat(delta)

func _update_nearest_enemy() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var closest_dist: float = INF
	_nearest_enemy = null
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = _player.global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			_nearest_enemy = e

func _vec_to_dir(v: Vector2) -> String:
	if abs(v.x) >= abs(v.y):
		return "right" if v.x > 0.0 else "left"
	else:
		return "down" if v.y > 0.0 else "up"
