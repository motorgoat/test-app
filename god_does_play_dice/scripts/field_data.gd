class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.

var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var stage: int = 0                # 0 Leere Erde, 1 Wiese, 2 Wald, 3 Dorf, 4 Stadt, 5 Fabrik
var fresh: int = 0                # > 0: frisch verwüstet (Meteor, Verschmutzung), zeigt Rauch


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.stage = stage
	f.fresh = fresh
	return f


func is_nature() -> bool:
	return stage == 1 or stage == 2


func is_civilisation() -> bool:
	return stage >= 3
