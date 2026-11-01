extends SceneTree
## Çevrilecek tüm metinleri toplar ve eksik çevirileri raporlar.
##
## Kullanım (proje klasöründen):
##   godot --headless --path . -s res://tools/i18n/extract.gd
##
## Çıktılar:
##   tools/i18n/messages.pot  : tüm metinler (Poedit gibi araçlarla yeni dil eklemek için şablon)
##   tools/i18n/missing_en.txt: assets/i18n/en.po içinde çevirisi olmayan metinler
##
## Metin kaynakları: koddaki tr("...") çağrıları, aşağıdaki sabitler ve data/ altındaki
## kart / boss / harita kaynaklarının metin alanları.

const SCRIPT_DIR := "res://scripts"
const DATA_DIRS := ["res://data/cards", "res://data/bosses", "res://data/maps"]
const RESOURCE_FIELDS := ["display_name", "description", "intro_text", "effect_name", "effect_text",
		"quest_text", "reward_text", "mechanic_name", "mechanic_text", "attack_name"]
## tr() ile kullanılan sabitler: betik -> sabit adları.
const CONSTANTS := {
	"res://scripts/main.gd": ["STORY_TEXT", "ENDING_TEXT", "HOW_TO_TEXT"],
	"res://scripts/game_state.gd": ["SHARD_NAMES"],
	"res://scripts/data/elements.gd": ["NAMES"],
	"res://scripts/data/boss_attack.gd": ["PATTERN_NAMES"],
	"res://scripts/ui/tutorial.gd": ["STEPS"],
	"res://scripts/ui/grimoire.gd": ["PREFACE", "LORE", "MAP_NOTES", "DOGA_LORE", "SEED_TEXT"],
	"res://scripts/score.gd": ["REASONS"],
	"res://scripts/main_menu.gd": ["BUTTON_LAYOUT"],
}

var _messages: Array[String] = []


func _initialize() -> void:
	for path in _files(SCRIPT_DIR, ".gd"):
		_scan_script(path)
	for script_path: String in CONSTANTS:
		var constants: Dictionary = load(script_path).get_script_constant_map()
		for constant_name: String in CONSTANTS[script_path]:
			_add_constant(constants[constant_name])
	for dir in DATA_DIRS:
		for path in _files(dir, ".tres"):
			_scan_resource(load(path))

	_write_pot()
	_report_missing("en")
	quit()


## Sabitteki metinler: sözlük değerleri, dizi öğeleri (iç içe) ya da düz metin.
## Dizilerde boşluk ya da büyük harf içeren metinler alınır; küçük harfli anahtar, ikon ve
## fonksiyon adları (ör. "stats", "seed", "_start_game") alınmaz.
func _add_constant(value: Variant, in_array := false) -> void:
	if value is Dictionary:
		for v: Variant in value.values():
			_add_constant(v)
	elif value is Array:
		for v: Variant in value:
			_add_constant(v, true)
	elif value is String and (not in_array or " " in value or value != value.to_lower()):
		_add(value)


func _files(dir: String, ext: String) -> Array[String]:
	var result: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			result.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		result.append_array(_files(dir.path_join(d), ext))
	return result


func _scan_script(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string('\\btr\\("((?:[^"\\\\]|\\\\.)*)"\\)')
	for m in re.search_all(source):
		_add(m.get_string(1).c_unescape())


func _scan_resource(res: Resource) -> void:
	if res == null:
		return
	for field: String in RESOURCE_FIELDS:
		if field in res:
			_add(str(res.get(field)))
	if "attacks" in res:
		for attack: Resource in res.get("attacks"):
			_scan_resource(attack)


func _add(text: String) -> void:
	if text.strip_edges() != "" and not _messages.has(text):
		_messages.append(text)


static func _po_escape(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")


func _write_pot() -> void:
	var f := FileAccess.open("res://tools/i18n/messages.pot", FileAccess.WRITE)
	f.store_string("msgid \"\"\nmsgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n\n")
	for text in _messages:
		f.store_string("msgid \"%s\"\nmsgstr \"\"\n\n" % _po_escape(text))
	print("%d metin -> tools/i18n/messages.pot" % _messages.size())


func _report_missing(locale: String) -> void:
	var path := "res://assets/i18n/%s.po" % locale
	var translation: Translation = load(path) if ResourceLoader.exists(path) else null
	var missing: Array[String] = []
	for text in _messages:
		if translation == null or translation.get_message(text) == StringName():
			missing.append(text)
	var f := FileAccess.open("res://tools/i18n/missing_%s.txt" % locale, FileAccess.WRITE)
	for text in missing:
		f.store_string(_po_escape(text) + "\n")
	print("%s: %d eksik çeviri -> tools/i18n/missing_%s.txt" % [locale, missing.size(), locale])
