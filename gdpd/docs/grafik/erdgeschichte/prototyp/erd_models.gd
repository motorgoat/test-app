class_name ErdModels
## PROTOTYP Erdgeschichte (GDPD_ERDGESCHICHTE_GRAFIK.md): Tiere und Pflanzen der neuen Zeitalter.
## Alle Tiere wie Models.creature_mesh: ein Mesh, Vertexfarben, Bewegung im creature.gdshader über Teile
## (UV.x): 0 Rumpf, 1/2 Beine Takt A/B, 3 Kopf/Hals, 5/6 Arme/Flügel, 7 Schwanz (hängend), 8 Schwanz waagrecht (neu).
## Blick nach +x. Maße in Feld-Inhalts-Einheiten (ein Feld ≈ 0,62 breit, ein Hirsch ≈ 0,05 lang).



static func creature(kind: String, variant: int, m: Models.MB) -> bool:
	match kind:
		"sauro":
			_sauro(m, variant)
		"trex":
			_trex(m, variant)
		"raptor":
			_raptor(m, variant)
		"ptero":
			_ptero(m)
		"mammoth":
			_mammoth(m, variant)
		"ape":
			_ape(m, variant)
		"hunter":
			_hunter(m, variant)
		"shrew":
			_shrew(m, variant)
		"trilobite":
			_trilobite(m, variant)
		"jelly":
			_jelly(m)
		"dragonfly":
			_dragonfly(m)
		"amph":
			_amph(m)
		_:
			return false
	return true


static func model(name: String, p: Dictionary, seed: float, variant: int) -> bool:
	match name:
		"cycad":
			_cycad(p, seed, 0.07 + 0.015 * float(variant % 3))
		"araucaria":
			_araucaria(p, seed, 0.3 + 0.04 * float(variant % 2))
		"acacia":
			_acacia(p, seed, 0.2 + 0.03 * float(variant % 2))
		"campfire":
			_campfire(p, seed)
		"snow_spruce":
			Models._tree_spruce(p, 0.26 + 0.03 * float(variant % 2), seed, [Color("#2a4030"), Color("#4f6a52")], 5)
			_snowcaps(p, seed, 0.26 + 0.03 * float(variant % 2), 5)
		"ice_rock":
			var s: Models.MB = p["solid"]
			s.blob(Vector3(0, 0.03, 0), Vector3(0.05, 0.035, 0.04), seed, Color("#9fb4c2"), Color("#e8f0f4"), 0.35, false,
				Vector3(INF, 0, 0), 0, -0.4)
		_:
			return false
	return true


static func _legs4(m: Models.MB, xs: Array, zs: Array, h: float, w: float, col: Color, foot: Color, pivot_y: float) -> void:
	for xi in 2:
		for zi in 2:
			var x: float = xs[xi]
			var z: float = zs[zi]
			m.part = 1.0 if (xi == 0) == (zi == 0) else 2.0
			m.pivot = Vector2(x, pivot_y)
			m.box(Vector3(x, h * 0.5, z), Vector3(w, h, w), col)
			m.box(Vector3(x, h * 0.06, z), Vector3(w * 1.2, h * 0.12, w * 1.2), foot)
	m.part = 0.0


## Langhals (Pflanzenfresser): Säulenbeine, schwerer Rumpf, langer Hals (Teil 3, senkt sich beim Fressen bis an die
## Farne), langer waagrechter Schwanz (Teil 8). Grau-oliv mit dunklem Rücken, heller Bauch. Länge ≈ 0,26, Höhe ≈ 0,16.
static func _sauro(m: Models.MB, variant: int) -> void:
	var skins := [Color("#a39274"), Color("#9a8c70"), Color("#a8967a")]   # hell, warm: hebt sich vom satten Grün ab
	var skin: Color = skins[variant % skins.size()]
	var back := skin.darkened(0.42)
	var belly := skin.lerp(Color("#d2c6a2"), 0.45)
	_legs4(m, [0.034, -0.034], [-0.017, 0.017], 0.05, 0.016, skin.darkened(0.15), skin.darkened(0.45), 0.06)
	m.blob(Vector3(0, 0.066, 0), Vector3(0.058, 0.03, 0.028), 3.0 + float(variant), belly, skin, 0.06, true)
	m.blob(Vector3(-0.004, 0.08, 0), Vector3(0.05, 0.018, 0.02), 5.0 + float(variant), skin, back, 0.06, true)
	# Hals und Kopf (Teil 3): Drehpunkt an der Schulter
	m.part = 3.0
	m.pivot = Vector2(0.045, 0.075)
	var pts := [Vector3(0.045, 0.075, 0), Vector3(0.07, 0.1, 0), Vector3(0.088, 0.13, 0), Vector3(0.1, 0.158, 0), Vector3(0.112, 0.176, 0)]
	for i in pts.size() - 1:
		var r0 := lerpf(0.017, 0.008, float(i) / 4.0)
		var r1 := lerpf(0.017, 0.008, float(i + 1) / 4.0)
		m.rod(pts[i], pts[i + 1], r0, r1, 7, skin, skin.lerp(back, 0.3))
	m.blob(Vector3(0.122, 0.178, 0), Vector3(0.016, 0.009, 0.009), 7.0, skin.darkened(0.1), skin, 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.128, 0.182, 0.006), Vector3(0.003, 0.003, 0.002), Color("#141210"))
	m.box(Vector3(0.128, 0.182, -0.006), Vector3(0.003, 0.003, 0.002), Color("#141210"))
	# Schwanz (Teil 8): von der Hüfte, sinkt und wird dünn
	m.part = 8.0
	m.pivot = Vector2(-0.05, 0.07)
	var tp := [Vector3(-0.05, 0.07, 0), Vector3(-0.085, 0.06, 0), Vector3(-0.12, 0.045, 0), Vector3(-0.15, 0.032, 0)]
	for i in tp.size() - 1:
		m.rod(tp[i], tp[i + 1], lerpf(0.018, 0.003, float(i) / 3.0), lerpf(0.018, 0.003, float(i + 1) / 3.0), 6, skin, back)
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Raubsaurier (T-rex-artig): zweibeinig, waagrechter Körper, großer Kopf mit hellen Zähnen, winzige Arme,
## dunkles Braun mit Rücken-Streifen, gelbes Auge. Länge ≈ 0,2, Höhe ≈ 0,1.
static func _trex(m: Models.MB, variant: int) -> void:
	var skin := Color("#5a4a36") if variant % 2 == 0 else Color("#4e4434")
	var back := skin.darkened(0.45)
	var belly := skin.lerp(Color("#c8b48c"), 0.4)
	for zi in 2:
		var z := -0.014 if zi == 0 else 0.014
		m.part = 1.0 if zi == 0 else 2.0
		m.pivot = Vector2(0.0, 0.058)
		m.blob(Vector3(0.0, 0.05, z), Vector3(0.016, 0.02, 0.008), 2.0 + float(zi), skin.darkened(0.1), skin, 0.05, true)
		m.rod(Vector3(-0.004, 0.036, z), Vector3(0.006, 0.006, z), 0.006, 0.0045, 5, skin.darkened(0.2), skin.darkened(0.3))
		m.box(Vector3(0.012, 0.003, z), Vector3(0.018, 0.005, 0.009), back)
	m.part = 0.0
	m.blob(Vector3(0.008, 0.066, 0), Vector3(0.042, 0.022, 0.019), 4.0 + float(variant), belly, skin, 0.05, true)
	for k in 4:
		m.box(Vector3(-0.012 + 0.012 * float(k), 0.085, 0), Vector3(0.006, 0.004, 0.02), back)
	# Ärmchen
	for zi in 2:
		var z := -0.012 if zi == 0 else 0.012
		m.part = 5.0 if zi == 0 else 6.0
		m.pivot = Vector2(0.038, 0.066)
		m.rod(Vector3(0.038, 0.066, z), Vector3(0.048, 0.055, z), 0.003, 0.002, 4, skin, skin)
	# Kopf (Teil 3)
	m.part = 3.0
	m.pivot = Vector2(0.042, 0.075)
	m.rod(Vector3(0.036, 0.072, 0), Vector3(0.056, 0.086, 0), 0.012, 0.011, 7, skin, skin)
	m.blob(Vector3(0.072, 0.09, 0), Vector3(0.024, 0.014, 0.012), 6.0, skin.darkened(0.05), skin.lightened(0.05), 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.078, 0.077, 0), Vector3(0.036, 0.007, 0.018), belly.darkened(0.2))
	for k in 5:
		m.box(Vector3(0.064 + 0.007 * float(k), 0.081, 0.0085), Vector3(0.002, 0.004, 0.0015), Color("#ece4d0"))
		m.box(Vector3(0.064 + 0.007 * float(k), 0.081, -0.0085), Vector3(0.002, 0.004, 0.0015), Color("#ece4d0"))
	m.box(Vector3(0.066, 0.098, 0.011), Vector3(0.004, 0.003, 0.002), Color("#f0b030"))
	m.box(Vector3(0.066, 0.098, -0.011), Vector3(0.004, 0.003, 0.002), Color("#f0b030"))
	# Schwanz (Teil 8)
	m.part = 8.0
	m.pivot = Vector2(-0.03, 0.068)
	var tp := [Vector3(-0.03, 0.068, 0), Vector3(-0.07, 0.064, 0), Vector3(-0.11, 0.056, 0), Vector3(-0.14, 0.05, 0)]
	for i in tp.size() - 1:
		m.rod(tp[i], tp[i + 1], lerpf(0.017, 0.002, float(i) / 3.0), lerpf(0.017, 0.002, float(i + 1) / 3.0), 6, skin, back)
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Kleiner Raubsaurier (Rudel zu dritt): schlank, rostbraun mit hellen Streifen, Federkamm am Kopf. Länge ≈ 0,08.
static func _raptor(m: Models.MB, variant: int) -> void:
	var skin := Color("#8a5a36") if variant % 2 == 0 else Color("#7a5a40")
	var stripe := Color("#d8c098")
	for zi in 2:
		var z := -0.005 if zi == 0 else 0.005
		m.part = 1.0 if zi == 0 else 2.0
		m.pivot = Vector2(0.0, 0.022)
		m.rod(Vector3(0.0, 0.022, z), Vector3(-0.003, 0.01, z), 0.003, 0.002, 4, skin, skin)
		m.rod(Vector3(-0.003, 0.01, z), Vector3(0.004, 0.0, z), 0.002, 0.0015, 4, skin.darkened(0.3), skin.darkened(0.3))
	m.part = 0.0
	m.blob(Vector3(0.004, 0.026, 0), Vector3(0.016, 0.0075, 0.0065), 2.0 + float(variant), stripe, skin, 0.05, true)
	m.box(Vector3(0.0, 0.032, 0), Vector3(0.016, 0.0025, 0.004), stripe)
	m.part = 3.0
	m.pivot = Vector2(0.016, 0.03)
	m.rod(Vector3(0.014, 0.028, 0), Vector3(0.024, 0.038, 0), 0.004, 0.003, 5, skin, skin)
	m.blob(Vector3(0.03, 0.039, 0), Vector3(0.009, 0.004, 0.0038), 4.0, skin.darkened(0.1), skin, 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.024, 0.044, 0), Vector3(0.008, 0.004, 0.0015), Color("#b84a2a"))
	m.part = 8.0
	m.pivot = Vector2(-0.01, 0.027)
	m.rod(Vector3(-0.01, 0.027, 0), Vector3(-0.045, 0.03, 0), 0.0045, 0.0012, 5, skin, stripe)
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Flugsaurier (kreist wie die Vögel, MultiMesh): breite, hellbraune Hautflügel mit dunklem Rand, Kopf mit Kamm.
## Spannweite ≈ 0,07 (doppelt so groß wie ein Vogel). Blick nach +x, Flügel in z (Teil 5/6).
static func _ptero(m: Models.MB) -> void:
	var wing := Color("#b89a78")
	var edge := Color("#5a4232")
	m.blob(Vector3.ZERO, Vector3(0.012, 0.004, 0.004), 1.0, wing.darkened(0.2), wing, 0.05, true)
	m.blob(Vector3(0.016, 0.003, 0), Vector3(0.008, 0.0028, 0.0025), 2.0, wing.darkened(0.1), wing, 0.05, true)
	m.tri(Vector3(0.022, 0.003, 0), Vector3(0.036, 0.002, 0), Vector3(0.024, 0.006, 0), Color("#d8c098"), Vector3(0, 0, 1))
	m.tri(Vector3(0.022, 0.003, 0), Vector3(0.024, 0.006, 0), Vector3(0.036, 0.002, 0), Color("#d8c098"), Vector3(0, 0, -1))
	m.tri(Vector3(0.012, 0.005, 0), Vector3(0.002, 0.012, 0), Vector3(0.008, 0.004, 0), edge, Vector3(0, 0, 1))
	m.tri(Vector3(0.012, 0.005, 0), Vector3(0.008, 0.004, 0), Vector3(0.002, 0.012, 0), edge, Vector3(0, 0, -1))
	for zs in [-1.0, 1.0]:
		var z: float = zs
		m.part = 5.0 if z < 0.0 else 6.0
		var a := Vector3(0.008, 0.001, 0)
		var b := Vector3(-0.008, 0.001, 0)
		var tip := Vector3(0.0, 0.006, z * 0.036)
		var back_tip := Vector3(-0.01, 0.003, z * 0.02)
		m.tri(a, b, back_tip, wing, Vector3.UP)
		m.tri(a, back_tip, tip, wing.lightened(0.05), Vector3.UP)
		m.tri(a, back_tip, b, wing.darkened(0.25), Vector3.DOWN)
		m.tri(a, tip, back_tip, wing.darkened(0.25), Vector3.DOWN)
		m.tri(tip, back_tip, tip + Vector3(-0.006, -0.001, -z * 0.002), edge, Vector3.UP)
	m.part = 0.0


## Mammut: hoher Buckel, zottiges dunkles Fell mit hellerem Saum (hängende Fransen), Rüssel und weiße, gebogene
## Stoßzähne. Liest sich auf Schnee als dunkler Umriss mit zwei hellen Bögen. Länge ≈ 0,1, Höhe ≈ 0,09.
static func _mammoth(m: Models.MB, variant: int) -> void:
	var fur := Color("#5e4130") if variant % 2 == 0 else Color("#6e4c34")
	var dark := fur.darkened(0.35)
	var light := fur.lerp(Color("#b08a64"), 0.45)
	_legs4(m, [0.026, -0.024], [-0.014, 0.014], 0.036, 0.014, dark, Color("#2a201a"), 0.045)
	m.blob(Vector3(-0.004, 0.054, 0), Vector3(0.04, 0.026, 0.026), 2.0 + float(variant), dark, fur, 0.14, true)
	m.blob(Vector3(0.016, 0.07, 0), Vector3(0.024, 0.024, 0.022), 4.0 + float(variant), fur, light, 0.18, true)
	# Fransen am Bauch
	for k in 7:
		var x := -0.034 + 0.011 * float(k)
		for zs in [-1.0, 1.0]:
			var z: float = zs
			m.box(Vector3(x, 0.034, z * 0.021), Vector3(0.008, 0.012, 0.004), light.darkened(0.15 * float(k % 2)))
	m.part = 3.0
	m.pivot = Vector2(0.032, 0.07)
	m.blob(Vector3(0.044, 0.07, 0), Vector3(0.016, 0.02, 0.016), 6.0, dark, fur, 0.1, true, Vector3(INF, 0, 0), 0)
	m.blob(Vector3(0.04, 0.088, 0), Vector3(0.012, 0.01, 0.012), 8.0, fur, light, 0.1, true)
	# Rüssel
	m.rod(Vector3(0.056, 0.064, 0), Vector3(0.062, 0.04, 0), 0.006, 0.0045, 5, dark, dark)
	m.rod(Vector3(0.062, 0.04, 0), Vector3(0.06, 0.02, 0), 0.0045, 0.003, 5, dark, dark)
	# Stoßzähne
	var ivory := Color("#efe6d2")
	for zs in [-1.0, 1.0]:
		var z: float = zs
		m.rod(Vector3(0.054, 0.058, z * 0.008), Vector3(0.072, 0.04, z * 0.014), 0.0038, 0.0032, 5, ivory, ivory)
		m.rod(Vector3(0.072, 0.04, z * 0.014), Vector3(0.088, 0.046, z * 0.012), 0.0032, 0.0024, 5, ivory, ivory)
		m.rod(Vector3(0.088, 0.046, z * 0.012), Vector3(0.092, 0.06, z * 0.006), 0.0024, 0.0012, 4, ivory, ivory)
		m.box(Vector3(0.036, 0.074, z * 0.016), Vector3(0.006, 0.012, 0.004), dark)
	m.part = 7.0
	m.pivot = Vector2(-0.044, 0.06)
	m.box(Vector3(-0.046, 0.05, 0), Vector3(0.003, 0.018, 0.003), dark)
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Affe (Primat): geht auf den Knöcheln, lange Arme (Teil 5/6), schwarzbraunes Fell, helles Gesicht. Höhe ≈ 0,045.
static func _ape(m: Models.MB, variant: int) -> void:
	var fur := Color("#3a2c22") if variant % 2 == 0 else Color("#4a3426")
	var face := Color("#b08a6a")
	for zi in 2:
		var z := -0.006 if zi == 0 else 0.006
		m.part = 1.0 if zi == 0 else 2.0
		m.pivot = Vector2(-0.008, 0.016)
		m.rod(Vector3(-0.008, 0.016, z), Vector3(-0.006, 0.0, z), 0.0042, 0.0035, 5, fur, fur.darkened(0.2))
	m.part = 0.0
	m.blob(Vector3(0.0, 0.026, 0), Vector3(0.014, 0.013, 0.011), 2.0 + float(variant), fur.darkened(0.1), fur, 0.12, true)
	m.blob(Vector3(0.008, 0.034, 0), Vector3(0.012, 0.01, 0.011), 3.0, fur, fur.lightened(0.05), 0.12, true)
	for zi in 2:
		var z := -0.011 if zi == 0 else 0.011
		m.part = 5.0 if zi == 0 else 6.0
		m.pivot = Vector2(0.012, 0.036)
		m.rod(Vector3(0.012, 0.036, z), Vector3(0.018, 0.016, z), 0.0042, 0.0036, 5, fur, fur)
		m.rod(Vector3(0.018, 0.016, z), Vector3(0.02, 0.0, z), 0.0036, 0.003, 5, fur, fur.darkened(0.2))
	m.part = 3.0
	m.pivot = Vector2(0.016, 0.042)
	m.blob(Vector3(0.022, 0.046, 0), Vector3(0.008, 0.008, 0.0075), 5.0, fur, fur, 0.08, true, Vector3(INF, 0, 0), 0)
	m.blob(Vector3(0.029, 0.044, 0), Vector3(0.0045, 0.005, 0.006), 6.0, face.darkened(0.1), face, 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.031, 0.048, 0.003), Vector3(0.0015, 0.0015, 0.0015), Color("#141010"))
	m.box(Vector3(0.031, 0.048, -0.003), Vector3(0.0015, 0.0015, 0.0015), Color("#141010"))
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Frühmensch / Jäger: Fellkleid (braun, heller Saum), dunkles langes Haar, Speer in der rechten Hand (Teil 6).
## Gleiche Größe und Teile wie Models._person (0,055 hoch): bückt sich, geht, arbeitet.
static func _hunter(m: Models.MB, variant: int) -> void:
	var fur: Color = [Color("#7a5a3c"), Color("#8a6a48"), Color("#6a4a32")][variant % 3]
	var skin: Color = Models.SKIN_C[(variant / 2 + 2) % Models.SKIN_C.size()]
	var hair := Color("#2a2018")
	var hip := 0.024
	m.hip = hip
	for zi in 2:
		var z := -0.0042 if zi == 0 else 0.0042
		m.part = 1.0 if zi == 0 else 2.0
		m.pivot = Vector2(0, hip)
		m.box(Vector3(0, hip * 0.52, z), Vector3(0.0062, hip * 0.96, 0.0058), skin.darkened(0.1))
		m.box(Vector3(0.0015, 0.0018, z), Vector3(0.009, 0.0036, 0.0064), Color("#5a4030"))
	m.part = 4.0
	m.pivot = Vector2(0, hip)
	m.cyl(Vector3(0, hip * 0.5, 0), 0.0105, 0.0082, hip * 0.62, 8, fur.lightened(0.15), fur, false)
	m.box(Vector3(0, hip + 0.0105, 0), Vector3(0.0115, 0.021, 0.0155), fur, fur.lightened(0.05))
	m.box(Vector3(0, hip + 0.0225, 0), Vector3(0.004, 0.003, 0.004), skin)
	m.blob(Vector3(0.0006, hip + 0.0285, 0), Vector3(0.0062, 0.0068, 0.0058), 1.0 + float(variant), skin.darkened(0.12), skin, 0.06, true,
		Vector3(INF, 0, 0), 1)
	m.blob(Vector3(-0.002, hip + 0.03, 0), Vector3(0.0068, 0.0062, 0.0066), 3.0, hair.darkened(0.1), hair, 0.12, true, Vector3(INF, 0, 0), 1, -0.3)
	m.box(Vector3(-0.005, hip + 0.022, 0), Vector3(0.004, 0.012, 0.01), hair)
	for zi in 2:
		var z := -0.0098 if zi == 0 else 0.0098
		m.part = 5.0 if zi == 0 else 6.0
		m.pivot = Vector2(0, hip + 0.019)
		m.box(Vector3(0, hip + 0.0105, z), Vector3(0.0045, 0.018, 0.0042), skin)
		if zi == 1 and variant % 3 != 2:
			m.rod(Vector3(-0.012, hip - 0.012, z + 0.002), Vector3(0.016, hip + 0.05, z + 0.002), 0.0013, 0.0011, 4, Color("#8a6a42"),
				Color("#8a6a42"))
			m.box(Vector3(0.017, hip + 0.053, z + 0.002), Vector3(0.003, 0.007, 0.0025), Color("#5a5652"))
	m.part = 0.0
	m.hip = 0.0
	m.pivot = Vector2.ZERO


## Kleines Säugetier (nach dem Meteor): spitzmausartig, braun, langer Schwanz. Länge ≈ 0,03.
static func _shrew(m: Models.MB, variant: int) -> void:
	var fur := Color("#7a5e44") if variant % 2 == 0 else Color("#6a5240")
	_legs4(m, [0.006, -0.006], [-0.003, 0.003], 0.004, 0.0022, fur.darkened(0.2), fur.darkened(0.3), 0.006)
	m.blob(Vector3(0, 0.007, 0), Vector3(0.011, 0.006, 0.0055), 2.0, fur.lightened(0.1), fur, 0.1, true)
	m.part = 3.0
	m.pivot = Vector2(0.008, 0.008)
	m.blob(Vector3(0.013, 0.008, 0), Vector3(0.0065, 0.0042, 0.004), 3.0, fur, fur, 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.01, 0.012, 0.0028), Vector3(0.002, 0.003, 0.002), fur.darkened(0.2))
	m.box(Vector3(0.01, 0.012, -0.0028), Vector3(0.002, 0.003, 0.002), fur.darkened(0.2))
	m.part = 8.0
	m.pivot = Vector2(-0.01, 0.006)
	m.rod(Vector3(-0.01, 0.006, 0), Vector3(-0.026, 0.004, 0), 0.0012, 0.0006, 3, Color("#b89a84"), Color("#b89a84"))
	m.part = 0.0
	m.pivot = Vector2.ZERO


## Trilobit (Kambrium, am flachen Grund): flaches Oval aus Segmenten, Kopfschild, grau-braun. Länge ≈ 0,025.
static func _trilobite(m: Models.MB, variant: int) -> void:
	var c := Color("#7a6a58") if variant % 2 == 0 else Color("#6a6460")
	m.blob(Vector3(0.008, 0.002, 0), Vector3(0.007, 0.0025, 0.009), 1.0, c.darkened(0.2), c.lightened(0.1), 0.05, true)
	for k in 5:
		var w := 0.008 - 0.0011 * float(k)
		m.box(Vector3(0.0 - 0.0035 * float(k), 0.0018, 0), Vector3(0.003, 0.0026, w * 2.0), c if k % 2 == 0 else c.darkened(0.2))
	m.box(Vector3(-0.004, 0.0032, 0), Vector3(0.018, 0.0012, 0.003), c.lightened(0.15))


## Qualle (Kambrium): durchscheinende, leicht leuchtende Glocke mit Fäden (MultiMesh, pulsiert). Ø ≈ 0,025.
static func _jelly(m: Models.MB) -> void:
	var c := Color("#e8c8e0")
	m.blob(Vector3(0, 0.006, 0), Vector3(0.012, 0.007, 0.012), 1.0, c.darkened(0.15), c, 0.05, true, Vector3(INF, 0, 0), 1, -0.1)
	for k in 6:
		var a := TAU * float(k) / 6.0
		m.rod(Vector3(cos(a) * 0.007, 0.002, sin(a) * 0.007), Vector3(cos(a) * 0.009, -0.014, sin(a) * 0.009), 0.0008, 0.0004, 3, c, c)


## Libelle (Karbon, Riesenlibelle über Farn und Sumpf): dünner blaugrüner Leib, vier gläserne Flügel. Spannweite ≈ 0,04.
static func _dragonfly(m: Models.MB) -> void:
	var body := Color("#2a6a6a")
	m.rod(Vector3(-0.016, 0, 0), Vector3(0.008, 0, 0), 0.0012, 0.0018, 4, body, body.lightened(0.2))
	m.blob(Vector3(0.01, 0.0005, 0), Vector3(0.0025, 0.002, 0.003), 1.0, body, Color("#3a8a7a"), 0.05, true)
	var wing := Color("#dfe8ec")
	for zs in [-1.0, 1.0]:
		var z: float = zs
		m.part = 5.0 if z < 0.0 else 6.0
		for xo in [0.004, -0.002]:
			var x: float = xo
			m.tri(Vector3(x, 0.001, 0), Vector3(x - 0.004, 0.001, z * 0.02), Vector3(x + 0.002, 0.001, z * 0.019), wing, Vector3.UP)
			m.tri(Vector3(x, 0.001, 0), Vector3(x + 0.002, 0.001, z * 0.019), Vector3(x - 0.004, 0.001, z * 0.02), wing.darkened(0.15), Vector3.DOWN)
	m.part = 0.0


## Amphibie (Landgang, groß): breiter, flacher Kopf, gespreizte Beine, olivgrün mit gelbem Bauch. Länge ≈ 0,06.
static func _amph(m: Models.MB) -> void:
	var skin := Color("#55603a")
	var belly := Color("#c8a040")
	for xi in 2:
		for zi in 2:
			var x := 0.012 if xi == 0 else -0.012
			var z := -1.0 if zi == 0 else 1.0
			m.part = 1.0 if (xi == 0) == (zi == 0) else 2.0
			m.pivot = Vector2(x, 0.008)
			m.rod(Vector3(x, 0.008, z * 0.008), Vector3(x + 0.003, 0.001, z * 0.016), 0.0028, 0.0022, 4, skin, skin.darkened(0.2))
	m.part = 0.0
	m.blob(Vector3(0, 0.008, 0), Vector3(0.018, 0.005, 0.009), 1.0, belly, skin, 0.08, true)
	for k in 4:
		m.bead(Vector3(-0.01 + 0.007 * float(k), 0.013, 0.003 * float(k % 2) - 0.0015), 0.0018, Color("#3a4228"))
	m.part = 3.0
	m.pivot = Vector2(0.016, 0.008)
	m.blob(Vector3(0.024, 0.008, 0), Vector3(0.01, 0.0045, 0.009), 2.0, skin.darkened(0.1), skin, 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.024, 0.0125, 0.005), Vector3(0.0025, 0.0025, 0.0025), Color("#d8b030"))
	m.box(Vector3(0.024, 0.0125, -0.005), Vector3(0.0025, 0.0025, 0.0025), Color("#d8b030"))
	m.part = 8.0
	m.pivot = Vector2(-0.016, 0.008)
	m.rod(Vector3(-0.016, 0.008, 0), Vector3(-0.04, 0.004, 0), 0.0045, 0.001, 5, skin, skin.darkened(0.2))
	m.part = 0.0
	m.pivot = Vector2.ZERO


# --- Pflanzen ----------------------------------------------------------------------------------------------

## Palmfarn (Saurierzeit): dicker, schuppiger Stumpf, Krone aus steifen, glänzenden Wedeln (Liest sich als
## „Urzeit-Palme“, niedriger als Wald, höher als Farn).
static func _cycad(p: Dictionary, seed: float, h: float) -> void:
	var s: Models.MB = p["solid"]
	var l: Models.MB = p["leaf"]
	s.cyl(Vector3.ZERO, h * 0.22, h * 0.17, h * 0.55, 8, Color("#5a4630"), Color("#6e5838"), true)
	for k in 4:
		s.cyl(Vector3(0, h * (0.08 + 0.12 * float(k)), 0), h * 0.235, h * 0.2, h * 0.05, 8, Color("#4a3a28"), Color("#5a4630"), false)
	var n := 9
	for k in n:
		var a := seed * 1.7 + TAU * float(k) / float(n)
		var dir := Vector3(cos(a), 0, sin(a))
		Models._frond(l, Vector3(0, h * 0.55, 0), dir, h * 0.95, h * 0.75, h * 0.6, seed + float(k), Color("#2e5a26"), Color("#7aa84a"))
	l.blob(Vector3(0, h * 0.6, 0), Vector3(h * 0.12, h * 0.1, h * 0.12), seed, Color("#8a6a2a"), Color("#c8a040"), 0.2, true)


## Araukarie / Schirm-Nadelbaum (Saurierzeit): hoher, kahler Stamm, oben flache Etagen (Schirm-Silhouette).
static func _araucaria(p: Dictionary, seed: float, h: float) -> void:
	var s: Models.MB = p["solid"]
	var l: Models.MB = p["leaf"]
	s.rod(Vector3.ZERO, Vector3(0, h, 0), h * 0.035, h * 0.02, 6, Models.BARK_D, Models.BARK)
	# Schirm: zwei flache, helle Kronen-Etagen (von oben eine runde Scheibe, von der Seite ein T)
	for k in 2:
		var y := h * (0.82 + 0.13 * float(k))
		var r := h * (0.34 - 0.1 * float(k))
		l.blob(Vector3(0, y, 0), Vector3(r, h * 0.06, r), seed + float(k), Color("#2e4a26"), Color("#6a8a46"), 0.3, true,
			Vector3(0, y - h * 0.2, 0), 1, -0.2)
	for k in 5:
		var a := seed + TAU * float(k) / 5.0
		s.rod(Vector3(0, h * 0.8, 0), Vector3(cos(a) * h * 0.26, h * 0.84, sin(a) * h * 0.26), h * 0.012, h * 0.008, 4, Models.BARK_D, Models.BARK)


## Akazie (Savanne, Affen und Frühmenschen): schräger Stamm, flache, breite Schirmkrone.
static func _acacia(p: Dictionary, seed: float, h: float) -> void:
	var s: Models.MB = p["solid"]
	var l: Models.MB = p["leaf"]
	var top := Vector3(0.02, h * 0.8, 0.01)
	s.rod(Vector3.ZERO, top, h * 0.05, h * 0.035, 6, Models.BARK_D, Models.BARK)
	s.rod(top, top + Vector3(-0.05, h * 0.15, 0.02), h * 0.03, h * 0.02, 5, Models.BARK, Models.BARK)
	s.rod(top, top + Vector3(0.05, h * 0.13, -0.03), h * 0.03, h * 0.02, 5, Models.BARK, Models.BARK)
	for k in 5:
		var a := seed + TAU * float(k) / 5.0
		l.blob(top + Vector3(cos(a) * h * 0.32, h * 0.2, sin(a) * h * 0.28), Vector3(h * 0.3, h * 0.07, h * 0.26), seed + float(k),
			Color("#4a5a24"), Color("#8a9a46"), 0.25, true, Vector3(INF, 0, 0), 1, -0.3)


## Lagerfeuer: Steinring, gekreuzte Scheite, Glut (Teil „warm“: leuchtet nachts ×2,5). Die Flamme setzt der Builder
## mit Models.flame() darauf.
static func _campfire(p: Dictionary, seed: float) -> void:
	var s: Models.MB = p["solid"]
	var w: Models.MB = p["warm"]
	for k in 8:
		var a := TAU * float(k) / 8.0
		s.blob(Vector3(cos(a) * 0.03, 0.005, sin(a) * 0.03), Vector3(0.008, 0.006, 0.007), seed + float(k), Color("#5a5652"), Color("#8a857c"),
			0.3, false, Vector3(INF, 0, 0), 0, -0.4)
	for k in 3:
		var a := seed + TAU * float(k) / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		s.rod(d * 0.022 + Vector3(0, 0.003, 0), -d * 0.004 + Vector3(0, 0.014, 0), 0.0035, 0.003, 5, Color("#4a3426"), Color("#2a1e18"))
	w.blob(Vector3(0, 0.004, 0), Vector3(0.016, 0.004, 0.016), seed, Color("#ff7a2a"), Color("#ffc060"), 0.3, true)


## Schnee auf den Etagen einer Fichte (Eiszeit): helle Kappen oben auf jeder Etage.
static func _snowcaps(p: Dictionary, seed: float, h: float, tiers: int) -> void:
	var s: Models.MB = p["solid"]
	for k in tiers:
		var t := float(k) / float(tiers)
		var y := h * (0.2 + 0.72 * t)
		var r := h * 0.3 * (1.0 - t * 0.75)
		s.cyl(Vector3(0, y, 0), r * 0.8, r * 0.25, h * 0.07, 8, Color("#dfe6ec"), Color("#f4f7fa"), true, seed)
