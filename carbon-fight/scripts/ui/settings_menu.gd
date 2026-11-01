class_name SettingsMenu
extends ColorRect
## Ayarlar penceresi: dil, müzik/efekt sesi, tam ekran, hızlı animasyon.
## Değişiklikler anında uygulanır ve Settings autoload'u üzerinden kaydedilir.

var _box: VBoxContainer
## Oyun sahnesi true yapar; ana menüde gereksiz geri dönüş butonu gösterilmez.
var show_main_menu_button := false


func _ready() -> void:
	color = Color(0.04, 0.05, 0.08, 0.82)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var skin := Art.skin("panel")
	panel.add_theme_stylebox_override("panel", skin if skin != null else UIStyle.box(UIStyle.PANEL, UIStyle.PANEL_BORDER, 2))
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)

	Settings.language_changed.connect(_build)
	_build()


func open() -> void:
	_build()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	if visible:
		Sfx.play("click")
	visible = false
	_close_confirm()


func _build() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()

	var title := UIStyle.label(tr("Ayarlar"), 32, UIStyle.GOLD)
	title.add_theme_constant_override("outline_size", 8)
	_box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	_box.add_child(grid)

	var language := OptionButton.new()
	var codes: Array = Settings.LANGUAGES.keys()
	for i in codes.size():
		language.add_item(Settings.LANGUAGES[codes[i]], i)
		if codes[i] == Settings.language:
			language.select(i)
	language.item_selected.connect(func(i: int) -> void:
		Sfx.play("click")
		Settings.set_language(codes[i]))
	_row(grid, tr("Dil / Language"), language)

	_row(grid, tr("Müzik"), _slider(Settings.music_volume, Settings.set_music_volume))
	_row(grid, tr("Efektler"), _slider(Settings.sfx_volume, func(v: float) -> void:
		Settings.set_sfx_volume(v)
		Sfx.play("click")))
	_row(grid, tr("Tam ekran"), _toggle(Settings.fullscreen, Settings.set_fullscreen))
	_row(grid, tr("Hızlı animasyon"), _toggle(Settings.fast_animations, Settings.set_fast_animations))

	var note := UIStyle.label(tr("Ayarlar otomatik kaydedilir. Esc ile aç/kapat."), 16, UIStyle.TEXT_DIM)
	_box.add_child(note)

	if show_main_menu_button:
		var main_menu_button := Button.new()
		main_menu_button.text = tr("ANA MENÜYE DÖN")
		main_menu_button.icon = UIStyle.icon("seed")
		main_menu_button.custom_minimum_size = Vector2(260, 48)
		main_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		main_menu_button.add_theme_font_size_override("font_size", 24)
		main_menu_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		main_menu_button.pressed.connect(_return_to_main_menu)
		_box.add_child(main_menu_button)

	var close_button := Button.new()
	close_button.text = tr("Kapat")
	close_button.custom_minimum_size = Vector2(200, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(close)
	_box.add_child(close_button)


## Oyun sürerken ana menüye dönmek ilerlemeyi siler: önce onay iste. Oyun bittiyse doğrudan dön.
func _return_to_main_menu() -> void:
	Sfx.play("click")
	if GameState.is_over():
		_go_to_main_menu()
	else:
		_show_confirm()


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _show_confirm() -> void:
	_close_confirm()
	var layer := ColorRect.new()
	layer.name = "Confirm"
	layer.color = Color(0.04, 0.05, 0.08, 0.7)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.DANGER, 2))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := UIStyle.label(tr("Ana menüye dönülsün mü?"), 24, UIStyle.DANGER)
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var body := UIStyle.label(tr("Emin misin? Oyun yarıda kalacak ve ilerlemen kaybolacak."), 16)
	body.custom_minimum_size.x = 400  # satır kaydırma bu genişlikte ölçülsün
	box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.text = tr("Vazgeç")
	cancel.custom_minimum_size = Vector2(160, 44)
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.pressed.connect(func() -> void:
		Sfx.play("click")
		_close_confirm())
	buttons.add_child(cancel)
	var confirm := Button.new()
	confirm.text = tr("Evet, dön")
	confirm.custom_minimum_size = Vector2(160, 44)
	confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm.pressed.connect(func() -> void:
		Sfx.play("click")
		_go_to_main_menu())
	buttons.add_child(confirm)
	cancel.grab_focus.call_deferred()  # yanlışlıkla Enter'a basılırsa ilerleme gitmesin


func _close_confirm() -> void:
	var layer := get_node_or_null("Confirm")
	if layer != null:
		remove_child(layer)
		layer.queue_free()


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label := UIStyle.label(text, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(label)
	control.custom_minimum_size.x = 220
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(control)


func _slider(value: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.y = 24
	# Sürüklerken değil, bırakınca kaydet (sürekli diske yazmamak için).
	slider.drag_ended.connect(func(_changed: bool) -> void: on_change.call(slider.value))
	slider.value_changed.connect(func(v: float) -> void:
		if not slider.has_focus():
			on_change.call(v))
	return slider


func _toggle(value: bool, on_change: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.text = tr("Açık") if value else tr("Kapalı")
	toggle.toggled.connect(func(on: bool) -> void:
		Sfx.play("click")
		toggle.text = tr("Açık") if on else tr("Kapalı")
		on_change.call(on))
	return toggle
