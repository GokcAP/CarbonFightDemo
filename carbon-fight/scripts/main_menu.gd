class_name MainMenu
extends Control
## Oyunun başlangıç ekranı. Oyun sahnesi yalnızca "Yeni Oyun" seçilince yüklenir.

const TEAM_LOGO_PATH := "res://assets/ui/sidequest_logo.png"
const CREDITS_SCENE := preload("res://scenes/credits.tscn")
## Başlığın menüdeki yeri (ekranın üst ortası) ve boyutu; açılışta ekranın ortasında bu kadar büyük.
const TITLE_SIZE := Vector2(720, 150)
const TITLE_TOP := 42.0
const SPLASH_SCALE := 1.9
## Butonlar ekran merkezine göre asimetrik dağılır (ortadaki Denge Ağacı açık kalır):
## [metin, fonksiyon adı, ikon, merkeze uzaklık, boyut, eğim derecesi]
const BUTTON_LAYOUT := [
	["YENİ OYUN", "_start_game", "seed", Vector2(-380, -110), Vector2(300, 72), -3.0],
	["KARAKTERLER VE HARİTALAR", "_open_grimoire", "quest", Vector2(360, -140), Vector2(370, 60), 2.0],
	["AYARLAR", "_open_settings", "cool", Vector2(-300, 12), Vector2(240, 56), 2.5],
	["EMEĞİ GEÇENLER", "_open_credits", "star", Vector2(415, -32), Vector2(280, 56), -2.0],
	["ÇIKIŞ", "_quit_game", "skull", Vector2(285, 80), Vector2(180, 50), 3.0],
]

## Açılış (büyük başlık) yalnızca oyun ilk açıldığında; oyundan menüye dönünce gösterilmez.
static var _intro_done := false

var _settings: SettingsMenu
var _credits: Credits
var _title_box: VBoxContainer
var _hint: Label
var _splash: Button
var _breathe: Tween
var _buttons: Array[Button] = []
## En iyi skor kutusu: açılışta ("Başlamak için tıkla") gizli, menü butonlarıyla birlikte belirir.
var _best_box: PanelContainer
## 0 = açılış (büyük, ortada), 1 = menü (normal boyut, üstte).
var _title_t := 1.0


func _ready() -> void:
	theme = UIStyle.make_theme()
	# Oyundan (ör. boss savaşından) dönülünce boss müziği değil, oyunun kendi müziği çalsın.
	Sfx.play_default_music()
	_build_ui()
	_settings = SettingsMenu.new()
	add_child(_settings)
	Settings.language_changed.connect(_rebuild_ui)


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_done and event.is_action_pressed("ui_accept"):
		_finish_intro()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings.visible:
		_settings.close()
	elif _credits != null:
		return
	else:
		_open_settings()
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Menüye özel hareketli arka plan (scripts/ui/menu_background.gd).
	var background := MenuBackground.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# Başlık: açılışta ekranın ortasında kocaman, sonra üstteki yerine küçülerek kayar.
	_title_box = VBoxContainer.new()
	_title_box.size = TITLE_SIZE
	_title_box.pivot_offset = TITLE_SIZE / 2
	_title_box.add_theme_constant_override("separation", 2)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)
	var title := UIStyle.label("CarbonFight", 64, UIStyle.WELFARE)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 12)
	_title_box.add_child(title)
	var subtitle := UIStyle.label(tr("Denge Tohumu'nu geri kazan."), 24, UIStyle.GOLD)
	_title_box.add_child(subtitle)

	# Oval kenarlı, ekrana asimetrik dağılmış butonlar.
	_buttons.clear()
	for spec: Array in BUTTON_LAYOUT:
		var button := _button(tr(spec[0]), Callable(self, spec[1]), UIStyle.icon(spec[2]), spec[4])
		button.rotation_degrees = spec[5]
		button.set_meta("offset", spec[3])
		if spec[1] == "_quit_game":
			button.tooltip_text = tr("Oyundan çık")
		add_child(button)
		_buttons.append(button)

	# "by" + takım logosu (SideQuest), alt ortada. Logo 160×48 piksel art, 2 kat büyütülür.
	var team_logo := load(TEAM_LOGO_PATH) as Texture2D
	if team_logo != null:
		var footer := HBoxContainer.new()
		footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		footer.position = Vector2(-190, -104)
		footer.size = Vector2(380, 96)
		footer.alignment = BoxContainer.ALIGNMENT_CENTER
		footer.add_theme_constant_override("separation", 12)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var by_label := UIStyle.label("by", 16, UIStyle.TEXT_DIM)
		by_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # "b" ve "y" alt alta bölünmesin
		by_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(by_label)
		footer.add_child(UIStyle.tex_rect(team_logo, 2))
		add_child(footer)
		_appear(footer, 0.46)

	# Sağ üst köşe: en iyi skor (oyunlar arasında kalıcı).
	var best_box := PanelContainer.new()
	best_box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, UIStyle.GOLD, 2))
	best_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	best_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	best_box.offset_right = -20
	best_box.offset_top = 20
	var best := UIStyle.label("🏆 %s" % (tr("En iyi skor: %d") % Score.best), 24, UIStyle.GOLD)
	best.autowrap_mode = TextServer.AUTOWRAP_OFF
	best_box.add_child(best)
	best_box.visible = false
	add_child(best_box)
	_best_box = best_box

	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if _intro_done:
		_title_t = 1.0
		_show_buttons()
	else:
		_build_splash()
	_layout()


func _button(text: String, callback: Callable, icon: Texture2D, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.custom_minimum_size = button_size
	button.size = button_size
	button.pivot_offset = button_size / 2
	button.add_theme_font_size_override("font_size", 24)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	button.mouse_entered.connect(func() -> void: Fx.bump(button, 1.05))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _oval_style(state))
	return button


## Oval (yuvarlak köşeli) buton stili: pixel görünümlü basamaklı köşeler, altta gölge.
func _oval_style(state: String) -> StyleBox:
	if state == "focus":
		return StyleBoxEmpty.new()
	var colors := {
		"normal": [Color("257179"), Color("a7f070")],
		"hover": [Color("38b764"), Color("f4f4f4")],
		"pressed": [Color("29366f"), Color("73eff7")],
		"disabled": [Color("333c57"), Color("566c86")],
	}
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors[state][0]
	sb.border_color = colors[state][1]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(26)
	sb.anti_aliasing = false
	sb.shadow_color = Color(0.04, 0.05, 0.08, 0.6)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	return sb


## Başlığı ve butonları ekran boyutuna göre yerleştir.
func _layout() -> void:
	var center := size / 2
	for button in _buttons:
		var offset: Vector2 = button.get_meta("offset")
		button.position = (center + offset - button.size / 2).round()
	_apply_title(_title_t)


## t = 0: açılış (ekranın ortasında büyük), t = 1: menü (üstte normal boyut).
func _apply_title(t: float) -> void:
	_title_t = t
	var menu_pos := Vector2(size.x / 2 - TITLE_SIZE.x / 2, TITLE_TOP)
	var splash_pos := Vector2(size.x / 2 - TITLE_SIZE.x / 2, size.y / 2 - TITLE_SIZE.y / 2 - 30)
	_title_box.position = splash_pos.lerp(menu_pos, t).round()
	var k := lerpf(SPLASH_SCALE, 1.0, t)
	_title_box.scale = Vector2(k, k)


## Açılış: büyük başlık + "Başlamak için tıkla". Ekrana (ya da Enter/Space) basınca menüye geçer.
func _build_splash() -> void:
	_title_t = 0.0
	for button in _buttons:
		button.visible = false
	_hint = UIStyle.label(tr("Başlamak için tıkla"), 24, Color("f4f4f4"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = -250
	_hint.offset_bottom = -210
	add_child(_hint)
	var pulse := _hint.create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.25, 0.8)
	pulse.tween_property(_hint, "modulate:a", 1.0, 0.8)
	# Ekranın tamamı tıklanabilir (başlık dahil).
	_splash = Button.new()
	_splash.flat = true
	_splash.focus_mode = Control.FOCUS_NONE
	_splash.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_splash.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_splash.pressed.connect(_finish_intro)
	add_child(_splash)
	# Büyük başlık hafifçe nefes alır.
	_breathe = _title_box.create_tween().set_loops()
	_breathe.tween_property(_title_box, "modulate", Color(1.2, 1.2, 1.2), 1.2).set_trans(Tween.TRANS_SINE)
	_breathe.tween_property(_title_box, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)


func _finish_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	Sfx.play("click")
	if is_instance_valid(_splash):
		_splash.queue_free()
	if is_instance_valid(_hint):
		_hint.queue_free()
	if _breathe != null:
		_breathe.kill()
	_title_box.modulate = Color.WHITE
	var t := _title_box.create_tween()
	t.tween_method(_apply_title, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_show_buttons)


func _show_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].visible = true
		_appear(_buttons[i], 0.05 + i * 0.08)
	if is_instance_valid(_best_box):
		_best_box.visible = true
		_appear(_best_box, 0.2)


## Hafif giriş animasyonu, menünün her açılışta daha canlı görünmesini sağlar.
func _appear(control: Control, delay: float) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.92, 0.92)
	control.pivot_offset = control.size * 0.5
	# Tween kontrolün kendisine bağlı: dil değişince arayüz silinirse tween de durur.
	var tween := control.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(control, "modulate:a", 1.0, 0.24)


func _start_game() -> void:
	Sfx.play("click")
	Codex.reset_if_complete()  # oyun bitirildiyse büyü kitabı yeniden mühürlenir
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _open_settings() -> void:
	Sfx.play("click")
	_settings.open()
	_settings.move_to_front()


## Karakterler ve haritalar: yenilen boss'ların sayfaları açılan büyü kitabı.
func _open_grimoire() -> void:
	Sfx.play("click")
	add_child(Grimoire.new())


func _open_credits() -> void:
	if _credits != null:
		return
	Sfx.play("click")
	_credits = CREDITS_SCENE.instantiate() as Credits
	_credits.setup(false)
	_credits.closed.connect(func() -> void: _credits = null)
	add_child(_credits)


func _quit_game() -> void:
	Sfx.play("click")
	get_tree().quit()


func _rebuild_ui() -> void:
	_buttons.clear()
	for child in get_children():
		if child == _settings:
			continue
		remove_child(child)
		child.queue_free()
	_build_ui()
	_settings.move_to_front()
