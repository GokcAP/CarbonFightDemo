class_name Art
extends RefCounted
## Değiştirilebilir görsellerin tek giriş noktası. Dosyalar isim kuralıyla bulunur; dosya yoksa
## genel yer tutucuya ya da eski görsele düşülür. Ölçüler ve çapa noktaları: res://assets/README.md

const ISO_DIR := "res://assets/sprites/iso/"
const BUILDING_DIR := "res://assets/sprites/buildings/"
const UI_DIR := "res://assets/ui/"
## UI çerçevelerinin 9-slice kenar payı (art pikseli).
const SKIN_MARGIN := 4

static var _textures := {}
static var _skins := {}


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## Önce haritaya özel dosya (ör. tile_gri_sehir.png), yoksa genel dosya (tile.png).
static func _per_map(prefix: String, map_id: StringName) -> Texture2D:
	var specific := texture("%s%s_%s.png" % [ISO_DIR, prefix, map_id])
	return specific if specific != null else texture("%s%s.png" % [ISO_DIR, prefix])


## Slotun karo tabanı (64x40).
static func tile_base(map_id: StringName) -> Texture2D:
	return _per_map("tile", map_id)


## Tahtanın altındaki ada (256x144).
static func ground(map_id: StringName) -> Texture2D:
	return _per_map("ground", map_id)


## Zemin katmanı elması (64x32): asphalt, green, altar, hot.
static func overlay(overlay_name: String) -> Texture2D:
	return texture(ISO_DIR + "overlay_%s.png" % overlay_name)


## Karo üstünde duran nesne (64x64): smoke, trash.
static func prop(prop_name: String) -> Texture2D:
	return texture(ISO_DIR + "prop_%s.png" % prop_name)


## Kartın tahtadaki binası (64x64). Yoksa null; slot kartın ikonunu kullanır.
static func building(card: CardData) -> Texture2D:
	return texture(BUILDING_DIR + "%s.png" % card.id)


## assets/ui/<ad>.png dosyasından pixel 9-slice çerçeve; dosya yoksa null.
## tint: gri tonlu çerçeveyi boyamak için (kart çerçevesi).
static func skin(skin_name: String, tint := Color.WHITE) -> StyleBoxTexture:
	var key := "%s|%s" % [skin_name, tint.to_html()]
	if _skins.has(key):
		return _skins[key]
	var tex := texture(UI_DIR + skin_name + ".png")
	var sb: StyleBoxTexture = null
	if tex != null:
		var img := tex.get_image()
		img.resize(img.get_width() * UIStyle.PX, img.get_height() * UIStyle.PX, Image.INTERPOLATE_NEAREST)
		sb = StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		sb.set_texture_margin_all(SKIN_MARGIN * UIStyle.PX)
		sb.set_content_margin_all(4 * UIStyle.PX)
		sb.modulate_color = tint
	_skins[key] = sb
	return sb
