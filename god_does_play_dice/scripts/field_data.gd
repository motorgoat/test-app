class_name FieldData
extends RefCounted
## Ein Feld (Aufkleber) auf dem Würfel. Reine Daten, keine Darstellung. (GDD Kap. 16)

var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Position des Würfelchens im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite, auf der das Feld liegt
var terrain: String = "meadow"    # meadow, forest, lake, mountain, gold
var owner: int = -1               # Spieler-ID oder −1 = neutral
var level: int = 0                # Ausbau-Stufe 0–4, gehört zum Feld und wandert mit
var is_center: bool = false       # Mittelfeld einer Seite: dreht sich nie mit
var home: int = -1                # bei Zentren: die Seite (= Spieler-ID), zu der es gehört
# Für Projekt-Stufe 2 (Straßen, Krieger, Mauern) schon im Datenmodell vorgesehen:
var troops: int = 0
var wall: bool = false
var roads: Array = []             # [{"dir": Vector3i, "owner": int}]


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.terrain = terrain
	f.owner = owner
	f.level = level
	f.is_center = is_center
	f.home = home
	f.troops = troops
	f.wall = wall
	f.roads = []
	for r in roads:
		f.roads.append((r as Dictionary).duplicate())
	return f
