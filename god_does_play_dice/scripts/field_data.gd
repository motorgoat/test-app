class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.

var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var kind: String = "nature"       # nature, settlement, industry, faith, mountain, crater, center
var level: int = 1                # 1–3
var nation: int = -1              # bei Siedlung und Glaube: Volk
var is_center: bool = false       # Mitte einer Seite: dreht sich nie, Wahrzeichen zur Orientierung
var landmark: int = -1            # bei Mitten: welches Wahrzeichen (0–5)
# Zähler
var bond: int = 0                 # Runden neben Gleichem
var need: int = 0                 # Runden ohne Bedürfnis
var damage: int = 0               # Runden Krieg an der Grenze
var pollution: int = 0            # Runden neben Fabrik
var burning: bool = false
var volcano: int = 0              # > 0: Vulkan bricht in so vielen Runden aus
var crater_age: int = 0


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.kind = kind
	f.level = level
	f.nation = nation
	f.is_center = is_center
	f.landmark = landmark
	f.bond = bond
	f.need = need
	f.damage = damage
	f.pollution = pollution
	f.burning = burning
	f.volcano = volcano
	f.crater_age = crater_age
	return f


func scored() -> bool:
	return kind == "nature" or kind == "settlement" or kind == "industry" or kind == "faith"


func has_nation() -> bool:
	return (kind == "settlement" or kind == "faith") and nation >= 0
