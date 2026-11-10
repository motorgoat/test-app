class_name CameraRig
extends Node3D
## Kamera-Halter im Würfelmittelpunkt. Die Kamera schaut immer auf den Ursprung.
## Weiches Drehen mit Nachschwung, Abstand passt sich dem Bildschirm an.

const ORBIT_SPEED := 0.0058
const FIT_RADIUS := 2.45

var cam: Camera3D
var zoom_factor := 1.0
var _dist := 9.0
var _vel := Vector2.ZERO
var _q_from := Quaternion.IDENTITY
var _q_to := Quaternion.IDENTITY
var _anim_t := 1.0
var _anim_dur := 0.85
var _shake := 0.0
var _tilt := Vector2.ZERO       # leichtes Neigen durch Schwenken des Handys
var _g_base := Vector3.ZERO
var key: DirectionalLight3D     # Sonne (die einzige Lampe mit Schatten)
var fill: DirectionalLight3D    # kühles Himmelslicht von der anderen Seite
var drift_enabled := true       # Leerlauf-Drift (World schaltet sie in Tour und Tutorial ab)
var _still_t := 0.0             # so lange gab es keine Kamera-Eingabe
var _drift := Vector2.ZERO      # aktuelle Drift (Grad), weich ein- und ausgeblendet
var _drift_w := 0.0
var _drift_t := 0.0
var _shake_t := 0.0
var _punch := 1.0               # kurzer Zoom-Stoß beim Verschmelzen (Faktor auf den Abstand)
var _punch_tw: Tween


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	cam.far = 100.0
	add_child(cam)
	cam.current = true
	# Licht hängt an der Kamera: jede Seite sieht gleich schön aus. Werte nach GDPD_GRAFIK.md 4 (die Stimmung
	# in World.set_mood überblendet Farbe, Energie und Richtung).
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36, -48, 0)
	key.light_color = Color("#ffe2b8")
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.shadow_blur = 1.2
	# ruhiger Schatten: eine einzige, enge Schattenkarte und genug Abstand gegen Flimmern
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 24.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	key.shadow_opacity = 0.7
	add_child(key)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("#a9c2e8")
	fill.light_energy = 0.55
	add_child(fill)
	basis = start_basis()
	_fit()
	get_viewport().size_changed.connect(_fit)


static func start_basis() -> Basis:
	var z := Vector3(0.75, 0.95, 1.1).normalized()
	var y := (Vector3.UP - z * z.dot(Vector3.UP)).normalized()
	return Basis(y.cross(z).normalized(), y, z)


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	var half_v := deg_to_rad(cam.fov) * 0.5
	var half_h := atan(tan(half_v) * aspect)
	var half := minf(half_v, half_h)
	_dist = FIT_RADIUS / sin(half)
	_apply()


func _apply() -> void:
	var off := Vector3.ZERO
	if _shake > 0.0:
		# weiches Schütteln: glattes Rauschen statt Zufall je Bild, Stärke trauma²
		var tr := _shake * _shake
		off = Vector3(_wobble(_shake_t, 0.0), _wobble(_shake_t, 1.7), 0) * tr * 0.11
	var tb := Basis(Vector3.UP, _tilt.x + deg_to_rad(_drift.x)) * Basis(Vector3.RIGHT, _tilt.y + deg_to_rad(_drift.y))
	cam.transform = Transform3D(tb, tb * (Vector3(0, 0, _dist * zoom_factor * _punch * (1.0 - 0.015 * _drift_w * (0.5 + 0.5 * sin(_drift_t * 0.31)))) + off))


static func _wobble(t: float, seed_off: float) -> float:
	return sin(t * 37.0 + seed_off) * 0.55 + sin(t * 23.0 + seed_off * 2.3) * 0.3 + sin(t * 51.0 + seed_off * 0.7) * 0.15


func _process(delta: float) -> void:
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / _anim_dur)
		quaternion = _q_from.slerp(_q_to, ease(_anim_t, -2.2)).normalized()
	elif _vel.length() > 0.5:
		_rotate_by(_vel * delta)
		_vel = _vel * exp(-delta * 3.2)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		_shake_t += delta
	_update_tilt(delta)
	_update_drift(delta)
	_apply()


## Leerlauf-Drift: Nach 4 s ohne Berührung schwebt die Kamera ganz langsam (±2°, Lissajous), dazu ein leichtes
## „Atmen“ des Abstands. Jede Eingabe (poke) stoppt sie sofort. In Tour und Tutorial ist sie aus.
func _update_drift(delta: float) -> void:
	_still_t += delta
	var want := 1.0 if drift_enabled and _still_t > 4.0 and _anim_t >= 1.0 and _vel.length() < 0.5 else 0.0
	_drift_w = move_toward(_drift_w, want, delta * (0.35 if want > 0.0 else 4.0))
	if _drift_w > 0.0:
		_drift_t += delta
	_drift = Vector2(sin(_drift_t * 0.27) * 2.0, sin(_drift_t * 0.19 + 1.1) * 1.3) * _drift_w


## Eingabe am Würfel: Drift sofort aus (und erst nach 4 s Ruhe wieder an).
func poke() -> void:
	_still_t = 0.0
	if _drift_w > 0.0:
		# die Drift in die Ruhelage übernehmen: kein Sprung unter dem Finger
		basis = (basis * Basis(Vector3.UP, deg_to_rad(_drift.x)) * Basis(Vector3.RIGHT, deg_to_rad(_drift.y))).orthonormalized()
		_drift = Vector2.ZERO
		_drift_w = 0.0
		_apply()


## Kurzer Zoom-Stoß (Verschmelzen): 1,0 -> 1-amount in 0,12 s, dann federnd zurück.
func punch(amount: float = 0.035) -> void:
	if _punch_tw != null and _punch_tw.is_valid():
		_punch_tw.kill()
	_punch_tw = create_tween()
	_punch_tw.tween_property(self, "_punch", 1.0 - amount, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tw.tween_property(self, "_punch", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Handy schwenken neigt den Würfel ein wenig. Die Ruhelage passt sich langsam an, wie man das Handy hält.
func _update_tilt(delta: float) -> void:
	var g := Input.get_gravity()
	var target := Vector2.ZERO
	if g.length() > 1.0 and Balance.TILT_MAX > 0.0:
		if _g_base == Vector3.ZERO:
			_g_base = g
		_g_base = _g_base.lerp(g, 1.0 - exp(-delta * 0.6))
		var d := (g - _g_base) / 9.81
		# Senkrecht passend zum Ziehen umgekehrt (ORBIT_INVERT_Y): Oberkante des Handys wegkippen wirkt wie Finger nach unten
		var tz := -d.z if ORBIT_INVERT_Y else d.z
		target = Vector2(clampf(-d.x * 2.6, -1.0, 1.0), clampf(tz * 2.6, -1.0, 1.0)) * Balance.TILT_MAX
	_tilt = _tilt.lerp(target, 1.0 - exp(-delta * 6.0))


## Senkrecht umgekehrt (Build 12, Wunsch nach dem Spielen am Handy): Finger nach unten zieht die Kamera nach unten
## (man sieht mehr von der Unterseite), Finger nach oben zeigt mehr von oben. Waagerecht wie bisher.
const ORBIT_INVERT_Y := true


func _rotate_by(px: Vector2) -> void:
	var vy := px.y if ORBIT_INVERT_Y else -px.y
	basis = (basis * Basis(Vector3.UP, -px.x * ORBIT_SPEED) * Basis(Vector3.RIGHT, vy * ORBIT_SPEED)).orthonormalized()


## Ziehen: dreht sofort mit, merkt sich die Geschwindigkeit für den Nachschwung.
func orbit(rel: Vector2, delta: float) -> void:
	poke()
	_anim_t = 1.0
	_rotate_by(rel)
	if delta > 0.0:
		_vel = _vel.lerp(rel / delta, 0.5)


## Um die Blickachse drehen (zwei Finger drehen).
func roll(angle: float) -> void:
	poke()
	_anim_t = 1.0
	basis = (basis * Basis(Vector3.BACK, -angle)).orthonormalized()


func release() -> void:
	pass


func stop() -> void:
	_vel = Vector2.ZERO


func zoom(factor: float) -> void:
	poke()
	zoom_factor = clampf(zoom_factor * factor, 0.6, 1.6)
	_apply()


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.6)


## Weich so drehen, dass die Stelle mit Normale n gut sichtbar ist (leicht schräg von oben).
func focus(n: Vector3) -> void:
	var t := Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
	var z := (n + t * 0.55 + t.cross(n) * 0.3).normalized()
	var y := (Vector3.UP - z * z.dot(Vector3.UP)).normalized()
	var target := Basis(y.cross(z).normalized(), y, z)
	_vel = Vector2.ZERO
	_q_from = quaternion.normalized()
	_q_to = target.get_rotation_quaternion()
	_anim_t = 0.0
