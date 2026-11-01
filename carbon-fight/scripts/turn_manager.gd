class_name TurnManager
extends Node
## Kart oynandıktan veya çöpe atıldıktan sonra otomatik tur sonu sırasını uygular:
## ekonomi → (boss aşaması) kartlar vurur → boss öldü mü → boss saldırır → karbon iyileştirir
## → harita etkileri (duman, gelgit, asfalt) → doğal değişim + yanma/kilit → kayıp kontrolü
## → boss mekaniği güncellenir → boss sıradaki saldırıyı seçer.
## Onarım aşamasında boss uyuyor: kartlar vurmaz, boss saldırmaz; baskıyı harita etkisi yapar.

## Adımlar arası bekleme (saniye). 0 = anında (test/simülasyon için).
@export var step_delay := 0.35

## Bu tur saldırıya uğrayan slotlar; yanma/kilit sayacı bu tur azalmaz.
var _hit_this_turn: Array[int] = []


func end_turn() -> void:
	if GameState.phase != GameState.Phase.PLAYER:
		return
	GameState.set_phase(GameState.Phase.RESOLVE)
	_hit_this_turn.clear()
	var before_carbon := GameState.carbon
	var before_welfare := GameState.welfare
	var before_temp := GameState.temperature

	_apply_economy()
	await _pause()

	if GameState.stage == GameState.Stage.BOSS:
		if GameState.boss.mechanic != BossData.Mechanic.ASH_MOTHER:
			var boss_defeated := await _cards_attack()
			if GameState.is_over() or boss_defeated:
				return  # ödül ekranı sonraki haritayı başlatır
		await _boss_attack()
		if GameState.is_over():
			return
		_carbon_heals_boss()

	GameState.tick_map()
	await _pause()
	_apply_natural_changes()
	await _tick_statuses()

	GameState.log_message.emit(tr("— Tur %d sonu: Karbon %+d, Refah %+d, Sıcaklık %+.2f°C") % [
		GameState.turn,
		GameState.carbon - before_carbon,
		GameState.welfare - before_welfare,
		GameState.temperature - before_temp,
	])
	if _check_loss():
		return
	GameState.tick_boss_mechanics()
	if GameState.is_over():
		return
	GameState.choose_intent()
	GameState.turn += 1
	GameState.start_turn()


func _pause(factor := 1.0) -> void:
	if step_delay > 0.0:
		await get_tree().create_timer(step_delay * factor).timeout


# 1. Ekonomi
func _apply_economy() -> void:
	var eco := GameState.economy()
	GameState.change_stats(eco.x, eco.y, 0.0)


# 2-3. Kartlar sırayla vurur; boss ölürse true döner.
func _cards_attack() -> bool:
	for i in Grid.SLOT_COUNT:
		if not GameState.can_attack(i):
			continue
		var damage := GameState.card_damage(i)
		GameState.card_attacked.emit(i, damage)
		GameState.hit_boss(damage, GameState.grid[i].data.element)
		await _pause(0.6)
		if GameState.boss_hp <= 0:
			GameState.defeat_boss()
			return true
	return false


# 4. Boss ilan ettiği saldırıyı yapar; sonra öfkesi artar.
func _boss_attack() -> void:
	var attack := GameState.intent_attack
	if attack == null:
		return
	var damage := GameState.intent_damage()
	GameState.log_message.emit("%s %s! (%s)" % [GameState.boss.emoji, tr(attack.attack_name), attack.get_effect_text(GameState.rage_bonus())])
	GameState.boss_attacking.emit()
	await _pause(0.6)
	var golem := GameState.boss.mechanic == BossData.Mechanic.HEAT_ABSORB
	for slot in GameState.intent_slots:
		_hit_this_turn.append(slot)
		var card := GameState.grid[slot]
		if card != null:
			match card.data.kind:
				CardData.Kind.SHARD:
					GameState.damage_shard(slot, damage)
				CardData.Kind.NORMAL:
					GameState.damage_card(slot, damage)
		elif damage > 0:
			GameState.change_stats(0, -damage, 0.0)
			GameState.slot_hit.emit(slot, damage)
		GameState.burn_turns[slot] = maxi(GameState.burn_turns[slot], attack.burn_turns)
		GameState.locked_turns[slot] = maxi(GameState.locked_turns[slot], attack.lock_turns)
		# Golemin yakan saldırıları slotu yeniden ısıtır.
		if golem and attack.burn_turns > 0 and GameState.green[slot] == 0:
			GameState.hot[slot] = 1
	if GameState.boss.mechanic != BossData.Mechanic.ASH_MOTHER:
		GameState.boss_rage += GameState.config.rage_per_turn
	GameState.intent_attack = null
	GameState.intent_slots.clear()
	GameState.intent_changed.emit()
	GameState.grid_changed.emit()
	GameState.boss_changed.emit()
	await _pause(1.5)


# 5. Yüksek karbon boss'u iyileştirir (Kül Ana hariç).
func _carbon_heals_boss() -> void:
	if GameState.boss.mechanic == BossData.Mechanic.ASH_MOTHER:
		return
	var cfg := GameState.config
	var excess := GameState.carbon - cfg.boss_heal_carbon_threshold
	if excess < cfg.boss_heal_carbon_per_hp:
		return
	var healed := GameState.heal_boss(excess / cfg.boss_heal_carbon_per_hp)
	if healed > 0:
		GameState.log_message.emit(tr("🏭 Yüksek karbon boss'u besledi: +%d HP") % healed)


# 6a. Doğal değişim ve karbon → sıcaklık (asfalt varken katlanır)
func _apply_natural_changes() -> void:
	var cfg := GameState.config
	GameState.change_stats(cfg.carbon_per_turn, GameState.welfare_decay(), 0.0)
	var d_temp := (GameState.carbon - cfg.carbon_baseline) * cfg.temp_per_carbon
	if d_temp > 0.0:
		d_temp *= GameState.temp_multiplier()
	GameState.change_stats(0, 0, d_temp)


# 6b. Yanma hasarı ve yanma/kilit süreleri
func _tick_statuses() -> void:
	var burned := false
	for i in Grid.SLOT_COUNT:
		if i in _hit_this_turn:
			continue
		if GameState.burn_turns[i] > 0:
			GameState.burn_turns[i] -= 1
			var card := GameState.grid[i]
			if card != null and card.data.kind == CardData.Kind.NORMAL:
				burned = true
				GameState.damage_card(i, GameState.config.burn_damage, true)
		if GameState.locked_turns[i] > 0:
			GameState.locked_turns[i] -= 1
			if GameState.locked_turns[i] == 0:
				GameState.log_message.emit(tr("🔓 Slot %d serbest.") % (i + 1))
	GameState.grid_changed.emit()
	if burned:
		await _pause()


# 7. Kayıp kontrolü
func _check_loss() -> bool:
	var cfg := GameState.config
	if GameState.temperature >= cfg.temp_lose:
		GameState.finish(false, tr("Sıcaklık %.1f°C'ye ulaştı.") % cfg.temp_lose)
	elif GameState.welfare <= 0:
		GameState.finish(false, tr("Refah tükendi."))
	elif GameState.check_ash_rage():
		pass
	return GameState.is_over()
