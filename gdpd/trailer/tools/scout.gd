extends SceneTree
## Hilfswerkzeug: Bretter der Kampagne durchsehen (Arten je Seite), für die Wahl der Trailer-Bretter.
func _initialize() -> void:
	for lv in [12, 13, 14, 16, 18, 19, 20, 21, 22, 23, 24, 26, 27]:
		for bi in range(0, mini(6, Campaign.pool_size(lv))):
			var gs := Campaign.new_state(lv, Campaign.board(lv, bi))
			var cnt := {}
			var top := {}
			for f in gs.fields:
				var fd: FieldData = f
				var nm: String = FieldData.KIND_SHORT[fd.kind] if fd.kind < FieldData.KIND_SHORT.size() else str(fd.kind)
				cnt[nm] = int(cnt.get(nm, 0)) + 1
				if fd.n == Vector3i(0, 1, 0):
					top[nm] = int(top.get(nm, 0)) + 1
			print("L%d b%d all=%s top=%s" % [lv, bi, str(cnt), str(top)])
	quit()
