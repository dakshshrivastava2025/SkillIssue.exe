extends Node
## GameManager — Manages room loading and transitions.
##
## Place this as an Autoload OR as a Node in Main.tscn.
## It loads rooms sequentially. When a room emits room_completed,
## it waits 1.5 seconds then loads the next room.

@export var room_container_path: NodePath = ^"RoomContainer"

const ROOM_PATHS: Array[String] = [
	"res://scenes/rooms/Room1_Tutorial.tscn",
	"res://scenes/rooms/Room2_IcyFloor.tscn",
	"res://scenes/rooms/Room3_FasterEnemies.tscn",
	"res://scenes/rooms/Room4_Director.tscn",
	"res://scenes/rooms/Room5_Boss.tscn",
]

var current_room_index: int = 0
var _room_container: Node2D = null
var _current_room_instance: Node = null

func _ready() -> void:
	_room_container = get_node_or_null(room_container_path)
	if not _room_container:
		push_error("[GameManager] RoomContainer not found at path: %s" % room_container_path)
		return
	load_room(0)

## Load a room by index (0-4).
func load_room(index: int) -> void:
	if index >= ROOM_PATHS.size():
		print("[GameManager] ✓ All rooms complete!")
		return

	current_room_index = index

	# Clear previous room
	if _current_room_instance and is_instance_valid(_current_room_instance):
		_current_room_instance.queue_free()
		_current_room_instance = null

	var path: String = ROOM_PATHS[index]
	var scene = load(path)
	if scene == null:
		push_error("[GameManager] Could not load: %s" % path)
		return

	_current_room_instance = scene.instantiate()
	_room_container.add_child(_current_room_instance)

	if _current_room_instance.has_signal("room_completed"):
		_current_room_instance.room_completed.connect(_on_room_completed)

	print("[GameManager] Room %d loaded: %s" % [index, path])

func _on_room_completed() -> void:
	print("[GameManager] Room %d complete. Next room in 1.5s..." % current_room_index)
	await get_tree().create_timer(1.5).timeout
	load_room(current_room_index + 1)
