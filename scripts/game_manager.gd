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
		_room_container = get_parent().get_node_or_null("RoomContainer")
	if not _room_container:
		push_error("[GameManager] RoomContainer not found!")
		return
	load_room(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			print("[GameManager] Debug (F2): Skipping to next room!")
			_on_room_completed()
		elif event.keycode == KEY_F3:
			print("[GameManager] Debug (F3): Killing all enemies in room!")
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.has_method("_die"):
					e._die()
				elif e.has_method("take_damage"):
					e.take_damage(9999.0)
		elif event.keycode == KEY_R:
			print("[GameManager] Restarting current run (R)...")
			var p = get_tree().get_first_node_in_group("player")
			if p and is_instance_valid(p) and p.has_method("reset_state"):
				p.reset_state()
			load_room(0)

## Load a room by index (0-4).
func load_room(index: int) -> void:
	var path: String = _find_room_path(index)
	if path == "":
		print("[GameManager] ✓ All rooms complete!")
		return

	current_room_index = index

	# If restarting from room 0, ensure player is fully restored
	if index == 0:
		var p = get_tree().get_first_node_in_group("player")
		if p and is_instance_valid(p) and p.has_method("reset_state"):
			p.reset_state()

	# Clear previous room
	if _current_room_instance and is_instance_valid(_current_room_instance):
		_current_room_instance.queue_free()
		_current_room_instance = null

	var scene = load(path)
	if scene == null:
		push_error("[GameManager] Could not load: %s" % path)
		return

	_current_room_instance = scene.instantiate()
	_room_container.add_child(_current_room_instance)

	if _current_room_instance.has_signal("room_completed"):
		_current_room_instance.room_completed.connect(_on_room_completed)

	print("[GameManager] Room %d loaded: %s" % [index, path])

func _find_room_path(index: int) -> String:
	var options: Array[Array] = [
		["res://Scenes/enemies/room_1_tutorial.tscn", "res://scenes/rooms/Room1_Tutorial.tscn", "res://Scenes/rooms/Room1_Tutorial.tscn", "res://Scenes/Room1_Tutorial.tscn"],
		["res://Scenes/enemies/room_2_icy.tscn", "res://scenes/rooms/Room2_Icy.tscn", "res://scenes/rooms/Room2_IcyFloor.tscn", "res://Scenes/rooms/Room2_Icy.tscn"],
		["res://Scenes/enemies/room_3_faster.tscn", "res://scenes/rooms/Room3_Faster.tscn", "res://scenes/rooms/Room3_FasterEnemies.tscn", "res://Scenes/rooms/Room3_Faster.tscn"],
		["res://Scenes/enemies/room_4_director.tscn", "res://scenes/rooms/Room4_Director.tscn", "res://Scenes/rooms/Room4_Director.tscn"],
		["res://Scenes/enemies/room_5_boss.tscn", "res://scenes/rooms/Room5_Boss.tscn", "res://Scenes/rooms/Room5_Boss.tscn"],
	]
	if index < 0 or index >= options.size():
		return ""
	for p in options[index]:
		if ResourceLoader.exists(p):
			return p
	return ""

func _on_room_completed() -> void:
	print("[GameManager] Room %d complete. Next room in 1.5s..." % current_room_index)
	await get_tree().create_timer(1.5).timeout
	load_room(current_room_index + 1)
