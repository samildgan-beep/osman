class_name PauseMenu
extends Overlay
## Duraklatma menüsü.

signal resume
signal rescue
signal restart
signal settings
signal quit_to_levels


func _ready() -> void:
	build_frame("DURAKLATILDI", Vector2(560, 0))
	add_button("DEVAM", func(): resume.emit())
	add_button("TAKILDIM (kurtar)", func(): rescue.emit())
	add_button("YENİDEN BAŞLA", func(): restart.emit())
	add_button("AYARLAR", func(): settings.emit())
	add_button("BÖLÜMLER", func(): quit_to_levels.emit())
	body.add_child(UITheme.label("Takıldım: son geçtiğin noktaya döner, eşya eline verilir (+15 sn).", 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	pop_in()
