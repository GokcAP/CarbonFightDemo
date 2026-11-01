class_name Grimoire
extends Control
## Denge Grimuarı: karakterler ve haritalar hakkında ayrıntılı bilgi veren büyü kitabı (Ayarlar'dan açılır).
## Kapak -> tıklayınca açılır -> içindekiler + önsöz -> her bölümde solda boss, sağda harita sayfası
## -> son bölümde Doğa Ana ve Denge Tohumu. Sayfalar, o haritanın boss'u yenilene kadar mühürlüdür
## (kilitler Codex autoload'unda kalıcı tutulur). Sayfa çevirme: sağ sayfa kalkıp cildin üstünden
## sola döner, arkası yeni sol sayfa olur. Görseller: assets/sprites/book/ (tools/art_gen/grimoire_art.py).

const SCALE := 3
const COVER_TEX := preload("res://assets/sprites/book/cover.png")
const OPEN_TEX := preload("res://assets/sprites/book/open.png")
const DOGA_ANA := preload("res://assets/sprites/bosses/doga_ana.png")
const SEED_ICON := preload("res://assets/sprites/cards/denge_tohumu.png")
const BOOK_SIZE := Vector2(320, 200) * SCALE
const COVER_SIZE := Vector2(160, 200) * SCALE
## Parşömen sayfaların (çevrilen yaprağın) art koordinatı ve içerik alanının sayfaya göre konumu.
const LEFT_SHEET := Rect2(10, 6, 148, 188)
const RIGHT_SHEET := Rect2(162, 6, 148, 188)
const CONTENT_OFFSET := Vector2(10, 12) * SCALE
const CONTENT_SIZE := Vector2(128, 166) * SCALE
const TEXT_WIDTH := CONTENT_SIZE.x - 20
const FLIP_TIME := 0.18

const INK := Color("3a2414")
const BLOOD := Color("7a1f2b")
const FADED := Color("8a6a3e")

const PREFACE := "Bu grimuar, kırılan dengenin hikayesini saklar. Kirlilikten doğan canavarları ve onların zehirlediği diyarları anlatır. Her canavarı yendiğinde onun ve diyarının sayfasındaki mühür çözülür."
## Boss'ların hikayeleri (boss id -> metin).
const LORE := {
	"termik_ejderha": "Kömür ocaklarının derinliklerinde yüzyıllarca uyuyan bu ejderha, yakılan her kömürle biraz daha büyüdü. Pulları kurum, nefesi kızgın kül. Su Parçası'nı yuttuğunda vadinin bütün dereleri bir gecede buharlaştı.",
	"plastik_leviathan": "Denize atılan her şişe, her poşet onun bedenine eklendi. Leviathan dalgaların altında sessizce dolaşır, kıyıya yalnızca yemek için çıkar. Toprak Parçası onun midesinde; sahil bu yüzden çoraklaştı.",
	"isi_adasi_golemi": "Şehrin asfaltı ve betonu güneşin ısısını hapsedince bu dev uyandı. Her sıcak sokak ona güç verir, gölge ve yeşillik onu zayıflatır. Güneş Parçası göğsünde bir kor gibi parlıyor.",
	"kul_ana": "Bir zamanlar ormanların koruyucusu olan Doğa Ana, Denge Tohumu kırılınca öfkeyle yandı. Kül bir düşman değil, yaralı bir annedir. Ona vurmak yarasını derinleştirir; parçaları geri getirmek onu iyileştirir.",
}
## Haritalar için gezgin notları (harita id -> metin).
const MAP_NOTES := {
	"dumanli_vadi": "Gezgin notu: Vadide gökyüzü hep gri. Bacaları söndürdükçe güneş yeniden görünür. Su kartları ejderhanın alev zırhını kırar.",
	"solgun_korfez": "Gezgin notu: Gelgit sırayla satırları yutar. Toprak kartlarını çöplerin yanına koy; Leviathan dalınca baloncuklu sütuna kart bırak.",
	"gri_sehir": "Gezgin notu: Asfalt sıcaklığı ikiye katlar. Toprak kartlarını asfaltta iki tur yaşatırsan şehir yeşillenir ve golemin zırhı erir.",
	"kul_ormani": "Gezgin notu: Burada kazanmak için savaşma. Parçaları sunaklarına koy, sunakları kartlarla koru ve tohumu ortaya yerleştir.",
}
const DOGA_LORE := "Denge Tohumu yeniden birleştiğinde Kül'ün külleri döküldü ve Doğa Ana uyandı. Saçlarında yeniden çiçekler açtı, orman filizlendi. Ama denge hâlâ kırılgan: onu korumak artık senin elinde."
const SEED_TEXT := "Su, Toprak ve Güneş'in birliği. Bu oyun bitti; ama gerçek dünyada da 2°C eşiği var. Her seçim bir kart gibidir: ya dengeyi korur ya da canavarları besler."

var _book: Control
var _cover: TextureRect
var _left_page: Control
var _right_page: Control
var _prev: Button
var _next: Button
var _hint: Label
var _spreads: Array = []
var _spread := 0
var _busy := false
var _opened := false
var _anim: Array = []  # [TextureRect, kare A, kare B]
var _frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spreads = _build_spreads()

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_book = Control.new()
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.visible = false
	add_child(_book)
	var open_bg := TextureRect.new()
	open_bg.texture = OPEN_TEX
	open_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	open_bg.size = BOOK_SIZE
	open_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(open_bg)
	_left_page = _page_area(LEFT_SHEET)
	_right_page = _page_area(RIGHT_SHEET)

	_prev = _nav_button("<", func() -> void: _turn(_spread - 1))
	_next = _nav_button(">", func() -> void: _turn(_spread + 1))
	var close_button := Button.new()
	close_button.text = tr("Kapat")
	close_button.custom_minimum_size = Vector2(160, 40)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_close)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close_button.position.y -= 12
	add_child(close_button)

	_build_cover()
	var timer := Timer.new()
	timer.wait_time = 0.45
	timer.autostart = true
	timer.timeout.connect(_next_frame)
	add_child(timer)
	resized.connect(_layout)
	_layout()


# --- Kurulum -----------------------------------------------------------------------

func _build_spreads() -> Array:
	var list := [[{"kind": "index"}, {"kind": "preface"}]]
	for map: MapData in GameState.config.maps:
		var is_open := Codex.is_unlocked(String(map.id))
		list.append([{"kind": "boss", "map": map, "open": is_open}, {"kind": "map", "map": map, "open": is_open}])
	var won := Codex.is_unlocked(Codex.FINAL_ID)
	list.append([{"kind": "doga", "open": won}, {"kind": "seed", "open": won}])
	return list


func _page_area(sheet: Rect2) -> Control:
	var c := Control.new()
	c.position = sheet.position * SCALE + CONTENT_OFFSET
	c.size = CONTENT_SIZE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(c)
	return c


func _nav_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(52, 72)
	b.add_theme_font_size_override("font_size", 32)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	b.visible = false
	add_child(b)
	return b


func _build_cover() -> void:
	_cover = TextureRect.new()
	_cover.texture = COVER_TEX
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.size = COVER_SIZE
	_cover.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cover.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_book())
	add_child(_cover)
	var title := UIStyle.label(tr("Denge Grimuarı"), 24, UIStyle.GOLD)
	title.position = Vector2(26, 22) * SCALE
	title.size = Vector2(120, 16) * SCALE
	_cover.add_child(title)
	var subtitle := UIStyle.label(tr("Karakterler ve Haritalar"), 16, Color("ffe0a8"))
	subtitle.position = Vector2(26, 38) * SCALE
	subtitle.size = Vector2(120, 10) * SCALE
	_cover.add_child(subtitle)
	_hint = UIStyle.label(tr("Açmak için tıkla"), 16, UIStyle.GOLD)
	_hint.position = Vector2(26, 160) * SCALE
	_hint.size = Vector2(120, 10) * SCALE
	_cover.add_child(_hint)
	var pulse := _hint.create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.35, 0.7)
	pulse.tween_property(_hint, "modulate:a", 1.0, 0.7)
	# Kapak hafifçe büyüyerek belirir.
	_cover.pivot_offset = COVER_SIZE / 2
	_cover.scale = Vector2(0.9, 0.9)
	_cover.modulate.a = 0.0
	var appear := _cover.create_tween().set_parallel()
	appear.tween_property(_cover, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(_cover, "modulate:a", 1.0, 0.2)


func _layout() -> void:
	var book_pos := ((size - BOOK_SIZE) / 2).floor()
	_book.position = book_pos
	if is_instance_valid(_cover):
		# Kapalı kitap ekranın ortasında; açılınca kapak açık kitabın sağ yarısının üstünden döner.
		_cover.position = book_pos + Vector2(BOOK_SIZE.x / 2, 0) if _opened else ((size - COVER_SIZE) / 2).floor()
	_prev.position = Vector2(book_pos.x - 68, book_pos.y + BOOK_SIZE.y / 2 - 36)
	_next.position = Vector2(book_pos.x + BOOK_SIZE.x + 16, book_pos.y + BOOK_SIZE.y / 2 - 36)


# --- Açma / kapama ------------------------------------------------------------------

func _open_book() -> void:
	if _opened:
		return
	_opened = true
	Sfx.play("place", 0.0, 0.7)
	_fill(_left_page, _spreads[0][0], 1)
	_fill(_right_page, _spreads[0][1], 2)
	_hint.visible = false
	# Kapak cildin (sol kenarı) etrafında dönerek açılır, açık kitap altında belirir.
	var target := _book.position + Vector2(BOOK_SIZE.x / 2, 0)
	_book.visible = true
	_book.modulate.a = 0.0
	_cover.pivot_offset = Vector2(0, COVER_SIZE.y / 2)
	var t := create_tween()
	t.tween_property(_cover, "position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_book, "modulate:a", 1.0, 0.25)
	t.tween_property(_cover, "scale:x", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_cover, "modulate", Color(0.5, 0.45, 0.5), 0.32)
	t.tween_callback(func() -> void:
		_cover.queue_free()
		_update_nav())


func _close() -> void:
	Sfx.play("click")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
	elif not _opened and event.is_action_pressed("ui_accept"):
		_open_book()
	elif _opened and event.is_action_pressed("ui_left"):
		_turn(_spread - 1)
	elif _opened and event.is_action_pressed("ui_right"):
		_turn(_spread + 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _update_nav() -> void:
	_prev.visible = _opened
	_next.visible = _opened
	_prev.disabled = _spread <= 0
	_next.disabled = _spread >= _spreads.size() - 1


# --- Sayfa çevirme ------------------------------------------------------------------

## Çevrilen yaprak: parşömen arka planı + sayfa içeriği; cilt kenarına göre ölçeklenir.
func _make_sheet(sheet_rect: Rect2, desc: Dictionary, number: int, spine_at_left: bool) -> Control:
	var sheet := Control.new()
	sheet.position = sheet_rect.position * SCALE
	sheet.size = sheet_rect.size * SCALE
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.clip_contents = true
	sheet.pivot_offset = Vector2(0 if spine_at_left else sheet.size.x, sheet.size.y / 2)
	var bg := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = OPEN_TEX
	atlas.region = sheet_rect
	bg.texture = atlas
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = sheet.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(bg)
	var content := Control.new()
	content.position = CONTENT_OFFSET
	content.size = CONTENT_SIZE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(content)
	_fill(content, desc, number)
	_book.add_child(sheet)
	return sheet


func _turn(to: int) -> void:
	if _busy or not _opened or to == _spread or to < 0 or to >= _spreads.size():
		return
	_busy = true
	Sfx.play("place", 0.05, 1.6)
	var old: Array = _spreads[_spread]
	var new: Array = _spreads[to]
	var forward := to > _spread
	var n := to * 2
	# İleri: sağ yaprak (eski sağ sayfa) kalkar, altında yeni sağ sayfa görünür.
	# Geri: sol yaprak (eski sol sayfa) kalkar, altında yeni sol sayfa görünür.
	var lifting: Control
	if forward:
		lifting = _make_sheet(RIGHT_SHEET, old[1], _spread * 2 + 2, true)
		_fill(_right_page, new[1], n + 2)
	else:
		lifting = _make_sheet(LEFT_SHEET, old[0], _spread * 2 + 1, false)
		_fill(_left_page, new[0], n + 1)
	var t := create_tween()
	t.tween_property(lifting, "scale:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(lifting, "modulate", Color(0.62, 0.55, 0.5), FLIP_TIME)
	t.tween_callback(func() -> void:
		lifting.queue_free()
		# Yaprağın arkası diğer tarafa iner: yeni sol (ileri) ya da yeni sağ (geri) sayfa.
		var landing := _make_sheet(LEFT_SHEET, new[0], n + 1, false) if forward \
			else _make_sheet(RIGHT_SHEET, new[1], n + 2, true)
		landing.scale.x = 0.0
		landing.modulate = Color(0.62, 0.55, 0.5)
		var t2 := create_tween()
		t2.tween_property(landing, "scale:x", 1.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(landing, "modulate", Color.WHITE, FLIP_TIME)
		t2.tween_callback(func() -> void:
			if forward:
				_fill(_left_page, new[0], n + 1)
			else:
				_fill(_right_page, new[1], n + 2)
			landing.queue_free()
			_spread = to
			_busy = false
			_update_nav()))


# --- Sayfa içerikleri ---------------------------------------------------------------

func _fill(page: Control, desc: Dictionary, number: int) -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = CONTENT_SIZE - Vector2(0, 26)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = CONTENT_SIZE.x - 12
	scroll.add_child(box)

	var kind: String = desc["kind"]
	if desc.get("open", true) == false:
		_fill_locked(box, desc)
	else:
		match kind:
			"index":
				_fill_index(box)
			"preface":
				box.add_child(_title(tr("Önsöz")))
				box.add_child(_divider())
				box.add_child(_text(tr(PREFACE)))
				var opened := 0
				for i in range(1, _spreads.size()):
					if _spreads[i][0].get("open", false):
						opened += 1
				box.add_child(_divider())
				box.add_child(_text(tr("Açılan bölümler: %d/%d") % [opened, _spreads.size() - 1], 16, FADED, true))
			"boss":
				_fill_boss(box, desc["map"])
			"map":
				_fill_map(box, desc["map"])
			"doga":
				box.add_child(_title(tr("Doğa Ana")))
				box.add_child(_picture(DOGA_ANA, 2))
				box.add_child(_text(tr(DOGA_LORE)))
			"seed":
				box.add_child(_title(tr("Denge Tohumu")))
				box.add_child(_picture(SEED_ICON, 4))
				box.add_child(_text(tr(SEED_TEXT)))

	var num := _text("- %d -" % number, 16, FADED, true)
	num.position = Vector2(0, CONTENT_SIZE.y - 22)
	num.size = Vector2(CONTENT_SIZE.x, 20)
	page.add_child(num)


func _fill_index(box: VBoxContainer) -> void:
	box.add_child(_title(tr("İçindekiler")))
	box.add_child(_divider())
	for i in range(1, _spreads.size()):
		var left: Dictionary = _spreads[i][0]
		var is_open: bool = left.get("open", false)
		var name := "???"
		if is_open:
			if left["kind"] == "boss":
				var map: MapData = left["map"]
				name = "%s / %s" % [tr(map.boss.display_name), tr(map.display_name)]
			else:
				name = "%s / %s" % [tr("Doğa Ana"), tr("Denge Tohumu")]
		var entry := Button.new()
		entry.flat = true
		entry.text = "%d. %s" % [i, name]
		entry.icon = null if is_open else UIStyle.icon("lock")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		entry.add_theme_color_override("font_color", INK if is_open else FADED)
		entry.add_theme_color_override("font_hover_color", BLOOD)
		entry.add_theme_color_override("font_pressed_color", BLOOD)
		entry.add_theme_constant_override("outline_size", 0)
		entry.add_theme_font_size_override("font_size", UIStyle.BODY_FONT_SIZE)
		var target := i
		entry.pressed.connect(func() -> void: _turn(target))
		box.add_child(entry)


func _fill_boss(box: VBoxContainer, map: MapData) -> void:
	var boss := map.boss
	box.add_child(_title(tr(boss.display_name)))
	var pic := _picture(boss.icon, 2)
	if boss.icon_alt != null:
		_anim.append([pic.get_child(0), boss.icon, boss.icon_alt])
	box.add_child(pic)
	box.add_child(_text(tr(LORE.get(String(boss.id), ""))))
	box.add_child(_divider())
	if boss.mechanic != BossData.Mechanic.ASH_MOTHER:
		box.add_child(_text(tr("Zayıf: %s  /  Dirençli: %s") % [Elements.plain(boss.weakness), Elements.plain(boss.resistance)]))
	box.add_child(_heading(tr("Mekanik: %s") % tr(boss.mechanic_name)))
	box.add_child(_text(tr(boss.mechanic_text)))
	box.add_child(_heading(tr("Saldırılar")))
	for attack in boss.attacks:
		box.add_child(_text("- %s: %s" % [tr(attack.attack_name), attack.get_effect_text(0)]))


func _fill_map(box: VBoxContainer, map: MapData) -> void:
	box.add_child(_title(tr(map.display_name)))
	if map.background != null:
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = INK
		sb.set_border_width_all(SCALE)
		sb.border_color = INK
		frame.add_theme_stylebox_override("panel", sb)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var img := TextureRect.new()
		img.texture = map.background
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(320, 150)
		frame.add_child(img)
		box.add_child(frame)
	box.add_child(_text(tr(map.intro_text)))
	box.add_child(_divider())
	box.add_child(_heading(tr("Harita etkisi: %s") % tr(map.effect_name)))
	box.add_child(_text(tr(map.effect_text)))
	box.add_child(_heading(tr("Onarım görevi")))
	box.add_child(_text(tr(map.quest_text)))
	if map.reward_shard != "":
		box.add_child(_heading(tr("Ödül: %s") % GameState.shard_name(map.reward_shard)))
		box.add_child(_text(tr(map.reward_text)))
	box.add_child(_divider())
	box.add_child(_text(tr(MAP_NOTES.get(String(map.id), "")), 16, FADED))


## Mühürlü sayfa: karartılmış siluet, kilit ve ne zaman açılacağı.
func _fill_locked(box: VBoxContainer, desc: Dictionary) -> void:
	box.add_child(_title(tr("Mühürlü Sayfa")))
	var tex: Texture2D = null
	var scale := 2
	match desc["kind"]:
		"boss":
			tex = desc["map"].boss.icon
		"map":
			tex = desc["map"].background
			scale = 1
		"doga":
			tex = DOGA_ANA
		"seed":
			tex = SEED_ICON
			scale = 4
	if tex != null:
		var pic := _picture(tex, scale)
		pic.get_child(0).modulate = Color(0.16, 0.1, 0.1, 0.85)
		box.add_child(pic)
	box.add_child(_picture(UIStyle.icon("lock"), 3))
	var is_final: bool = desc["kind"] in ["doga", "seed"]
	box.add_child(_text(tr("Bu sayfa, Kül sakinleştirildiğinde açılır.") if is_final
		else tr("Bu sayfanın mührü, bu diyarın canavarı yenildiğinde çözülür."), 16, FADED, true))


# --- Yazı ve görsel yardımcıları ------------------------------------------------------

func _text(text: String, font_size := UIStyle.BODY_FONT_SIZE, color := INK, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UIStyle.snap_size(font_size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_WIDTH  # satır kaydırma bu genişlikte ölçülsün
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _title(text: String) -> Label:
	return _text(text, 24, BLOOD, true)


func _heading(text: String) -> Label:
	return _text(text, 16, BLOOD)


func _divider() -> Label:
	return _text("~  *  ~", 16, FADED, true)


func _picture(tex: Texture2D, scale: int) -> CenterContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s := tex.get_size() * scale
	if s.x > TEXT_WIDTH:
		s *= TEXT_WIDTH / s.x
	r.custom_minimum_size = s
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(r)
	return center


## Boss sprite'larının iki karelik bekleme animasyonu.
func _next_frame() -> void:
	_frame = 1 - _frame
	_anim = _anim.filter(func(a: Array) -> bool: return is_instance_valid(a[0]))
	for a in _anim:
		(a[0] as TextureRect).texture = a[1 + _frame]
