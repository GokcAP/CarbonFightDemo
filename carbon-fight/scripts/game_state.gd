extends Node
## Autoload (GameState): statlar, faz, harita/aşama, grid ve karo durumları, el/deste ve boss.
## Hikaye: Denge Tohumu üç parçaya bölündü; her harita onarılır, canavar yenilir, parça alınır,
## finalde parçalar sunaklara konup Kül Ana sakinleştirilir.
## Tur sırası TurnManager'da; burası durumu, kuralları ve oyuncu eylemlerini tutar.

signal stats_changed
signal grid_changed
signal hand_changed
signal boss_changed
signal intent_changed
signal phase_changed
signal log_message(text: String)
signal game_over(won: bool, reason: String)
# Harita / hikaye akışı
signal map_started
signal map_completed
signal quest_changed
# Görsel geri bildirim (animasyon/ses buraya bağlanır)
signal card_attacked(slot: int, damage: int)
signal boss_damaged(amount: int)
signal boss_healed(amount: int)
signal slot_hit(slot: int, damage: int)
signal card_merged(slot: int)
signal card_destroyed(slot: int)
signal card_placed(slot: int)
signal card_sacrificed(damage: int)
## Oyuncu kart oynadı, boss'a kurban etti veya çöpe attı; Main mevcut tur çözümünü otomatik başlatır.
signal turn_action_committed
signal boss_attacking
signal boss_defeated
signal boss_spawned
## Boss ödülünden kazanılan kalıcı Su/Toprak/Güneş parçasının arayüz animasyonu.
signal shard_collected(element: String)
signal chimney_cleared(slot: int)
signal trash_cleared(slot: int)
signal tide_flooded(row: int)
signal green_created(slot: int)
signal slots_cooled(slots: Array)
signal armor_broken
signal boss_forced_up
signal shard_placed(slot: int)
signal shard_lost(slot: int)

enum Phase { PLAYER, RESOLVE, GAME_OVER, STORY }
enum Stage { REPAIR, BOSS }

const SHARD_ORDER: Array[String] = ["su", "toprak", "gunes"]
const SHARD_NAMES := {"su": "Su Parçası", "toprak": "Toprak Parçası", "gunes": "Güneş Parçası"}

var config: BalanceConfig = preload("res://data/balance.tres")

var phase := Phase.PLAYER
var carbon: int
var temperature: float
var welfare: int
var turn: int

# --- Harita ---
var map_index := 0
var map: MapData
var stage := Stage.REPAIR
## Kazanılan tohum parçaları (kalıcı pasifler).
var shards: Array[String] = []

## Grid.SLOT_COUNT uzunluğunda; boş slot = null.
var grid: Array[CardInstance] = []
## Slot başına kalan kilit / yanma turu; 0 = yok.
var locked_turns := PackedInt32Array()
var burn_turns := PackedInt32Array()
# Karo durumları (slot başına; 0 = yok)
var smoke := PackedInt32Array()
var trash := PackedInt32Array()
var asphalt := PackedInt32Array()
var green := PackedInt32Array()
var green_progress := PackedInt32Array()
var hot := PackedInt32Array()
## Sunak slotlarının elementi ("" = sunak değil).
var altar_element: Array[String] = []

var hand: Array[CardData] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var played_this_turn := false

# --- Görev ---
var trash_cleaned := 0
var tide_row := 0
var map_turn := 0

# --- Boss ---
var boss: BossData
var boss_hp := 0
var boss_rage := 0
var bosses_defeated := 0
## Boss'un ilan ettiği sıradaki saldırı ve hedef slotları.
var intent_attack: BossAttack
var intent_slots: Array[int] = []
var flame_layers := 0
var diving := false
var dive_column := -1
var exposed_turns := 0
var vulnerable_turns := 0
var ash_rage := 0
var seed_given := false
## Kül Ana'yı daha önce sakinleştirmiş parçalar: düşüp geri konan parça öfkeyi yeniden azaltmaz
## (yoksa düş-geri koy döngüsüyle öfke hiç dolmuyor, final bitmiyordu).
var calmed_shards: Array[String] = []
var won := false


func _empty_ints() -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(Grid.SLOT_COUNT)
	a.fill(0)
	return a


# --- Oyun ve harita akışı ------------------------------------------------------

func new_game() -> void:
	phase = Phase.PLAYER
	carbon = config.start_carbon
	temperature = config.start_temperature
	welfare = config.start_welfare
	turn = 1
	bosses_defeated = 0
	shards.clear()
	won = false
	start_map(0)


## Haritayı kurar: karo durumları, kirli bacalar, asfalt, sunaklar, yeni deste.
func start_map(index: int) -> void:
	map_index = index
	map = config.maps[index]
	stage = Stage.REPAIR
	boss = map.boss
	boss_hp = boss.max_hp
	boss_rage = 0
	intent_attack = null
	intent_slots.clear()
	flame_layers = 0
	diving = false
	dive_column = -1
	exposed_turns = 0
	vulnerable_turns = 0
	seed_given = false
	calmed_shards.clear()
	trash_cleaned = 0
	tide_row = 0
	map_turn = 0

	grid.clear()
	grid.resize(Grid.SLOT_COUNT)
	locked_turns = _empty_ints()
	burn_turns = _empty_ints()
	smoke = _empty_ints()
	trash = _empty_ints()
	asphalt = _empty_ints()
	green = _empty_ints()
	green_progress = _empty_ints()
	hot = _empty_ints()
	altar_element.clear()
	altar_element.resize(Grid.SLOT_COUNT)
	altar_element.fill("")

	for slot in map.chimney_slots:
		var chimney := CardInstance.new(config.chimney_card)
		chimney.dirty = true
		grid[slot] = chimney
	for slot in map.asphalt_slots:
		asphalt[slot] = 1
	for slot in map.start_trash_slots:
		trash[slot] = 1
	for i in mini(map.altar_slots.size(), SHARD_ORDER.size()):
		altar_element[map.altar_slots[i]] = SHARD_ORDER[i]

	hand.clear()
	discard_pile.clear()
	draw_pile.clear()
	for card in config.cards:
		for i in config.deck_copies:
			draw_pile.append(card)
	draw_pile.shuffle()

	log_message.emit("— %s —" % tr(map.display_name))
	if map.quest == MapData.Quest.ALTARS:
		# Final: parçalar ele gelir, Kül Ana hemen karşında.
		hand.assign(config.shard_cards)
		ash_rage = config.ash_rage_start
		_wake_boss()
	else:
		ash_rage = 0
	_roll_smoke()

	map_started.emit()
	stats_changed.emit()
	grid_changed.emit()
	boss_changed.emit()
	quest_changed.emit()
	start_turn()


func start_turn() -> void:
	played_this_turn = false
	while hand.size() < config.hand_size:
		var card := _draw_card()
		if card == null:
			break
		hand.append(card)
	hand_changed.emit()
	set_phase(Phase.PLAYER)


func set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit()


func is_over() -> bool:
	return phase == Phase.GAME_OVER


func is_final() -> bool:
	return map != null and map.quest == MapData.Quest.ALTARS


func is_last_map() -> bool:
	return map_index + 1 >= config.maps.size()


func finish(victory: bool, reason: String) -> void:
	won = victory
	set_phase(Phase.GAME_OVER)
	intent_slots.clear()
	intent_changed.emit()
	game_over.emit(victory, reason)


# --- Oyuncu eylemleri -------------------------------------------------------

func can_play_card() -> bool:
	return phase == Phase.PLAYER and not played_this_turn


## Bu kart bu slota konabilir mi? (kilit, çöp, sunak ve tohum kuralları)
func can_play_on(card: CardData, slot: int) -> bool:
	if card == null or not can_play_card():
		return false
	if locked_turns[slot] > 0 or trash[slot] > 0:
		return false
	match card.kind:
		CardData.Kind.SHARD:
			return altar_element[slot] == card.element and not has_shard(slot)
		CardData.Kind.SEED:
			return slot == map.seed_slot and shards_on_altars() >= SHARD_ORDER.size()
	# Normal kart: sunaklar parçalara ayrılmıştır.
	return altar_element[slot] == ""


func is_merge(card: CardData, slot: int) -> bool:
	var current := grid[slot]
	return card.kind == CardData.Kind.NORMAL and current != null and not current.dirty \
		and current.data.id == card.id


## Boş slota yerleştir, aynı kartla birleştir veya farklı kartın yerine koy.
func play_card(hand_index: int, slot: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index]
	if not can_play_on(card, slot):
		return false
	hand.remove_at(hand_index)
	played_this_turn = true

	var current := grid[slot]
	if is_merge(card, slot):
		current.merge(config.max_level)
		discard_pile.append(card)
		log_message.emit(tr("⭐ %s birleşti → Seviye %d") % [tr(card.display_name), current.level])
		card_merged.emit(slot)
		_on_card_entered(slot, card)  # birleşme de çöp dönüştürür, serinletir, dalışı bozar
	else:
		if current != null:
			if current.dirty:
				log_message.emit(tr("🏭 Kirli baca söndürüldü!"))
				chimney_cleared.emit(slot)
			else:
				discard_pile.append(current.data)
				log_message.emit(tr("%s kaldırıldı.") % tr(current.data.display_name))
		grid[slot] = CardInstance.new(card)
		green_progress[slot] = 0
		log_message.emit(tr("%s → Slot %d") % [tr(card.display_name), slot + 1])
		card_placed.emit(slot)
		_on_card_entered(slot, card)
	hand_changed.emit()
	grid_changed.emit()
	if card.kind == CardData.Kind.SEED:
		_win_with_seed()
		turn_action_committed.emit()
		return true
	_check_quest()
	turn_action_committed.emit()
	return true


## Kart yeni yerleşince harita ve boss tepkileri.
func _on_card_entered(slot: int, card: CardData) -> void:
	if card.kind == CardData.Kind.SHARD:
		_on_shard_placed(slot)
		return
	# Solgun Körfez: Toprak kartı komşu çöpleri geri dönüştürür.
	if card.element == "toprak":
		for n in Grid.neighbors(slot):
			if trash[n] > 0:
				trash[n] = 0
				trash_cleaned += 1
				trash_cleared.emit(n)
				log_message.emit(tr("♻ Çöp geri dönüştürüldü (%d/%d)") % [mini(trash_cleaned, map.trash_goal), map.trash_goal])
	if stage != Stage.BOSS:
		return
	match boss.mechanic:
		BossData.Mechanic.HEAT_ABSORB:
			# Yeşil Alan'a konan kart kendisini ve komşularını, Toprak kartı kendi slotunu serinletir.
			var targets: Array[int] = []
			if green[slot] > 0:
				targets.append(slot)
				targets.append_array(Grid.neighbors(slot))
			elif card.element == "toprak":
				targets.append(slot)
			var cooled := []
			for s in targets:
				if hot[s] > 0:
					hot[s] = 0
					cooled.append(s)
			if not cooled.is_empty():
				log_message.emit(tr("❄ %d slot serinledi. Golemin ısı zırhı: %d") % [cooled.size(), heat_armor()])
				slots_cooled.emit(cooled)
				_update_heat_armor()
		BossData.Mechanic.DIVE:
			if diving and Grid.column_of(slot) == dive_column:
				diving = false
				exposed_turns = 1
				log_message.emit(tr("🫧 Leviathan yüzeye zorlandı! Bu tur ×%s hasar alır.") % config.dive_exposed_multiplier)
				boss_forced_up.emit()
	boss_changed.emit()


## Kurban vuruşu mümkün mü? (Yalnızca uyanık boss'a ve normal kartla.)
func can_sacrifice(card: CardData) -> bool:
	return card != null and can_play_card() and stage == Stage.BOSS and card.kind == CardData.Kind.NORMAL


## Normal kart çöpe atılabilir. Hikâye kartlarını engellemek finalin kilitlenmesini önler.
func can_discard_card(hand_index: int) -> bool:
	return hand_index >= 0 and hand_index < hand.size() and can_play_card() \
		and hand[hand_index].kind == CardData.Kind.NORMAL


## Kartı ıskartaya gönderir; yeni kart mevcut start_turn() dolumunda karıştırılmış desteden gelir.
func discard_card(hand_index: int) -> bool:
	if not can_discard_card(hand_index):
		return false
	var card := hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	played_this_turn = true
	log_message.emit(tr("🗑 %s ıskartaya atıldı.") % tr(card.display_name))
	hand_changed.emit()
	turn_action_committed.emit()
	return true


## Kurban vuruşu: kart boss'a AP × sacrifice_multiplier (× element) vurur ve yok olur.
## Kül Ana'ya vurmak ise onu öfkelendirir.
func sacrifice_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size() or not can_sacrifice(hand[hand_index]):
		return false
	var card := hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	played_this_turn = true
	hand_changed.emit()
	if boss.mechanic == BossData.Mechanic.ASH_MOTHER:
		change_ash_rage(config.ash_rage_sacrifice)
		log_message.emit(tr("🔥 Kül'e vurmak onu öfkelendirdi! Öfke %+d") % config.ash_rage_sacrifice)
		card_sacrificed.emit(0)
		check_ash_rage()
		turn_action_committed.emit()
		return true
	var dealt := hit_boss(_sacrifice_raw(card), card.element)
	log_message.emit(tr("💥 Kurban vuruşu: %s → %d") % [tr(card.display_name), dealt])
	card_sacrificed.emit(dealt)
	if boss_hp <= 0:
		defeat_boss()
	turn_action_committed.emit()
	return true


## Kurban vuruşunun boss'a gerçekten vereceği hasar (alev zırhı, dalış, ısı zırhı dahil).
func sacrifice_damage(card: CardData) -> int:
	if boss.mechanic == BossData.Mechanic.ASH_MOTHER:
		return 0
	return roundi(_sacrifice_raw(card) * mechanic_multiplier(card.element))


## Mekanikten önceki kurban hasarı: AP (parça bonusu dahil) × kurban çarpanı × element.
func _sacrifice_raw(card: CardData) -> int:
	var ap := card.ap
	if card.element == "gunes" and "gunes" in shards:
		ap += config.gunes_shard_ap
	return roundi(ap * config.sacrifice_multiplier * element_multiplier(card.element))


# --- Savaş -------------------------------------------------------------------

func element_multiplier(element: String) -> float:
	if element == boss.weakness:
		return config.weakness_multiplier
	if element == boss.resistance:
		return config.resistance_multiplier
	return 1.0


## Aynı elementten aktif dik komşu başına +synergy_bonus.
func synergy_multiplier(slot: int) -> float:
	var count := 0
	for n in Grid.neighbors(slot):
		if can_attack(n) and grid[n].data.element == grid[slot].data.element:
			count += 1
	return 1.0 + count * config.synergy_bonus


## Parça pasifleri dahil AP.
func card_ap(slot: int) -> int:
	var card := grid[slot]
	if card == null:
		return 0
	var ap := card.ap()
	if card.data.element == "gunes" and "gunes" in shards:
		ap += config.gunes_shard_ap
	return ap


## Su Parçası: tüm kartlara ek zırh.
func armor_bonus() -> int:
	return config.su_shard_armor if "su" in shards else 0


func card_damage(slot: int) -> int:
	var card := grid[slot]
	var damage := card_ap(slot) * synergy_multiplier(slot) * element_multiplier(card.data.element)
	if smoke[slot] > 0:
		damage *= config.smoke_ap_multiplier
	return roundi(damage)


## Sinerji çizgileri için: aynı elementten aktif komşu çiftleri [[a, b], ...].
func synergy_pairs() -> Array:
	var result := []
	for i in Grid.SLOT_COUNT:
		if not can_attack(i):
			continue
		for j in Grid.neighbors(i):
			if j > i and can_attack(j) and grid[i].data.element == grid[j].data.element:
				result.append([i, j])
	return result


## Boss mekaniğinin bu element için hasar çarpanı (Su alev zırhı katmanı kırar, hasar vermez).
func mechanic_multiplier(element: String) -> float:
	match boss.mechanic:
		BossData.Mechanic.FLAME_ARMOR:
			if flame_layers > 0:
				return 0.0 if element == "su" else config.flame_armor_multiplier
		BossData.Mechanic.DIVE:
			if diving:
				return 0.0
			if exposed_turns > 0:
				return config.dive_exposed_multiplier
		BossData.Mechanic.HEAT_ABSORB:
			if vulnerable_turns > 0:
				return config.golem_vulnerable_multiplier
			if heat_armor() > 0:
				return config.heat_armor_multiplier
	return 1.0


## Boss'a hasar uygular; boss mekaniğine göre değiştirir. Gerçek hasarı döndürür.
func hit_boss(raw: int, element: String) -> int:
	if boss.mechanic == BossData.Mechanic.FLAME_ARMOR and flame_layers > 0 and element == "su":
		flame_layers -= 1
		log_message.emit(tr("💧 Alev zırhı kırıldı! Kalan katman: %d") % flame_layers)
		armor_broken.emit()
		boss_changed.emit()
		return 0
	var dealt := roundi(raw * mechanic_multiplier(element))
	damage_boss(dealt)
	return dealt


func damage_boss(amount: int) -> void:
	boss_hp = maxi(0, boss_hp - amount)
	boss_damaged.emit(amount)
	boss_changed.emit()


## Boss'u iyileştirir (en fazla tam cana); gerçekte iyileşen miktarı döndürür.
func heal_boss(amount: int) -> int:
	var healed := mini(amount, boss.max_hp - boss_hp)
	if healed <= 0:
		return 0
	boss_hp += healed
	boss_healed.emit(healed)
	boss_changed.emit()
	return healed


## Boss öldü: ödül ver, parçayı al. Sonraki harita ödül ekranından start_map ile başlar.
func defeat_boss() -> void:
	bosses_defeated += 1
	boss_defeated.emit()
	change_stats(config.boss_reward_carbon, config.boss_reward_welfare, config.map_reward_temp)
	log_message.emit(tr("🏆 %s yenildi! Karbon %+d, Refah %+d") % [
		tr(boss.display_name), config.boss_reward_carbon, config.boss_reward_welfare])
	if map.reward_shard != "" and not map.reward_shard in shards:
		shards.append(map.reward_shard)
		log_message.emit(tr("✨ %s alındı: %s") % [shard_name(map.reward_shard), tr(map.reward_text)])
		shard_collected.emit(map.reward_shard)
	intent_attack = null
	intent_slots.clear()
	intent_changed.emit()
	set_phase(Phase.STORY)
	map_completed.emit()


## Onarım bitti (ya da final başladı): canavar uyanır.
func _wake_boss() -> void:
	stage = Stage.BOSS
	boss = map.boss
	boss_hp = boss.max_hp
	boss_rage = 0
	match boss.mechanic:
		BossData.Mechanic.FLAME_ARMOR:
			flame_layers = config.flame_armor_layers
		BossData.Mechanic.HEAT_ABSORB:
			for i in Grid.SLOT_COUNT:
				hot[i] = 0 if green[i] > 0 else 1
	log_message.emit(tr("%s %s ortaya çıktı!") % [boss.emoji, tr(boss.display_name)])
	if tr(boss.mechanic_text) != "":
		log_message.emit("%s: %s" % [tr(boss.mechanic_name), tr(boss.mechanic_text)])
	boss_changed.emit()
	boss_spawned.emit()
	grid_changed.emit()
	choose_intent()


## Sıradaki saldırıyı seç ve hedefleri ilan et. Kül Ana parçalı sunakları, diğerleri dolu slotları hedefler.
func choose_intent() -> void:
	if stage != Stage.BOSS or boss.attacks.is_empty():
		intent_attack = null
		intent_slots.clear()
		intent_changed.emit()
		return
	intent_attack = boss.attacks.pick_random()
	var preferred: Array[int] = []
	if boss.mechanic == BossData.Mechanic.ASH_MOTHER:
		# Kül Ana hep sunaklara nişan alır: parçası olanlara, hiç yoksa boş sunaklara.
		for i in Grid.SLOT_COUNT:
			if has_shard(i):
				preferred.append(i)
		if preferred.is_empty():
			for i in Grid.SLOT_COUNT:
				if altar_element[i] != "":
					preferred.append(i)
	if preferred.is_empty():
		for i in Grid.SLOT_COUNT:
			if grid[i] != null:
				preferred.append(i)
	var anchor: int = preferred.pick_random() if not preferred.is_empty() else randi_range(0, Grid.SLOT_COUNT - 1)
	intent_slots = Grid.pattern_slots(intent_attack.pattern, anchor)
	intent_changed.emit()


## Saldırı hasarına eklenen öfke (Kül Ana'da öfke barından gelir).
func rage_bonus() -> int:
	if boss.mechanic == BossData.Mechanic.ASH_MOTHER:
		return ash_rage / maxi(1, config.ash_rage_damage_divisor)
	return boss_rage


func intent_damage() -> int:
	return intent_attack.damage + rage_bonus() if intent_attack != null else 0


## Sıradaki saldırı bu slota gerçekte ne kadar vurur: karta zırh (Su Parçası dahil) düşülmüş,
## sunaktaki parçaya koruyucu kartlar düşülmüş, boş slotta Refah kaybı olarak.
func expected_hit(slot: int) -> int:
	var damage := intent_damage()
	var card := grid[slot]
	if card == null:
		return damage
	match card.data.kind:
		CardData.Kind.SHARD:
			return maxi(0, damage - config.ash_guard_per_card * altar_guards(slot))
		CardData.Kind.NORMAL:
			return maxi(0, damage - card.data.armor - armor_bonus())
	return 0


## Boss mekaniklerinin tur sonu güncellemesi (TurnManager, niyet seçiminden önce çağırır).
func tick_boss_mechanics() -> void:
	if stage != Stage.BOSS:
		return
	match boss.mechanic:
		BossData.Mechanic.DIVE:
			if exposed_turns > 0:
				exposed_turns -= 1
			elif diving:
				diving = false
				log_message.emit(tr("🌊 Leviathan yüzeye çıktı."))
			else:
				diving = true
				dive_column = randi_range(0, Grid.SIZE - 1)
				log_message.emit(tr("🫧 Leviathan daldı! Baloncuklar %d. sütunda.") % (dive_column + 1))
		BossData.Mechanic.HEAT_ABSORB:
			if vulnerable_turns > 0:
				vulnerable_turns -= 1
				if vulnerable_turns == 0:
					_reheat(config.golem_reheat_slots)
		BossData.Mechanic.ASH_MOTHER:
			change_ash_rage(config.ash_rage_per_turn)
			check_ash_rage()
	boss_changed.emit()
	grid_changed.emit()


## Golem: yeşil olmayan rastgele slotları yeniden ısıtır.
func _reheat(count: int) -> void:
	var candidates: Array[int] = []
	for i in Grid.SLOT_COUNT:
		if green[i] == 0 and hot[i] == 0:
			candidates.append(i)
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		hot[candidates[i]] = 1
	log_message.emit(tr("🔥 Golem ısıyı geri emdi! Isı zırhı: %d") % heat_armor())


func heat_armor() -> int:
	var count := 0
	for v in hot:
		count += v
	return count


func _update_heat_armor() -> void:
	if boss.mechanic == BossData.Mechanic.HEAT_ABSORB and heat_armor() == 0 and vulnerable_turns == 0:
		vulnerable_turns = config.golem_vulnerable_turns
		log_message.emit(tr("💥 Golemin zırhı çatladı! %d tur savunmasız (×%s hasar).") % [
			vulnerable_turns, config.golem_vulnerable_multiplier])
		armor_broken.emit()
		boss_changed.emit()


## Boss saldırısı ya da yanma: karta hasar (Su Parçası zırhı dahil). Ölürse yok eder.
func damage_card(slot: int, amount: int, ignore_armor := false) -> int:
	var card := grid[slot]
	if card == null:
		return 0
	var dealt := card.take_damage(amount, ignore_armor, armor_bonus())
	slot_hit.emit(slot, dealt)
	if card.is_dead():
		destroy_card(slot)
	return dealt


func destroy_card(slot: int) -> void:
	var card := grid[slot]
	if card == null:
		return
	grid[slot] = null
	green_progress[slot] = 0
	if not card.dirty:
		discard_pile.append(card.data)
	log_message.emit(tr("💀 %s yok oldu.") % tr(card.data.display_name))
	card_destroyed.emit(slot)
	grid_changed.emit()
	_check_quest()


# --- Final: sunaklar ve tohum ------------------------------------------------

func has_shard(slot: int) -> bool:
	return grid[slot] != null and grid[slot].data.kind == CardData.Kind.SHARD


func shards_on_altars() -> int:
	var count := 0
	for i in Grid.SLOT_COUNT:
		if altar_element[i] != "" and has_shard(i):
			count += 1
	return count


## Sunağın dik komşularındaki koruyucu kart sayısı.
func altar_guards(slot: int) -> int:
	var count := 0
	for n in Grid.neighbors(slot):
		if grid[n] != null and grid[n].data.kind == CardData.Kind.NORMAL and not grid[n].dirty:
			count += 1
	return count


func _on_shard_placed(slot: int) -> void:
	var element := grid[slot].data.element
	if element in calmed_shards:
		log_message.emit(tr("✨ %s sunağa geri kondu (öfke azalmadı).") % tr(grid[slot].data.display_name))
	else:
		calmed_shards.append(element)
		change_ash_rage(config.ash_rage_per_shard)
		log_message.emit(tr("✨ %s sunağa yerleşti. Kül sakinleşiyor (öfke %+d).") % [
			tr(grid[slot].data.display_name), config.ash_rage_per_shard])
	shard_placed.emit(slot)
	if shards_on_altars() >= SHARD_ORDER.size() and not seed_given and config.seed_card != null:
		seed_given = true
		hand.append(config.seed_card)
		log_message.emit(tr("🌱 Üç parça birleşti! Denge Tohumu elinde. Onu ortadaki slota koy."))
	boss_changed.emit()


## Kül Ana sunaktaki parçaya vurur. Komşu kartlar hasarı azaltır; parça düşerse ele döner.
func damage_shard(slot: int, amount: int) -> void:
	var card := grid[slot]
	var guard := config.ash_guard_per_card * altar_guards(slot)
	var dealt := maxi(0, amount - guard)
	card.hp -= dealt
	slot_hit.emit(slot, dealt)
	if guard > 0:
		log_message.emit(tr("🛡 Kartlar sunağı korudu (−%d hasar).") % mini(guard, amount))
	if card.hp <= 0:
		grid[slot] = null
		hand.append(card.data)
		change_ash_rage(config.ash_rage_shard_lost)
		log_message.emit(tr("💔 %s sunaktan düştü ve ele döndü! Öfke %+d") % [tr(card.data.display_name), config.ash_rage_shard_lost])
		shard_lost.emit(slot)
		hand_changed.emit()
		grid_changed.emit()
		boss_changed.emit()


func change_ash_rage(delta: int) -> void:
	ash_rage = clampi(ash_rage + delta, 0, config.ash_rage_max)
	boss_changed.emit()


## Öfke doldu mu? Dolduysa oyun biter. true = bitti.
func check_ash_rage() -> bool:
	if boss.mechanic == BossData.Mechanic.ASH_MOTHER and ash_rage >= config.ash_rage_max and not is_over():
		finish(false, tr("Kül'ün öfkesi ormanı tamamen yaktı."))
		return true
	return false


func _win_with_seed() -> void:
	bosses_defeated += 1
	# Kül Ana öldürülmez; aynı görsel olay sinyali BossPanel'deki dönüşüm animasyonunu başlatır.
	boss_defeated.emit()
	log_message.emit(tr("🌳 Denge Tohumu yerine kondu. Kül yeniden Doğa Ana oldu!"))
	finish(true, tr("Denge Tohumu yeniden birleşti. Doğa Ana uyandı."))


# --- Harita etkileri ----------------------------------------------------------

## Tur sonu harita etkileri: duman, gelgit, çöp, asfalt ve yeşillenme.
func tick_map() -> void:
	map_turn += 1
	_roll_smoke()

	if map.tide_interval > 0 and map_turn % map.tide_interval == 0:
		var row := tide_row
		tide_row = (tide_row + 1) % Grid.SIZE
		log_message.emit(tr("🌊 Gelgit! %d. satır sular altında.") % (row + 1))
		tide_flooded.emit(row)
		var dropped := 0
		for c in Grid.SIZE:
			var slot := row * Grid.SIZE + c
			if grid[slot] != null:
				if grid[slot].data.kind == CardData.Kind.NORMAL:
					damage_card(slot, config.tide_wave_damage, true)
			elif altar_element[slot] == "" and trash[slot] == 0:
				trash[slot] = 1
				dropped += 1
		# Görev kilitlenmesin: haritada hiç çöp kalmadıysa çöp başka boş bir slota vurur.
		if dropped == 0 and map.quest == MapData.Quest.TRASH and _trash_count() == 0:
			var empty := _empty_slots()
			if not empty.is_empty():
				trash[empty.pick_random()] = 1

	if map.random_trash_interval > 0 and map_turn % map.random_trash_interval == 0:
		var empty := _empty_slots()
		# Son boş slotu çöp doldurmasın: tahta tamamen kapanırsa kart oynanamıyor, oyun kilitleniyordu.
		if empty.size() > 1:
			trash[empty.pick_random()] = 1
			log_message.emit(tr("🗑 Akıntı bir çöp getirdi."))

	for i in Grid.SLOT_COUNT:
		if asphalt[i] == 0:
			continue
		var card := grid[i]
		if card == null or card.data.kind != CardData.Kind.NORMAL:
			green_progress[i] = 0
			continue
		damage_card(i, config.asphalt_hp_loss, true)
		if grid[i] == null:
			continue
		if card.data.element == "toprak" and map.quest == MapData.Quest.GREEN:
			green_progress[i] += 1
			if green_progress[i] >= map.green_turns:
				asphalt[i] = 0
				green[i] = 1
				hot[i] = 0
				green_progress[i] = 0
				log_message.emit(tr("🌿 Slot %d kalıcı olarak Yeşil Alan oldu!") % (i + 1))
				green_created.emit(i)
		else:
			green_progress[i] = 0

	grid_changed.emit()
	_check_quest()


## Çöp düşebilecek boş slotlar (sunak ve tohum slotu hariç).
func _empty_slots() -> Array[int]:
	var result: Array[int] = []
	for i in Grid.SLOT_COUNT:
		if grid[i] == null and trash[i] == 0 and altar_element[i] == "" \
				and not (is_final() and i == map.seed_slot):
			result.append(i)
	return result


func _trash_count() -> int:
	var count := 0
	for v in trash:
		count += v
	return count


func _roll_smoke() -> void:
	smoke.fill(0)
	if map.smoke_count <= 0:
		return
	var candidates: Array[int] = []
	for i in Grid.SLOT_COUNT:
		if altar_element[i] == "":
			candidates.append(i)
	candidates.shuffle()
	for i in mini(map.smoke_count, candidates.size()):
		smoke[candidates[i]] = 1


func asphalt_count() -> int:
	var count := 0
	for v in asphalt:
		count += v
	return count


## Asfalt varken sıcaklık artışı katlanır.
## Yalnızca asfaltın yeşillendirilebildiği haritada (Gri Şehir) geçerli; finaldeki asfalt
## temizlenemediği için orada katlamak sıcaklığı her tur 2 kat artırıp oyunu hemen bitiriyordu.
func temp_multiplier() -> float:
	if map == null or map.quest != MapData.Quest.GREEN:
		return 1.0
	return config.asphalt_temp_multiplier if asphalt_count() > 0 else 1.0


func welfare_decay() -> int:
	return config.toprak_shard_welfare if "toprak" in shards else config.welfare_per_turn


# --- Görev ------------------------------------------------------------------

## (yapılan, hedef)
func quest_progress() -> Vector2i:
	match map.quest:
		MapData.Quest.CHIMNEYS:
			var left := 0
			for card in grid:
				if card != null and card.dirty:
					left += 1
			return Vector2i(map.chimney_slots.size() - left, map.chimney_slots.size())
		MapData.Quest.TRASH:
			return Vector2i(mini(trash_cleaned, map.trash_goal), map.trash_goal)
		MapData.Quest.GREEN:
			var count := 0
			for v in green:
				count += v
			return Vector2i(count, map.asphalt_slots.size())
		_:
			return Vector2i(shards_on_altars(), SHARD_ORDER.size())


## Tohum parçasının oyuncunun dilindeki adı.
func shard_name(element: String) -> String:
	return tr(SHARD_NAMES[element])


func quest_label() -> String:
	var p := quest_progress()
	match map.quest:
		MapData.Quest.CHIMNEYS:
			return tr("Kirli baca söndür: %d/%d") % [p.x, p.y]
		MapData.Quest.TRASH:
			return tr("Çöp temizle: %d/%d") % [p.x, p.y]
		MapData.Quest.GREEN:
			return tr("Asfaltı yeşillendir: %d/%d") % [p.x, p.y]
		_:
			return tr("Parçaları sunaklara koy: %d/%d") % [p.x, p.y]


func _check_quest() -> void:
	quest_changed.emit()
	if stage != Stage.REPAIR or is_over():
		return
	var p := quest_progress()
	if p.y > 0 and p.x >= p.y:
		log_message.emit(tr("✅ Onarım tamamlandı!"))
		_wake_boss()


# --- Ekonomi ------------------------------------------------------------------

## Kart var ve slot kilitli değil.
func is_active(slot: int) -> bool:
	return grid[slot] != null and locked_turns[slot] == 0


## Boss'a vurabilir mi? (Kirli baca, parça ve tohum vurmaz; Kül Ana'ya kartlar saldırmaz.)
func can_attack(slot: int) -> bool:
	return is_active(slot) and not grid[slot].dirty and grid[slot].data.kind == CardData.Kind.NORMAL


## Bu turun kart ekonomisi: (karbon, refah). Dumandaki Güneş kartları üretmez.
func economy() -> Vector2i:
	var result := Vector2i.ZERO
	for i in Grid.SLOT_COUNT:
		if not is_active(i):
			continue
		var card := grid[i]
		if card.dirty:
			result.x += config.dirty_chimney_carbon
			continue
		if card.data.kind != CardData.Kind.NORMAL:
			continue
		if smoke[i] > 0 and card.data.element == "gunes":
			continue
		result.x += card.data.carbon_delta
		result.y += card.data.welfare_delta
	return result


# --- Yardımcılar --------------------------------------------------------------

func change_stats(d_carbon: int, d_welfare: int, d_temp: float) -> void:
	carbon = clampi(carbon + d_carbon, 0, config.carbon_max)
	welfare = clampi(welfare + d_welfare, 0, config.welfare_max)
	temperature = maxf(config.temp_min, temperature + d_temp)
	stats_changed.emit()


func get_score() -> int:
	var score := welfare * 10 + bosses_defeated * 500 + maxi(0, roundi((config.temp_lose - temperature) * 1000.0))
	return score + (2000 if won else 0)


func _draw_card() -> CardData:
	if draw_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()
