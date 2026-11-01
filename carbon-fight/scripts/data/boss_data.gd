class_name BossData
extends Resource
## Bir İklim Boss'u (bir tohum parçasını yutmuş canavar) ya da final boss Kül Ana.

## Her boss'un kendine ait savaş mekaniği (GameState'te uygulanır).
enum Mechanic { NONE, FLAME_ARMOR, DIVE, HEAT_ABSORB, ASH_MOTHER }

@export var id: StringName
@export var display_name: String
@export var emoji: String = ""
@export var icon: Texture2D
## Bekleme animasyonunun 2. karesi (icon ile sırayla gösterilir).
@export var icon_alt: Texture2D
@export var color: Color = Color.WHITE
@export_multiline var description: String
## ASH_MOTHER için kullanılmaz (Kül Ana öldürülmez, sakinleştirilir).
@export var max_hp: int = 50
@export var mechanic: Mechanic = Mechanic.NONE
@export var mechanic_name: String = ""
@export_multiline var mechanic_text: String = ""
## Bu elementten kart ×weakness_multiplier vurur.
@export_enum("gunes", "toprak", "su", "fosil") var weakness: String = "su"
## Bu elementten kart ×resistance_multiplier vurur.
@export_enum("gunes", "toprak", "su", "fosil") var resistance: String = "fosil"
@export var attacks: Array[BossAttack] = []
