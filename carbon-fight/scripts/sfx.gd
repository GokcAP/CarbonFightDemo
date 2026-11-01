extends Node
## Autoload (Sfx): 8-bit ses efektleri ve müzik döngüsü.
## Oyun olaylarına GameState sinyalleri üzerinden kendisi bağlanır; arayüz kodu sadece
## tıklama gibi yerel sesler için Sfx.play() çağırır.

const SFX_DIR := "res://assets/sfx/%s.wav"
const NAMES := ["click", "place", "merge", "hit", "boss_hit", "hurt", "break", "heal", "roar",
		"spawn", "sacrifice", "win", "lose"]
const VOICES := 8
## Boss müziği: assets/music/<boss_id>.wav. Dosya yoksa o boss'ta genel müzik çalar.
const BOSS_MUSIC_DIR := "res://assets/music/%s.wav"
const MUSIC_FADE_TIME := 0.6

@export var sfx_volume_db := -4.0
@export var music_volume_db := -14.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _default_music: AudioStream
var _boss_music := {}
## Ayarlardaki müzik seviyesine göre hedef ses (dB); geçişler buna döner.
var _music_db := music_volume_db
var _fade: Tween
## Geçiş sürerken bile istenen son parça (karşılaştırma buna göre yapılır).
var _target_music: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path: String = SFX_DIR % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_players.append(p)

	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	_music.finished.connect(_music.play)  # döngü
	add_child(_music)
	if ResourceLoader.exists(SFX_DIR % "music"):
		_default_music = load(SFX_DIR % "music")
		_music.stream = _default_music
		_target_music = _default_music
		_music.play()

	# Boss uyanınca onun müziği, harita başında ve boss yenilince genel müzik.
	GameState.map_started.connect(_update_music)
	GameState.boss_spawned.connect(_update_music)
	GameState.map_completed.connect(func() -> void: _play_music(_default_music))

	GameState.card_placed.connect(func(_s: int) -> void: play("place"))
	GameState.card_merged.connect(func(_s: int) -> void: play("merge"))
	GameState.card_attacked.connect(func(_s: int, _d: int) -> void: play("hit", 0.15))
	GameState.boss_healed.connect(func(_a: int) -> void: play("heal"))
	GameState.slot_hit.connect(func(_s: int, _d: int) -> void: play("hurt", 0.12))
	GameState.card_destroyed.connect(func(_s: int) -> void: play("break"))
	GameState.card_sacrificed.connect(func(_d: int) -> void: play("sacrifice"))
	GameState.boss_attacking.connect(func() -> void: play("roar"))
	GameState.boss_defeated.connect(func() -> void: play("boss_hit", 0.0, 0.7))
	GameState.game_over.connect(func(won: bool, _r: String) -> void: _on_game_over(won))
	GameState.map_completed.connect(func() -> void: play("win", 0.0))
	GameState.chimney_cleared.connect(func(_s: int) -> void: play("merge", 0.0, 0.8))
	GameState.trash_cleared.connect(func(_s: int) -> void: play("place", 0.05, 1.4))
	GameState.tide_flooded.connect(func(_r: int) -> void: play("break", 0.0, 0.6))
	GameState.green_created.connect(func(_s: int) -> void: play("heal"))
	GameState.slots_cooled.connect(func(_s: Array) -> void: play("heal", 0.05, 1.3))
	GameState.armor_broken.connect(func() -> void: play("boss_hit", 0.0, 1.3))
	GameState.boss_forced_up.connect(func() -> void: play("spawn", 0.0, 1.4))
	GameState.shard_placed.connect(func(_s: int) -> void: play("merge", 0.0, 1.2))
	GameState.shard_lost.connect(func(_s: int) -> void: play("hurt", 0.0, 0.7))


## Sesi çalar. pitch_jitter: her çalışta rastgele perde farkı (tekrar hissini azaltır).
func play(sound: String, pitch_jitter := 0.06, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Ayarlardan gelen doğrusal (0..1) ses seviyeleri; temel seviyelerin (sfx/music_volume_db) üstüne uygulanır.
func set_volumes(music: float, sfx: float) -> void:
	var sfx_db := sfx_volume_db + linear_to_db(maxf(sfx, 0.0001))
	for p in _players:
		p.volume_db = sfx_db
	_music_db = music_volume_db + linear_to_db(maxf(music, 0.0001))
	_music.volume_db = _music_db
	_music.stream_paused = music <= 0.001


## Oyunun genel müziğine geç (ana menü açılınca çağrılır).
func play_default_music() -> void:
	_play_music(_default_music)


## Boss savaşındaysa boss'un müziği, değilse genel müzik.
func _update_music() -> void:
	var stream := _default_music
	if GameState.stage == GameState.Stage.BOSS and GameState.boss != null:
		var id := String(GameState.boss.id)
		if not _boss_music.has(id):
			var path := BOSS_MUSIC_DIR % id
			_boss_music[id] = load(path) if ResourceLoader.exists(path) else null
		if _boss_music[id] != null:
			stream = _boss_music[id]
	_play_music(stream)


## Parçayı kısa bir sessizleşme/açılma geçişiyle değiştirir; aynı parça çalıyorsa dokunmaz.
func _play_music(stream: AudioStream) -> void:
	if stream == null or (stream == _target_music and _music.playing):
		return
	_target_music = stream
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	if _music.playing:
		_fade.tween_property(_music, "volume_db", -40.0, MUSIC_FADE_TIME / 2)
	_fade.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	_fade.tween_property(_music, "volume_db", _music_db, MUSIC_FADE_TIME / 2)


func set_music_enabled(on: bool) -> void:
	if on and not _music.playing and _music.stream != null:
		_music.play()
	elif not on:
		_music.stop()


func _on_game_over(won: bool) -> void:
	_music.stop()
	play("win" if won else "lose", 0.0)
	await get_tree().create_timer(3.0).timeout
	if _music.stream != null:
		_music.play()
