class_name CardTrash
extends Button
## Tur sonu alanındaki kart bırakma hedefi. Yalnızca normal kartları ıskartaya gönderir;
## görev parçaları ve Denge Tohumu çöpe atılamaz, böylece hikâye akışı kilitlenmez.

var _drop_hover := false
var _available := true


func _ready() -> void:
	text = tr("KARTI ÇÖPE AT")
	icon = UIStyle.icon("trash")
	custom_minimum_size.y = 64
	add_theme_font_size_override("font_size", 24)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_NONE
	tooltip_text = tr("İstemediğin normal kartı buraya sürükle. Kart ıskartaya gider ve tur otomatik ilerler.")
	mouse_exited.connect(_set_drop_hover.bind(false))


func set_available(available: bool) -> void:
	_available = available
	self_modulate = Color.WHITE if available else Color(0.55, 0.55, 0.65, 0.7)
	mouse_default_cursor_shape = Control.CURSOR_DRAG if available else Control.CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_hover(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "card"):
		return false
	var hand_index: int = data["hand_index"]
	var ok := GameState.can_discard_card(hand_index)
	_set_drop_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	if GameState.discard_card(data["hand_index"]):
		Sfx.play("break", 0.02, 0.85)
		Fx.bump(self, 1.08)


func _set_drop_hover(on: bool) -> void:
	if _drop_hover == on:
		return
	_drop_hover = on
	self_modulate = Color(1.25, 0.72, 0.72) if on else (Color.WHITE if _available else Color(0.55, 0.55, 0.65, 0.7))
