class_name Grid
extends RefCounted
## 3x3 ızgara geometrisi: komşuluk ve saldırı desenleri.

const SIZE := 3
const SLOT_COUNT := SIZE * SIZE


static func row_of(slot: int) -> int:
	return slot / SIZE


static func column_of(slot: int) -> int:
	return slot % SIZE


## Dik komşular (yukarı, aşağı, sol, sağ).
static func neighbors(slot: int) -> Array[int]:
	var result: Array[int] = []
	var row := row_of(slot)
	var col := column_of(slot)
	if row > 0:
		result.append(slot - SIZE)
	if row < SIZE - 1:
		result.append(slot + SIZE)
	if col > 0:
		result.append(slot - 1)
	if col < SIZE - 1:
		result.append(slot + 1)
	return result


static func pattern_slots(pattern: BossAttack.Pattern, anchor: int) -> Array[int]:
	var result: Array[int] = []
	match pattern:
		BossAttack.Pattern.SINGLE:
			result.append(anchor)
		BossAttack.Pattern.ROW:
			var start := row_of(anchor) * SIZE
			for i in SIZE:
				result.append(start + i)
		BossAttack.Pattern.COLUMN:
			for i in SIZE:
				result.append(i * SIZE + column_of(anchor))
		BossAttack.Pattern.PLUS:
			result.append(anchor)
			result.append_array(neighbors(anchor))
	return result
