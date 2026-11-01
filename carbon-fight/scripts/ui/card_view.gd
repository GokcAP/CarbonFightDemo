class_name CardView
extends PanelContainer
## Eldeki kart (pixel art). hand_index >= 0 ise sürüklenebilir.

const CARD_SIZE := Vector2(140, 172)

var card: CardData
var hand_index := -1
## >= 0 ise kart bu kadar gecikmeyle "dağıtılarak" belirir.
var deal_delay := -1.0
var _hover_tween: Tween


static func create(card_data: CardData, index := -1, delay := -1.0) -> CardView:
	var view := CardView.new()
	view.card = card_data
	view.hand_index = index
	view.deal_delay = delay
	return view


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	var border_width := 4 if card.kind != CardData.Kind.NORMAL else 2
	# Kart çerçevesi assets/ui/card_frame.png (gri tonlu, kart rengiyle boyanır); yoksa kodla çizilir.
	var skin := Art.skin("card_frame", card.color)
	add_theme_stylebox_override("panel", skin if skin != null else UIStyle.box(card.color.darkened(0.72), card.color, border_width))
	tooltip_text = tr("%s\n%s\nElement: %s") % [tr(card.display_name), tr(card.description), Elements.plain(card.element)]
	if hand_index >= 0:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	box.add_child(UIStyle.label(card.display_name, 16))

	var art_frame := PanelContainer.new()
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_theme_stylebox_override("panel", UIStyle.box(card.color.darkened(0.5), Color.TRANSPARENT, 0, UIStyle.PX * 2))
	if card.icon != null:
		art_frame.add_child(UIStyle.tex_rect(card.icon, UIStyle.PX))
	else:
		art_frame.add_child(UIStyle.label(card.emoji, 32))
	box.add_child(art_frame)

	var element_row := UIStyle.icon_label(card.element, Elements.plain(card.element), 16, Elements.COLORS[card.element])
	element_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(element_row)

	if card.kind != CardData.Kind.NORMAL:
		var hint := tr("Kendi sunağına koy") if card.kind == CardData.Kind.SHARD else tr("Ortadaki slota koy")
		box.add_child(UIStyle.label(hint, 16, UIStyle.GOLD))
		_finish_setup()
		return

	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 6)
	# Toplanan parçaların kalıcı bonusları dahil (tahtadaki slot etiketiyle aynı değerler).
	var ap := card.ap + (GameState.config.gunes_shard_ap if card.element == "gunes" and "gunes" in GameState.shards else 0)
	stats.add_child(UIStyle.icon_label("ap", str(ap)))
	stats.add_child(UIStyle.icon_label("hp", str(card.hp)))
	stats.add_child(UIStyle.icon_label("armor", str(card.armor + GameState.armor_bonus())))
	box.add_child(stats)

	var economy := HBoxContainer.new()
	economy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	economy.alignment = BoxContainer.ALIGNMENT_CENTER
	economy.add_theme_constant_override("separation", 8)
	if card.carbon_delta != 0:
		var good := card.carbon_delta < 0
		economy.add_child(UIStyle.icon_label("carbon", "%+d" % card.carbon_delta, 16, UIStyle.GOOD if good else UIStyle.BAD))
	if card.welfare_delta != 0:
		var good := card.welfare_delta > 0
		economy.add_child(UIStyle.icon_label("welfare", "%+d" % card.welfare_delta, 16, UIStyle.GOOD if good else UIStyle.BAD))
	box.add_child(economy)
	_finish_setup()


func _finish_setup() -> void:
	# Satır kaydıran yazılar kart genişliğinde ölçülsün. Aksi halde el oyun ortasında yenilenince
	# (ör. parça ele dönünce) 1 piksel genişlikte ölçülüp kartı yüzlerce piksel uzatıyor,
	# el ekrandan taşıyor ve tahtayı aşağı itiyordu.
	for label: Label in find_children("*", "Label", true, false):
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			label.custom_minimum_size.x = CARD_SIZE.x - 20
			label.size.x = CARD_SIZE.x - 20  # ilk ölçüm de bu genişlikle yapılsın
	if deal_delay >= 0.0:
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(deal_delay)
		tween.tween_callback(_deal_in)


func _deal_in() -> void:
	modulate.a = 1.0
	Fx.land(self)


func _set_hover(on: bool) -> void:
	if on and not GameState.can_play_card():
		return
	pivot_offset = size / 2
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.1)
	z_index = 1 if on else 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	if hand_index < 0 or not GameState.can_play_card():
		return null
	# Önizlemeyi fareye ortalamak için bir sarmalayıcı kullan.
	var holder := Control.new()
	var preview := CardView.create(card)
	preview.modulate.a = 0.9
	preview.rotation_degrees = -4
	preview.position = -CARD_SIZE / 2
	holder.add_child(preview)
	set_drag_preview(holder)
	Sfx.play("click")
	return {"type": "card", "hand_index": hand_index}
