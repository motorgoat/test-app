extends SceneTree
## Backt die geteilten Rauschtexturen des Looks (scripts/look.gd) nach res://textures/*.res.
## Danach startet das Spiel ohne Rechenzeit für das Rauschen.
##   godot --headless --script res://tools/bake_look.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://textures"))
	for which in ["fbm", "cell", "detail"]:
		var tex := ImageTexture.create_from_image(Look.make_noise_image(which))
		var path := "res://textures/noise_%s.res" % which
		var err := ResourceSaver.save(tex, path, ResourceSaver.FLAG_COMPRESS)
		print("bake %s -> %s (%d)" % [which, path, err])
	quit()
