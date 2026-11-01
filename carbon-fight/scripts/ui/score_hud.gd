class_name ScoreHud
extends PanelContainer
## Oyun sırasında sağ üstte duran skor kutusu: canlı skor, en iyi skor ve skorun neden
## değiştiğini gösteren emojili satırlar (ör. "+60 🌾 Refah"). Veriyi Score autoload'u verir.
## Sebep satırları kutunun içindeki ayrılmış alanda belirir; çevredeki hiçbir şeyin üstüne binmez.

const REASON_TIME := 2.6
const REASON_LINES := 2
const LINE_HEIGHT := 20

var _value: Label
var _best: Label
var _reasons: VBoxContainer
var _shown := 0
var _count_tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, UIStyle.GOLD, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var title := UIStyle.label(tr("SKOR"), 16, UIStyle.TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_best = UIStyle.label("", 16, UIStyle.GOLD)
	_best.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_best)
	_value = UIStyle.label("", 32)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(_value)
	# Sebep satırları için sabit yükseklikte alan (kutu boyu değişip düzen kaymasın).
	_reasons = VBoxContainer.new()
	_reasons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reasons.add_theme_constant_override("separation", 0)
	_reasons.custom_minimum_size.y = REASON_LINES * LINE_HEIGHT
	box.add_child(_reasons)

	Score.changed.connect(_on_changed)
	Score.gained.connect(_on_gained)
	Score.best_changed.connect(func(_b: int) -> void: _refresh_best())
	_shown = Score.current()
	_value.text = str(_shown)
	_refresh_best()


func _refresh_best() -> void:
	_best.text = tr("En iyi: %d") % maxi(Score.best, Score.current() if GameState.is_over() else 0)


## Skor sayısı yeni değere sayarak gider.
func _on_changed(score: int) -> void:
	if _count_tween != null:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(func(v: float) -> void:
		_shown = roundi(v)
		_value.text = str(_shown), float(_shown), float(score), 0.4)


## Skorun bir parçası değişti: skorun altındaki alanda emojili sebep satırı belirir, sonra söner.
## En fazla REASON_LINES satır görünür; yenisi gelince en eskisi çıkar.
func _on_gained(delta: int, emoji: String, reason: String) -> void:
	Fx.bump(_value, 1.15 if delta > 0 else 1.05)
	while _reasons.get_child_count() >= REASON_LINES:
		var oldest := _reasons.get_child(0)
		_reasons.remove_child(oldest)
		oldest.queue_free()
	var line := UIStyle.label("%+d %s %s" % [delta, emoji, reason], 16, UIStyle.GOOD if delta > 0 else UIStyle.BAD)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.custom_minimum_size.y = LINE_HEIGHT
	_reasons.add_child(line)
	line.modulate.a = 0.0
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 1.0, 0.15)
	t.tween_interval(REASON_TIME - 0.6)
	t.tween_property(line, "modulate:a", 0.0, 0.45)
	t.tween_callback(func() -> void:
		if line.get_parent() == _reasons:
			_reasons.remove_child(line)
		line.queue_free())
