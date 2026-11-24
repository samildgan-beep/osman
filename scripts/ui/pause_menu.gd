class_name PauseMenu
extends Overlay
## Duraklatma menüsü.

signal resume
signal rescue
signal restart
signal settings
signal quit_to_levels


func _ready() -> void:
	build_frame("PAUSED", Vector2(560, 0))
	add_button("RESUME", func(): resume.emit())
	add_button("I'M STUCK (rescue)", func(): rescue.emit())
	add_button("RESTART", func(): restart.emit())
	add_button("SETTINGS", func(): settings.emit())
	add_button("LEVELS", func(): quit_to_levels.emit())
	body.add_child(UITheme.label("I'm stuck: go back to your last checkpoint with the item in your hands (+15 s).", 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	pop_in()
