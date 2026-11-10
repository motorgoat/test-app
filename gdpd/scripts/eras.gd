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
## Erdgeschichte (GDPD_ERDGESCHICHTE_GRAFIK.md 2), alle optional:
##   blanket, blanket_c, blanket_veil  Decke aus Schnee (Verwehungen) oder Asche (Schleier) auf allen Oberseiten
##   ice      Eis auf allen Wasserfeldern, vom Ufer her (0 … 1)
##   ambient.fall  fallende Teilchen: "snow", "snow_light", "ash"
##   models   weitere Gestalt-Zweige: cambrian, devon, carbon, dino, ash, recover, mammal, ice, ape, fire, stones
##   night    Lagerfeuer-Nacht (Fenster/Feuer leuchten heller, 0 … 1)

const URBODEN := {"a": "#5b4e42", "b": "#6e6152", "acc": "#857868", "amt": 0.55, "mc": 0.42, "crk": 1.0}
const URBODEN_DARK := {"a": "#4d433a", "b": "#5c5146", "acc": "#7a6e60", "amt": 0.5, "mc": 0.42, "crk": 1.0}
const BASALT := {"a": "#4a4a4d", "b": "#5c5b59", "acc": "#86827b", "amt": 0.9, "mc": 0.72}   # mittelgrauer Basalt (passt zum Fels-Symbol)
const BASALT_GREY := {"a": "#45444a", "b": "#55534f", "acc": "#7d7972", "amt": 0.9, "mc": 0.72}
const SHORE_DARK := {"a": "#34302c", "b": "#403a35", "acc": "#4c453f", "amt": 0.4, "mc": 0.45}   # dunkler, nasser Rand
const SHORE_OCHRE := {"a": "#6b6152", "b": "#7d725f", "acc": "#8a806e", "amt": 0.3, "mc": 0.45}

# --- Erdgeschichte (GDPD_ERDGESCHICHTE_GRAFIK.md 2–3): Paletten, die Arten in einem Zeitalter umfärben ---
const TUNDRA := {"a": "#76784e", "b": "#8c8a5c", "acc": "#a8a49a", "amt": 0.4, "mc": 0.4}          # Wiese → Tundra
const FROST := {"a": "#6e665c", "b": "#807870", "acc": "#9a958e", "amt": 0.5, "mc": 0.5, "crk": 0.6} # Erde → Frostboden
const SAVANNA := {"a": "#a08a48", "b": "#b89e58", "spk": "#d8c890", "spk2": "#8a7a3a", "samt": 0.3, "mc": 0.3}  # Wiese → Savanne
const SAVANNA_HERD := {"a": "#8e7a40", "b": "#a08a4c", "acc": "#6a5636", "amt": 0.5, "path": 0.85, "pc": "#7a6440", "mc": 0.3}
const ASHSOIL := {"a": "#504b47", "b": "#57524d", "acc": "#6e6a66", "amt": 0.3, "mc": 0.5}         # Erde nach dem Einschlag
const ASH_FOREST := {"a": "#3a3430", "b": "#463e36", "acc": "#2a2420", "amt": 0.4, "mc": 0.75}     # verbrannter Waldboden
const DINO_HERD := {"a": "#5d6c2c", "b": "#74803a", "acc": "#6a5a36", "amt": 0.4, "path": 0.6, "pc": "#7a6a48", "mc": 0.3}
const DINO_FERN := {"a": "#3a5222", "b": "#4c6a2a", "acc": "#5a4a30", "amt": 0.25, "mc": 0.7}
const DINO_FOREST := {"a": "#2c3c1a", "b": "#3c4822", "acc": "#5a4a30", "amt": 0.3, "mc": 0.8}
const SWAMP_FOREST := {"a": "#2a3a1c", "b": "#36401e", "acc": "#4a5a2a", "amt": 0.35, "mc": 0.82, "moss": 0.4}  # Karbon: Sumpfwald
const SHORE_MUD := {"a": "#5a5a3c", "b": "#6a6844", "acc": "#4a5a2c", "amt": 0.35, "mc": 0.45}     # Landgang: schlammiges, grünes Ufer
const CAMBRIAN_SHORE := {"a": "#a49478", "b": "#b8aa8c", "acc": "#c8bca0", "amt": 0.3, "mc": 0.45}  # Kambrium: heller Sand

const ERAS := {
	# --- Erdgeschichte: neue Zeitalter (Reihenfolge wie die Kampagne) ---
	"kambrium": {"mood": "kambrium", "water": {"deep": "#0f3a44", "shallow": "#3a8a86", "glint": 1.1},
		"ground": {15: CAMBRIAN_SHORE, 0: URBODEN, 16: BASALT_GREY},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": true, "cambrian": true}, "season": 1, "sunface": false},
	"meer": {"mood": "meer", "water": {"deep": "#0e3446", "shallow": "#2f7a84", "glint": 1.1},
		"ground": {15: CAMBRIAN_SHORE, 0: URBODEN},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false, "devon": true}, "season": 1, "sunface": false},
	"landgang": {"mood": "landgang", "water": {"deep": "#143a3a", "shallow": "#3f7a62", "glint": 1.0},
		"ground": {15: SHORE_MUD, 0: URBODEN},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false}, "season": 1, "sunface": false},
	"karbon": {"mood": "karbon", "water": {"deep": "#16302a", "shallow": "#3e5a3a", "glint": 0.7},
		"ground": {15: SHORE_MUD, 2: SWAMP_FOREST, 4: SWAMP_FOREST},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false, "carbon": true}, "season": 1, "sunface": false},
	"saurier": {"mood": "saurier", "water": {"deep": "#14383a", "shallow": "#3f7a66", "glint": 1.0},
		"ground": {5: DINO_HERD, 23: DINO_FERN, 2: DINO_FOREST, 32: DINO_HERD},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false, "dino": true}, "season": 1, "sunface": false},
	"asche": {"mood": "asche", "water": {"deep": "#3e4a48", "shallow": "#6a6c64", "glint": 0.3}, "ground": {0: ASHSOIL, 2: ASH_FOREST, 4: ASH_FOREST},
		"ambient": {"embers": 24, "fireflies": 0, "pollen": false, "birds": false, "steam": false, "fall": "ash"},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false, "ash": true}, "season": 1, "sunface": false,
		"blanket": 0.42, "blanket_c": "#77736e", "blanket_veil": 1.0},
	"erholung": {"mood": "erholung", "water": {"deep": "#1a3a3c", "shallow": "#4a7068", "glint": 0.8}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": true, "wild": true, "ducks": false, "basalt": false, "recover": true}, "season": 1, "sunface": false,
		"blanket": 0.06, "blanket_c": "#8a8682", "blanket_veil": 1.0},
	"saeuger": {"mood": "saeuger", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": true, "basalt": false, "mammal": true}, "season": 1, "sunface": false},
	"eiszeit": {"mood": "eiszeit", "water": {"deep": "#1c3a4a", "shallow": "#5a8090", "glint": 0.8}, "ground": {1: TUNDRA, 0: FROST},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false, "fall": "snow"},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false, "ice": true}, "season": 1, "sunface": false,
		"blanket": 0.4, "blanket_c": "#eaf0f6", "ice": 0.55},
	"savanne": {"mood": "savanne", "water": {"deep": "#1c3a3a", "shallow": "#5a8070", "glint": 1.0}, "ground": {1: SAVANNA, 5: SAVANNA_HERD},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false, "ape": true}, "season": 1, "sunface": false},
	"feuer": {"mood": "feuer", "water": {"deep": "#1a3038", "shallow": "#4a6a66", "glint": 0.9}, "ground": {1: SAVANNA, 5: SAVANNA_HERD},
		"ambient": {"embers": 0, "fireflies": 12, "pollen": false, "birds": false, "steam": false},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false, "ape": true, "fire": true}, "season": 1, "sunface": false,
		"night": 0.6},
	"jaeger": {"mood": "jaeger", "water": {"deep": "#1c3a48", "shallow": "#527a86", "glint": 0.9}, "ground": {1: TUNDRA},
		"ambient": {"embers": 0, "fireflies": 0, "pollen": false, "birds": false, "steam": false, "fall": "snow_light"},
		"models": {"primeval": false, "wild": true, "ducks": false, "basalt": false, "ice": true, "fire": true}, "season": 1, "sunface": false,
		"blanket": 0.15, "blanket_c": "#eaf0f6", "ice": 0.2},
	"glaube": {"mood": "glaube", "water": {"deep": "#12383f", "shallow": "#3d7f72", "glint": 1.0}, "ground": {},
		"ambient": {"embers": 0, "fireflies": 10, "pollen": true, "birds": true, "steam": false},
		"models": {"primeval": false, "wild": false, "ducks": true, "basalt": false, "stones": true}, "season": 1, "sunface": false},

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
const ORDER := ["glut", "glut_kuehl", "dunst", "blau", "kambrium", "meer", "landgang", "karbon", "saurier", "asche", "erholung",
	"saeuger", "eiszeit", "savanne", "feuer", "jaeger", "fruehling", "sommer", "herbst", "tag", "menschen", "glaube", "abend",
	"vollendet", "nacht", "winter"]


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
## Erdgeschichte: Erholung nach dem Einschlag mischt Asche → Erholung (dust_clear, World.set_era).
static func mix_from(name: String) -> String:
	return {"blau": "dunst", "erholung": "asche"}.get(name, "")
