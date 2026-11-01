extends Control
## Ana ekran: statlar + harita/görev paneli (sol), boss + 3x3 grid + el (orta), olay günlüğü + kart çöpü (sağ).
## Hikaye akışı: giriş hikayesi → harita tanıtımı → onarım → boss → parça ödülü → sonraki harita → final.
## Arayüz kodla kurulur; sahnede yalnızca bu script ve TurnManager vardır.
## Görsel dil: pixel art (Sweetie 16), Pixelify Sans font, art pikseli = 2 ekran pikseli.

## Sıcaklık sınıra yaklaştıkça arka plan bu renge döner.
const HOT_TINT := Color(1.35, 0.55, 0.42)
const CREDITS_SCENE := preload("res://scenes/credits.tscn")

const STORY_TEXT := """Doğa Ana dünyayı Denge Tohumu ile dengede tutuyordu. İnsanlar doymak bilmeden tükettikçe tohum çatladı ve üç parçaya bölündü.

Parçalar, kirlilikten doğan üç canavarın içine düştü. Tohumu kaybeden Doğa Ana öfkelendi ve Kül'e dönüştü. Dünya ısınmaya başladı.

Sen Eko-Lider'sin. Her haritayı onar, canavarı yen, parçayı geri al ve tohumu Doğa Ana'ya geri ver."""

## Final sahnesinden (Kül -> Doğa Ana, konuşma balonu) sonra açılan tebrikler sayfasının metni.
const ENDING_TEXT := """Denge Tohumu yeniden birleşti. Kül'ün külleri döküldü, yanmış orman filizleniyor.

Bu bir oyundu. Ama 2°C eşiği gerçek."""

const HOW_TO_TEXT := """Turda 1 kart oyna: boş slota yerleşir, aynı kartın üstüne birleşir, boss'a bırakırsan kurban vuruşu. Kart oynanınca tur otomatik ilerler.
İstemediğin normal kartı çöp kutusuna sürükleyerek ıskartaya atabilirsin.
Aynı element komşular +%25 AP. Kırmızı slotlar boss'un hedefi.
Önce haritanın onarım görevini bitir; canavar ancak o zaman uyanır."""

@onready var turn_manager: TurnManager = $TurnManager

var _slots: Array[Slot] = []
var _bg: TextureRect
var _content: MarginContainer
var _boss_panel: BossPanel
var _turn_label: Label
var _carbon_row: HBoxContainer
var _carbon_bar: ProgressBar
var _temp_row: HBoxContainer
var _temp_bar: ProgressBar
var _welfare_row: HBoxContainer
var _welfare_bar: ProgressBar
var _map_name: Label
var _effect_row: HBoxContainer
var _effect_text: Label
var _quest_row: HBoxContainer
var _shard_icons: Array[TextureRect] = []
var _actions_label: Label
var _hand_box: HBoxContainer
var _log: RichTextLabel
var _discard_bin: CardTrash
var _dialog_layer: ColorRect
## Oynayan final sahnesi (yoksa null).
var _ending: EndingScene
var _dialog_icon: TextureRect
var _dialog_title: Label
var _dialog_body: Label
## Oyun sonu skoru (okunur, büyük); diğer diyaloglarda gizli.
var _dialog_score: Label
var _dialog_button: Button
var _dialog_callback := Callable()
## Açık diyaloğu (yeni dilde) yeniden gösteren fonksiyon; dil değişince kullanılır.
var _dialog_source := Callable()
var _settings: SettingsMenu
var _base_step_delay := 0.0
var _last_stats := Vector3(-1, -1, -1)
var _credits: Credits
var _settings_button: Button
var _tutorial: Tutorial


func _ready() -> void:
	theme = UIStyle.make_theme()
	GameState.new_game()
	_build_ui()

	GameState.stats_changed.connect(_refresh_stats)
	GameState.hand_changed.connect(_refresh_hand)
	GameState.phase_changed.connect(_refresh_phase)
	GameState.log_message.connect(_add_log)
	GameState.game_over.connect(_on_game_over)
	GameState.map_started.connect(_on_map_started)
	GameState.map_completed.connect(_on_map_completed)
	GameState.quest_changed.connect(_refresh_map_panel)
	GameState.boss_changed.connect(_refresh_phase)
	GameState.card_attacked.connect(_on_card_attacked)
	GameState.slot_hit.connect(_on_slot_hit)
	GameState.card_merged.connect(_on_card_merged)
	GameState.card_placed.connect(func(slot: int) -> void: Fx.land(_slots[slot].art()))
	GameState.card_destroyed.connect(_on_card_destroyed)
	GameState.card_sacrificed.connect(func(_damage: int) -> void: Fx.shake(_content, 10.0, 7))
	GameState.turn_action_committed.connect(_on_card_action_committed)
	GameState.boss_attacking.connect(func() -> void: Fx.shake(_content, 5.0))
	GameState.boss_defeated.connect(func() -> void: Fx.shake(_content, 12.0, 9))
	GameState.shard_collected.connect(_on_shard_collected)
	GameState.chimney_cleared.connect(func(slot: int) -> void: _slot_text(slot, tr("Baca söndü!"), UIStyle.HIGHLIGHT))
	GameState.trash_cleared.connect(func(slot: int) -> void: _slot_text(slot, tr("Geri dönüştü"), UIStyle.GOOD))
	GameState.green_created.connect(_on_green_created)
	GameState.slots_cooled.connect(_on_slots_cooled)
	GameState.tide_flooded.connect(_on_tide)
	GameState.shard_placed.connect(_on_shard_placed)
	GameState.shard_lost.connect(func(slot: int) -> void: _slot_text(slot, tr("Parça düştü!"), UIStyle.DANGER))

	_settings = SettingsMenu.new()
	_settings.show_main_menu_button = true
	add_child(_settings)
	_base_step_delay = turn_manager.step_delay
	Settings.changed.connect(_apply_settings)
	Settings.language_changed.connect(_rebuild_ui)
	_apply_settings()

	_refresh_all()
	_refresh_map_panel()
	_add_log(tr("Hoş geldin, Eko-Lider! Denge Tohumu'nu yeniden birleştir."))
	_show_story()
	# Her yeni oyunda oyunun nasıl oynandığı adım adım anlatılır (atlanabilir).
	_tutorial = Tutorial.new()
	_tutorial.main = self
	add_child(_tutorial)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _credits != null:
			return
		_toggle_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _settings.visible:
			return
		if _dialog_layer.visible:
			_close_dialog()


# --- Kurulum -----------------------------------------------------------------

func _build_ui() -> void:
	var base := ColorRect.new()
	base.color = UIStyle.BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	_bg = TextureRect.new()
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 14)
	add_child(_content)
	_content.resized.connect(_fit_content, CONNECT_DEFERRED)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	row.add_child(_build_left_column())
	row.add_child(_build_center_column())
	row.add_child(_build_right_column())

	_build_dialog()


func _build_left_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 250
	col.add_theme_constant_override("separation", 8)

	var title := UIStyle.label(tr("CarbonFight"), 32, UIStyle.WELFARE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	_turn_label = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_turn_label)

	var stats := _panel()
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 5)
	stats.add_child(stats_box)
	col.add_child(stats)
	var cfg := GameState.config
	_carbon_row = UIStyle.icon_label("carbon")
	stats_box.add_child(_carbon_row)
	_carbon_bar = UIStyle.bar(UIStyle.CARBON, cfg.carbon_max, 0.0, 10)
	stats_box.add_child(_carbon_bar)
	_temp_row = UIStyle.icon_label("temp")
	stats_box.add_child(_temp_row)
	_temp_bar = UIStyle.bar(UIStyle.HEAT, cfg.temp_lose, cfg.temp_min, 10)
	stats_box.add_child(_temp_bar)
	_welfare_row = UIStyle.icon_label("welfare")
	stats_box.add_child(_welfare_row)
	_welfare_bar = UIStyle.bar(UIStyle.WELFARE, cfg.welfare_max, 0.0, 10)
	stats_box.add_child(_welfare_bar)

	# Harita ve görev paneli
	var map_panel := _panel()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 6)
	map_panel.add_child(map_box)
	col.add_child(map_panel)
	_map_name = UIStyle.label("", 24, UIStyle.GOLD)
	_map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_box.add_child(_map_name)
	_effect_row = UIStyle.icon_label("smoke", "", 16, UIStyle.BURN)
	map_box.add_child(_effect_row)
	_effect_text = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_effect_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	map_box.add_child(_effect_text)
	_quest_row = UIStyle.icon_label("quest", "", 16, UIStyle.HIGHLIGHT)
	(_quest_row.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(_quest_row.get_child(1) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_box.add_child(_quest_row)

	var shard_row := HBoxContainer.new()
	shard_row.add_theme_constant_override("separation", 6)
	var shard_label := UIStyle.label(tr("Tohum:"), 16, UIStyle.TEXT_DIM)
	shard_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	shard_row.add_child(shard_label)
	for element in GameState.SHARD_ORDER:
		var icon := UIStyle.tex_rect(UIStyle.icon("shard_" + element), 2)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		_shard_icons.append(icon)
		shard_row.add_child(icon)
	map_box.add_child(shard_row)
	return col


func _build_center_column() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Aralıklı tahta daha uzun: sütun 720 yüksekliğe sığsın diye boşluklar dar (el ve çöp hedefi taşmasın).
	col.add_theme_constant_override("separation", 2)

	var boss_row := CenterContainer.new()
	_boss_panel = BossPanel.new()
	boss_row.add_child(_boss_panel)
	col.add_child(boss_row)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	# 2.5D tahta: zemin adası + 9 elmas slot + sinerji bağları.
	var board := IsoBoard.new()
	center.add_child(board)
	_slots = board.slots

	_actions_label = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	col.add_child(_actions_label)

	_hand_box = HBoxContainer.new()
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.add_theme_constant_override("separation", 14)
	_hand_box.custom_minimum_size.y = CardView.CARD_SIZE.y
	col.add_child(_hand_box)
	return col


func _build_right_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 270
	col.add_theme_constant_override("separation", 10)

	# Sağ üst: canlı skor ve en iyi skor.
	col.add_child(ScoreHud.new())

	# Başlık satırı: "Olaylar" + Ayarlar butonu
	var title_row := HBoxContainer.new()
	var title := UIStyle.label(tr("Olaylar"), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var settings_button := Button.new()
	settings_button.text = tr("Ayarlar")
	settings_button.tooltip_text = tr("Ayarlar (Esc)")
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_button.pressed.connect(_toggle_settings)
	title_row.add_child(settings_button)
	_settings_button = settings_button
	col.add_child(title_row)

	var log_panel := _panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.add_theme_color_override("default_color", Color("f4f4f4"))
	log_panel.add_child(_log)
	col.add_child(log_panel)

	var help := UIStyle.label(tr(HOW_TO_TEXT), 16, UIStyle.TEXT_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(help)

	_discard_bin = CardTrash.new()
	col.add_child(_discard_bin)
	return col


## Hikaye, harita tanıtımı, ödül ve oyun sonu için tek diyalog katmanı.
func _build_dialog() -> void:
	_dialog_layer = ColorRect.new()
	_dialog_layer.color = Color(0.04, 0.05, 0.08, 0.82)
	_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.visible = false
	add_child(_dialog_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(center)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_dialog_icon = UIStyle.tex_rect(null, 1)
	box.add_child(_dialog_icon)
	_dialog_title = UIStyle.label("", 32)
	_dialog_title.add_theme_constant_override("outline_size", 8)
	box.add_child(_dialog_title)
	_dialog_body = UIStyle.label("", 16)
	box.add_child(_dialog_body)
	_dialog_score = UIStyle.label("", 32, UIStyle.GOLD)
	_dialog_score.add_theme_constant_override("outline_size", 8)
	_dialog_score.visible = false
	box.add_child(_dialog_score)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	box.add_child(button_row)
	_dialog_button = Button.new()
	_dialog_button.custom_minimum_size = Vector2(240, 48)
	_dialog_button.add_theme_font_size_override("font_size", 24)
	_dialog_button.pressed.connect(_close_dialog)
	button_row.add_child(_dialog_button)


func _show_dialog(icon: Texture2D, title: String, body: String, button: String, on_close := Callable(),
		title_color := Color.WHITE, icon_scale := 4) -> void:
	_dialog_score.visible = false
	_dialog_icon.texture = icon
	_dialog_icon.visible = icon != null
	if icon != null:
		_dialog_icon.custom_minimum_size = icon.get_size() * icon_scale
	_dialog_title.text = title
	_dialog_title.add_theme_color_override("font_color", title_color)
	_dialog_body.text = body
	_dialog_button.text = button
	_dialog_callback = on_close
	_dialog_layer.visible = true
	_dialog_layer.move_to_front()
	if _settings != null:
		_settings.move_to_front()
	_dialog_layer.modulate.a = 0.0
	create_tween().tween_property(_dialog_layer, "modulate:a", 1.0, 0.3)
	if icon != null:
		Fx.pop_in(_dialog_icon, 0.5)


func _close_dialog() -> void:
	if not _dialog_layer.visible:
		return
	Sfx.play("click")
	_dialog_layer.visible = false
	_dialog_source = Callable()
	var callback := _dialog_callback
	_dialog_callback = Callable()
	if callback.is_valid():
		callback.call()


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var skin := Art.skin("panel")
	p.add_theme_stylebox_override("panel", skin if skin != null else UIStyle.box(UIStyle.PANEL, UIStyle.PANEL_BORDER, 2))
	return p


# --- Ayarlar ve dil -----------------------------------------------------------

func _toggle_settings() -> void:
	if _settings.visible:
		_settings.close()
	else:
		Sfx.play("click")
		_settings.open()
		_settings.move_to_front()


func _apply_settings() -> void:
	turn_manager.step_delay = _base_step_delay * Settings.animation_factor()


## Dil değişince tüm arayüzü yeni dilde yeniden kur (oyun durumu korunur).
func _rebuild_ui() -> void:
	var dialog_source := _dialog_source if _dialog_layer.visible else Callable()
	var dialog_callback := _dialog_callback
	for child in get_children():
		if child == turn_manager or child == _settings or child == _tutorial or child == _ending:
			continue
		remove_child(child)
		child.queue_free()
	_slots = []
	_shard_icons.clear()
	_last_stats = Vector3(-1, -1, -1)
	_build_ui()
	if is_instance_valid(_tutorial):
		_tutorial.move_to_front()
		_tutorial.rebuild()
	_settings.move_to_front()
	_refresh_all()
	_refresh_map_panel()
	_add_log(tr("Dil değiştirildi."))
	if dialog_source.is_valid():
		dialog_source.call()
		_dialog_callback = dialog_callback


## Eğitimin işaret edeceği arayüz öğesi.
func tutorial_target(key: String) -> Control:
	match key:
		"stats":
			return _carbon_row.get_parent().get_parent() as Control
		"map":
			return _map_name.get_parent().get_parent() as Control
		"boss":
			return _boss_panel
		"hand":
			return _hand_box
		"board":
			return _slots[0].get_parent() as Control if not _slots.is_empty() else null
		"end_turn":
			return _discard_bin
		"settings":
			return _settings_button
	return null


# --- Hikaye akışı -------------------------------------------------------------

func _show_story() -> void:
	_show_dialog(UIStyle.icon("seed"), tr("Denge Tohumu"), tr(STORY_TEXT), tr("Devam"), _show_map_intro)
	_dialog_source = _show_story


func _show_map_intro() -> void:
	var map := GameState.map
	var body := tr("%s\n\nHarita etkisi - %s: %s\n\nGörev: %s") % [tr(map.intro_text), tr(map.effect_name), tr(map.effect_text), tr(map.quest_text)]
	var number := tr("Harita %d/%d") % [GameState.map_index + 1, GameState.config.maps.size()]
	if GameState.is_final():
		number = tr("Final")
	_show_dialog(map.boss.icon, "%s: %s" % [number, tr(map.display_name)], body, tr("Başla"), Callable(), UIStyle.GOLD, 2)
	_dialog_source = _show_map_intro


func _on_map_started() -> void:
	_apply_map_visuals()
	_refresh_map_panel()
	if is_node_ready() and not _dialog_layer.visible:
		_show_map_intro()


func _on_map_completed() -> void:
	_refresh_map_panel()
	await get_tree().create_timer(1.3).timeout
	_show_map_reward()


func _show_map_reward() -> void:
	var map := GameState.map
	var shard := map.reward_shard
	var icon: Texture2D = UIStyle.icon("star")
	var title := tr("%s yenildi!") % tr(map.boss.display_name)
	var body := tr("Harita onarıldı.")
	if shard != "":
		icon = load("res://assets/sprites/cards/shard_%s.png" % shard)
		title = tr("%s alındı!") % GameState.shard_name(shard)
		body = tr("%s yenildi ve yuttuğu parçayı bıraktı.\n\nKalıcı bonus: %s\n\nÖdül: Karbon %+d, Refah %+d, Sıcaklık %+.1f°C") % [
			tr(map.boss.display_name), tr(map.reward_text), GameState.config.boss_reward_carbon,
			GameState.config.boss_reward_welfare, GameState.config.map_reward_temp]
	_show_dialog(icon, title, body, tr("Sonraki harita"), _next_map, Elements.COLORS.get(shard, UIStyle.GOLD), 3)
	_dialog_source = _show_map_reward


func _next_map() -> void:
	_log.clear()
	GameState.start_map(GameState.map_index + 1)


func _apply_map_visuals() -> void:
	if GameState.map != null and GameState.map.background != null:
		_bg.texture = GameState.map.background
	_refresh_stats()


# --- Güncelleme ---------------------------------------------------------------

func _refresh_all() -> void:
	_apply_map_visuals()
	_refresh_stats()
	_refresh_hand()
	_refresh_phase()


func _set_stat(row: HBoxContainer, text: String, danger: bool) -> void:
	var l := row.get_child(1) as Label
	l.text = text
	l.add_theme_color_override("font_color", UIStyle.DANGER if danger else Color.WHITE)


func _refresh_stats() -> void:
	var cfg := GameState.config
	_set_stat(_carbon_row, tr("Karbon: %d / %d") % [GameState.carbon, cfg.carbon_max],
		GameState.carbon > cfg.boss_heal_carbon_threshold)
	_carbon_bar.value = GameState.carbon
	var asphalt_note := tr(" x2") if GameState.temp_multiplier() > 1.0 else ""
	_set_stat(_temp_row, tr("Sıcaklık: %.2f°C / %.1f%s") % [GameState.temperature, cfg.temp_lose, asphalt_note],
		GameState.temperature >= cfg.temp_warning)
	_temp_bar.value = GameState.temperature
	_set_stat(_welfare_row, tr("Refah: %d / %d") % [GameState.welfare, cfg.welfare_max], GameState.welfare <= 20)
	_welfare_bar.value = GameState.welfare

	# Değişen statı zıplat.
	var now := Vector3(GameState.carbon, GameState.temperature, GameState.welfare)
	if _last_stats.x >= 0:
		if now.x != _last_stats.x:
			Fx.bump(_carbon_row, 1.08)
		if not is_equal_approx(now.y, _last_stats.y):
			Fx.bump(_temp_row, 1.08)
		if now.z != _last_stats.z:
			Fx.bump(_welfare_row, 1.08)
	_last_stats = now

	# Arka plan haritanın tonunda; ısındıkça kızarır.
	var heat := inverse_lerp(cfg.start_temperature, cfg.temp_lose, GameState.temperature)
	var base_tint := GameState.map.tint if GameState.map != null else Color.WHITE
	var tint := base_tint.lerp(HOT_TINT, clampf(heat, 0.0, 1.0))
	create_tween().tween_property(_bg, "modulate", tint, 0.6)


func _refresh_map_panel() -> void:
	var map := GameState.map
	if map == null or _map_name == null:
		return
	_map_name.text = tr(map.display_name)
	var effect_icons := {MapData.Quest.CHIMNEYS: "smoke", MapData.Quest.TRASH: "trash",
		MapData.Quest.GREEN: "asphalt", MapData.Quest.ALTARS: "fire"}
	(_effect_row.get_child(0) as TextureRect).texture = UIStyle.icon(effect_icons[map.quest])
	(_effect_row.get_child(1) as Label).text = tr(map.effect_name)
	_effect_text.text = tr(map.effect_text)
	var quest_icons := {MapData.Quest.CHIMNEYS: "chimney", MapData.Quest.TRASH: "trash",
		MapData.Quest.GREEN: "toprak", MapData.Quest.ALTARS: "altar"}
	(_quest_row.get_child(0) as TextureRect).texture = UIStyle.icon(quest_icons[map.quest])
	var quest_text := GameState.quest_label()
	if GameState.stage == GameState.Stage.BOSS and not GameState.is_final():
		quest_text = tr("Onarıldı! %s ile savaş.") % tr(map.boss.display_name)
	(_quest_row.get_child(1) as Label).text = quest_text
	for i in _shard_icons.size():
		var element: String = GameState.SHARD_ORDER[i]
		var owned := element in GameState.shards
		_shard_icons[i].modulate = Color.WHITE if owned else Color(0.25, 0.25, 0.3, 0.8)
		_shard_icons[i].tooltip_text = "%s: %s" % [GameState.shard_name(element), _shard_bonus_text(element)] + \
			("" if owned else tr(" (henüz alınmadı)"))


func _shard_bonus_text(element: String) -> String:
	for map in GameState.config.maps:
		if map.reward_shard == element:
			return tr(map.reward_text)
	return ""


## Güvenlik: arayüz bir anlık taşmayla ekrandan büyük kalırsa (Godot küçültmüyor), içerik
## aslında sığıyorsa ekran boyutuna geri oturt.
func _fit_content() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	var screen := size
	if _content.size.is_equal_approx(screen):
		return
	var need := _content.get_combined_minimum_size()
	if need.x <= screen.x and need.y <= screen.y:
		_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _refresh_hand() -> void:
	# Eski kartları hemen çıkar: queue_free kare sonuna kadar beklediği için bir an eski + yeni kartlar
	# birlikte duruyor, el ekrana sığmıyor ve tüm arayüz taşıyordu (tahta aşağı kayıp el kayboluyordu).
	for child in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()
	var count := GameState.hand.size()
	_hand_box.add_theme_constant_override("separation", 14 if count <= 4 else -24)
	for i in count:
		_hand_box.add_child(CardView.create(GameState.hand[i], i, i * 0.08))
	_refresh_phase()


func _refresh_phase() -> void:
	if _discard_bin == null:
		return
	var player_turn := GameState.phase == GameState.Phase.PLAYER
	_discard_bin.set_available(player_turn and GameState.can_play_card())
	var stage_name := tr("Onarım") if GameState.stage == GameState.Stage.REPAIR else tr("Boss")
	if GameState.is_final():
		stage_name = tr("Final")
	_turn_label.text = tr("Tur %d - Harita %d/%d - %s") % [
		GameState.turn, GameState.map_index + 1, GameState.config.maps.size(), stage_name]
	if GameState.phase == GameState.Phase.RESOLVE:
		_actions_label.text = tr("Tur çözülüyor...")
	elif GameState.stage == GameState.Stage.REPAIR:
		_actions_label.text = tr("Onarım: %s · Kart oyna veya çöpe at") % GameState.quest_label()
	elif GameState.is_final():
		_actions_label.text = tr("Parçaları sunaklara koy, sunakları kartlarla koru")
	else:
		_actions_label.text = tr("Kartı slota, boss'a veya çöp kutusuna sürükle")
	_hand_box.modulate.a = 1.0 if GameState.can_play_card() else 0.6


func _on_card_action_committed() -> void:
	# Drop işlemi ve ilgili görsel sinyaller tamamlansın; sonra mevcut TurnManager sırası çalışsın.
	call_deferred("_advance_turn_after_action")


func _advance_turn_after_action() -> void:
	if GameState.phase == GameState.Phase.PLAYER and GameState.played_this_turn:
		turn_manager.end_turn()


# --- Efektler -----------------------------------------------------------------

func _slot_text(slot: int, text: String, color: Color, font_size := UIStyle.BODY_FONT_SIZE) -> void:
	Fx.float_text(_slots[slot], text, color, font_size)


## Kart vuruşu: slottan boss'a uçan element ikonu.
func _on_card_attacked(slot: int, _damage: int) -> void:
	var s := _slots[slot]
	Fx.bump(s.art(), 1.25)
	var card := GameState.grid[slot]
	if card == null:
		return
	var bolt := UIStyle.tex_rect(Elements.icon(card.data.element), UIStyle.PX)
	bolt.top_level = true
	bolt.z_index = 20
	add_child(bolt)
	var half := bolt.custom_minimum_size / 2
	bolt.global_position = s.global_position + Slot.CENTER - half
	var target := _boss_panel.sprite_center() - half + Vector2(randf_range(-20, 20), randf_range(-14, 14))
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(bolt, "scale", Vector2(1.8, 1.8), 0.06)
	tween.parallel().tween_property(bolt, "modulate:a", 0.0, 0.06)
	tween.tween_callback(bolt.queue_free)


func _on_slot_hit(slot: int, damage: int) -> void:
	var s := _slots[slot]
	Fx.shake(s, 5.0)
	if GameState.grid[slot] != null:
		Fx.hit_flash(s.art(), UIStyle.DANGER, 0.3)
		Fx.float_text(s, "-%d" % damage, UIStyle.DANGER)
	else:
		Fx.flash(s, Color(1.8, 0.6, 0.6))
		Fx.float_text(s, tr("-%d Refah") % damage, UIStyle.DANGER, 16)


func _on_card_merged(slot: int) -> void:
	var s := _slots[slot]
	Fx.bump(s, 1.15)
	Fx.hit_flash(s.art(), UIStyle.GOLD, 0.5)
	Fx.float_text(s, tr("Seviye %d!") % GameState.grid[slot].level, UIStyle.GOLD, 24)


func _on_card_destroyed(slot: int) -> void:
	Fx.flash(_slots[slot], Color(2.0, 2.0, 2.0), 0.4)
	Fx.float_text(_slots[slot], tr("YIKILDI"), Color.WHITE, 24)


func _on_green_created(slot: int) -> void:
	Fx.bump(_slots[slot], 1.15)
	Fx.flash(_slots[slot], Color(0.7, 1.8, 0.7), 0.6)
	_slot_text(slot, tr("Yeşil Alan!"), UIStyle.GOOD, 24)


func _on_slots_cooled(slots: Array) -> void:
	for slot in slots:
		Fx.flash(_slots[slot], Color(0.7, 1.4, 2.0), 0.5)
	_slot_text(slots[0], tr("Serinledi"), UIStyle.HIGHLIGHT)


func _on_tide(row: int) -> void:
	for c in Grid.SIZE:
		var slot := row * Grid.SIZE + c
		Fx.shake(_slots[slot], 4.0)
		Fx.flash(_slots[slot], Color(0.6, 1.0, 2.0), 0.6)
	_slot_text(row * Grid.SIZE + 1, tr("Gelgit!"), UIStyle.HIGHLIGHT, 24)


func _on_shard_placed(slot: int) -> void:
	Fx.bump(_slots[slot], 1.2)
	Fx.hit_flash(_slots[slot].art(), UIStyle.GOLD, 0.6)
	_slot_text(slot, tr("Sunağa yerleşti"), UIStyle.GOLD)


## Boss'tan çıkan parçayı sol paneldeki kalıcı Su/Toprak/Güneş yuvasına uçurur.
func _on_shard_collected(element: String) -> void:
	var target_index := GameState.SHARD_ORDER.find(element)
	if target_index < 0 or target_index >= _shard_icons.size():
		return
	var target_icon := _shard_icons[target_index]
	if not is_instance_valid(target_icon):
		return
	# Panel yenilense bile uçuş tamamlanana kadar hedef yuva soluk kalır.
	target_icon.self_modulate = Color(0.35, 0.35, 0.4, 0.75)

	var texture := load("res://assets/sprites/cards/shard_%s.png" % element) as Texture2D
	if texture == null:
		texture = UIStyle.icon("shard_" + element)
	var flying := UIStyle.tex_rect(texture, 2)
	flying.top_level = true
	flying.z_index = 40
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flying)
	var half := flying.custom_minimum_size / 2.0
	var start := _boss_panel.sprite_center() - half
	var destination := target_icon.global_position + target_icon.size / 2.0 - half
	flying.global_position = start
	flying.pivot_offset = half
	flying.scale = Vector2(0.25, 0.25)
	flying.modulate.a = 0.0

	var tween := flying.create_tween()
	tween.tween_interval(0.28)
	tween.tween_property(flying, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flying, "modulate:a", 1.0, 0.1)
	tween.tween_method(func(progress: float) -> void:
		var arc := Vector2(0.0, -sin(progress * PI) * 90.0)
		flying.global_position = start.lerp(destination, progress) + arc,
		0.0, 1.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(flying, "rotation", TAU, 0.72)
	tween.parallel().tween_property(flying, "scale", Vector2(0.65, 0.65), 0.72)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target_icon):
			target_icon.self_modulate = Color.WHITE
			Fx.bump(target_icon, 1.45)
			Fx.hit_flash(target_icon, Elements.COLORS.get(element, UIStyle.GOLD), 0.55)
		flying.queue_free())


func _add_log(text: String) -> void:
	# Yalnızca tur özeti başlığını ayır; aynı satırdaki değerler ve diğer olaylar değişmez.
	var is_turn_summary := text.begins_with("— Tur ") or text.begins_with("— End of turn ")
	var separator := text.find(":") if is_turn_summary else -1
	if separator >= 0:
		_log.push_color(UIStyle.GOLD)
		_log.add_text(text.left(separator + 1))
		_log.pop()
		_log.add_text(text.substr(separator + 1) + "\n")
	else:
		_log.add_text(text + "\n")


func _on_game_over(won: bool, reason: String) -> void:
	await get_tree().create_timer(0.8).timeout
	if won:
		_play_ending(reason)
	else:
		_show_game_over(won, reason)


## Zafer: önce Kül -> Doğa Ana sahnesi (Doğa Ana sözünü balonda söyler), sonra tebrikler sayfası.
func _play_ending(reason: String) -> void:
	_ending = EndingScene.new()
	_ending.finished.connect(func() -> void:
		_ending = null
		_show_game_over(true, reason))
	add_child(_ending)
	if _settings != null:
		_settings.move_to_front()


func _show_game_over(won: bool, reason: String) -> void:
	var stats := tr("Yenilen canavar: %d   Kalan Refah: %d   Son Sıcaklık: %.2f°C") % [
		mini(GameState.bosses_defeated, 3), GameState.welfare, GameState.temperature]
	if won:
		# Tebrikler ve skor sayfası; "Devam" deyince emeği geçenler açılır.
		_show_dialog(UIStyle.icon("seed"), tr("Tebrikler!"), "%s\n\n%s" % [tr(ENDING_TEXT), stats], tr("Devam"),
			_open_credits_from_game_over, UIStyle.WELFARE, 4)
	else:
		_show_dialog(UIStyle.icon("skull"), tr("KAYBETTİN"), "%s\n\n%s" % [reason, stats], tr("Yeniden Başla"),
			_restart, UIStyle.DANGER, 4)
	_dialog_source = _show_game_over.bind(won, reason)
	# Skor ayrı, büyük ve okunur satırda; altında rekor ya da en iyi skor.
	var record := tr("Yeni rekor!") if Score.last_was_record else tr("En iyi skor: %d") % Score.best
	_dialog_score.text = "%s\n%s" % [tr("Skor: %d") % GameState.get_score(), record]
	_dialog_score.visible = true


func _open_credits_from_game_over() -> void:
	if _credits != null:
		return
	Sfx.play("click")
	_credits = CREDITS_SCENE.instantiate() as Credits
	_credits.setup(true)
	add_child(_credits)
	_credits.move_to_front()


func _restart() -> void:
	_log.clear()
	_last_stats = Vector3(-1, -1, -1)
	Codex.reset_if_complete()  # oyun bitirildiyse büyü kitabı yeniden mühürlenir
	GameState.new_game()
	_refresh_all()
	_add_log(tr("Yeni oyun başladı."))
