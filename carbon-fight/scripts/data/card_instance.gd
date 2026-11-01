class_name CardInstance
extends RefCounted
## Griddeki bir kart: veri + seviye + anlık can.

var data: CardData
var level := 1
var hp: int
## Haritada önceden yerleşik Kirli Baca (Dumanlı Vadi). Vurmaz, yalnızca kirletir.
var dirty := false


func _init(card_data: CardData) -> void:
	data = card_data
	hp = max_hp()


func ap() -> int:
	return data.ap * level


func max_hp() -> int:
	return data.hp * level


## Aynı kart üstüne bırakılınca: seviye atlar (sınırdaysa yalnızca iyileşir), can dolar.
func merge(max_level: int) -> void:
	level = mini(level + 1, max_level)
	hp = max_hp()


## Zırh düşülerek hasar alır; gerçekte alınan hasarı döndürür.
func take_damage(amount: int, ignore_armor := false, bonus_armor := 0) -> int:
	var dealt := amount if ignore_armor else maxi(0, amount - data.armor - bonus_armor)
	hp -= dealt
	return dealt


func is_dead() -> bool:
	return hp <= 0
