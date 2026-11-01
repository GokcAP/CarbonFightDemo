class_name BossPanel
extends PanelContainer
## Üstteki boss paneli: animasyonlu pixel sprite, isim, zayıflık/direnç, HP (Kül Ana'da öfke),
## boss mekaniği göstergesi ve sıradaki saldırı. Onarım aşamasında canavar uyur (siluet).
## Kart buraya bırakılırsa Kurban vuruşu yapılır.

const IDLE_FRAME_TIME := 0.45
const SLEEP_TINT := Color(0.12, 0.12, 0.18, 0.9)
const DOGA_ANA := preload("res://assets/sprites/bosses/doga_ana.png")

var _sprite: TextureRect
var _sprite_frame: PanelContainer
var _name: Label
var _elements: HBoxContainer
var _weak: HBoxContainer
var _resist: HBoxContainer
var _hp_stack: Control
var _hp_delay: ProgressBar
var _hp_bar: ProgressBar
var _hp_label: Label
var _rage: HBoxContainer
var _mechanic: HBoxContainer
var _intent_icon: TextureRect
var _intent: Label
var _drag_card: CardData
var _frame := 0
var _dying := false
var _pending_intro := false
var _hp_tween: Tween
var _death_origin := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(540, 0)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	_sprite_frame = PanelContainer.new()
	_sprite_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	row.add_child(_sprite_frame)
	_sprite = UIStyle.tex_rect(null, 1)
	_sprite.custom_minimum_size = Vector2(64, 64) * UIStyle.PX
	_sprite_frame.add_child(_sprite)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = _left(UIStyle.label("", 24))
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_rage = UIStyle.icon_label("rage", "", 16, UIStyle.DANGER)
	_rage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_rage)
	col.add_child(name_row)

	_elements = HBoxContainer.new()
	_elements.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elements.add_theme_constant_override("separation", 6)
	_elements.add_child(_left(UIStyle.label(tr("Zayıf:"), 16, UIStyle.TEXT_DIM), false))
	_weak = UIStyle.icon_label("su")
	_elements.add_child(_weak)
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	_elements.add_child(gap)
	_elements.add_child(_left(UIStyle.label(tr("Dirençli:"), 16, UIStyle.TEXT_DIM), false))
	_resist = UIStyle.icon_label("fosil")
	_elements.add_child(_resist)
	col.add_child(_elements)

	# Gecikmeli HP barı: hasar önce açık renkte kalır, sonra erir.
	_hp_stack = Control.new()
	_hp_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_stack.custom_minimum_size.y = 20
	col.add_child(_hp_stack)
	_hp_delay = UIStyle.bar(Color("f4f4f4"), 1, 0, 20)
	_hp_delay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_stack.add_child(_hp_delay)
	_hp_bar = UIStyle.bar(UIStyle.DANGER, 1, 0, 20)
	_hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_stack.add_child(_hp_bar)
	# HP yazısı barın üstünde.
	_hp_label = UIStyle.label("", 16)
	_hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_stack.add_child(_hp_label)

	_mechanic = UIStyle.icon_label("fire", "", 16, UIStyle.HIGHLIGHT)
	col.add_child(_mechanic)

	var intent_row := HBoxContainer.new()
	intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_row.add_theme_constant_override("separation", 6)
	_intent_icon = UIStyle.tex_rect(UIStyle.icon("warn"))
	_intent_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	intent_row.add_child(_intent_icon)
	_intent = _left(UIStyle.label("", 16, UIStyle.GOLD))
	_intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intent_row.add_child(_intent)
	col.add_child(intent_row)

	var idle := Timer.new()
	idle.wait_time = IDLE_FRAME_TIME
	idle.autostart = true
	idle.timeout.connect(_next_frame)
	add_child(idle)

	GameState.boss_changed.connect(refresh)
	GameState.intent_changed.connect(refresh)
	GameState.boss_damaged.connect(_on_damaged)
	GameState.boss_healed.connect(_on_healed)
	GameState.boss_attacking.connect(_on_attacking)
	GameState.boss_defeated.connect(_on_defeated)
	GameState.boss_spawned.connect(_on_spawned)
	GameState.map_started.connect(_on_map_started)
	GameState.armor_broken.connect(func() -> void: Fx.float_text(self, tr("Zırh kırıldı!"), UIStyle.HIGHLIGHT, 24))
	GameState.boss_forced_up.connect(_on_forced_up)
	GameState.shard_placed.connect(func(_s: int) -> void: Fx.hit_flash(_sprite, UIStyle.WELFARE, 0.5))
	refresh()


func _left(label: Label, wrap := true) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_drag_card = UIStyle.dragged_card(get_viewport())
	elif what == NOTIFICATION_DRAG_END:
		_drag_card = null
	else:
		return
	if is_node_ready():
		refresh()


func _awake() -> bool:
	return GameState.stage == GameState.Stage.BOSS


func _is_ash() -> bool:
	return GameState.boss.mechanic == BossData.Mechanic.ASH_MOTHER


func refresh() -> void:
	var boss := GameState.boss
	if boss == null:
		return
	var cfg := GameState.config
	var awake := _awake()
	if not _dying:
		_apply_frame()
		_sprite.self_modulate = Color.WHITE if awake else SLEEP_TINT

	_name.text = tr(boss.display_name) if awake else tr("%s (uyuyor)") % tr(boss.display_name)
	_name.add_theme_color_override("font_color", boss.color.lightened(0.35) if awake else UIStyle.TEXT_DIM)
	_elements.visible = not _is_ash()
	_set_element(_weak, boss.weakness, " ×%s" % cfg.weakness_multiplier, UIStyle.GOOD)
	_set_element(_resist, boss.resistance, " ×%s" % cfg.resistance_multiplier, UIStyle.BAD)

	_hp_stack.visible = awake
	_rage.visible = awake and not _is_ash()
	if _is_ash():
		# Kül Ana: HP yerine öfke barı.
		_hp_bar.max_value = cfg.ash_rage_max
		_hp_delay.max_value = cfg.ash_rage_max
		_hp_bar.value = GameState.ash_rage
		_hp_delay.value = GameState.ash_rage
		_hp_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.BURN, 20))
		_hp_label.text = tr("Öfke %d / %d") % [GameState.ash_rage, cfg.ash_rage_max]
	else:
		_hp_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.DANGER, 20))
		_update_hp(boss)
		_hp_label.text = tr("HP %d / %d") % [GameState.boss_hp, boss.max_hp]
	(_rage.get_child(1) as Label).text = tr("Öfke +%d") % GameState.boss_rage
	_update_mechanic(boss)
	tooltip_text = "%s\n\n%s: %s" % [tr(boss.description), tr(boss.mechanic_name), tr(boss.mechanic_text)]

	_intent_icon.texture = UIStyle.icon("warn")
	_intent.add_theme_color_override("font_color", UIStyle.GOLD)
	if not awake:
		_intent_icon.texture = UIStyle.icon("quest")
		_intent.text = GameState.quest_label()
	elif GameState.intent_attack != null:
		_intent.text = tr("Sıradaki: %s - %s") % [
			tr(GameState.intent_attack.attack_name), GameState.intent_attack.get_effect_text(GameState.rage_bonus())]
	else:
		_intent.text = ""

	var border := boss.color if awake else UIStyle.PANEL_BORDER
	var width := 2
	if _drag_card != null and GameState.can_sacrifice(_drag_card):
		border = UIStyle.DANGER
		width = 4
		_intent_icon.texture = UIStyle.icon("skull")
		if _is_ash():
			_intent.text = tr("Vurma! Kül öfkelenir (öfke +%d)") % cfg.ash_rage_sacrifice
		else:
			_intent.text = tr("Kurban vuruşu: ~%d hasar (kart yok olur)") % GameState.sacrifice_damage(_drag_card)
		_intent.add_theme_color_override("font_color", UIStyle.DANGER)
	add_theme_stylebox_override("panel", UIStyle.box(Color(boss.color.darkened(0.78), 0.92), border, width))


func _update_hp(boss: BossData) -> void:
	_hp_bar.max_value = boss.max_hp
	_hp_delay.max_value = boss.max_hp
	var old_hp := _hp_bar.value
	_hp_bar.value = GameState.boss_hp
	if _hp_tween != null:
		_hp_tween.kill()
	if GameState.boss_hp >= old_hp or GameState.boss_hp >= _hp_delay.value:
		_hp_delay.value = GameState.boss_hp
	else:
		_hp_tween = create_tween()
		_hp_tween.tween_interval(0.35)
		_hp_tween.tween_property(_hp_delay, "value", float(GameState.boss_hp), 0.45).set_ease(Tween.EASE_IN)


## Boss'a özel mekanik satırı.
func _update_mechanic(boss: BossData) -> void:
	var icon_name := "fire"
	var text := ""
	var color := UIStyle.HIGHLIGHT
	var cfg := GameState.config
	if not _awake():
		icon_name = "rage"
		text = tr("Mekanik: %s") % tr(boss.mechanic_name)
		color = UIStyle.TEXT_DIM
	else:
		match boss.mechanic:
			BossData.Mechanic.FLAME_ARMOR:
				if GameState.flame_layers > 0:
					text = tr("Alev Zırhı %d/%d - yalnızca Su kırar") % [GameState.flame_layers, cfg.flame_armor_layers]
					color = UIStyle.BURN
				else:
					text = tr("Alev zırhı yok - tam hasar!")
			BossData.Mechanic.DIVE:
				icon_name = "bubble"
				if GameState.exposed_turns > 0:
					text = tr("Yüzeye zorlandı: ×%s hasar!") % cfg.dive_exposed_multiplier
					color = UIStyle.GOLD
				elif GameState.diving:
					text = tr("Dalışta! %d. sütuna kart koy") % (GameState.dive_column + 1)
				else:
					text = tr("Yüzeyde - sonraki tur dalar")
					color = UIStyle.TEXT_DIM
			BossData.Mechanic.HEAT_ABSORB:
				icon_name = "temp"
				if GameState.vulnerable_turns > 0:
					text = tr("Savunmasız %d tur: ×%s hasar!") % [GameState.vulnerable_turns, cfg.golem_vulnerable_multiplier]
					color = UIStyle.GOLD
				else:
					text = tr("Isı Zırhı %d (sıcak slot) - ×%s hasar") % [GameState.heat_armor(), cfg.heat_armor_multiplier]
					color = UIStyle.BURN
			BossData.Mechanic.ASH_MOTHER:
				icon_name = "seed"
				text = tr("Sunaktaki parça: %d/3 - vurma, sakinleştir") % GameState.shards_on_altars()
				color = UIStyle.GOOD
	_mechanic.visible = text != ""
	(_mechanic.get_child(0) as TextureRect).texture = UIStyle.icon(icon_name)
	var l := _mechanic.get_child(1) as Label
	l.text = text
	l.add_theme_color_override("font_color", color)


func _set_element(row: HBoxContainer, element: String, suffix: String, color: Color) -> void:
	(row.get_child(0) as TextureRect).texture = Elements.icon(element)
	var l := row.get_child(1) as Label
	l.text = Elements.plain(element) + suffix
	l.add_theme_color_override("font_color", color)


## Boss sprite'ının ekran merkezi (mermi efektleri için).
func sprite_center() -> Vector2:
	return _sprite.global_position + _sprite.size / 2


# --- Animasyon ------------------------------------------------------------------

func _next_frame() -> void:
	_frame = 1 - _frame
	if not _dying:
		_apply_frame()


func _apply_frame() -> void:
	var boss := GameState.boss
	if boss == null:
		return
	var tex: Texture2D = boss.icon_alt if _frame == 1 and boss.icon_alt != null else boss.icon
	_sprite.texture = tex


func _on_damaged(amount: int) -> void:
	Fx.hit_flash(_sprite)
	Fx.shake(_sprite_frame, 6.0)
	if amount <= 0:
		var why := tr("DALIŞTA") if GameState.diving else tr("BLOK")
		Fx.float_text(self, why, UIStyle.TEXT_DIM, 24)
	else:
		Fx.float_text(self, "-%d" % amount, UIStyle.DANGER, 32)


func _on_healed(amount: int) -> void:
	Fx.hit_flash(_sprite, UIStyle.WELFARE, 0.4)
	Fx.float_text(self, tr("+%d HP") % amount, UIStyle.WELFARE, 24)


func _on_attacking() -> void:
	Fx.lunge(_sprite)
	Fx.hit_flash(_sprite, UIStyle.DANGER, 0.3)


func _on_forced_up() -> void:
	Fx.pop_in(_sprite, 0.3)
	Fx.float_text(self, tr("Yüzeye çıktı!"), UIStyle.GOLD, 24)


func _on_defeated() -> void:
	if _dying:
		return
	_dying = true
	_death_origin = _sprite.position
	_sprite.pivot_offset = _sprite.size / 2
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color.WHITE
	match String(GameState.boss.id):
		"termik_ejderha":
			_death_dragon()
		"plastik_leviathan":
			_death_leviathan()
		"isi_adasi_golemi":
			_death_golem()
		"kul_ana":
			_transform_ash_mother()
		_:
			_death_fallback()


## Termik Ejderha: son bir alev parlamasıyla dönerek küle ayrılır.
func _death_dragon() -> void:
	Fx.hit_flash(_sprite, UIStyle.BURN, 0.45)
	Fx.shake(_sprite_frame, 9.0, 8)
	_spawn_death_pixels(UIStyle.BURN, 12, 54.0)
	var tween := _sprite.create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "rotation", 0.32, 0.16)
	tween.parallel().tween_property(_sprite, "modulate", Color(UIStyle.BURN, 0.75), 0.16)
	tween.tween_property(_sprite, "scale", Vector2(0.15, 0.15), 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "rotation", -0.7, 0.48)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_after_death)


## Plastik Leviathan: dalgalanıp panelin altına batar.
func _death_leviathan() -> void:
	Fx.hit_flash(_sprite, UIStyle.HIGHLIGHT, 0.4)
	_spawn_death_pixels(Color("41a6f6"), 10, 44.0)
	var tween := _sprite.create_tween()
	for angle in [0.14, -0.14, 0.1, -0.08]:
		tween.tween_property(_sprite, "rotation", angle, 0.09)
	tween.tween_property(_sprite, "position:y", _death_origin.y + 46.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "scale", Vector2(0.72, 1.18), 0.48)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.42).set_delay(0.08)
	tween.tween_callback(_after_death)


## Isı Adası Golemi: sarsılıp taş parçaları saçarak kendi ağırlığıyla çöker.
func _death_golem() -> void:
	Fx.hit_flash(_sprite, Color.WHITE, 0.35)
	Fx.shake(_sprite_frame, 12.0, 11)
	_spawn_death_pixels(Color("94b0c2"), 14, 58.0)
	var tween := _sprite.create_tween()
	tween.tween_interval(0.22)
	tween.tween_property(_sprite, "scale", Vector2(1.28, 0.28), 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "position:y", _death_origin.y + 30.0, 0.42)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.24)
	tween.tween_callback(_after_death)


## Final boss ölmez: kül kabuğu söner ve Doğa Ana görünür.
func _transform_ash_mother() -> void:
	Fx.hit_flash(_sprite, UIStyle.WELFARE, 0.7)
	_spawn_death_pixels(UIStyle.WELFARE, 16, 64.0)
	var tween := _sprite.create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.35, 1.35), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.28)
	tween.tween_callback(func() -> void:
		_sprite.texture = DOGA_ANA
		_sprite.scale = Vector2(0.2, 0.2)
		_sprite.rotation = 0.0
		_sprite.modulate = Color(UIStyle.WELFARE, 0.0))
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.35)
	tween.tween_callback(_after_death)


func _death_fallback() -> void:
	Fx.hit_flash(_sprite, Color.WHITE, 0.5)
	var tween := _sprite.create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.35, 0.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_after_death)


## Yeni sprite gerektirmeyen, nearest-filter görünümüne uygun küçük kare parçacıklar.
func _spawn_death_pixels(color: Color, count: int, spread: float) -> void:
	var center := _sprite.position + _sprite.size / 2
	for i in count:
		var pixel := ColorRect.new()
		pixel.color = color.lightened(randf_range(0.0, 0.25))
		pixel.custom_minimum_size = Vector2(6, 6)
		pixel.size = Vector2(6, 6)
		pixel.position = center - pixel.size / 2
		pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sprite_frame.add_child(pixel)
		var direction := Vector2.from_angle(TAU * float(i) / float(count) + randf_range(-0.25, 0.25))
		var target := pixel.position + direction * randf_range(spread * 0.55, spread)
		var particle_tween := pixel.create_tween().set_parallel()
		particle_tween.tween_property(pixel, "position", target.round(), randf_range(0.42, 0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(pixel, "modulate:a", 0.0, 0.28).set_delay(0.3)
		particle_tween.chain().tween_callback(pixel.queue_free)


func _after_death() -> void:
	_dying = false
	_sprite.position = _death_origin
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0
	_sprite.modulate = Color.WHITE
	# Finalde dönüşmüş Doğa Ana, Credits açılana kadar ekranda kalır.
	if GameState.is_over() and GameState.won and _is_ash():
		_sprite.visible = true
	else:
		# Ölen boss ödül ekranında yeniden çizilmesin; yeni harita başlayınca geri açılır.
		_sprite.visible = false
	if _pending_intro:
		_pending_intro = false
		_intro()


func _on_map_started() -> void:
	_dying = false
	_pending_intro = false
	_sprite.visible = true
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0
	_sprite.modulate = Color.WHITE
	refresh()


func _on_spawned() -> void:
	if _dying:
		_pending_intro = true
	else:
		_intro()


## Canavar uyanır / ortaya çıkar.
func _intro() -> void:
	if GameState.is_over():
		return
	_sprite.visible = true
	_sprite.modulate.a = 1.0
	refresh()
	Fx.pop_in(_sprite)
	Fx.float_text(self, tr("%s uyandı!") % tr(GameState.boss.display_name), GameState.boss.color.lightened(0.3), 32)
	Sfx.play("spawn")


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "card"):
		return false
	var hand_index: int = data["hand_index"]
	return hand_index >= 0 and hand_index < GameState.hand.size() and GameState.can_sacrifice(GameState.hand[hand_index])


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.sacrifice_card(data["hand_index"])
