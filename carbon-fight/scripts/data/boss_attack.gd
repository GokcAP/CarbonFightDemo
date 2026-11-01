class_name BossAttack
extends Resource
## Boss'un bir saldırısı: hangi desene vurduğu ve bıraktığı etkiler.

enum Pattern { SINGLE, ROW, COLUMN, PLUS }

const PATTERN_NAMES := {
	Pattern.SINGLE: "Tek slot",
	Pattern.ROW: "Sıra",
	Pattern.COLUMN: "Sütun",
	Pattern.PLUS: "Artı",
}

@export var attack_name: String
@export var pattern: Pattern = Pattern.SINGLE
## Öfke bu değerin üstüne eklenir.
@export var damage: int = 0
## Slot kaç tur yanar (tur başına config.burn_damage).
@export var burn_turns: int = 0
## Slot kaç tur kilitlenir (kart vurmaz, üretmez, slota kart konamaz).
@export var lock_turns: int = 0


func get_effect_text(rage: int) -> String:
	var parts := PackedStringArray([tr(PATTERN_NAMES[pattern])])
	if damage + rage > 0:
		parts.append(tr("%d hasar") % (damage + rage))
	if burn_turns > 0:
		parts.append(tr("yanma %d tur") % burn_turns)
	if lock_turns > 0:
		parts.append(tr("kilit %d tur") % lock_turns)
	return ", ".join(parts)
