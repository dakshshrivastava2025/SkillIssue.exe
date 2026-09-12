extends Node2D

@export var current_room: int = 1

@onready var player: Player = $Player
@onready var boss: BossController = $Boss
@onready var chest: TreasureChest = $TreasureChest
@onready var hud: Control = $CanvasLayer/HUDController
@onready var floor_rect: TextureRect = $ArenaVisual/FloorRect
@onready var wall_top: ColorRect = $ArenaVisual/WallTop
@onready var wall_bottom: ColorRect = $ArenaVisual/WallBottom
@onready var wall_left: ColorRect = $ArenaVisual/WallLeft
@onready var wall_right: ColorRect = $ArenaVisual/WallRight

# Room color themes for progressive difficulty
const ROOM_THEMES = [
	{ "floor": Color(0.85, 0.85, 0.9, 1.0), "wall": Color(0.12, 0.14, 0.2, 1.0), "name": "Room 1: The Crypt" },
	{ "floor": Color(0.9, 0.75, 0.75, 1.0), "wall": Color(0.25, 0.1, 0.1, 1.0), "name": "Room 2: The Blood Sanctum" },
	{ "floor": Color(0.75, 0.9, 0.8, 1.0), "wall": Color(0.08, 0.2, 0.15, 1.0), "name": "Room 3: The Abyssal Chamber" }
]

func _ready() -> void:
	_setup_room(current_room)
	
	if current_room == 1:
		var ai = get_node_or_null("/root/AIDirector")
		if ai:
			ai.reset_full_session()
	
	if player:
		player.health_changed.connect(hud.update_player_hp)
		hud.update_player_hp(player.current_health, player.max_health)
	if boss:
		boss.boss_health_changed.connect(hud.update_boss_hp)
		boss.boss_defeated.connect(_on_boss_defeated)
	if chest:
		chest.chest_opened.connect(_on_chest_opened)

func _setup_room(room_num: int) -> void:
	var theme_idx = (room_num - 1) % ROOM_THEMES.size()
	var theme = ROOM_THEMES[theme_idx]
	
	if floor_rect:
		floor_rect.modulate = theme["floor"]
	if wall_top:
		wall_top.color = theme["wall"]
		wall_bottom.color = theme["wall"]
		wall_left.color = theme["wall"]
		wall_right.color = theme["wall"]
		
	# Scale boss difficulty with room number
	if boss:
		boss.max_health = 600 + (room_num - 1) * 200
		boss.current_health = boss.max_health
		boss.base_speed = 220.0 + (room_num - 1) * 20.0
		hud.update_boss_hp(boss.current_health, boss.max_health)
		
	if hud and hud.has_node("HUD/StatusLabel"):
		hud.get_node("HUD/StatusLabel").text = theme["name"] + " | DEFEAT THE BOSS"

func _on_boss_defeated() -> void:
	if chest:
		chest.unlock_chest()
	if hud and hud.has_node("HUD/StatusLabel"):
		hud.get_node("HUD/StatusLabel").text = "BOSS DEFEATED! Open the chest to proceed."

func _on_chest_opened() -> void:
	await get_tree().create_timer(1.2).timeout
	current_room += 1
	get_tree().paused = false
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		get_tree().paused = false
		current_room = 1
		var ai = get_node_or_null("/root/AIDirector")
		if ai:
			ai.reset_full_session()
		get_tree().reload_current_scene()
