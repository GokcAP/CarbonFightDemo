class_name Tutorial
extends Control
## Yeni oyun başlayınca oyunun üstünde açılan etkileşimli tanıtım. Oyun kurallarına dokunmaz:
## yalnızca ilgili yeri parlayan bir çerçeveyle gösterir, açıklama kutusu açar ve bazı adımlarda oyuncunun bir şey
## yapmasını (kart oynamak, otomatik tur çözümünü görmek, baca söndürmek) bekler.
## Diyalog, ayarlar ya da emeği geçenler açıkken gizlenir. Hedef öğeleri ana ekran verir
## (main.tutorial_target), böylece dil değişip arayüz yeniden kurulsa da çalışır.

signal finished

enum Wait { NONE, PLAY_CARD, END_TURN, CHIMNEY }

## [hedef anahtarı, metin, beklenen eylem]
const STEPS := [
	["", "Hoş geldin, Eko-Lider! Kısa bir turla oyunu öğrenelim. İstediğin an \"Atla\" diyebilirsin.", Wait.NONE],
	["stats", "Bunlar dünyanın durumu. Karbon yükseldikçe Sıcaklık artar. Sıcaklık 2.0°C'ye ulaşırsa ya da Refah 0'a düşerse kaybedersin.", Wait.NONE],
	["map", "Her haritanın bir etkisi ve bir onarım görevi var. Dumanlı Vadi'de görevin Kirli Bacaları söndürmek.", Wait.NONE],
	["boss", "Bu haritanın canavarı. Şimdilik uyuyor; onarım görevini bitirince uyanır ve savaş başlar.", Wait.NONE],
	["hand", "Bunlar kartların. Her kartın bir elementi, saldırı gücü, canı ve zırhı var. Altta her tur karbona ve refaha etkisi yazıyor.", Wait.NONE],
	["board", "Bir kartı tutup tahtadaki boş bir karoya sürükle. Her tur yalnızca bir kart oynayabilirsin.", Wait.PLAY_CARD],
	["end_turn", "Kartın yerleşti ve tur otomatik ilerliyor. Bu çöp kutusuna istemediğin normal kartı bırakırsan da tur ilerler ve yerine yeni kart gelir.", Wait.END_TURN],
	["board", "Duman tüten binalar Kirli Bacalar: her tur karbon salarlar. Söndürmek için bir kartı doğrudan bacanın üstüne sürükle.", Wait.CHIMNEY],
	["boss", "Boss uyanınca kartların her tur ona vurur. Kırmızı karolar sıradaki saldırının hedefi. Aynı elementten komşu kartlar daha güçlü vurur, aynı kartı üstüne bırakırsan seviye atlar. Kartı boss'a bırakırsan kurban vuruşu yaparsın.", Wait.NONE],
	["settings", "Dil, ses ve diğer ayarlar burada (Esc). İyi şanslar!", Wait.NONE],
]

const PANEL_WIDTH := 380.0
const MARGIN := 12.0
## Bu hedeflerde kutu üste konur (altındaki elin/kartların üstünü kapatmasın).
const PREFER_ABOVE := ["board", "hand"]

var main: Node
var _step := 0
var _turn_at_step := 0
var _panel: PanelContainer
var _header: Label
var _body: Label
var _next: Button
var _skip: Button
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.chimney_cleared.connect(_on_chimney_cleared)
	_enter_step(0)


## Dil değişince metinleri yeniden kur.
func rebuild() -> void:
	_panel.queue_free()
	_build()
	_enter_step(_step)


func _build() -> void:
	_panel = PanelContainer.new()
	# Opak kutu: arkadaki yazılar karışmasın.
	_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.GOLD, 2))
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_header = UIStyle.label("", 16, UIStyle.GOLD)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_header)
	_body = UIStyle.label("", 16)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.custom_minimum_size.x = PANEL_WIDTH - 24  # satır kaydırma bu genişlikte ölçülsün
	box.add_child(_body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_skip = Button.new()
	_skip.text = tr("Atla")
	_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip.pressed.connect(_finish)
	buttons.add_child(_skip)
	_next = Button.new()
	_next.custom_minimum_size.x = 110
	_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_next.pressed.connect(_advance)
	buttons.add_child(_next)


func _enter_step(index: int) -> void:
	_step = index
	_turn_at_step = GameState.turn
	var step: Array = STEPS[_step]
	_header.text = tr("Eğitim %d/%d") % [_step + 1, STEPS.size()]
	_body.text = tr(step[1])
	_next.visible = step[2] == Wait.NONE
	_next.text = tr("Bitir") if _step == STEPS.size() - 1 else tr("Devam")
	_panel.reset_size()


func _advance() -> void:
	Sfx.play("click")
	if _step + 1 >= STEPS.size():
		_finish()
	else:
		_enter_step(_step + 1)


func _finish() -> void:
	finished.emit()
	queue_free()


func _on_chimney_cleared(_slot: int) -> void:
	if STEPS[_step][2] == Wait.CHIMNEY:
		_advance()


func _blocked() -> bool:
	return main == null or main._dialog_layer.visible or main._settings.visible \
		or main._credits != null or GameState.is_over()


func _process(delta: float) -> void:
	_time += delta
	visible = not _blocked()
	if not visible:
		return
	match STEPS[_step][2]:
		Wait.PLAY_CARD:
			if GameState.played_this_turn:
				_advance()
		Wait.END_TURN:
			if GameState.turn > _turn_at_step and GameState.phase == GameState.Phase.PLAYER:
				_advance()
		Wait.CHIMNEY:
			# Bacaların hepsi zaten söndüyse bekleme.
			if GameState.stage != GameState.Stage.REPAIR or GameState.quest_progress().x >= GameState.quest_progress().y:
				_advance()
	_place_panel()
	queue_redraw()


func _target() -> Control:
	var key: String = STEPS[_step][0]
	if key == "":
		return null
	var t: Control = main.tutorial_target(key)
	return t if t != null and is_instance_valid(t) and t.is_visible_in_tree() else null


## Kutuyu hedefin altına (sığmazsa üstüne, o da olmazsa yanına) yerleştir; ekranın içinde tut.
func _place_panel() -> void:
	var screen := size
	var psize := _panel.size
	var t := _target()
	var pos: Vector2
	if t == null:
		pos = (screen - psize) / 2
	else:
		var r := _local_rect(t)
		var below := r.end.y + MARGIN
		var above := r.position.y - psize.y - MARGIN
		pos = Vector2(r.get_center().x - psize.x / 2, below)
		if STEPS[_step][0] in PREFER_ABOVE:
			# Üstte tam yer yoksa bile ekranın tepesine dayan: alta inip eldeki kartları örtmesin
			# (eğitim tam o kartları sürüklemeyi isterken kutu üstlerini kapatıyordu).
			pos.y = maxf(above, MARGIN)
		elif pos.y + psize.y > screen.y - MARGIN:
			pos.y = above
		if pos.y < MARGIN:
			# Hedef çok uzunsa yanına koy.
			pos.y = r.get_center().y - psize.y / 2
			pos.x = r.end.x + MARGIN if r.get_center().x < screen.x / 2 else r.position.x - psize.x - MARGIN
	pos.x = clampf(pos.x, MARGIN, screen.x - psize.x - MARGIN)
	pos.y = clampf(pos.y, MARGIN, screen.y - psize.y - MARGIN)
	# Hedef el değilse kutu eldeki kartların üstüne binmesin; binerse elin üstüne çık.
	var hand: Control = main.tutorial_target("hand")
	if STEPS[_step][0] != "hand" and hand != null and is_instance_valid(hand) and hand.is_visible_in_tree():
		var hand_rect := _local_rect(hand)
		if Rect2(pos, psize).intersects(hand_rect):
			pos.y = maxf(MARGIN, hand_rect.position.y - psize.y - MARGIN)
	_panel.position = pos.round()


func _local_rect(t: Control) -> Rect2:
	var r := t.get_global_rect()
	r.position -= global_position
	return r


## Hedefin etrafında yanıp sönen altın çerçeve.
func _draw() -> void:
	var t := _target()
	if t == null:
		return
	var r := _local_rect(t).grow(6)
	var a := 0.55 + 0.45 * sin(_time * 5.0)
	var c := Color(UIStyle.GOLD, a)
	draw_rect(r, Color(UIStyle.GOLD, 0.08 * a))
	draw_rect(r, UIStyle.OUTLINE, false, 6.0)
	draw_rect(r, c, false, 4.0)
