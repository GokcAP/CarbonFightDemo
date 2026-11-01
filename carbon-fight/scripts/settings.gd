extends Node
## Autoload (Settings): oyuncu ayarları. user://settings.cfg dosyasına kaydedilir ve açılışta uygulanır.
## Dil değişince language_changed yayılır; ana ekran arayüzünü yeni dilde yeniden kurar.

signal changed
signal language_changed

const PATH := "user://settings.cfg"
## Desteklenen diller: kod -> kendi dilindeki adı. Çeviriler: assets/i18n/<kod>.po
const LANGUAGES := {"tr": "Türkçe", "en": "English"}
## "Hızlı animasyon" açıkken tur adımları arasındaki bekleme bu oranla çarpılır.
const FAST_ANIMATION_FACTOR := 0.45

var language := "tr"
## 0..1 arası doğrusal ses seviyesi.
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
var fast_animations := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var default_language := "tr"  # oyunun ana dili; İngilizce ayarlardan seçilir
	if cfg.load(PATH) != OK:
		language = default_language
		return
	language = cfg.get_value("general", "language", default_language)
	if not LANGUAGES.has(language):
		language = default_language
	music_volume = clampf(cfg.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	fast_animations = cfg.get_value("gameplay", "fast_animations", fast_animations)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "fast_animations", fast_animations)
	cfg.save(PATH)


func apply() -> void:
	TranslationServer.set_locale(language)
	Sfx.set_volumes(music_volume, sfx_volume)
	_apply_window_mode()
	changed.emit()


func set_language(value: String) -> void:
	if value == language or not LANGUAGES.has(value):
		return
	language = value
	TranslationServer.set_locale(language)
	save_settings()
	language_changed.emit()
	changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	Sfx.set_volumes(music_volume, sfx_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	Sfx.set_volumes(music_volume, sfx_volume)
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_mode()
	save_settings()


func set_fast_animations(value: bool) -> void:
	fast_animations = value
	save_settings()
	changed.emit()


## Tur adımları arasındaki beklemenin çarpanı (TurnManager.step_delay ile çarpılır).
func animation_factor() -> float:
	return FAST_ANIMATION_FACTOR if fast_animations else 1.0


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
