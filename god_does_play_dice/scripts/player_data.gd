class_name PlayerData
extends RefCounted
## Ein Land (eine Würfelseite). Die Spieler-ID ist gleich dem Index der Seite.

var id: int = 0
var name: String = ""
var color: Color = Color.WHITE
var active: bool = false          # false = neutrale Seite ohne Spieler
var human: bool = false
var inv: Dictionary = {}          # wood, stone, food, gold
var residents: int = 0            # freie Bewohner
var warriors: int = 0             # Projekt-Stufe 2
var stage: int = 1                # Zentrum-Stufe 1–5
var rotations: int = 0            # verfügbare Drehungen
var residents_bought: int = 0
var fields_bought: int = 0
var upgrade_tick: int = 0         # Takt des letzten Zentrum-Ausbaus


func copy() -> PlayerData:
	var pl := PlayerData.new()
	pl.id = id
	pl.name = name
	pl.color = color
	pl.active = active
	pl.human = human
	pl.inv = inv.duplicate()
	pl.residents = residents
	pl.warriors = warriors
	pl.stage = stage
	pl.rotations = rotations
	pl.residents_bought = residents_bought
	pl.fields_bought = fields_bought
	pl.upgrade_tick = upgrade_tick
	return pl
