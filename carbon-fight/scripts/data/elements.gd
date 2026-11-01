class_name Elements
extends RefCounted
## Element adları ve görsel bilgileri.

const NAMES := {"gunes": "Güneş", "toprak": "Toprak", "su": "Su", "fosil": "Fosil"}
const EMOJI := {"gunes": "☀", "toprak": "🌿", "su": "💧", "fosil": "🛢"}
const COLORS := {
	"gunes": Color("f4c542"),
	"toprak": Color("6ccf6c"),
	"su": Color("3fb6c9"),
	"fosil": Color("a08a7e"),
}


## Elementin 16x16 pixel ikonu (assets/sprites/icons/<element>.png).
static func icon(element: String) -> Texture2D:
	return UIStyle.icon(element)


## Emojisiz ad (pixel fontta emoji yok).
static func plain(element: String) -> String:
	return TranslationServer.translate(NAMES.get(element, element))


static func label(element: String) -> String:
	return "%s %s" % [EMOJI.get(element, ""), plain(element)]
