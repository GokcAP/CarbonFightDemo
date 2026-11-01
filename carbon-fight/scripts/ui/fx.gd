class_name Fx
extends RefCounted
## Küçük tween efektleri: uçan sayı, sarsıntı, renk flaşı, vuruş flaşı, zıplama, giriş.

const HIT_FLASH_SHADER := preload("res://assets/shaders/hit_flash.gdshader")


static func float_text(target: Control, text: String, color: Color, font_size := 24) -> void:
	var label := UIStyle.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_constant_override("outline_size", 6)
	label.top_level = true
	label.z_index = 10
	target.add_child(label)
	label.size = Vector2(target.size.x, 40)
	var start := target.global_position + Vector2(0, target.size.y / 2 - 30)
	label.global_position = start.round()
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.6, 1.6)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", start.y - 48, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


static func flash(target: CanvasItem, color: Color, duration := 0.35) -> void:
	target.modulate = color
	target.create_tween().tween_property(target, "modulate", Color.WHITE, duration)


## Sprite'ı bir anlığına beyaza (veya verilen renge) boyar. Hedefe shader'ı kendisi takar.
static func hit_flash(target: CanvasItem, color := Color.WHITE, duration := 0.18) -> void:
	var mat := target.material as ShaderMaterial
	if mat == null or mat.shader != HIT_FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = HIT_FLASH_SHADER
		target.material = mat
	mat.set_shader_parameter("flash_color", color)
	target.create_tween().tween_method(
		func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, duration)


## Sarsıntı. Üst üste çağrılsa da kaymasın diye ilk konumu meta'da saklar.
static func shake(target: Control, strength := 8.0, steps := 5) -> void:
	if not target.has_meta("shake_origin"):
		target.set_meta("shake_origin", target.position)
	var origin: Vector2 = target.get_meta("shake_origin")
	var tween := target.create_tween()
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.6) * falloff
		tween.tween_property(target, "position", origin + offset.round(), 0.035)
	tween.tween_property(target, "position", origin, 0.035)
	tween.tween_callback(func() -> void: target.remove_meta("shake_origin"))


static func bump(target: Control, amount := 1.12) -> void:
	target.pivot_offset = target.size / 2
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2(amount, amount), 0.07)
	tween.tween_property(target, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kart bırakılınca: büyükten normale "oturma".
static func land(target: Control) -> void:
	target.pivot_offset = target.size / 2
	target.scale = Vector2(1.3, 1.3)
	target.create_tween().tween_property(target, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sıfırdan büyüyerek giriş (yeni boss).
static func pop_in(target: Control, duration := 0.45) -> void:
	target.pivot_offset = target.size / 2
	target.scale = Vector2(0.1, 0.1)
	target.modulate.a = 0.0
	var tween := target.create_tween().set_parallel()
	tween.tween_property(target, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, duration * 0.5)


## Boss saldırı hamlesi: geri çekil, öne atıl, yerine dön.
static func lunge(target: Control) -> void:
	target.pivot_offset = target.size / 2
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2(0.9, 0.9), 0.12)
	tween.tween_property(target, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(target, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sonsuz yanıp sönme (hedeflenen slot için). Tween döner; durdurmak için kill().
static func pulse(target: CanvasItem, color: Color, period := 0.6) -> Tween:
	var tween := target.create_tween().set_loops()
	tween.tween_property(target, "self_modulate", color, period / 2)
	tween.tween_property(target, "self_modulate", Color.WHITE, period / 2)
	return tween
