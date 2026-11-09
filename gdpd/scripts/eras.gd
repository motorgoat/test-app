class_name Eras
## Zeitalter der Schöpfung (GDPD_SCHOEPFUNG_GRAFIK.md 2): eine Welt-Größe über den Arten. Färbt Himmel, Licht,
## Wasser und Boden der ganzen Welt. Nur Konstanten; World.set_era() und Look.set_era() lesen sie.
##
## Ein Eintrag:
##   mood     Stimmung in World.MOODS (Licht, Himmel, Post)
##   water    Farbe des toten Wassers (Urozean) dieses Zeitalters: deep, shallow, glint (Glitzern ×)
##   ground   Bodenwerte je Art, die Look.GROUND überschreiben (Basalt-Fels, Urboden, dunkles Ufer)
##   ambient  embers (Funken), fireflies (Glühwürmchen), pollen, birds (Vogelzug), steam (Dampf an Lava-Ufern)
##   models   Modell-Zweige: primeval (Urboden, Urwald), wild (wilde Herde statt Weide), ducks (Enten auf Wasser),
##            basalt (Fels als Basalt)
##   season   0 Frühling, 1 Sommer, 2 Herbst, 3 Winter
##   sunface  Akt 4: oben ist Tag (Sonnenseite, Nachtseite unten)

const URBODEN := {"a": "#5b4e42", "b": "#6e6152", "acc": "#857868", "amt": 0.55, "mc": 0.42, "crk": 1.0}
const URBODEN_DARK := {"a": "#4d433a", "b": "#5c5146", "acc": "#7a6e60", "amt": 0.5, "mc": 0.42, "crk": 1.0}
const BASALT := {"a": "#4a4a4d", "b": "#5c5b59", "acc": "#86827b", "amt": 0.9, "mc": 0.72}   # mittelgrauer Basalt (passt zum Fels-Symbol)
const BASALT_GREY := {"a": "#45444a", "b": "#55534f", "acc": "#7d7972", "amt": 0.9, "mc": 0.72}
const SHORE_DARK := {"a": "#34302c", "b": "#403a35", "acc": "#4c453f", "amt": 0.4, "mc": 0.45}   # dunkler, nasser Rand
const SHORE_OCHRE := {"a": "#6b6152", "b": "#7d725f", "acc": "#8a806e", "amt": 0.3, "mc": 0.45}

const ERAS := {
	"glut": {"mood": "glut", "water": {"deep": "#1c2a33", "shallow": "#3d4c55", "glint": 0.8},
		"ground": {16: BASALT, 0: URBODEN_DARK, 15: SHORE_DARK},
		"ambient": {"embers": 60, "fireflies": 0, "pollen": false, "birds": false, "steam": true},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": true}, "season": 1, "sunface": false},
	"glut_kuehl": {"mood": "glut_kuehl", "water": {"deep": "#1c2a33", "shallow": "#3d4c55", "glint": 0.8},
		"ground": {16: BASALT, 0: URBODEN_DARK, 15: SHORE_DARK},
		"ambient": {"embers": 30, "fireflies": 0, "pollen": false, "birds": false, "steam": true},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": true}, "season": 1, "sunface": false},
	"dunst": {"mood": "dunst", "water": {"deep": "#1f3034", "shallow": "#475a5a", "glint": 0.8},
		"ground": {16: BASALT_GREY, 0: URBODEN, 15: SHORE_OCHRE},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": true},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": true}, "season": 1, "sunface": false},
	"blau": {"mood": "tag", "water": {"deep": "#1b3a3f", "shallow": "#4a7472", "glint": 1.0},
		"ground": {0: URBODEN},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": false, "steam": true},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false}, "season": 1, "sunface": false},
	"fruehling": {"mood": "morgen", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 20, "pollen": true, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false}, "season": 0, "sunface": true},
	"sommer": {"mood": "tag", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 20, "pollen": true, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false}, "season": 1, "sunface": true},
	"herbst": {"mood": "abend", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 20, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false}, "season": 2, "sunface": true},
	"tag": {"mood": "tag", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": true, "basalt": false}, "season": 1, "sunface": false},
	"menschen": {"mood": "tag", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": true, "basalt": false}, "season": 1, "sunface": false},
	"abend": {"mood": "abend", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": true, "basalt": false}, "season": 1, "sunface": false},
	"vollendet": {"mood": "vollendet", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": true, "basalt": false}, "season": 1, "sunface": false},
	# nur Prüfung und Look-Dev: die Nachtseite als ganze Welt
	"nacht": {"mood": "nacht", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 0.4}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 20, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": false, "basalt": false}, "season": 1, "sunface": false},
	# Winter (Paket „Winter“, später): Schneedecke, kahle Laubbäume
	"winter": {"mood": "morgen", "water": {"deep": "#1c3a46", "shallow": "#5a8088", "glint": 0.8}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": false, "basalt": false}, "season": 3, "sunface": false},
}

## Reihenfolge für Sheets und Tests (Akt 1 … 7)
const ORDER := ["glut", "glut_kuehl", "dunst", "blau", "fruehling", "sommer", "herbst", "tag", "menschen", "abend", "vollendet",
	"nacht", "winter"]


## Zeitalter eines Levels (Level 1 … 30, Akt 1 … 7; act <= 0: aus dem Level). Spec GDPD_SCHOEPFUNG.md 4.1, Grafik 2.2.
static func of(act: int, level: int) -> String:
	if act <= 0:
		act = act_of(level)
	match act:
		1:
			return "glut_kuehl" if level >= 4 else "glut"
		2:
			return "dunst"
		3:
			return "blau"
		4:
			if level <= 13:
				return "fruehling"
			return "sommer" if level == 14 else "herbst"
		5:
			return "tag"
		6:
			if level >= 27:
				return "abend"
			return "menschen" if level >= 24 else "tag"
		7:
			return "vollendet"
	return "tag"


## Akt eines Levels (Level-Tabelle der Spec: 1–4, 5–8, 9–12, 13–15, 16–19, 20–28, 29–30).
static func act_of(level: int) -> int:
	if level <= 0:
		return 0
	for a in [[4, 1], [8, 2], [12, 3], [15, 4], [19, 5], [28, 6]]:
		if level <= int(a[0]):
			return int(a[1])
	return 7


static func has(name: String) -> bool:
	return ERAS.has(name)


static func get_era(name: String) -> Dictionary:
	return ERAS.get(name, ERAS["tag"])


## Welches Zeitalter vor diesem kommt (Akt 3 mischt Dunst → Blau nach den Algen).
static func mix_from(name: String) -> String:
	return "dunst" if name == "blau" else ""
