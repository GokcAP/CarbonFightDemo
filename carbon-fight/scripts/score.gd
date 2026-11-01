extends Node
## Autoload (Score): oyun sırasındaki canlı skor, skorun neden değiştiği ve kalıcı en iyi skor.
## Skorun kendisi GameState.get_score() ile aynıdır (refah, sıcaklık, yenilen boss, zafer); burası
## yalnızca hangi parçanın değiştiğini bulup kısa aralıklarla gruplayarak duyurur.
## En iyi skor user://score.cfg dosyasına, yalnızca oyun bittiğinde (kazanma/kaybetme) yazılır.

signal changed(score: int)
## Skorun bir parçası değişti: değişim, emoji ve sebep (çevrilmiş).
signal gained(delta: int, emoji: String, reason: String)
signal best_changed(best: int)

const PATH := "user://score.cfg"
## Bu süre içindeki değişimler tek satırda toplanır (bir tur sonunda onlarca küçük satır çıkmasın).
const BATCH_TIME := 0.45
const EMOJI := {"welfare": "🌾", "temperature": "🌡️", "bosses": "🏆", "victory": "🌳"}
const REASONS := {"welfare": "Refah", "temperature": "Sıcaklık", "bosses": "Canavar yenildi", "victory": "Zafer"}

var best := 0
## Son oyun yeni rekor muydu (oyun sonu ekranı için).
var last_was_record := false

var _last := {}
var _pending := {}
var _timer: Timer


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		best = cfg.get_value("score", "best", 0)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = BATCH_TIME
	_timer.timeout.connect(_flush)
	add_child(_timer)
	GameState.stats_changed.connect(_on_changed)
	GameState.boss_defeated.connect(_on_changed)
	GameState.map_started.connect(_on_map_started)
	GameState.game_over.connect(_on_game_over)


func current() -> int:
	return GameState.get_score()


## GameState.get_score() formülünün parçaları.
func _parts() -> Dictionary:
	var cfg := GameState.config
	return {
		"welfare": GameState.welfare * 10,
		"temperature": maxi(0, roundi((cfg.temp_lose - GameState.temperature) * 1000.0)),
		"bosses": GameState.bosses_defeated * 500,
		"victory": 2000 if GameState.won else 0,
	}


## Yeni oyun başlayınca başlangıç değerleri sebep gösterilmeden kabul edilir.
func _on_map_started() -> void:
	if GameState.map_index == 0 and GameState.turn == 1:
		_last = _parts()
		_pending.clear()
		last_was_record = false
		changed.emit(current())


func _on_changed() -> void:
	var parts := _parts()
	if _last.is_empty():
		_last = parts
	for key: String in parts:
		var delta: int = parts[key] - _last.get(key, parts[key])
		if delta != 0:
			_pending[key] = _pending.get(key, 0) + delta
	_last = parts
	changed.emit(current())
	if not _pending.is_empty():
		_timer.start()


func _flush() -> void:
	for key: String in _pending:
		if _pending[key] != 0:
			gained.emit(_pending[key], EMOJI[key], tr(REASONS[key]))
	_pending.clear()


func _on_game_over(_won: bool, _reason: String) -> void:
	_on_changed()
	_flush()
	var score := current()
	last_was_record = score > best
	if last_was_record:
		best = score
		var cfg := ConfigFile.new()
		cfg.set_value("score", "best", best)
		cfg.save(PATH)
		best_changed.emit(best)
