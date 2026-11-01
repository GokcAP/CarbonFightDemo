class_name IsoQuad
extends Control
## Tahta döndükçe karoyla birlikte dönen kalın kare blok: üst yüz dokunun elmasından eşlenir
## (desen ve dekor da döner), görünen yan yüzler dokudan örneklenen renklerle çizilir.
## Karo, zemin katmanı ve harita adası bunu kullanır; binalar dik durur (nesne inceleme gibi).

## Köşelerin malzeme sırası (açı 0'da ekranda üst, sağ, alt, sol): ızgara (satır, sütun) yönleri.
const GRID_CORNERS := [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]

static var _side_cache := {}

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Dokuda üst elmasın köşeleri (art pikseli, GRID_CORNERS sırasıyla).
var uv := PackedVector2Array()
## Yan yüz kalınlığı (ekran pikseli); 0 = yalnızca üst yüz.
var depth := 0.0
## Ekrandaki köşeler (yerel, GRID_CORNERS sırasıyla).
var corners := PackedVector2Array()
var outline := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Dokunun üst elması (sol üst köşe, boyut; art pikseli) ve yan yüz kalınlığı.
func setup(top_size: Vector2, side_depth: float) -> IsoQuad:
	var h := top_size / 2
	uv = PackedVector2Array([Vector2(h.x, 0), Vector2(top_size.x, h.y), Vector2(h.x, top_size.y), Vector2(0, h.y)])
	depth = side_depth
	return self


## Merkez etrafında, ızgara biriminde `half` yarı kenarlı kareyi `angle` kadar döndürüp yerleştir.
func place(center: Vector2, half: float, angle: float) -> void:
	corners = IsoQuad.rhombus(center, half, angle)
	queue_redraw()


## Döndürülmüş ızgara karesinin ekran köşeleri (IsoBoard izdüşümüyle).
static func rhombus(center: Vector2, half: float, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	for g: Vector2 in GRID_CORNERS:
		var r := g.x * half
		var c := g.y * half
		var rr := r * cos_a + c * sin_a
		var cc := -r * sin_a + c * cos_a
		points.append(center + Vector2((cc - rr) * IsoBoard.STEP.x / 2, (cc + rr) * IsoBoard.STEP.y / 2))
	return points


func _draw() -> void:
	if texture == null or corners.size() != 4:
		return
	var sides := _side_colors()
	var down := Vector2(0, depth)
	var silhouette: Array[PackedVector2Array] = []
	if depth > 0.0:
		for i in 4:
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			var normal := Vector2(b.y - a.y, a.x - b.x)
			if normal.y <= 0.0:
				continue  # arkaya bakan yüz görünmez
			var t := clampf(normal.normalized().x * 0.5 + 0.5, 0.0, 1.0)
			var face := PackedVector2Array([a, b, b + down, a + down])
			draw_colored_polygon(face, sides[0].lerp(sides[1], t))
			silhouette.append(face)
	var tex_size := texture.get_size()
	var uvs := PackedVector2Array()
	for p in uv:
		uvs.append(p / tex_size)
	draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, texture)
	if outline:
		for face in silhouette:
			draw_polyline(PackedVector2Array([face[1], face[2], face[3], face[0]]), UIStyle.OUTLINE, UIStyle.PX)
		var ring := corners.duplicate()
		ring.append(corners[0])
		draw_polyline(ring, UIStyle.OUTLINE, UIStyle.PX)


## Dokunun sol ve sağ yan yüz renkleri (açı 0'daki çizimden örneklenir, dokuya göre önbellekte).
func _side_colors() -> Array:
	var key := texture.get_rid()
	if _side_cache.has(key):
		return _side_cache[key]
	var colors := [Color(0.3, 0.3, 0.35), Color(0.22, 0.22, 0.27)]
	var image := texture.get_image()
	if image != null and depth > 0.0:
		var art_depth := depth / UIStyle.PX
		var left := ((uv[3] + uv[2]) / 2 + Vector2(0, art_depth / 2)).floor()
		var right := ((uv[1] + uv[2]) / 2 + Vector2(0, art_depth / 2)).floor()
		colors = [_sample(image, left), _sample(image, right)]
	_side_cache[key] = colors
	return colors


static func _sample(image: Image, point: Vector2) -> Color:
	var p := Vector2i(clampi(int(point.x), 0, image.get_width() - 1), clampi(int(point.y), 0, image.get_height() - 1))
	return image.get_pixelv(p)
