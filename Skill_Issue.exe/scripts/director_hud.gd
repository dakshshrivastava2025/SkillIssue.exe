extends CanvasLayer
## DirectorHUD — In-game HUD containing:
##   1. Always-visible Player Health Bar in Top-Left
##   2. AI Director Debug Telemetry Panel (Toggle with F1)

@onready var kills_label:   Label = null
@onready var dodges_label:  Label = null
@onready var retreat_label: Label = null
@onready var flags_label:   Label = null

var _debug_panel: PanelContainer = null

# Player HP UI References
var _player_hud: Control = null
var _hp_bar_fill: ColorRect = null
var _hp_bar_bg: ColorRect = null
var _hp_label: Label = null
var _current_player: Node2D = null

const BAR_WIDTH: float = 240.0
const BAR_HEIGHT: float = 18.0

func _ready() -> void:
	layer = 10
	_build_player_health_hud()
	_build_debug_ui_if_needed()
	print("[DirectorHUD] Player Health Bar initialized in Top-Left. Press F1 to toggle AI Director overlay.")

func _build_player_health_hud() -> void:
	if get_node_or_null("PlayerHealthHUD"):
		return

	_player_hud = Control.new()
	_player_hud.name = "PlayerHealthHUD"
	_player_hud.position = Vector2(20, 16)
	_player_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hud)

	# Container panel
	var panel = PanelContainer.new()
	panel.name = "HUDPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_hud.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# Title Label
	var title = Label.new()
	title.text = "❤️ PLAYER HP"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(title)

	# Health Bar Frame
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar_container)

	# Background Rect
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.name = "HPBarBG"
	_hp_bar_bg.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_hp_bar_bg.color = Color(0.08, 0.09, 0.14, 0.95)
	bar_container.add_child(_hp_bar_bg)

	# Border
	var border = ReferenceRect.new()
	border.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	border.border_color = Color(0.35, 0.4, 0.55, 1.0)
	border.border_width = 2.0
	border.editor_only = false
	bar_container.add_child(border)

	# Fill Rect
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.name = "HPBarFill"
	_hp_bar_fill.position = Vector2(2, 2)
	_hp_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bar_fill.color = Color(0.2, 0.85, 0.4, 1.0)
	bar_container.add_child(_hp_bar_fill)

	# HP Number Text (Centered on the bar)
	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.text = "100 / 100"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0, 0)
	_hp_label.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	bar_container.add_child(_hp_label)

func _build_debug_ui_if_needed() -> void:
	if get_node_or_null("DebugPanel"):
		return
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.position = Vector2(20, 85)
	_debug_panel.size = Vector2(400, 160)
	_debug_panel.visible = false
	add_child(_debug_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	_debug_panel.add_child(vbox)

	var title = Label.new()
	title.text = "=== AI DIRECTOR OVERLAY (F1) ==="
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
	vbox.add_child(title)

	kills_label = Label.new()
	kills_label.name = "KillsLabel"
	vbox.add_child(kills_label)

	dodges_label = Label.new()
	dodges_label.name = "DodgesLabel"
	vbox.add_child(dodges_label)

	retreat_label = Label.new()
	retreat_label.name = "RetreatLabel"
	vbox.add_child(retreat_label)

	flags_label = Label.new()
	flags_label.name = "FlagsLabel"
	vbox.add_child(flags_label)

func _process(_delta: float) -> void:
	_sync_player_health()
	if _debug_panel and _debug_panel.visible:
		_refresh_debug()

func _sync_player_health() -> void:
	if not _current_player or not is_instance_valid(_current_player):
		_current_player = get_tree().get_first_node_in_group("player")
		if _current_player and _current_player.has_signal("health_changed"):
			if not _current_player.health_changed.is_connected(update_player_hp):
				_current_player.health_changed.connect(update_player_hp)
	
	if _current_player and is_instance_valid(_current_player):
		var cur_hp = _current_player.get("health")
		var max_hp = _current_player.get("max_health")
		if cur_hp != null and max_hp != null:
			update_player_hp(float(cur_hp), float(max_hp))

func update_player_hp(curr: float, max_val: float) -> void:
	if not _hp_bar_fill or not _hp_label:
		return
	var ratio = clamp(curr / max(1.0, max_val), 0.0, 1.0)
	_hp_bar_fill.size.x = ratio * BAR_WIDTH
	_hp_label.text = "%d / %d" % [int(round(curr)), int(round(max_val))]

	# Dynamic HP Color
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.35, 1.0) # Green
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.95, 0.75, 0.2, 1.0) # Yellow/Orange
	else:
		_hp_bar_fill.color = Color(0.95, 0.2, 0.2, 1.0)  # Red

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if _debug_panel:
			_debug_panel.visible = !_debug_panel.visible

func _refresh_debug() -> void:
	var d := AIDirector

	if kills_label:
		kills_label.text = "Kills: %d" % d.kills

	if dodges_label:
		var dc := d.dodge_counts
		dodges_label.text = (
			"Dodges  L:%d  R:%d  U:%d  D:%d   dominant: %s" % [
				dc.get("left", 0), dc.get("right", 0),
				dc.get("up", 0),   dc.get("down", 0),
				d.dominant_dodge if d.dominant_dodge != "" else "—"
			]
		)

	if retreat_label:
		retreat_label.text = "Retreat time: %.1f s" % d.retreat_time

	if flags_label:
		flags_label.text = (
			"Aggressive: %s   |   Retreater: %s   |   Rhythmic: %s" % [
				_bool(d.is_aggressive),
				_bool(d.is_retreater),
				_bool(d.attack_is_rhythmic),
			]
		)

func _bool(v: bool) -> String:
	return "[YES]" if v else "no"
