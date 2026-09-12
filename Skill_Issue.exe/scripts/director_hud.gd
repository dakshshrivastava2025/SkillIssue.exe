extends CanvasLayer
## DirectorHUD — Debug overlay showing the AIDirector's live state.
##
## Scene setup:
##   DirectorHUD (CanvasLayer)  ← attach this script; layer = 10
##   └── Panel (PanelContainer)
##       └── VBox (VBoxContainer)
##           ├── TitleLabel   (Label)
##           ├── KillsLabel   (Label)
##           ├── DodgesLabel  (Label)
##           ├── RetreatLabel (Label)
##           └── FlagsLabel   (Label)
##
## Add DirectorHUD as a child of Main.tscn so it persists across rooms.
## Toggle visibility with F1 during runtime.

@onready var kills_label:   Label = $Panel/VBox/KillsLabel
@onready var dodges_label:  Label = $Panel/VBox/DodgesLabel
@onready var retreat_label: Label = $Panel/VBox/RetreatLabel
@onready var flags_label:   Label = $Panel/VBox/FlagsLabel

func _ready() -> void:
	visible = false
	_build_ui_if_needed()
	print("[DirectorHUD] Press F1 to toggle the AI Director debug overlay.")

func _build_ui_if_needed() -> void:
	if get_node_or_null("Panel"):
		return
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(20, 20)
	panel.size = Vector2(400, 160)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "=== AI DIRECTOR OVERLAY (F1) ==="
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
	if not visible:
		return
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		visible = !visible

func _refresh() -> void:
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
