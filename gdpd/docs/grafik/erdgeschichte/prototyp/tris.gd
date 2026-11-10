extends SceneTree
func _initialize() -> void:
	for k in ["deer", "bison", "wolf", "person", "fish", "bird", "sauro", "trex", "raptor", "ptero", "mammoth", "ape", "hunter", "shrew", "trilobite", "jelly", "dragonfly", "amph"]:
		var m: Mesh = Models.creature_mesh(k, 0)
		print("TRIS ", k, " ", m.get_faces().size() / 3)
	for k in ["oak", "spruce", "tree_fern", "fern", "cycad", "araucaria", "acacia", "campfire"]:
		var n := 0
		for pv in Models.get_model(k, 0):
			n += ((pv as Array)[0] as Mesh).get_faces().size() / 3
		print("TRIS ", k, " ", n)
	quit()
