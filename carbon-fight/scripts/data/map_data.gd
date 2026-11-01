class_name MapData
extends Resource
## Bir harita (hikaye seviyesi): onarım fazı (harita etkisi + görev) → boss savaşı → ödül parçası.
## Final haritası (Kül Ormanı) onarım fazı olmadan doğrudan Kül Ana ile başlar.

enum Quest { CHIMNEYS, TRASH, GREEN, ALTARS }

@export var id: StringName
@export var display_name: String
@export var emoji: String = ""
@export_multiline var intro_text: String
@export var background: Texture2D
## Arka planın bu haritadaki rengi (sıcaklık tonu bunun üstüne eklenir).
@export var tint: Color = Color.WHITE
@export var boss: BossData

@export_group("Harita etkisi")
@export var effect_name: String
@export_multiline var effect_text: String

@export_group("Onarım görevi")
@export var quest: Quest = Quest.CHIMNEYS
@export_multiline var quest_text: String

@export_group("Ödül")
## Boss yenilince kazanılan tohum parçası: "su", "toprak" veya "gunes". Final için boş.
@export var reward_shard: String = ""
@export_multiline var reward_text: String

@export_group("Duman")
## Her tur is bürünen rastgele slot sayısı.
@export var smoke_count: int = 0

@export_group("Kirli bacalar")
## Önceden yerleşik Kömür Santrali (Kirli Baca) slotları.
@export var chimney_slots: Array[int] = []

@export_group("Gelgit ve çöp")
## Kaç turda bir sıradaki satır sular altında kalır (0 = yok).
@export var tide_interval: int = 0
## Harita başında çöplü slotlar.
@export var start_trash_slots: Array[int] = []
## Temizlenmesi gereken çöp sayısı.
@export var trash_goal: int = 0
## Kaç turda bir rastgele boş slota çöp düşer (final; 0 = yok).
@export var random_trash_interval: int = 0

@export_group("Asfalt")
@export var asphalt_slots: Array[int] = []
## Toprak kartı asfaltta kaç tur hayatta kalırsa slot Yeşil Alan olur.
@export var green_turns: int = 2

@export_group("Sunaklar (final)")
## Sunak slotları, sırasıyla Su, Toprak, Güneş parçası için.
@export var altar_slots: Array[int] = []
## Denge Tohumu'nun konacağı slot.
@export var seed_slot: int = 4
