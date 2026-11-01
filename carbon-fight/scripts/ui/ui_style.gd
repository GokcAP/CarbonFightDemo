class_name UIStyle
extends RefCounted
## Ortak renkler (Sweetie 16 paleti), pixel çerçeveler, font, tema ve ikon yardımcıları.

## Bir "art pikseli" ekranda kaç piksel. Sprite'lar ve çerçeveler bu katla büyütülür.
const PX := 2
const FONT_PATH := "res://assets/fonts/CarbonFightPixel.ttf"
const ICON_DIR := "res://assets/sprites/icons/%s.png"
## 720p hedefinde harf ve rakamların iç boşluklarını koruyan en küçük okunabilir boyut.
const BODY_FONT_SIZE := 18
const BUTTON_FONT_SIZE := 24
const TITLE_FONT_SIZE := 32

const OUTLINE := Color("1a1c2c")
const BG := Color("1a1c2c")
const PANEL := Color("333c57eb")
const PANEL_BORDER := Color("566c86")
const SLOT_BG := Color("1a1c2cd0")
const SLOT_BORDER := Color("566c86")
const TEXT_DIM := Color("94b0c2")
const HIGHLIGHT := Color("73eff7")
const GOLD := Color("ffcd75")
const DANGER := Color("ff5f6d")
const LOCK := Color("566c86")
const BURN := Color("ef7d57")
const CARBON := Color("94b0c2")
const WELFARE := Color("a7f070")
const HEAT := Color("ef7d57")
const GOOD := Color("a7f070")
const BAD := Color("ff8a7a")

static var _font: FontFile
static var _box_cache := {}
static var _icon_cache := {}


# --- Font ve tema ---------------------------------------------------------------

## Pixel karakterini korurken küçük harf ve rakamlardaki kırılmayı azaltan render ayarları.
static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_LIGHT
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.generate_mipmaps = false
	return _font


## Küçük metni okunabilir tabanda tut; mevcut 24/32 px görsel hiyerarşisini koru.
static func snap_size(font_size: int) -> int:
	if font_size < 21:
		return BODY_FONT_SIZE
	if font_size < 28:
		return BUTTON_FONT_SIZE
	return TITLE_FONT_SIZE


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = BODY_FONT_SIZE

	# Buton çerçeveleri assets/ui/button_<durum>.png'den; dosya yoksa kodla çizilir.
	var fallback := {
		"normal": box(Color("257179"), Color("a7f070"), 2),
		"hover": box(Color("38b764"), Color("f4f4f4"), 2),
		"pressed": box(Color("29366f"), Color("73eff7"), 2),
		"disabled": box(Color("333c57"), Color("566c86"), 2),
	}
	for state: String in fallback:
		var skin := Art.skin("button_" + state)
		t.set_stylebox(state, "Button", skin if skin != null else fallback[state])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("f4f4f4"))
	t.set_color("font_hover_color", "Button", Color("f4f4f4"))
	t.set_color("font_pressed_color", "Button", Color("73eff7"))
	t.set_color("font_disabled_color", "Button", Color("94b0c2"))
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 3)

	t.set_stylebox("panel", "TooltipPanel", box(Color("1a1c2cf0"), Color("94b0c2"), 2))
	t.set_color("font_color", "TooltipLabel", Color("f4f4f4"))
	t.set_font_size("font_size", "TooltipLabel", BODY_FONT_SIZE)

	t.set_color("default_color", "RichTextLabel", Color("f4f4f4"))
	t.set_font_size("normal_font_size", "RichTextLabel", BODY_FONT_SIZE)
	t.set_constant("line_separation", "RichTextLabel", 4)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("566c86")
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color("1a1c2c80")
	scroll_bg.content_margin_left = 4
	scroll_bg.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)
	return t


# --- Pixel çerçeve --------------------------------------------------------------

## Pixel art çerçeve: koyu dış çizgi + (isteğe bağlı) renkli kenar + iç ışık/gölge.
## border_width ekran pikseli cinsindendir ve art pikseline yuvarlanır. Köşeler pixel olarak kırpılır.
static func box(bg: Color, border := Color.TRANSPARENT, border_width := 0, content_margin := 4 * PX) -> StyleBoxTexture:
	var bw := 0
	if border.a > 0.0 and border_width > 0:
		bw = maxi(1, border_width / PX)
	var key := "%s|%s|%d|%d" % [bg.to_html(), border.to_html(), bw, content_margin]
	if _box_cache.has(key):
		return _box_cache[key]

	var margin := 2 + bw  # dış çizgi + kenar + iç ışık
	var n := margin * 2 + 2
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			if (x == 0 or x == n - 1) and (y == 0 or y == n - 1):
				continue  # kırpık köşe
			var d := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var lit := d == x or d == y  # üst/sol kenar aydınlık, alt/sağ gölgeli
			var c := bg
			if d == 0:
				c = OUTLINE
			elif d <= bw:
				c = border.lightened(0.25) if lit else border.darkened(0.25)
			elif d == bw + 1:
				c = bg.lightened(0.12) if lit else bg.darkened(0.3)
			img.set_pixel(x, y, c)
	img.resize(n * PX, n * PX, Image.INTERPOLATE_NEAREST)

	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(margin * PX)
	sb.set_content_margin_all(content_margin)
	_box_cache[key] = sb
	return sb


# --- Metin ----------------------------------------------------------------------

static func label(text: String, font_size := BODY_FONT_SIZE, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", snap_size(font_size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- İkon / sprite --------------------------------------------------------------

static func icon(icon_name: String) -> Texture2D:
	if not _icon_cache.has(icon_name):
		var path := ICON_DIR % icon_name
		_icon_cache[icon_name] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[icon_name]


## Nearest filtreli, tam sayı katında büyütülmüş sprite.
static func tex_rect(tex: Texture2D, scale := 1) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = (tex.get_size() if tex != null else Vector2(16, 16)) * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## [ikon] metin satırı. Metne row.get_child(1) ile erişilir.
static func icon_label(icon_name: String, text := "", font_size := BODY_FONT_SIZE, color := Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.add_child(tex_rect(icon(icon_name)))
	var l := label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return row


# --- Bar ------------------------------------------------------------------------

static func bar(color: Color, max_value: float, min_value := 0.0, height := 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = min_value
	b.max_value = max_value
	b.step = 0.01
	b.show_percentage = false
	b.custom_minimum_size.y = height
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", bar_background())
	b.add_theme_stylebox_override("fill", bar_fill(color, height))
	return b


static func bar_background() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1a1c2c")
	bg.border_color = Color("0d0e16")
	bg.set_border_width_all(PX)
	bg.set_expand_margin_all(PX)
	bg.anti_aliasing = false
	return bg


static func bar_fill(color: Color, height := 14) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.anti_aliasing = false
	if height >= 10:
		fill.border_color = color.lightened(0.4)
		fill.border_width_top = PX
	return fill


## Sürüklenen kartın verisi (sürükleme yoksa null).
static func dragged_card(viewport: Viewport) -> CardData:
	var data: Variant = viewport.gui_get_drag_data()
	if data is Dictionary and data.get("type") == "card":
		var index: int = data["hand_index"]
		if index >= 0 and index < GameState.hand.size():
			return GameState.hand[index]
	return null
