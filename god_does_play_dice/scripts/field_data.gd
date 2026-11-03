class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.

var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var terrain: String = "meadow"    # meadow, forest, lake, mountain, crater
var nation: int = -1              # Volk oder −1
var building: String = ""         # "", village, church, market
var people: int = 0
var animals: int = 0
var burning: bool = false
var volcano: int = 0              # > 0: Vulkan bricht in so vielen Runden aus
var crater_age: int = 0


func settled() -> bool:
	return nation >= 0 and building != ""


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.terrain = terrain
	f.nation = nation
	f.building = building
	f.people = people
	f.animals = animals
	f.burning = burning
	f.volcano = volcano
	f.crater_age = crater_age
	return f
