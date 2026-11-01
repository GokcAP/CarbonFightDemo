class_name Slot
extends Control
## 3x3 izometrik tahtadaki tek bir slot. Kart bırakılabilir (yerleştir / birleştir / değiştir).
## Kontrolün alanı binanın 64x64 tuvalidir; alt yarısı karonun elmasıdır ve
## fare/bırakma yalnızca bu elmasın içinde algılanır (_has_point).
## Katmanlar (alttan üste): karo tabanı → zemin katmanı (asfalt / yeşil alan / sunak) → sıcaklık
## → vurgu (hedef / bırakılabilir) → bina → duman → AP/zırh/can etiketi ve durum rozeti.

const PX := UIStyle.PX
## Kontrol boyutu = bina tuvali (art 64x64).
const SIZE := Vector2(64, 64) * PX
## Karo elmasının merkezi ve yarı boyutu (kontrol içinde).
const CENTER := Vector2(32, 48) * PX
const HALF := Vector2(32, 16) * PX

var index := 0
var _drag_card: CardData
var _drop_hover := false
var _base: IsoQuad
var _tile: IsoQuad
var _hot: IsoQuad
## Karonun ekrandaki (tahtayla birlikte dönmüş) elması; tıklama/bırakma bunun içinde algılanır.
var _diamond := PackedVector2Array()
var _mark: Polygon2D
var _outline: Line2D
var _art: TextureRect
var _fallback: Label
var _smoke: TextureRect
var _smoke_time := 0.0
var _ap: HBoxContainer
var _armor: HBoxContainer
var _hp_bar: ProgressBar
var _info: Control
var _stars: HBoxContainer
var _status_pill: PanelContainer
var _status_row: HBoxContainer
var _pulse_tween: Tween
## Etiket tutucu: AP/zırh/can satırı ve durum rozeti burada durur. Tahta bunu bütün slotların
## üstüne çizer; böylece öndeki karolar etiketlerin üstünü kapatmaz. Slotun konumunu takip eder.
var overlay: Control


## Eski kod uyumu: zemin katmanları artık izometrik (Art.overlay / Art.prop).
static func tile(tile_name: String) -> Texture2D:
	if tile_name in ["smoke", "trash"]:
		return Art.prop(tile_name)
	return Art.overlay(tile_name)


func _ready() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	# PASS: kart bırakma yine slota gelir; basılı sürükleme tahtaya geçer (tahtayı döndürmek için).
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Karo ve zemin katmanları tahtayla birlikte döner (binalar dik kalır).
	_base = _quad(Vector2(64, 32), 8 * PX)
	_base.outline = true
	_tile = _quad(Vector2(64, 32), 0)
	_hot = _quad(Vector2(64, 32), 0)
	_hot.texture = Art.overlay("hot")

	_mark = Polygon2D.new()
	_mark.visible = false
	add_child(_mark)
	_outline = Line2D.new()
	_outline.closed = true
	_outline.antialiased = false
	_outline.joint_mode = Line2D.LINE_JOINT_SHARP
	add_child(_outline)

	_art = _layer(Vector2.ZERO, Vector2(64, 64))
	_fallback = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_fallback.position = CENTER - Vector2(24, 12)
	_fallback.size = Vector2(48, 24)
	add_child(_fallback)
	_smoke = _layer(Vector2.ZERO, Vector2(64, 64), Art.prop("smoke"))
	_smoke.pivot_offset = SIZE / 2.0
	set_view(0.0)

	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = SIZE
	item_rect_changed.connect(_sync_overlay)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free())

	# Binanın üstünde yüzen bilgi: [AP] [yıldızlar] [zırh] + can barı.
	_info = CenterContainer.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.position = Vector2(0, -6 * PX)
	_info.size = Vector2(SIZE.x, 18 * PX)
	overlay.add_child(_info)
	var info_box := VBoxContainer.new()
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_theme_constant_override("separation", 2)
	_info.add_child(info_box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	_ap = UIStyle.icon_label("ap")
	_armor = UIStyle.icon_label("armor")
	_stars = HBoxContainer.new()
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.add_theme_constant_override("separation", 0)
	top.add_child(_ap)
	top.add_child(_stars)
	top.add_child(_armor)
	info_box.add_child(top)
	_hp_bar = UIStyle.bar(UIStyle.WELFARE, 1, 0, 6)
	_hp_bar.custom_minimum_size.x = 36 * PX
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_box.add_child(_hp_bar)

	# Durum rozeti karonun ön ucunda.
	var pill_box := CenterContainer.new()
	pill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_box.position = Vector2(0, CENTER.y + 4 * PX)
	pill_box.size = Vector2(SIZE.x, 12 * PX)
	overlay.add_child(pill_box)
	_status_pill = PanelContainer.new()
	_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pill.add_theme_stylebox_override("panel", UIStyle.box(Color("1a1c2ce0"), Color.TRANSPARENT, 0, 4))
	pill_box.add_child(_status_pill)
	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.add_theme_constant_override("separation", 6)
	_status_pill.add_child(_status_row)

	mouse_exited.connect(_set_drop_hover.bind(false))
	GameState.grid_changed.connect(refresh)
	GameState.intent_changed.connect(refresh)
	GameState.phase_changed.connect(refresh)
	GameState.boss_changed.connect(refresh)
	GameState.map_started.connect(refresh)
	refresh()


## Dumanlı Vadi'deki is bulutları birbirinin kopyası gibi hareket etmesin diye slot başına
## farklı fazda, tam piksel adımlarıyla yükselir ve salınır. Oyun durumunu etkilemez.
func _process(delta: float) -> void:
	if _smoke == null:
		return
	var animated := _smoke.visible and GameState.map != null \
		and String(GameState.map.id) == "dumanli_vadi"
	if not animated:
		_smoke.position = Vector2.ZERO
		_smoke.self_modulate = Color.WHITE
		return
	_smoke_time += delta
	var phase := _smoke_time + float(index) * 0.73
	# PX katlarına yuvarlama, hareket sırasında pixel-art kenarlarını keskin tutar.
	var drift_x := roundf(sin(phase * 1.45) * 2.0) * PX
	var rise_y := -roundf((sin(phase * 0.92) + 1.0) * 1.5) * PX
	_smoke.position = Vector2(drift_x, rise_y)
	var breath := 0.84 + (sin(phase * 1.8) + 1.0) * 0.07
	_smoke.self_modulate = Color(1.0, 1.0, 1.0, breath)


## Etiket tutucu slotla aynı yerde dursun (sarsıntı ve yerleşim dahil).
func _sync_overlay() -> void:
	if overlay != null:
		overlay.position = position


## Karo elmasında dönen doku katmanı (üst elmas art boyutu, yan yüz kalınlığı).
func _quad(top_size: Vector2, side_depth: float) -> IsoQuad:
	var quad := IsoQuad.new().setup(top_size, side_depth)
	quad.size = SIZE
	add_child(quad)
	return quad


## Tahtanın görünüm açısı: karo, zemin katmanları, vurgu ve tıklama alanı birlikte döner.
func set_view(angle: float) -> void:
	var half := HALF.x / IsoBoard.STEP.x
	for quad in [_base, _tile, _hot]:
		quad.place(CENTER, half, angle)
	_diamond = IsoQuad.rhombus(CENTER, half, angle)
	_mark.polygon = _diamond
	_outline.points = _diamond


## Art koordinatında konum/boyutla, Nearest filtreli bir doku katmanı.
func _layer(art_pos: Vector2, art_size: Vector2, tex: Texture2D = null) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = art_pos * PX
	r.size = art_size * PX
	add_child(r)
	return r


## Yalnızca karo elmasının içi tıklanabilir / bırakılabilir.
func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _diamond)


func _notification(what: int) -> void:
	# Sürükleme sırasında bırakılabilir slotları vurgula (birleşme altın renkte).
	if what == NOTIFICATION_DRAG_BEGIN:
		_drag_card = UIStyle.dragged_card(get_viewport())
	elif what == NOTIFICATION_DRAG_END:
		_drag_card = null
		_drop_hover = false
	else:
		return
	if is_node_ready():
		refresh()


## Bina sprite'ı (efektler için).
func art() -> Control:
	return _art


func refresh() -> void:
	if GameState.map == null:
		return
	var card := GameState.grid[index]
	var locked := GameState.locked_turns[index]
	var burning := GameState.burn_turns[index]
	var targeted := index in GameState.intent_slots
	var altar := GameState.altar_element[index]
	var has_trash := GameState.trash[index] > 0
	var diving_here := GameState.stage == GameState.Stage.BOSS \
		and GameState.boss.mechanic == BossData.Mechanic.DIVE \
		and GameState.diving and Grid.column_of(index) == GameState.dive_column

	# Karo ve zemin katmanları
	_base.texture = Art.tile_base(GameState.map.id)
	if altar != "":
		_tile.texture = Art.overlay("altar")
	elif GameState.green[index] > 0:
		_tile.texture = Art.overlay("green")
	elif GameState.asphalt[index] > 0:
		_tile.texture = Art.overlay("asphalt")
	else:
		_tile.texture = null
	_hot.visible = GameState.hot[index] > 0
	_smoke.visible = GameState.smoke[index] > 0
	_base.modulate = Color(0.55, 0.6, 0.8) if locked > 0 else Color.WHITE

	# Kenar çizgisi ve elmas vurgusu
	var line := Color.TRANSPARENT
	var width := 1
	var fill := Color.TRANSPARENT
	if altar != "":
		line = Elements.COLORS[altar]
	if card != null:
		if card.level > 1:
			line = UIStyle.GOLD
		if card.dirty:
			line = Color("566c86")
	if _drag_card != null and GameState.can_play_on(_drag_card, index):
		line = UIStyle.GOLD if GameState.is_merge(_drag_card, index) else UIStyle.HIGHLIGHT
		fill = Color(line, 0.45 if _drop_hover else 0.2)
		width = 2
	elif targeted:
		line = UIStyle.DANGER
		fill = Color(UIStyle.DANGER, 0.35)
		width = 2
	_outline.default_color = line
	_outline.width = width * PX
	_outline.visible = line.a > 0.0
	_mark.color = fill
	_mark.visible = fill.a > 0.0
	_set_pulse(targeted and _drag_card == null)

	var is_normal := card != null and card.data.kind == CardData.Kind.NORMAL and not card.dirty
	_hp_bar.visible = card != null and card.data.kind != CardData.Kind.SEED
	_ap.visible = is_normal
	_armor.visible = is_normal
	_clear(_stars)
	_art.modulate = Color.WHITE
	if card != null:
		_set_art(Art.building(card.data), card.data.icon)
		_fallback.visible = _art.texture == null
		_fallback.text = card.data.emoji
		if locked > 0:
			_art.modulate = Color(0.45, 0.45, 0.55)
		elif card.dirty:
			_art.modulate = Color(0.75, 0.7, 0.7)
		(_ap.get_child(1) as Label).text = str(GameState.card_ap(index))
		(_armor.get_child(1) as Label).text = str(card.data.armor + GameState.armor_bonus())
		_hp_bar.max_value = card.max_hp()
		_hp_bar.value = card.hp
		var hp_ratio := float(card.hp) / card.max_hp()
		var hp_color := UIStyle.WELFARE if hp_ratio > 0.5 else (UIStyle.GOLD if hp_ratio > 0.25 else UIStyle.DANGER)
		_hp_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(hp_color, 6))
		if card.level > 1:
			for i in card.level:
				_stars.add_child(UIStyle.tex_rect(UIStyle.icon("star")))
		tooltip_text = _card_tooltip(card)
	elif has_trash:
		_set_art(Art.prop("trash"), tile("trash"))
		_fallback.visible = false
		tooltip_text = tr("Çöp: buraya kart konamaz.\nYanına Toprak kartı koyarak geri dönüştür.")
	elif altar != "":
		_set_art(null, UIStyle.icon("shard_" + altar))
		_art.modulate = Color(1, 1, 1, 0.45)
		_fallback.visible = false
		tooltip_text = tr("%s sunağı: yalnızca %s buraya konur.") % [Elements.plain(altar), GameState.shard_name(altar)]
	elif GameState.is_final() and index == GameState.map.seed_slot:
		_set_art(null, UIStyle.icon("seed"))
		_art.modulate = Color(1, 1, 1, 0.35)
		_fallback.visible = false
		tooltip_text = tr("Denge Tohumu buraya konacak.")
	else:
		_art.visible = false
		_fallback.visible = _tile.texture == null
		_fallback.text = str(index + 1)
		tooltip_text = _tile_tooltip()
	_info.visible = _ap.visible or _hp_bar.visible or _stars.get_child_count() > 0

	_clear(_status_row)
	if card != null and card.dirty:
		_status_row.add_child(UIStyle.icon_label("chimney", tr("Kirli"), 16, UIStyle.BAD))
	if diving_here:
		_status_row.add_child(UIStyle.icon_label("bubble", "", 16, UIStyle.HIGHLIGHT))
	if GameState.asphalt[index] > 0 and GameState.green_progress[index] > 0:
		_status_row.add_child(UIStyle.icon_label("toprak", "%d/%d" % [GameState.green_progress[index], GameState.map.green_turns], 16, UIStyle.GOOD))
	if card != null and card.data.kind == CardData.Kind.SHARD:
		var guards := GameState.altar_guards(index)
		if guards > 0:
			_status_row.add_child(UIStyle.icon_label("armor", "-%d" % (guards * GameState.config.ash_guard_per_card)))
	if locked > 0:
		_status_row.add_child(UIStyle.icon_label("lock", str(locked)))
	if burning > 0:
		_status_row.add_child(UIStyle.icon_label("fire", str(burning), 16, UIStyle.BURN))
	if targeted:
		_status_row.add_child(UIStyle.icon_label("warn", "-%d" % GameState.expected_hit(index), 16, UIStyle.DANGER))
	_status_pill.visible = _status_row.get_child_count() > 0


## Bina sprite'ı varsa tuvalin tamamına (64x64), yoksa küçük ikonu karonun ortasında ayakta çiz.
func _set_art(building: Texture2D, icon: Texture2D) -> void:
	if building != null:
		_art.texture = building
		_art.position = Vector2.ZERO
		_art.size = SIZE
	elif icon != null:
		_art.texture = icon
		_art.size = icon.get_size() * PX
		_art.position = CENTER + Vector2(-_art.size.x / 2, 4 * PX - _art.size.y)
	else:
		_art.texture = null
	_art.visible = _art.texture != null


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _card_tooltip(card: CardInstance) -> String:
	if card.dirty:
		return tr("Kirli Baca: her tur +%d karbon salar.\nÜstüne temiz bir kart koyarak söndür.") % GameState.config.dirty_chimney_carbon
	match card.data.kind:
		CardData.Kind.SHARD:
			return tr("%s\nCan %d/%d · Komşu kartlar sunağı korur.") % [tr(card.data.display_name), card.hp, card.max_hp()]
		CardData.Kind.SEED:
			return tr(card.data.display_name)
	var lines := PackedStringArray([
		tr("%s (Seviye %d)") % [tr(card.data.display_name), card.level],
		tr(card.data.description),
		tr("%s · Can %d/%d") % [Elements.plain(card.data.element), card.hp, card.max_hp()],
	])
	var extra := _tile_tooltip()
	if extra != "":
		lines.append(extra)
	return "\n".join(lines)


func _tile_tooltip() -> String:
	var parts := PackedStringArray()
	if GameState.smoke[index] > 0:
		parts.append(tr("Duman: AP yarıya iner, Güneş kartları üretmez."))
	if GameState.asphalt[index] > 0:
		parts.append(tr("Asfalt: kart her tur 1 can kaybeder. Toprak kartı %d tur dayanırsa Yeşil Alan olur.") % GameState.map.green_turns)
	if GameState.green[index] > 0:
		parts.append(tr("Yeşil Alan: buraya konan kart çevresini serinletir."))
	if GameState.hot[index] > 0:
		parts.append(tr("Sıcak slot: Golem'e zırh verir."))
	return "\n".join(parts)


func _set_pulse(on: bool) -> void:
	if on and _pulse_tween == null:
		_pulse_tween = Fx.pulse(self, Color(1.8, 0.7, 0.7))
	elif not on and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		self_modulate = Color.WHITE


func _set_drop_hover(on: bool) -> void:
	if _drop_hover == on:
		return
	_drop_hover = on
	if is_node_ready():
		refresh()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "card"):
		return false
	var hand_index: int = data["hand_index"]
	if hand_index < 0 or hand_index >= GameState.hand.size():
		return false
	var ok := GameState.can_play_on(GameState.hand[hand_index], index)
	_set_drop_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_hover = false
	GameState.play_card(data["hand_index"], index)
