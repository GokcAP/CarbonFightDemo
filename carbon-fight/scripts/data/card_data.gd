class_name CardData
extends Resource
## Bir kartın tüm verisi. Denge sayıları burada (.tres) tutulur, kodda değil.

## NORMAL: destedeki bina kartı. SHARD: Denge Tohumu parçası (final, kendi sunağına konur).
## SEED: birleşmiş Denge Tohumu (final, orta slota konunca oyun kazanılır).
enum Kind { NORMAL, SHARD, SEED }

@export var id: StringName
@export var display_name: String
@export var emoji: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export_multiline var description: String
@export_enum("gunes", "toprak", "su", "fosil") var element: String = "gunes"
@export var kind: Kind = Kind.NORMAL

@export_group("Savaş (seviye 1)")
@export var ap: int = 1
@export var hp: int = 5
@export var armor: int = 0

@export_group("Ekonomi (her tur)")
@export var carbon_delta: int = 0
@export var welfare_delta: int = 0


func get_combat_text() -> String:
	return "⚔%d  ❤%d  🛡%d" % [ap, hp, armor]


func get_economy_text() -> String:
	var parts := PackedStringArray()
	if carbon_delta != 0:
		parts.append(tr("Karbon %+d") % carbon_delta)
	if welfare_delta != 0:
		parts.append(tr("Refah %+d") % welfare_delta)
	return "  ".join(parts)
