class_name HazardView
extends Node3D
## Eine angekündigte Gefahr an einem Platz im Raum (dreht sich NICHT mit dem Würfel).
## Roter Zielring auf dem Feld, darüber Meteor oder Gewitterwolke, dazu die Runden bis zum Einschlag.

var kind := ""
var place_key := -1
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _obj: Node3D
var _label: Label3D
var _time := 0.0
var _obj_base_y := 1.0


func setup(h: Dictionary) -> void:
	kind = h["type"]
	var p: Vector3i = h["p"]
	var n: Vector3i = h["n"]
	place_key = GameState.pos_key(p, n)
	var nv := Vector3(n)
	var a := GameState.axis_of(n)
	var x := Vector3(GameState.unit((a + 1) % 3, 1))
	transform = Transform3D(Basis(x, nv, x.cross(nv)), Vector3(p) + nv * 0.5)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.46
	torus.rings = 32
	torus.ring_segments = 8
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.25, 1)
	_ring.position.y = 0.07
	_ring_mat = Models.mat(Color("#ff4b3a"), 0.4, 1.4).duplicate()
	_ring.material_override = _ring_mat
	add_child(_ring)

	_obj = Node3D.new()
	add_child(_obj)
	if kind == "meteor":
		_obj_base_y = 1.25
		Models.sphere(_obj, 0.17, Color("#7a6250"), Vector3.ZERO, Models.mat(Color("#7a6250"), 0.8), 0.9)
		Models.sphere(_obj, 0.05, Color("#5e4a3c"), Vector3(0.08, 0.08, 0.12))
		Models.sphere(_obj, 0.21, Color(1.0, 0.55, 0.15, 0.35), Vector3.ZERO, Models.mat(Color(1.0, 0.55, 0.15, 0.35), 0.5, 1.8))
		for k in 3:
			Models.sphere(_obj, 0.12 - k * 0.03, Color(1.0, 0.7, 0.3, 0.3), Vector3(0.0, 0.2 + k * 0.17, 0.0), Models.mat(Color(1.0, 0.7, 0.3, 0.3), 0.5, 1.5))
	else:
		_obj_base_y = 1.0
		var cloud := Color("#8d97a8")
		Models.sphere(_obj, 0.17, cloud, Vector3(0, 0, 0))
		Models.sphere(_obj, 0.13, cloud, Vector3(0.17, -0.03, 0.04))
		Models.sphere(_obj, 0.12, cloud, Vector3(-0.17, -0.04, -0.02))
		Models.sphere(_obj, 0.1, cloud.lightened(0.1), Vector3(0.05, 0.1, -0.08))
		for k in 4:
			Models.box(_obj, Vector3(0.008, 0.08, 0.008), Color(0.55, 0.75, 1.0, 0.8), Vector3(-0.15 + k * 0.1, -0.22, 0.02 * k))
	_obj.position.y = _obj_base_y

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = Style.bold()
	_label.font_size = 64
	_label.pixel_size = 0.003
	_label.outline_size = 18
	_label.outline_modulate = Color("#e5483c")
	_label.position = Vector3(0, _obj_base_y + 0.35, 0)
	_label.render_priority = 4
	_label.outline_render_priority = 3
	add_child(_label)
	set_timer(int(h["timer"]))

	# Erscheinen
	_obj.scale = Vector3.ZERO
	_ring.scale = Vector3.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_obj, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ring, "scale", Vector3(1, 0.25, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_timer(t: int) -> void:
	_label.text = str(t)
	if kind == "meteor":
		_obj_base_y = 0.85 + 0.3 * t


func world_normal() -> Vector3:
	return global_transform.basis.y.normalized()


func set_label_visible(on: bool) -> void:
	_label.visible = on


func _process(delta: float) -> void:
	_time += delta
	_obj.position.y = lerpf(_obj.position.y, _obj_base_y + sin(_time * 2.2) * 0.04, minf(1.0, delta * 6.0))
	_label.position.y = _obj.position.y + 0.35
	_obj.rotation.y += delta * (0.8 if kind == "meteor" else 0.15)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	_ring_mat.emission_energy_multiplier = 0.8 + pulse * 1.2


## Einschlag: Meteor stürzt herab bzw. Blitz. Danach entfernt sich der Knoten selbst.
func strike() -> void:
	var tw := create_tween()
	if kind == "meteor":
		tw.tween_property(_obj, "position:y", 0.15, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_obj, "scale", Vector3(1.8, 0.3, 1.8), 0.08)
		tw.tween_property(_obj, "scale", Vector3.ZERO, 0.18)
	else:
		var bolt := Models.box(self, Vector3(0.05, 0.9, 0.05), Color("#fff3a0"), Vector3(0, 0.5, 0), Vector3(0, 0, 8), Models.mat(Color("#fff3a0"), 0.3, 6.0))
		bolt.visible = false
		tw.tween_callback(func() -> void: bolt.visible = true)
		tw.tween_interval(0.08)
		tw.tween_callback(func() -> void: bolt.visible = false)
		tw.tween_interval(0.06)
		tw.tween_callback(func() -> void: bolt.visible = true)
		tw.tween_interval(0.12)
		tw.tween_property(_obj, "scale", Vector3.ZERO, 0.25)
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffb347") if kind == "meteor" else Color("#e8f0ff")
	flash.omni_range = 3.0
	flash.light_energy = 0.0
	flash.position = Vector3(0, 0.4, 0)
	add_child(flash)
	var tf := create_tween()
	tf.tween_interval(0.3 if kind == "meteor" else 0.05)
	tf.tween_property(flash, "light_energy", 6.0, 0.05)
	tf.tween_property(flash, "light_energy", 0.0, 0.4)
	await tw.finished
	await get_tree().create_timer(0.2).timeout
	queue_free()
