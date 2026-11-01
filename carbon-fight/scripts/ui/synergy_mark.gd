class_name SynergyMark
extends Control
## Aynı elementten aktif iki komşu kartın arasındaki boşlukta parlayan pixel halka (izometrik elmas).
## Tahta bunu iki slotun derinlikleri arasına çizer: arkadaki karonun önünde, öndekinin arkasında kalır.

const HALF := Vector2(14, 7)

## Bağlı iki slot.
var pair: Array = []
var color := Color.WHITE
## Tahtanın görünüm açısı: halka da karolarla aynı doğrultuda döner.
var angle := 0.0:
	set(value):
		angle = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = HALF * 2


func _draw() -> void:
	var center := HALF
	# Pixel halka: koyu çerçeve + element rengi + parlak çekirdek.
	_diamond(center, HALF, UIStyle.OUTLINE)
	_diamond(center, Vector2(11, 5), color)
	_diamond(center, Vector2(5, 2), color.lightened(0.55))


func _diamond(center: Vector2, half: Vector2, fill: Color) -> void:
	draw_colored_polygon(IsoQuad.rhombus(center, half.x / IsoBoard.STEP.x, angle), fill)
