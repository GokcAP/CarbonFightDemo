class_name MenuBackground
extends Control
## Ana menüye özel hareketli pixel art arka plan (320x180 art, ekranı kaplayacak şekilde büyütülür).
## Solda iyileşen vadi (ateş böcekleri, düşen yapraklar, akan nehir), sağda kirli şehir
## (tüten bacalar, yükselen közler), ortada yarısı kurumuş Denge Ağacı ve nabız gibi atan tohum ışığı.
## Katman görselleri: assets/sprites/menu/ (tools/art_gen/menu_bg.py ile üretilir).
## Aşağıdaki koordinatlar menu_bg.py ile aynı olmalı.

const ART := Vector2(320, 180)
const DIR := "res://assets/sprites/menu/%s.png"
const HORIZON := 118
const TREE := Vector2(160, 72)
const CHIMNEYS := [Vector2(229, 62), Vector2(259, 56), Vector2(297, 66)]
const CLOUD_SPEEDS := [2.0, 5.0]  # art pikseli / saniye (uzak, yakın)

const STAR_COLORS := [Color("f4f4f4"), Color("73eff7"), Color("ffcd75")]
const LEAF_COLORS := [Color("a7f070"), Color("38b764"), Color("ffcd75")]
const EMBER_COLORS := [Color("ef7d57"), Color("ffcd75"), Color("b13e53")]

var _canvas: Control
var _back: Control
var _front: Control
var _clouds: Array = []  # [[TextureRect, TextureRect, hız, genişlik], ...]
var _time := 0.0
var _rng := RandomNumberGenerator.new()

var _stars: Array = []      # {pos, phase, speed, color}
var _glow: Array = []       # [Vector2, mesafe 0..1]
var _fireflies: Array = []  # {base, phase, a, b}
var _leaves: Array = []     # {pos, vel, color, phase}
var _smoke: Array = []      # {pos, vel, age, life}
var _embers: Array = []     # {pos, vel, age, life}
var _ripples: Array = []    # {s, offset}
var _leaf_timer := 0.0
var _smoke_timer := 0.0
var _ember_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = 2026

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = ART
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)

	_layer("sky")
	_back = _draw_layer(_draw_back)
	for i in 2:
		var tex := load(DIR % ["clouds_far", "clouds_near"][i]) as Texture2D
		var a := _layer_tex(tex)
		var b := _layer_tex(tex)
		_clouds.append([a, b, CLOUD_SPEEDS[i], tex.get_width()])
	_layer("land")
	_front = _draw_layer(_draw_front)

	_init_particles()
	resized.connect(_fit)
	_fit()


func _layer(layer_name: String) -> TextureRect:
	return _layer_tex(load(DIR % layer_name) as Texture2D)


func _layer_tex(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = tex.get_size()
	_canvas.add_child(r)
	return r


func _draw_layer(callback: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = ART
	c.draw.connect(callback)
	_canvas.add_child(c)
	return c


## Ekranı kaplayacak şekilde ölçekle, ortala.
func _fit() -> void:
	var s := maxf(size.x / ART.x, size.y / ART.y)
	_canvas.scale = Vector2(s, s)
	_canvas.position = ((size - ART * s) / 2).floor()


func _init_particles() -> void:
	for i in 46:
		# Yıldızlar solda (temiz gökyüzü) daha sık, sağda (is) seyrek.
		var x := pow(_rng.randf(), 1.6) * ART.x
		_stars.append({"pos": Vector2(int(x), _rng.randi_range(2, 52)), "phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(1.0, 3.0), "color": STAR_COLORS[_rng.randi() % 3]})
	# Tohum ışığı: ağacın arkasında dama desenli hale.
	for y in range(-44, 45):
		for x in range(-44, 45):
			var d := Vector2(x, y * 1.15).length() / 44.0
			if d < 1.0 and (x + y) % 2 == 0:
				_glow.append([TREE + Vector2(x, y), d])
	for i in 16:
		_fireflies.append({"base": Vector2(_rng.randf_range(8, 145), _rng.randf_range(102, 172)),
			"phase": _rng.randf() * TAU, "a": _rng.randf_range(0.4, 1.0), "b": _rng.randf_range(0.5, 1.2)})
	for i in 9:
		_ripples.append({"s": _rng.randf(), "offset": _rng.randf_range(-0.6, 0.6)})


func _process(delta: float) -> void:
	_time += delta
	for c in _clouds:
		var x := -fmod(_time * float(c[2]), float(c[3]))
		(c[0] as TextureRect).position = Vector2(floorf(x), 0 if c[2] < 3.0 else 14)
		(c[1] as TextureRect).position = Vector2(floorf(x) + c[3], 0 if c[2] < 3.0 else 14)
	_update_leaves(delta)
	_update_smoke(delta)
	_update_embers(delta)
	for r in _ripples:
		r["s"] = fmod(r["s"] + delta * 0.08, 1.0)
	_back.queue_redraw()
	_front.queue_redraw()


func _update_leaves(delta: float) -> void:
	_leaf_timer -= delta
	if _leaf_timer <= 0.0:
		_leaf_timer = _rng.randf_range(0.35, 0.8)
		_leaves.append({"pos": TREE + Vector2(_rng.randf_range(-32, -4), _rng.randf_range(-18, 14)),
			"vel": Vector2(_rng.randf_range(-7, -2), _rng.randf_range(7, 12)),
			"color": LEAF_COLORS[_rng.randi() % 3], "phase": _rng.randf() * TAU})
	for leaf in _leaves:
		leaf["pos"] += (leaf["vel"] + Vector2(sin(_time * 3.0 + leaf["phase"]) * 6.0, 0)) * delta
	_leaves = _leaves.filter(func(l: Dictionary) -> bool: return l["pos"].y < ART.y + 2)


func _update_smoke(delta: float) -> void:
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = 0.28
		var c: Vector2 = CHIMNEYS[_rng.randi() % CHIMNEYS.size()]
		_smoke.append({"pos": c + Vector2(0, -1), "vel": Vector2(_rng.randf_range(2, 6), _rng.randf_range(-7, -4)),
			"age": 0.0, "life": _rng.randf_range(3.0, 4.5)})
	for p in _smoke:
		p["age"] += delta
		p["pos"] += p["vel"] * delta
	_smoke = _smoke.filter(func(p: Dictionary) -> bool: return p["age"] < p["life"])


func _update_embers(delta: float) -> void:
	_ember_timer -= delta
	if _ember_timer <= 0.0:
		_ember_timer = _rng.randf_range(0.08, 0.2)
		var from_tree := _rng.randf() < 0.25
		var start := TREE + Vector2(_rng.randf_range(4, 30), _rng.randf_range(-20, 12)) if from_tree \
			else Vector2(_rng.randf_range(176, 320), _rng.randf_range(128, 178))
		_embers.append({"pos": start, "vel": Vector2(_rng.randf_range(-2, 4), _rng.randf_range(-16, -8)),
			"age": 0.0, "life": _rng.randf_range(1.5, 3.5)})
	for e in _embers:
		e["age"] += delta
		e["pos"] += e["vel"] * delta
	_embers = _embers.filter(func(e: Dictionary) -> bool: return e["age"] < e["life"])


# --- Çizim (art koordinatlarında, tam piksele hizalı) -------------------------------

func _px(layer: Control, pos: Vector2, color: Color, size := Vector2.ONE) -> void:
	layer.draw_rect(Rect2(pos.floor(), size), color)


func _draw_back() -> void:
	for s in _stars:
		var a := 0.25 + 0.75 * maxf(0.0, sin(_time * s["speed"] + s["phase"]))
		_px(_back, s["pos"], Color(s["color"], a))
	# Denge Tohumu ışığı: yavaşça büyüyüp sönen hale.
	var pulse := 0.55 + 0.45 * sin(_time * 1.6)
	for g in _glow:
		var d: float = g[1]
		var a := (1.0 - d) * (1.0 - d) * 0.55 * pulse
		var c := Color("a7f070").lerp(Color("73eff7"), d)
		_px(_back, g[0], Color(c, a))


func _draw_front() -> void:
	# Nehirde aşağı akan parıltılar
	for r in _ripples:
		var s: float = r["s"]
		var offset: float = r["offset"]
		var y := HORIZON + 2 + s * (ART.y - HORIZON - 2)
		var center := 70.0 - (y - HORIZON) * 0.95 + 6.0 * sin(y * 0.12)
		var half := 1.0 + (y - HORIZON) * 0.11
		var x := center + offset * half
		var a := sin(s * PI)
		_px(_front, Vector2(x, y), Color(Color("73eff7"), a), Vector2(2, 1))
	# Ateş böcekleri
	for f in _fireflies:
		var pos: Vector2 = f["base"] + Vector2(sin(_time * f["a"] + f["phase"]) * 7.0, cos(_time * f["b"] + f["phase"]) * 4.0)
		var a := maxf(0.0, sin(_time * 2.2 + f["phase"]))
		_px(_front, pos - Vector2.ONE, Color(Color("a7f070"), a * 0.3), Vector2(3, 3))
		_px(_front, pos, Color(Color("fff0a8"), a))
	# Düşen yapraklar
	for leaf in _leaves:
		var flip := sin(_time * 4.0 + leaf["phase"]) > 0.0
		_px(_front, leaf["pos"], leaf["color"], Vector2(2, 1) if flip else Vector2(1, 2))
	# Baca dumanı: büyüyüp solan pixel bulutlar
	for p in _smoke:
		var t: float = p["age"] / p["life"]
		var r := 1.0 + t * 5.0
		var c := Color("94b0c2").lerp(Color("566c86"), t)
		c.a = 0.6 * (1.0 - t)
		var pos: Vector2 = p["pos"].floor()
		_front.draw_rect(Rect2(pos - Vector2(r, r - 1).floor(), Vector2(r * 2 + 1, r * 2 - 1).floor()), c)
		_front.draw_rect(Rect2(pos - Vector2(r - 1, r).floor(), Vector2(r * 2 - 1, r * 2 + 1).floor()), c)
	# Yükselen közler
	for e in _embers:
		var t: float = e["age"] / e["life"]
		var flicker := int(_time * 12.0 + e["life"] * 10.0) % 3
		_px(_front, e["pos"], Color(EMBER_COLORS[flicker], 1.0 - t))
