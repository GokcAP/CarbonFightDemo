class_name EndingScene
extends Control
## Final sahnesi: Kül yavaş yavaş küle dönüşüp kaybolurken içinden Doğa Ana belirir ve yanındaki
## konuşma balonunda sözünü söyler. Tıklayınca (ya da Enter/Space) sahne biter ve `finished` yayılır;
## animasyon sürerken tıklamak sahneyi sona atlatır.

signal finished

const KUL := preload("res://assets/sprites/bosses/kul_ana_0.png")
const DOGA_ANA := preload("res://assets/sprites/bosses/doga_ana.png")
## Sprite büyütmesi (64x64 -> 320x320).
const SPRITE_SCALE := 5
const ASH := Color("94b0c2")
const BUBBLE_BG := Color("f4f4f4")

var _kul: TextureRect
var _doga: TextureRect
var _name: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _hint: Label
var _seq: Tween
## Parçacık yayılan evre: "ash" (Kül dağılıyor), "bloom" (Doğa Ana beliriyor) ya da "".
var _phase := ""
var _spawn_timer := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_doga = _sprite(DOGA_ANA)
	_doga.modulate = Color(UIStyle.WELFARE, 0.0)
	_doga.scale = Vector2(0.8, 0.8)
	_kul = _sprite(KUL)

	_name = UIStyle.label(tr("Kül"), 32, ASH)
	_name.add_theme_constant_override("outline_size", 8)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	_build_bubble()

	_hint = UIStyle.label(tr("Devam etmek için tıkla"), 24, Color("f4f4f4"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	add_child(_hint)

	resized.connect(_layout)
	_layout()
	_play()


func _sprite(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = texture.get_size() * SPRITE_SCALE
	rect.pivot_offset = rect.size / 2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Doğa Ana'nın sağında, kuyruğu ona dönük konuşma balonu.
func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UIStyle.box(BUBBLE_BG, UIStyle.OUTLINE, 2, 8 * UIStyle.PX))
	_bubble.custom_minimum_size.x = 380
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	add_child(_bubble)
	_bubble_text = UIStyle.label(tr("Beni yenmedin. Beni hatırladın."), 24, UIStyle.OUTLINE)
	_bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bubble_text.visible_ratio = 0.0
	_bubble.add_child(_bubble_text)
	# Kuyruk: balonun sol kenarından Doğa Ana'ya bakan pixel üçgen.
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func() -> void:
		var outline := PackedVector2Array([Vector2(2, -14), Vector2(-26, 6), Vector2(2, 14)])
		var fill := PackedVector2Array([Vector2(4, -10), Vector2(-20, 5), Vector2(4, 9)])
		tail.draw_colored_polygon(outline, UIStyle.OUTLINE)
		tail.draw_colored_polygon(fill, BUBBLE_BG))
	# Etikete bağlı (konteyner boyutlandırmasından etkilenmez); balonun iç boşluğu kadar sola kayar.
	_bubble_text.add_child(tail)
	_bubble_text.resized.connect(func() -> void:
		tail.position = Vector2(-8 * UIStyle.PX, _bubble_text.size.y / 2))


func _layout() -> void:
	var sprite_size := _kul.size
	var center := Vector2(size.x * 0.36, size.y * 0.44)
	for rect in [_kul, _doga]:
		rect.position = (center - sprite_size / 2).round()
	_name.size = Vector2(sprite_size.x, 40)
	_name.position = Vector2(center.x - sprite_size.x / 2, center.y + sprite_size.y / 2 + 8)
	_bubble.reset_size()
	_bubble.position = Vector2(center.x + sprite_size.x / 2 + 30, center.y - sprite_size.y * 0.32)
	_hint.size = Vector2(size.x, 40)
	_hint.position = Vector2(0, size.y - 80)


## Zaman çizelgesi: karar -> Kül dağılır -> Doğa Ana içinden belirir -> balon yazılır -> "devam".
func _play() -> void:
	_seq = create_tween()
	_seq.tween_property(self, "modulate:a", 1.0, 0.6)
	_seq.tween_interval(0.5)
	_seq.tween_callback(func() -> void: _phase = "ash")
	# Kül yavaşça söner ve hafifçe şişer; Doğa Ana aynı yerden, onun içinden belirmeye başlar.
	_seq.tween_property(_kul, "modulate", Color(ASH, 0.0), 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_seq.parallel().tween_property(_kul, "scale", Vector2(1.06, 1.06), 3.4)
	_seq.parallel().tween_callback(func() -> void: _phase = "bloom").set_delay(1.4)
	_seq.parallel().tween_property(_doga, "modulate", Color.WHITE, 3.0).set_delay(1.2).set_trans(Tween.TRANS_SINE)
	_seq.parallel().tween_property(_doga, "scale", Vector2.ONE, 3.0).set_delay(1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seq.parallel().tween_property(_name, "modulate:a", 0.0, 0.6).set_delay(1.8)
	_seq.parallel().tween_callback(func() -> void:
		_name.text = tr("Doğa Ana")
		_name.add_theme_color_override("font_color", UIStyle.WELFARE)).set_delay(2.4)
	_seq.parallel().tween_property(_name, "modulate:a", 1.0, 0.8).set_delay(2.5)
	_seq.tween_callback(func() -> void: _phase = "")
	_seq.tween_interval(0.4)
	_seq.tween_callback(func() -> void: Fx.pop_in(_bubble, 0.4))
	_seq.tween_interval(0.3)
	_seq.tween_property(_bubble_text, "visible_ratio", 1.0, 1.4)
	_seq.tween_interval(0.6)
	_seq.tween_callback(_show_hint)


func _process(delta: float) -> void:
	if _phase == "":
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = 0.05
	if _phase == "ash":
		_spawn_pixel(ASH.darkened(randf_range(0.0, 0.4)), Vector2(randf_range(-30, 30), randf_range(-120, -60)))
	else:
		_spawn_pixel(UIStyle.WELFARE.lightened(randf_range(0.0, 0.3)), Vector2(randf_range(-50, 50), randf_range(-90, -40)))


## Sprite'ın içinden çıkıp süzülerek sönen küçük kare parçacık (kül ya da yeşil ışık).
func _spawn_pixel(color: Color, drift: Vector2) -> void:
	var pixel := ColorRect.new()
	pixel.color = color
	pixel.size = Vector2(6, 6)
	pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var area := _kul.size * Vector2(0.5, 0.7)
	var start := _kul.position + _kul.size / 2 + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * area
	pixel.position = (start / 2).round() * 2
	add_child(pixel)
	move_child(pixel, _bubble.get_index())
	var t := pixel.create_tween().set_parallel()
	var duration := randf_range(1.0, 1.6)
	t.tween_property(pixel, "position", (pixel.position + drift).round(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pixel, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
	t.chain().tween_callback(pixel.queue_free)


func _show_hint() -> void:
	if _done:
		return
	_done = true
	var pulse := _hint.create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 1.0, 0.8)
	pulse.tween_property(_hint, "modulate:a", 0.3, 0.8)


## Animasyon bitmeden tıklanırsa son kareye atla; bittiyse sahneyi kapat.
func _advance() -> void:
	if not _done:
		if _seq != null:
			_seq.kill()
		_phase = ""
		modulate.a = 1.0
		_kul.modulate.a = 0.0
		_doga.modulate = Color.WHITE
		_doga.scale = Vector2.ONE
		_name.text = tr("Doğa Ana")
		_name.add_theme_color_override("font_color", UIStyle.WELFARE)
		_name.modulate.a = 1.0
		_bubble.modulate.a = 1.0
		_bubble.scale = Vector2.ONE
		_bubble_text.visible_ratio = 1.0
		_show_hint()
		return
	Sfx.play("click")
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if mouse_filter != Control.MOUSE_FILTER_IGNORE and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
