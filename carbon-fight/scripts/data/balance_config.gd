class_name BalanceConfig
extends Resource
## Oyunun tüm denge sayıları. data/balance.tres üzerinden Inspector'dan ayarlanır.

@export_group("Başlangıç")
@export var start_carbon: int = 50
@export var start_temperature: float = 1.1
@export var start_welfare: int = 60

@export_group("Doğal değişim (her tur)")
@export var carbon_per_turn: int = 5
@export var welfare_per_turn: int = -4
## Sıcaklık += (Karbon − carbon_baseline) × temp_per_carbon
@export var carbon_baseline: int = 30
@export var temp_per_carbon: float = 0.003
@export var temp_min: float = 1.0

@export_group("Eşikler")
@export var carbon_max: int = 100
@export var welfare_max: int = 100
@export var temp_warning: float = 1.5
@export var temp_lose: float = 2.0

@export_group("El ve deste")
@export var hand_size: int = 3
## Destede her karttan kaç kopya olacağı.
@export var deck_copies: int = 3
@export var cards: Array[CardData] = []

@export_group("Savaş")
@export var max_level: int = 3
## Aynı elementten her aktif dik komşu için AP bonusu.
@export var synergy_bonus: float = 0.25
@export var weakness_multiplier: float = 2.0
@export var resistance_multiplier: float = 0.5
## Boss'a bırakılan kart AP × bu değer kadar vurur.
@export var sacrifice_multiplier: int = 3
@export var burn_damage: int = 2
## Boss her saldırıdan sonra bu kadar ek hasar kazanır.
@export var rage_per_turn: int = 1

@export_group("Haritalar ve boss")
## Hikaye sırası: Dumanlı Vadi → Solgun Körfez → Gri Şehir → Kül Ormanı.
@export var maps: Array[MapData] = []
## Karbon bu değerin üstündeyse boss iyileşir...
@export var boss_heal_carbon_threshold: int = 60
## ...her bu kadar karbon puanı için 1 HP.
@export var boss_heal_carbon_per_hp: int = 4
@export var boss_reward_carbon: int = -10
@export var boss_reward_welfare: int = 10
## Her harita onarılıp boss yenilince sıcaklık bu kadar değişir.
@export var map_reward_temp: float = -0.1

@export_group("Harita kuralları")
## Dumanlı slottaki kartın AP çarpanı (Güneş kartları ayrıca üretmez).
@export var smoke_ap_multiplier: float = 0.5
## Önceden yerleşik Kömür Santrali'ni temsil eden kart (Kirli Baca).
@export var chimney_card: CardData
## Kirli Baca her tur bu kadar karbon salar (normal Kömür Santrali gibi refah üretmez).
@export var dirty_chimney_carbon: int = 3
## Gelgit dalgası dolu slottaki karta bu kadar hasar verir (çöp yalnızca boş slota düşer).
@export var tide_wave_damage: int = 2
## Asfalttaki kart her tur bu kadar can kaybeder (zırh yok sayılır).
@export var asphalt_hp_loss: int = 1
## Asfalt kaldıkça sıcaklık artışı bu kadar katlanır.
@export var asphalt_temp_multiplier: float = 2.0

@export_group("Boss mekanikleri")
## Termik Ejderha: alev zırhı katmanı; yalnızca Su kartı bir katman kırar.
@export var flame_armor_layers: int = 3
## Zırh varken Su dışı kartların hasar çarpanı.
@export var flame_armor_multiplier: float = 0.25
## Plastik Leviathan: dalış sütununa kart konunca yüzeye çıkar ve bu çarpanla hasar alır.
@export var dive_exposed_multiplier: float = 2.0
## Isı Adası Golemi: sıcak slot varken hasar çarpanı.
@export var heat_armor_multiplier: float = 0.5
@export var golem_vulnerable_turns: int = 2
@export var golem_vulnerable_multiplier: float = 2.0
## Savunmasızlık bitince golemin yeniden ısıttığı slot sayısı.
@export var golem_reheat_slots: int = 3

@export_group("Kül Ana (final)")
@export var ash_rage_start: int = 10
## Öfke bu değere ulaşırsa orman yanar (kayıp).
@export var ash_rage_max: int = 20
@export var ash_rage_per_turn: int = 1
## Sunağa yerleşen her parça öfkeyi bu kadar değiştirir.
@export var ash_rage_per_shard: int = -4
## Sunaktan düşen parça öfkeyi bu kadar artırır.
@export var ash_rage_shard_lost: int = 2
## Kül Ana'ya kurban vuruşu hasar vermez, öfkeyi artırır.
@export var ash_rage_sacrifice: int = 3
## Kül Ana saldırı hasarına öfke / bu değer eklenir.
@export var ash_rage_damage_divisor: int = 4
## Sunağın her dik komşusundaki kart, parçaya gelen hasarı bu kadar azaltır.
@export var ash_guard_per_card: int = 2
## Su, Toprak, Güneş parça kartları (bu sırayla) ve birleşmiş tohum.
@export var shard_cards: Array[CardData] = []
@export var seed_card: CardData

@export_group("Parça pasifleri")
## Su Parçası: tüm kartlara ek zırh.
@export var su_shard_armor: int = 1
## Toprak Parçası: refah her tur welfare_per_turn yerine bu kadar değişir.
@export var toprak_shard_welfare: int = -2
## Güneş Parçası: Güneş kartlarına ek AP.
@export var gunes_shard_ap: int = 2
