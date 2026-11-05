class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.

var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var stage: int = 0                # 0 Erde … 9 Metropole (siehe Balance)
var fresh: int = 0                # > 0: frisch verwüstet (Meteor, Verschmutzung), zeigt Rauch
var burning := false              # brennt: verliert jeden Zug eine Stufe, bis es gelöscht wird oder Erde ist


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.stage = stage
	f.fresh = fresh
	f.burning = burning
	return f


func is_nature() -> bool:
	return stage >= int(Balance.NATURE_STAGES[0]) and stage <= int(Balance.NATURE_STAGES[1])


func is_civilisation() -> bool:
	return stage >= Balance.CIVILISATION_FROM
