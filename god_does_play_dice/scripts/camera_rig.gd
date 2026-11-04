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


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	cam.far = 100.0
	add_child(cam)
	cam.current = true
	# Licht hängt an der Kamera: jede Seite sieht gleich schön aus
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_color = Color("#fff3df")
	key.light_energy = 0.78
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	key.directional_shadow_max_distance = 25.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_color = Color("#cfe0ff")
	fill.light_energy = 0.18
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
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.08
	var tb := Basis(Vector3.UP, _tilt.x) * Basis(Vector3.RIGHT, _tilt.y)
	cam.transform = Transform3D(tb, tb * (Vector3(0, 0, _dist * zoom_factor) + off))


func _process(delta: float) -> void:
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / _anim_dur)
		quaternion = _q_from.slerp(_q_to, ease(_anim_t, -2.2)).normalized()
	elif _vel.length() > 0.5:
		_rotate_by(_vel * delta)
		_vel = _vel * exp(-delta * 3.2)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
	_update_tilt(delta)
	_apply()


## Handy schwenken neigt den Würfel ein wenig. Die Ruhelage passt sich langsam an, wie man das Handy hält.
func _update_tilt(delta: float) -> void:
	var g := Input.get_gravity()
	var target := Vector2.ZERO
	if g.length() > 1.0 and Balance.TILT_MAX > 0.0:
		if _g_base == Vector3.ZERO:
			_g_base = g
		_g_base = _g_base.lerp(g, 1.0 - exp(-delta * 0.6))
		var d := (g - _g_base) / 9.81
		target = Vector2(clampf(-d.x * 1.6, -1.0, 1.0), clampf(d.z * 1.6, -1.0, 1.0)) * Balance.TILT_MAX
	_tilt = _tilt.lerp(target, 1.0 - exp(-delta * 6.0))


func _rotate_by(px: Vector2) -> void:
	basis = (basis * Basis(Vector3.UP, -px.x * ORBIT_SPEED) * Basis(Vector3.RIGHT, -px.y * ORBIT_SPEED)).orthonormalized()


## Ziehen: dreht sofort mit, merkt sich die Geschwindigkeit für den Nachschwung.
func orbit(rel: Vector2, delta: float) -> void:
	_anim_t = 1.0
	_rotate_by(rel)
	if delta > 0.0:
		_vel = _vel.lerp(rel / delta, 0.5)


## Um die Blickachse drehen (zwei Finger drehen).
func roll(angle: float) -> void:
	_anim_t = 1.0
	basis = (basis * Basis(Vector3.BACK, -angle)).orthonormalized()


func release() -> void:
	pass


func stop() -> void:
	_vel = Vector2.ZERO


func zoom(factor: float) -> void:
	zoom_factor = clampf(zoom_factor * factor, 0.6, 1.6)
	_apply()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


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
