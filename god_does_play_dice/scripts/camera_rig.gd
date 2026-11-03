class_name CameraRig
extends Node3D
## Kamera-Halter im Würfelmittelpunkt. Die Kamera schaut immer auf den Ursprung.
## Ziehen dreht frei, Zoomen ändert den Abstand, „Höhe“ hebt/senkt die Kamera.

const MIN_DIST := 5.0
const MAX_DIST := 14.0
const ORBIT_SPEED := 0.008

var cam: Camera3D
var dist := 8.5
var height := 0.0
var _q_from := Quaternion.IDENTITY
var _q_to := Quaternion.IDENTITY
var _anim_t := 1.0
var _anim_dur := 0.45


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.1
	cam.far = 100.0
	add_child(cam)
	cam.current = true
	# Licht hängt an der Kamera, damit jede Seite gleich gut aussieht
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -30, 0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	_apply()


func _apply() -> void:
	cam.position = Vector3(0, height, dist)


func _process(delta: float) -> void:
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + delta / _anim_dur)
		var e := ease(_anim_t, -2.0)
		quaternion = _q_from.slerp(_q_to, e).normalized()


func orbit(dx: float, dy: float) -> void:
	_anim_t = 1.0
	basis = (basis * Basis(Vector3.UP, -dx * ORBIT_SPEED) * Basis(Vector3.RIGHT, -dy * ORBIT_SPEED)).orthonormalized()


func zoom(factor: float) -> void:
	dist = clampf(dist * factor, MIN_DIST, MAX_DIST)
	_apply()


func pan_height(dy_px: float) -> void:
	height = clampf(height + dy_px * 0.01, -2.5, 2.5)
	_apply()


## Ansicht um 90° um eine lokale Achse drehen (Tipp neben den Würfel).
func turn(local_axis: Vector3, angle: float) -> void:
	_start_anim(Basis(quaternion) * Basis(local_axis, angle))


## Ansicht so drehen, dass die Seite mit Normale n vorne ist (leicht schräg von oben).
func focus_face(n: Vector3) -> void:
	_start_anim(face_basis(n))


static func face_basis(n: Vector3) -> Basis:
	var t := Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
	var s := t.cross(n)
	var z := (n + t * 0.6 + s * 0.35).normalized()
	var y := (Vector3.UP - z * z.dot(Vector3.UP)).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func _start_anim(target: Basis) -> void:
	_q_from = quaternion.normalized()
	_q_to = target.orthonormalized().get_rotation_quaternion()
	_anim_t = 0.0


func is_animating() -> bool:
	return _anim_t < 1.0
