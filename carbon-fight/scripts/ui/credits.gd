class_name Credits
extends Control
## Ana menü ve oyun sonu tarafından kullanılan ortak, kaydırılabilir Credits katmanı.

signal closed

const CREDITS_PATH := "res://assets/legal/credits.bbcode"
const GODOT_LICENSE_PATH := "res://assets/legal/GODOT_LICENSE.txt"
const BACKGROUND := preload("res://assets/sprites/bg/orman.png")

var _from_game_end := false
var _back_button: Button
var _license_button: Button
var _heading: Label
var _text: RichTextLabel
var _showing_licenses := false
var _scroll: ScrollContainer
var _closing := false
var _auto_scroll_pause := 0.0
var _auto_scroll_position := 0.0

const AUTO_SCROLL_SPEED := 14.0


func _ready() -> void:
	theme = UIStyle.make_theme()
	_build_ui()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	_back_button.grab_focus()


func setup(from_game_end: bool) -> void:
	_from_game_end = from_game_end
	if _back_button != null:
		_back_button.text = tr("ANA MENÜYE DÖN") if _from_game_end else tr("GERİ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _from_game_end or _showing_licenses or _scroll == null:
		return
	if _auto_scroll_pause > 0.0:
		_auto_scroll_pause -= delta
		_auto_scroll_position = float(_scroll.scroll_vertical)
		return
	var bar := _scroll.get_v_scroll_bar()
	if _scroll.scroll_vertical < int(bar.max_value - bar.page):
		_auto_scroll_position += AUTO_SCROLL_SPEED * delta
		_scroll.scroll_vertical = int(_auto_scroll_position)


func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24)
	add_child(outer)

	var panel := PanelContainer.new()
	var skin := Art.skin("panel")
	panel.add_theme_stylebox_override("panel", skin if skin != null else UIStyle.box(UIStyle.PANEL, UIStyle.PANEL_BORDER, 2))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_heading = UIStyle.label(tr("EMEĞİ GEÇENLER"), 32, UIStyle.GOLD)
	_heading.add_theme_constant_override("outline_size", 8)
	box.add_child(_heading)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(_on_scroll_input)
	box.add_child(_scroll)

	var text := RichTextLabel.new()
	_text = text
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = true
	text.custom_minimum_size.y = 400
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", UIStyle.font())
	text.add_theme_font_size_override("normal_font_size", UIStyle.BODY_FONT_SIZE)
	text.add_theme_color_override("default_color", Color("f4f4f4"))
	text.text = _credits_text()
	_scroll.add_child(text)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	_license_button = Button.new()
	_license_button.text = tr("LİSANSLAR")
	_license_button.custom_minimum_size = Vector2(220, 52)
	_license_button.add_theme_font_size_override("font_size", 24)
	_license_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_license_button.pressed.connect(_toggle_licenses)
	buttons.add_child(_license_button)

	_back_button = Button.new()
	_back_button.text = tr("ANA MENÜYE DÖN") if _from_game_end else tr("GERİ")
	_back_button.icon = UIStyle.icon("star")
	_back_button.custom_minimum_size = Vector2(260, 52)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.add_theme_font_size_override("font_size", 24)
	_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_button.pressed.connect(_close)
	buttons.add_child(_back_button)


## Seçili dildeki credits dosyası (ör. credits_en.bbcode); yoksa Türkçe credits.bbcode.
func _credits_text() -> String:
	var localized := CREDITS_PATH.get_basename() + "_%s.bbcode" % TranslationServer.get_locale().get_slice("_", 0)
	var path := localized if FileAccess.file_exists(localized) else CREDITS_PATH
	return FileAccess.get_file_as_string(path) + "[/center]"


## Lisanslar ekranı: Godot'nun MIT lisansı ve motorun içindeki üçüncü taraf bileşenler.
## Kayan credits'i uzatmasın diye ayrı bir butonun arkasında duruyor.
func _licenses_text() -> String:
	var godot_license := FileAccess.get_file_as_string(GODOT_LICENSE_PATH)
	return "[center][font_size=24][color=#73eff7]— Godot Engine —[/color][/font_size]\n\n[font_size=%d]" % UIStyle.BODY_FONT_SIZE \
		+ _escape(godot_license) + "[/font_size]" + _third_party_text() + "[/center]"


func _toggle_licenses() -> void:
	Sfx.play("click")
	_showing_licenses = not _showing_licenses
	_text.text = _licenses_text() if _showing_licenses else _credits_text()
	_heading.text = tr("LİSANSLAR") if _showing_licenses else tr("EMEĞİ GEÇENLER")
	_license_button.text = tr("EMEĞİ GEÇENLER") if _showing_licenses else tr("LİSANSLAR")
	_scroll.scroll_vertical = 0
	_auto_scroll_position = 0.0


## Godot'nun içindeki üçüncü taraf bileşenlerin (FreeType, ENet, mbedTLS vb.) telif ve lisans
## bildirimleri. Motorun kendisinden okunur, Godot sürümü değişince kendiliğinden güncel kalır.
func _third_party_text() -> String:
	var out := "\n\n[font_size=24][color=#73eff7]— %s —[/color][/font_size]\n\n[font_size=%d]" % [tr("Godot Üçüncü Taraf Bileşenleri"), UIStyle.BODY_FONT_SIZE]
	for component in Engine.get_copyright_info():
		var component_name: String = component["name"]
		if component_name == "Godot Engine":
			continue
		out += "[color=#a7f070]" + _escape(component_name) + "[/color]\n"
		for part in component["parts"]:
			for line in part["copyright"]:
				out += "© " + _escape(str(line)) + "\n"
			out += _escape(str(part["license"])) + "\n"
		out += "\n"
	var licenses := Engine.get_license_info()
	for license_name in licenses:
		out += "\n[color=#a7f070]" + _escape(str(license_name)) + "[/color]\n" + _escape(str(licenses[license_name])) + "\n"
	return out + "[/font_size]"


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventPanGesture:
		_auto_scroll_pause = 3.0


func _close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("click")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	await tween.finished
	if _from_game_end:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		closed.emit()
		queue_free()
