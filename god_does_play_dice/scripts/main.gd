extends Node
## Hauptszene: baut Welt und Oberfläche auf und skaliert die Oberfläche passend zum Bildschirm.

const BASE_SHORT_SIDE := 600.0   # logische Pixel an der kurzen Bildschirmseite (Handy zuerst)


func _ready() -> void:
	_apply_scale()
	get_tree().root.size_changed.connect(_apply_scale)
	var world := World.new()
	world.name = "World"
	add_child(world)
	var ui := GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(world)


func _apply_scale() -> void:
	var win := get_tree().root
	var s := win.size
	var f := clampf(minf(float(s.x), float(s.y)) / BASE_SHORT_SIDE, 1.0, 3.0)
	if absf(win.content_scale_factor - f) > 0.01:
		win.content_scale_factor = f
