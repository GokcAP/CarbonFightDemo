extends Node
## Autoload (Codex): Denge Grimuarı'nın açılmış sayfaları. user://codex.cfg dosyasına kalıcı kaydedilir.
## Bir haritanın boss'u yenilince o haritanın kimliği (ör. "dumanli_vadi") açılır: kitapta
## o boss'un ve haritanın sayfaları görünür. Oyun kazanılınca final haritası ve "doga_ana" açılır.
## Oyunun geri kalanını etkilemez; yalnızca GameState sinyallerini dinler.

signal unlocked(id: String)

const PATH := "user://codex.cfg"
const FINAL_ID := "doga_ana"

var _unlocked: Array[String] = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_unlocked.assign(cfg.get_value("codex", "unlocked", []))
	GameState.map_completed.connect(func() -> void: unlock(String(GameState.map.id)))
	GameState.game_over.connect(func(won: bool, _reason: String) -> void:
		if won:
			unlock(String(GameState.map.id))
			unlock(FINAL_ID))


func is_unlocked(id: String) -> bool:
	return id in _unlocked


func unlocked_count() -> int:
	return _unlocked.size()


func unlock(id: String) -> void:
	if id == "" or id in _unlocked:
		return
	_unlocked.append(id)
	_save()
	unlocked.emit(id)


## Oyun kazanıldıysa (bütün boss'lar bitti) yeni oyun başlarken kitabı sıfırla: her şey yeniden mühürlü.
## Oyun yarıda kaldıysa açılan sayfalar korunur.
func reset_if_complete() -> void:
	if is_unlocked(FINAL_ID):
		_unlocked.clear()
		_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("codex", "unlocked", _unlocked)
	cfg.save(PATH)
