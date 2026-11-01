class_name IsoBoard
extends Control
## 2.5D (izometrik) 3x3 tahta: haritanın zemin adası + 9 elmas slot + sinerji işaretleri.
## Slotlar arkadan öne doğru eklenir ki öndeki binalar arkadakilerin üstüne çizilsin.
## Tahta fareyle sürüklenerek 360° döndürülebilir: yalnızca karoların ekrandaki yeri değişir;
## slot numaraları, komşuluk ve oyun mantığı aynı kalır.

## Tek karonun ekrandaki boyutu (art 64x32).
const TILE := Vector2(64, 32) * UIStyle.PX
## En arka sıradaki binaların karonun üstüne taşan yüksekliği.
const OVERHANG := 32 * UIStyle.PX
## Karo yan yüz kalınlığı.
const DEPTH := 8 * UIStyle.PX
## Karolar arası boşluk (art 12 piksel yatay, 6 dikey): binalar sıkışık durmasın.
## tools/art_gen/iso_sprites.py GAP ile aynı olmalı.
const GAP := Vector2(12, 6) * UIStyle.PX
## Bir sütun/satır ilerleyince karonun kaydığı mesafe (karo + boşluk).
const STEP := TILE + GAP
## Zemin adasında tahta merkezinin art koordinatı (ground*.png 288x160 içinde).
const GROUND_CENTER := Vector2(144, 72) * UIStyle.PX
## Bu kadar piksel kaymadan sürükleme başlamaz (tıklamalar dönüşe sayılmasın).
const DRAG_THRESHOLD := 6.0
## Bırakınca en yakın düz açıya (90°'nin katı) oturma süresi: karolar platform kenarlarına paralel kalır.
const SETTLE_TIME := 0.3

var slots: Array[Slot] = []
## Görünüm açısı (radyan, saat yönü). 0 = varsayılan görünüm.
var view_angle := 0.0
## Harita adası: karolarla birlikte dönen kalın blok.
var _ground: IsoQuad
## Sinerji işaretleri (3x3'te en fazla 12 komşu çift); slotlarla birlikte derinliğe göre sıralanır.
var _marks: Array[SynergyMark] = []
## Basılan nokta (tahta içinde) ve tutulan noktanın platform merkezine göre son açısı.
var _press_pos := Vector2.INF
var _grab_angle := NAN
var _dragging := false
var _settle_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(STEP.x * (Grid.SIZE - 1) + TILE.x, OVERHANG + STEP.y * (Grid.SIZE - 1) + TILE.y + DEPTH)
	# Slotların arasından/üstünden sürükleyince tahta döner (slotlar fare olaylarını tahtaya geçirir).
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Ada dokusu: üst elmas 288x144, 16 piksel kalınlık (ground*.png 288x160).
	_ground = IsoQuad.new().setup(GROUND_CENTER / UIStyle.PX * 2, 16 * UIStyle.PX)
	_ground.outline = true
	add_child(_ground)

	# Sinerji işaretleri slotların arasındaki boşlukta: arkadaki karonun önünde, öndekinin arkasında.
	for i in 12:
		var mark := SynergyMark.new()
		mark.visible = false
		_marks.append(mark)
		add_child(mark)

	for i in Grid.SLOT_COUNT:
		var slot := Slot.new()
		slot.index = i
		slots.append(slot)
	# Ressam algoritması: önce arka (satır + sütun küçük) slotlar.
	var order := _depth_order()
	for slot in order:
		add_child(slot)

	# Slot etiketleri (AP/zırh/can, durum rozeti) en üstte: öndeki karolar üstlerini kapatmasın.
	for slot in order:
		add_child(slot.overlay)

	resized.connect(_layout)
	GameState.map_started.connect(_refresh_ground)
	GameState.grid_changed.connect(_refresh_marks)
	_refresh_ground()
	_refresh_marks()


func _depth(slot: int) -> float:
	var cell := _view_cell(slot)
	return cell.x + cell.y


func _depth_order() -> Array:
	var order := slots.duplicate()
	order.sort_custom(func(a: Slot, b: Slot) -> bool: return _depth(a.index) < _depth(b.index))
	return order


## Slotun dönmüş görünümdeki (satır, sütun) yeri; tahta merkezi etrafında view_angle kadar döner.
func _view_cell(slot: int) -> Vector2:
	var half := (Grid.SIZE - 1) / 2.0
	var r := Grid.row_of(slot) - half
	var c := Grid.column_of(slot) - half
	var cos_a := cos(view_angle)
	var sin_a := sin(view_angle)
	return Vector2(r * cos_a + c * sin_a + half, -r * sin_a + c * cos_a + half)


## Slotun elmas merkezinin tahta içindeki konumu.
func tile_center(slot: int) -> Vector2:
	var cell := _view_cell(slot)
	var r := cell.x
	var c := cell.y
	var origin := Vector2(size.x / 2, OVERHANG + TILE.y / 2)
	return origin + Vector2((c - r) * STEP.x / 2, (c + r) * STEP.y / 2)


func _layout() -> void:
	for slot in slots:
		# Çift piksele hizala: pixel art dönerken bulanıklaşmasın.
		slot.position = ((tile_center(slot.index) - Slot.CENTER) / 2).round() * 2
		slot.overlay.position = slot.position
	for mark in _marks:
		if mark.visible:
			var mid := (tile_center(mark.pair[0]) + tile_center(mark.pair[1])) / 2
			mark.position = ((mid - SynergyMark.HALF) / 2).round() * 2
	_ground.size = size
	_ground.place(tile_center(Grid.SLOT_COUNT / 2), GROUND_CENTER.x / STEP.x, view_angle)


## Görünüm açısını değiştir; karolar yeni yerlerine geçer, öndekiler yine en son çizilir.
func set_view_angle(angle: float) -> void:
	view_angle = wrapf(angle, 0.0, TAU)
	# Platform tek parça döner: karolar, adanın kenarları ve sinerji halkaları hep aynı doğrultuda.
	for slot in slots:
		slot.set_view(view_angle)
	for mark in _marks:
		mark.angle = view_angle
	_reorder()
	_layout()


## Ressam sırası: slotlar ve sinerji işaretleri arkadan öne; etiketler hepsinin üstünde.
func _reorder() -> void:
	var items: Array = []
	for slot in slots:
		items.append([_depth(slot.index), slot])
	for mark in _marks:
		if mark.visible:
			items.append([(_depth(mark.pair[0]) + _depth(mark.pair[1])) / 2.0, mark])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in items.size():
		move_child(items[i][1], i + 1)  # 0: zemin
	for slot in _depth_order():
		move_child(slot.overlay, -1)


## Aktif sinerji çiftleri değişti: işaretleri güncelle.
func _refresh_marks() -> void:
	var pairs := GameState.synergy_pairs() if GameState.grid.size() == Grid.SLOT_COUNT else []
	for i in _marks.size():
		var mark := _marks[i]
		mark.visible = i < pairs.size()
		if mark.visible:
			mark.pair = pairs[i]
			mark.color = Elements.COLORS[GameState.grid[mark.pair[0]].data.element]
			mark.queue_redraw()
	_reorder()
	_layout()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		# Nesne inceleme gibi: yalnızca platformun (ada ya da karolar) üstüne basınca döner.
		if not _on_platform(button.position):
			return
		_press_pos = button.position
		_grab_angle = _angle_at(button.position)
		_dragging = false
		if _settle_tween != null:
			_settle_tween.kill()


## Basış tahtada başladıysa, fare nereye giderse gitsin bırakılana kadar sürükleme izlenir.
func _input(event: InputEvent) -> void:
	if _press_pos == Vector2.INF:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_press_pos = Vector2.INF
		if _dragging:
			_dragging = false
			_settle()
		return
	var motion := event as InputEventMouseMotion
	if motion == null or get_viewport().gui_is_dragging():
		return
	var local := (make_input_local(motion) as InputEventMouseMotion).position
	if not _dragging and local.distance_to(_press_pos) < DRAG_THRESHOLD:
		return
	_dragging = true
	# Tutulan nokta fareyi izler: fare platform merkezi etrafında ne kadar döndüyse platform da o kadar.
	var now := _angle_at(local)
	if is_nan(now):
		return
	if not is_nan(_grab_angle):
		set_view_angle(view_angle - wrapf(now - _grab_angle, -PI, PI))
	_grab_angle = now


## Tahtadaki noktanın, platform merkezine göre ızgara düzlemindeki açısı (merkeze çok yakınsa NAN).
func _angle_at(point: Vector2) -> float:
	var d := point - tile_center(Grid.SLOT_COUNT / 2)
	var c := d.x / STEP.x + d.y / STEP.y
	var r := d.y / STEP.y - d.x / STEP.x
	if Vector2(r, c).length() < 0.25:
		return NAN
	return atan2(c, r)


## Nokta adanın üst yüzünde ya da görünen yan yüzlerinde mi?
func _on_platform(point: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point, _ground.corners):
		return true
	var lowered := PackedVector2Array()
	for p in _ground.corners:
		lowered.append(p + Vector2(0, _ground.depth))
	return Geometry2D.is_point_in_polygon(point, lowered)


## Serbest döndürmeden sonra en yakın düz açıya yumuşakça otur (çapraz görünüm kalmasın).
func _settle() -> void:
	var quarter := PI / 2
	var target := roundf(view_angle / quarter) * quarter
	if _settle_tween != null:
		_settle_tween.kill()
	_settle_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_settle_tween.tween_method(set_view_angle, view_angle, target, SETTLE_TIME)
	# Döndürme sırasında başlamış bir sarsıntı slotu eski yerine döndürebilir: bir kez daha hizala.
	_settle_tween.tween_interval(0.3)
	_settle_tween.tween_callback(_layout)


func _refresh_ground() -> void:
	if GameState.map == null:
		return
	_ground.texture = Art.ground(GameState.map.id)
	_layout()
