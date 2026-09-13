extends CanvasLayer
## DirectorHUD — In-game HUD containing:
##   1. Player HP Bar & Label (Top-Left)
##   2. Boss HP Bar & Label (Top-Right, activates when Boss is present)
##   3. Status / Objective Label (Top-Center)
##   4. Status Debuff Badges (Dash Locked, -35% Speed, -35% Dmg)
##   5. Controls Guide (Bottom-Center)
##   6. AI Director Intervention Prompts & Boss Dialogue Subtitles
##   7. AI Director Debug Telemetry Panel (Toggle with F1)
##   8. Full Death Screen with Vignette Backdrop & Retry (Press R / Click)

# Status Label
var _status_label: Label = null

# Player HP UI References
var _player_hud: Control = null
var _hp_bar_fill: ColorRect = null
var _hp_bar_bg: ColorRect = null
var _hp_label: Label = null
var _current_player: Node2D = null

# Boss HP UI References
var _boss_hud: Control = null
var _boss_hp_bar_fill: ColorRect = null
var _boss_hp_bar_bg: ColorRect = null
var _boss_hp_label: Label = null
var _current_boss: Node2D = null

# Debuff Badges
var _debuff_container: HBoxContainer = null
var _dash_debuff_pill: PanelContainer = null
var _speed_debuff_pill: PanelContainer = null
var _damage_debuff_pill: PanelContainer = null

# Controls Guide
var _controls_guide: Label = null

# AI Prompts & Dialogue
var _prompt_box: PanelContainer = null
var _prompt_label: Label = null
var _dialogue_box: PanelContainer = null
var _dialogue_label: RichTextLabel = null
var _prompt_tween: Tween = null
var _dialogue_tween: Tween = null

# Death Screen
var _death_screen_root: Control = null
var _death_panel: PanelContainer = null
var _retry_btn: Button = null

# Debug Telemetry Panel (F1)
var _debug_panel: PanelContainer = null
var kills_label: Label = null
var dodges_label: Label = null
var retreat_label: Label = null
var flags_label: Label = null

const BAR_WIDTH: float = 280.0
const BAR_HEIGHT: float = 20.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	
	_build_status_label()
	_build_player_health_hud()
	_build_boss_health_hud()
	_build_debuff_badges()
	_build_controls_guide()
	_build_prompt_and_dialogue_ui()
	_build_death_screen()
	_build_debug_ui_if_needed()
	
	# Connect to global AIDirector
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		if ai.has_signal("director_intervention_triggered"):
			ai.director_intervention_triggered.connect(_on_director_intervention)
		if ai.has_signal("boss_dialogue_generated"):
			ai.boss_dialogue_generated.connect(_on_boss_dialogue)
		if ai.has_signal("state_space_updated"):
			ai.state_space_updated.connect(_on_state_updated)

	print("[DirectorHUD] Complete UI Initialized (Player HP, Boss HP, Status, Debuffs, Controls, Death Screen, Dialogue).")

# ---------------------------------------------------------------------------
# 1. Status Label (Top-Center)
# ---------------------------------------------------------------------------
func _build_status_label() -> void:
	if get_node_or_null("StatusLabel"):
		return
	
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.offset_left = -320.0
	_status_label.offset_top = 18.0
	_status_label.offset_right = 320.0
	_status_label.offset_bottom = 46.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.text = "DUNGEON INFILTRATION — DEFEAT ALL ENEMIES"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.add_theme_font_size_override("font_size", 14)
	add_child(_status_label)

func update_status_text(new_text: String) -> void:
	if _status_label:
		_status_label.text = new_text

# ---------------------------------------------------------------------------
# 2. Player HP HUD (Top-Left)
# ---------------------------------------------------------------------------
func _build_player_health_hud() -> void:
	if get_node_or_null("PlayerHealthHUD"):
		return

	_player_hud = Control.new()
	_player_hud.name = "PlayerHealthHUD"
	_player_hud.position = Vector2(50, 18)
	_player_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_hud)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	_player_hud.add_child(vbox)

	# Label: "PLAYER: 100 / 100 HP"
	var title = Label.new()
	title.name = "Title"
	title.text = "PLAYER HP"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_font_size_override("font_size", 13)
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
	border.border_color = Color(0.35, 0.45, 0.65, 1.0)
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

	# HP Text
	_hp_label = Label.new()
	_hp_label.name = "HPLabel"
	_hp_label.text = "PLAYER: 100 / 100 HP"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0, 0)
	_hp_label.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_label.add_theme_font_size_override("font_size", 12)
	bar_container.add_child(_hp_label)

# ---------------------------------------------------------------------------
# 3. Boss HP HUD (Top-Right)
# ---------------------------------------------------------------------------
func _build_boss_health_hud() -> void:
	if get_node_or_null("BossHealthHUD"):
		return

	_boss_hud = Control.new()
	_boss_hud.name = "BossHealthHUD"
	_boss_hud.anchor_left = 1.0
	_boss_hud.anchor_right = 1.0
	_boss_hud.offset_left = -(BAR_WIDTH + 54)
	_boss_hud.offset_top = 18.0
	_boss_hud.visible = false
	_boss_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_hud)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	_boss_hud.add_child(vbox)

	# Label: "DARK WIZARD: 600 / 600 HP"
	var title = Label.new()
	title.name = "BossTitle"
	title.text = "DARK WIZARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	# Health Bar Frame
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar_container)

	# Background Rect
	_boss_hp_bar_bg = ColorRect.new()
	_boss_hp_bar_bg.name = "BossHPBarBG"
	_boss_hp_bar_bg.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_boss_hp_bar_bg.color = Color(0.12, 0.04, 0.08, 0.95)
	bar_container.add_child(_boss_hp_bar_bg)

	# Border
	var border = ReferenceRect.new()
	border.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	border.border_color = Color(0.85, 0.25, 0.35, 1.0)
	border.border_width = 2.0
	border.editor_only = false
	bar_container.add_child(border)

	# Fill Rect
	_boss_hp_bar_fill = ColorRect.new()
	_boss_hp_bar_fill.name = "BossHPBarFill"
	_boss_hp_bar_fill.position = Vector2(2, 2)
	_boss_hp_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_boss_hp_bar_fill.color = Color(0.95, 0.18, 0.25, 1.0)
	bar_container.add_child(_boss_hp_bar_fill)

	# Boss HP Text
	_boss_hp_label = Label.new()
	_boss_hp_label.name = "BossHPLabel"
	_boss_hp_label.text = "DARK WIZARD: 500 / 500 HP"
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_label.size = Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_boss_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_boss_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_boss_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_boss_hp_label.add_theme_font_size_override("font_size", 12)
	bar_container.add_child(_boss_hp_label)

# ---------------------------------------------------------------------------
# 4. Debuff Badges (Pills)
# ---------------------------------------------------------------------------
func _build_debuff_badges() -> void:
	if get_node_or_null("DebuffContainer"):
		return
		
	_debuff_container = HBoxContainer.new()
	_debuff_container.name = "DebuffContainer"
	_debuff_container.position = Vector2(50, 72)
	_debuff_container.add_theme_constant_override("separation", 8)
	add_child(_debuff_container)

	_dash_debuff_pill = _create_pill("⚡ DASH LOCKED", Color(1.0, 0.35, 0.35, 1.0), Color(0.35, 0.06, 0.06, 0.88))
	_debuff_container.add_child(_dash_debuff_pill)

	_speed_debuff_pill = _create_pill("🔻 -35% SPEED", Color(1.0, 0.75, 0.2, 1.0), Color(0.32, 0.16, 0.03, 0.88))
	_debuff_container.add_child(_speed_debuff_pill)

	_damage_debuff_pill = _create_pill("⚔️ -35% DMG", Color(0.9, 0.5, 1.0, 1.0), Color(0.24, 0.06, 0.3, 0.88))
	_debuff_container.add_child(_damage_debuff_pill)

func _create_pill(text: String, font_col: Color, bg_col: Color) -> PanelContainer:
	var pill = PanelContainer.new()
	pill.visible = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = font_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	pill.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	pill.add_child(margin)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", font_col)
	lbl.add_theme_font_size_override("font_size", 12)
	margin.add_child(lbl)
	return pill

# ---------------------------------------------------------------------------
# 5. Controls Guide (Bottom-Center)
# ---------------------------------------------------------------------------
func _build_controls_guide() -> void:
	if get_node_or_null("ControlsGuide"):
		return
	
	_controls_guide = Label.new()
	_controls_guide.name = "ControlsGuide"
	_controls_guide.anchor_left = 0.5
	_controls_guide.anchor_top = 1.0
	_controls_guide.anchor_right = 0.5
	_controls_guide.anchor_bottom = 1.0
	_controls_guide.offset_left = -450.0
	_controls_guide.offset_top = -28.0
	_controls_guide.offset_right = 450.0
	_controls_guide.offset_bottom = -8.0
	_controls_guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls_guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controls_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_guide.text = "WASD or Arrows (Move) | Shift (Dash) | Space (Attack) | R (Restart)"
	_controls_guide.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 0.85))
	_controls_guide.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_controls_guide.add_theme_font_size_override("font_size", 12)
	add_child(_controls_guide)

# ---------------------------------------------------------------------------
# 6. AI Prompt & Boss Dialogue UI
# ---------------------------------------------------------------------------
func _build_prompt_and_dialogue_ui() -> void:
	# Intervention Prompt (Top Right under boss bar)
	_prompt_box = PanelContainer.new()
	_prompt_box.name = "AIDirectorPrompt"
	_prompt_box.anchor_left = 1.0
	_prompt_box.anchor_right = 1.0
	_prompt_box.offset_left = -420.0
	_prompt_box.offset_top = 75.0
	_prompt_box.offset_right = -50.0
	_prompt_box.offset_bottom = 125.0
	_prompt_box.visible = false

	var sb_prompt = StyleBoxFlat.new()
	sb_prompt.bg_color = Color(0.12, 0.04, 0.06, 0.92)
	sb_prompt.border_color = Color(1.0, 0.3, 0.3, 0.9)
	sb_prompt.set_border_width_all(2)
	sb_prompt.set_corner_radius_all(6)
	_prompt_box.add_theme_stylebox_override("panel", sb_prompt)

	var p_margin = MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 12)
	p_margin.add_theme_constant_override("margin_top", 6)
	p_margin.add_theme_constant_override("margin_right", 12)
	p_margin.add_theme_constant_override("margin_bottom", 6)
	_prompt_box.add_child(p_margin)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))
	_prompt_label.add_theme_font_size_override("font_size", 12)
	p_margin.add_child(_prompt_label)
	add_child(_prompt_box)

	# Boss Dialogue Subtitles (Bottom Center above controls)
	_dialogue_box = PanelContainer.new()
	_dialogue_box.name = "BossDialogue"
	_dialogue_box.anchor_left = 0.5
	_dialogue_box.anchor_top = 1.0
	_dialogue_box.anchor_right = 0.5
	_dialogue_box.anchor_bottom = 1.0
	_dialogue_box.offset_left = -420.0
	_dialogue_box.offset_top = -88.0
	_dialogue_box.offset_right = 420.0
	_dialogue_box.offset_bottom = -34.0
	_dialogue_box.visible = false

	var sb_dialogue = StyleBoxFlat.new()
	sb_dialogue.bg_color = Color(0.05, 0.02, 0.04, 0.88)
	sb_dialogue.border_color = Color(0.8, 0.2, 0.3, 0.85)
	sb_dialogue.set_border_width_all(1)
	sb_dialogue.set_corner_radius_all(6)
	_dialogue_box.add_theme_stylebox_override("panel", sb_dialogue)

	var d_margin = MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 12)
	d_margin.add_theme_constant_override("margin_top", 4)
	d_margin.add_theme_constant_override("margin_right", 12)
	d_margin.add_theme_constant_override("margin_bottom", 4)
	_dialogue_box.add_child(d_margin)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = true
	_dialogue_label.add_theme_font_size_override("normal_font_size", 15)
	_dialogue_label.add_theme_font_size_override("bold_font_size", 15)
	d_margin.add_child(_dialogue_label)
	add_child(_dialogue_box)

# ---------------------------------------------------------------------------
# 7. Death Screen (Full Modal with Vignette Overlay)
# ---------------------------------------------------------------------------
func _build_death_screen() -> void:
	if get_node_or_null("DeathScreenRoot"):
		return

	_death_screen_root = Control.new()
	_death_screen_root.name = "DeathScreenRoot"
	_death_screen_root.anchor_right = 1.0
	_death_screen_root.anchor_bottom = 1.0
	_death_screen_root.visible = false
	_death_screen_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_screen_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_death_screen_root)

	# Fullscreen Dimming Overlay
	var dim = ColorRect.new()
	dim.name = "DimOverlay"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.04, 0.01, 0.01, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_screen_root.add_child(dim)

	# Center Death Panel
	_death_panel = PanelContainer.new()
	_death_panel.name = "DeathScreen"
	_death_panel.anchor_left = 0.5
	_death_panel.anchor_top = 0.5
	_death_panel.anchor_right = 0.5
	_death_panel.anchor_bottom = 0.5
	_death_panel.offset_left = -260.0
	_death_panel.offset_top = -150.0
	_death_panel.offset_right = 260.0
	_death_panel.offset_bottom = 150.0
	_death_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.02, 0.96)
	sb.border_color = Color(0.85, 0.12, 0.12, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	_death_panel.add_theme_stylebox_override("panel", sb)
	_death_screen_root.add_child(_death_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_death_panel.add_child(vbox)

	var title = Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "The dungeon learned your habits and exploited them."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	sub.add_theme_font_size_override("font_size", 14)
	vbox.add_child(sub)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	_retry_btn = Button.new()
	_retry_btn.text = "RETRY (Press R)"
	_retry_btn.custom_minimum_size = Vector2(160, 44)
	_retry_btn.focus_mode = Control.FOCUS_ALL
	_retry_btn.pressed.connect(_on_retry_pressed)
	btn_hbox.add_child(_retry_btn)

	var menu_btn = Button.new()
	menu_btn.text = "TITLE MENU"
	menu_btn.custom_minimum_size = Vector2(160, 44)
	menu_btn.focus_mode = Control.FOCUS_ALL
	menu_btn.pressed.connect(_on_title_menu_pressed)
	btn_hbox.add_child(menu_btn)

# ---------------------------------------------------------------------------
# 8. F1 Debug Telemetry Panel
# ---------------------------------------------------------------------------
func _build_debug_ui_if_needed() -> void:
	if get_node_or_null("DebugPanel"):
		return
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.position = Vector2(50, 105)
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
	vbox.add_child(kills_label)

	dodges_label = Label.new()
	vbox.add_child(dodges_label)

	retreat_label = Label.new()
	vbox.add_child(retreat_label)

	flags_label = Label.new()
	vbox.add_child(flags_label)

# ---------------------------------------------------------------------------
# Dynamic Per-Frame Sync
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	_sync_player_health()
	_sync_boss_health()
	_sync_debuff_badges()
	if _debug_panel and _debug_panel.visible:
		_refresh_debug()

func _sync_debuff_badges() -> void:
	var ai = get_node_or_null("/root/AIDirector")
	if not ai:
		return
	if _dash_debuff_pill:
		_dash_debuff_pill.visible = ai.get("dash_disabled_active") == true
	if _speed_debuff_pill:
		_speed_debuff_pill.visible = ai.get("speed_debuff_active") == true
	if _damage_debuff_pill:
		_damage_debuff_pill.visible = ai.get("damage_debuff_active") == true

func _sync_player_health() -> void:
	if not _current_player or not is_instance_valid(_current_player):
		_current_player = get_tree().get_first_node_in_group("player")
		if _current_player and is_instance_valid(_current_player):
			if _current_player.has_signal("health_changed") and not _current_player.health_changed.is_connected(update_player_hp):
				_current_player.health_changed.connect(update_player_hp)
			if _current_player.has_signal("died") and not _current_player.died.is_connected(_show_death_screen):
				_current_player.died.connect(_show_death_screen)
	
	if _current_player and is_instance_valid(_current_player):
		var cur_hp = _current_player.get("current_health")
		if cur_hp == null:
			cur_hp = _current_player.get("health")
		var max_hp = _current_player.get("max_health")
		if cur_hp != null and max_hp != null:
			update_player_hp(float(cur_hp), float(max_hp))

func _sync_boss_health() -> void:
	if not _current_boss or not is_instance_valid(_current_boss) or _current_boss.is_queued_for_deletion():
		_current_boss = null
		for b in get_tree().get_nodes_in_group("boss"):
			if b and is_instance_valid(b) and not b.is_queued_for_deletion():
				_current_boss = b
				break
		if _current_boss:
			_boss_hud.visible = true
			if _current_boss.has_signal("boss_health_changed") and not _current_boss.boss_health_changed.is_connected(update_boss_hp):
				_current_boss.boss_health_changed.connect(update_boss_hp)
			if _current_boss.has_signal("boss_defeated") and not _current_boss.boss_defeated.is_connected(_on_boss_defeated):
				_current_boss.boss_defeated.connect(_on_boss_defeated)
		else:
			if _boss_hud:
				_boss_hud.visible = false
			return
	
	if _current_boss and is_instance_valid(_current_boss) and not _current_boss.is_queued_for_deletion():
		_boss_hud.visible = true
		var cur_hp = _current_boss.get("current_health")
		var max_hp = _current_boss.get("max_health")
		if cur_hp != null and max_hp != null:
			update_boss_hp(int(cur_hp), int(max_hp))
	else:
		_current_boss = null
		if _boss_hud:
			_boss_hud.visible = false

func reset_boss_hud() -> void:
	_current_boss = null
	if _boss_hud:
		_boss_hud.visible = false
	if _boss_hp_bar_fill:
		_boss_hp_bar_fill.size.x = BAR_WIDTH
	if _boss_hp_label:
		_boss_hp_label.text = "DARK WIZARD: 500 / 500 HP"

func update_player_hp(curr: float, max_val: float) -> void:
	if not _hp_bar_fill or not _hp_label:
		return
	var ratio = clamp(curr / max(1.0, max_val), 0.0, 1.0)
	_hp_bar_fill.size.x = ratio * BAR_WIDTH
	_hp_label.text = "PLAYER: %d / %d HP" % [int(max(0.0, round(curr))), int(round(max_val))]

	# Dynamic HP Color
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.35, 1.0) # Green
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.95, 0.75, 0.2, 1.0) # Yellow/Orange
	else:
		_hp_bar_fill.color = Color(0.95, 0.2, 0.2, 1.0)  # Red

	if curr <= 0.0 and _death_screen_root and not _death_screen_root.visible:
		_show_death_screen()

func update_boss_hp(curr: int, max_val: int) -> void:
	if not _boss_hud or not _boss_hp_bar_fill or not _boss_hp_label:
		return
	_boss_hud.visible = true
	var ratio = clamp(float(curr) / float(max(1, max_val)), 0.0, 1.0)
	_boss_hp_bar_fill.size.x = ratio * BAR_WIDTH
	_boss_hp_label.text = "DARK WIZARD: %d / %d HP" % [max(0, curr), max_val]

	if curr <= 0:
		_on_boss_defeated()

func _on_boss_defeated() -> void:
	if _status_label:
		_status_label.text = "BOSS DEFEATED! PROCEED THROUGH THE GATE TO VICTORY!"

func _show_death_screen() -> void:
	if _death_screen_root:
		_death_screen_root.visible = true
		get_tree().paused = true
	if _status_label:
		_status_label.text = "YOU HAVE FALLEN"

func _on_retry_pressed() -> void:
	get_tree().paused = false
	if _death_screen_root:
		_death_screen_root.visible = false
	
	for b in get_tree().get_nodes_in_group("boss"):
		if b and is_instance_valid(b) and not b.is_queued_for_deletion() and b.has_method("reset_boss"):
			b.reset_boss()
	reset_boss_hud()
	
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		if ai.has_method("reset_full_session"):
			ai.reset_full_session()
		elif ai.has_method("reset"):
			ai.reset()
			
	var p = get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p) and p.has_method("reset_state"):
		p.reset_state()
		
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and gm.has_method("load_room"):
		gm.load_room(0)
	else:
		get_tree().reload_current_scene()

func _on_title_menu_pressed() -> void:
	get_tree().paused = false
	if _death_screen_root:
		_death_screen_root.visible = false
	var ai = get_node_or_null("/root/AIDirector")
	if ai:
		if ai.has_method("reset_full_session"):
			ai.reset_full_session()
		elif ai.has_method("reset"):
			ai.reset()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			if _debug_panel:
				_debug_panel.visible = !_debug_panel.visible
		elif event.keycode == KEY_R and _death_screen_root and _death_screen_root.visible:
			_on_retry_pressed()

func _on_director_intervention(_action_name: String, description: String) -> void:
	if not _prompt_box or not _prompt_label:
		return
	_prompt_box.visible = true
	_prompt_label.text = "⚡ " + description
	_prompt_box.modulate = Color(1.8, 0.4, 0.4, 0.0)
	
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt_box, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
	_prompt_tween.tween_interval(4.0)
	_prompt_tween.tween_property(_prompt_box, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	_prompt_tween.tween_callback(func(): _prompt_box.visible = false)

func _on_boss_dialogue(text: String, _trigger: String) -> void:
	if not _dialogue_box or not _dialogue_label:
		return
	_dialogue_box.visible = true
	_dialogue_label.text = "[center][b][color=#ff5566]DARK WIZARD:[/color][/b] [color=#ffffff]\"" + text + "\"[/color][/center]"
	_dialogue_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
	
	if _dialogue_tween:
		_dialogue_tween.kill()
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue_box, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	_dialogue_tween.tween_interval(4.5)
	_dialogue_tween.tween_property(_dialogue_box, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	_dialogue_tween.tween_callback(func(): _dialogue_box.visible = false)

func _on_state_updated(_state: Dictionary) -> void:
	_sync_debuff_badges()

func _refresh_debug() -> void:
	var d = get_node_or_null("/root/AIDirector")
	if not d:
		return

	if kills_label:
		var k = d.get("kills")
		kills_label.text = "Kills: %d" % (k if k != null else 0)

	if dodges_label:
		var dc_raw = d.get("dodge_counts")
		var dc: Dictionary = dc_raw if dc_raw is Dictionary else {}
		var dom = d.get("dominant_dodge")
		dodges_label.text = (
			"Dodges  L:%d  R:%d  U:%d  D:%d   dominant: %s" % [
				dc.get("left", 0), dc.get("right", 0),
				dc.get("up", 0),   dc.get("down", 0),
				dom if dom != null and str(dom) != "" else "—"
			]
		)

	if retreat_label:
		var rt = d.get("retreat_time")
		retreat_label.text = "Retreat time: %.1f s" % (rt if rt != null else 0.0)

	if flags_label:
		var is_agg = d.get("is_aggressive") == true
		var is_ret = d.get("is_retreater") == true
		var is_rhy = d.get("attack_is_rhythmic") == true
		flags_label.text = (
			"Aggressive: %s   |   Retreater: %s   |   Rhythmic: %s" % [
				_bool(is_agg),
				_bool(is_ret),
				_bool(is_rhy),
			]
		)

func _bool(v: bool) -> String:
	return "[YES]" if v else "no"
