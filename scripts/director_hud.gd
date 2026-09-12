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
	# Start hidden; press F1 to toggle
	visible = false
	print("[DirectorHUD] Press F1 to toggle the AI Director debug overlay.")

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
